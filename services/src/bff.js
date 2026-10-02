// BFF da loja: porta de entrada do app para a jornada de pagamento,
// mais os endpoints do laboratório (cenários, validações, métricas, status).
const express = require('express');
const { journeyMiddleware, forwardHeaders, callService } = require('./journey');
const { logsByExecution, journeyLogs, SERVICE, ENV, VERSION } = require('./logger');
const { validate, CHECKS, LATENCY_LIMITS_MS, REQUIRED_FIELDS } = require('./validator');
const { runJourney } = require('./journey-client');
const SCENARIOS = require('./scenarios');

const PAYMENT_URL = process.env.PAYMENT_URL || 'http://payment:8081';
const ACQUIRER_URL = process.env.ACQUIRER_URL || 'http://acquirer:8082';
const AGENT_HOST = process.env.DD_AGENT_HOST || 'datadog-agent';
const PORT = Number(process.env.PORT || 8080);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const pct = (arr, p) => {
  if (!arr.length) return null;
  const s = [...arr].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.ceil((p / 100) * s.length) - 1)];
};

module.exports = function bffApp() {
  const app = express();
  app.use(express.json());
  app.use(journeyMiddleware);

  const results = new Map(); // executionId -> resultado da validação

  // ---------------- Jornada de pagamento ----------------
  app.post('/api/v1/pagamento/iniciar', async (req, res) => {
    const { orderId, method, amount } = req.body || {};
    const j = { stage: 'pagamento.iniciar', orderId, method, amount, technical: 'success' };
    res.locals.journey = j;
    const r = await callService(`${PAYMENT_URL}/payments`, {
      headers: forwardHeaders(req.ctx, j.stage),
      body: { orderId, method, amount },
    });
    j.paymentId = r.json.paymentId;
    if (!r.ok) {
      j.technical = r.timeout ? 'timeout' : r.json.technical || 'dependency_error';
      return res.status(r.status).json({ error: 'payment_service_error', technical: j.technical });
    }
    return res.status(201).json(r.json);
  });

  app.post('/api/v1/pagamento/:paymentId/autorizar', async (req, res) => {
    const j = { stage: 'pagamento.autorizar', paymentId: req.params.paymentId, technical: 'success' };
    res.locals.journey = j;
    if (req.ctx.scenario === 'contrato_incompleto') j.omit = ['payment.method', 'session.id'];

    const r = await callService(`${PAYMENT_URL}/payments/${encodeURIComponent(req.params.paymentId)}/authorize`, {
      headers: forwardHeaders(req.ctx, j.stage),
      body: req.body || {},
      timeoutMs: 8000,
    });
    const ctxPayment = r.json || {};
    Object.assign(j, { orderId: ctxPayment.orderId, method: ctxPayment.method, amount: ctxPayment.amount });
    if (!r.ok) {
      j.technical = r.timeout ? 'timeout' : ctxPayment.technical || 'dependency_error';
      return res.status(r.status).json({ error: ctxPayment.error || 'payment_service_error', technical: j.technical });
    }
    j.business = ctxPayment.status;
    if (ctxPayment.reason) j.reason = ctxPayment.reason;
    return res.json(ctxPayment);
  });

  app.post('/api/v1/pagamento/:paymentId/confirmar', async (req, res) => {
    const j = { stage: 'pagamento.confirmar', paymentId: req.params.paymentId, technical: 'success' };
    res.locals.journey = j;
    const r = await callService(`${PAYMENT_URL}/payments/${encodeURIComponent(req.params.paymentId)}/confirm`, {
      headers: forwardHeaders(req.ctx, j.stage),
      body: {},
    });
    Object.assign(j, { orderId: r.json.orderId, method: r.json.method, amount: r.json.amount });
    if (!r.ok) {
      j.technical = r.timeout ? 'timeout' : r.json.technical || 'dependency_error';
      if (r.status === 409) {
        j.technical = 'success';
        j.business = r.json.status;
      }
      return res.status(r.status).json(r.json);
    }
    j.business = 'approved';
    return res.json(r.json);
  });

  // ---------------- Laboratório ----------------
  app.get('/health', (_req, res) => res.json({ status: 'up', service: SERVICE }));

  app.get('/api/v1/cenarios', (_req, res) =>
    res.json({ scenarios: SCENARIOS, checks: CHECKS, latencyLimitsMs: LATENCY_LIMITS_MS, requiredFields: REQUIRED_FIELDS }));

  async function validateExecution(executionId, scenarioId) {
    await sleep(150); // dá tempo do log de 'finish' dos serviços downstream
    const remote = await Promise.all(
      [PAYMENT_URL, ACQUIRER_URL].map((u) =>
        callService(`${u}/internal/logs?execution_id=${encodeURIComponent(executionId)}`, { method: 'GET', timeoutMs: 2000 })
          .then((r) => (Array.isArray(r.json) ? r.json : []))),
    );
    const logs = [...logsByExecution(executionId), ...remote.flat()].sort((a, b) => String(a.time).localeCompare(String(b.time)));
    const own = logs.find((l) => l.test && l.test.scenario);
    const scenario = SCENARIOS.find((s) => s.id === (scenarioId || (own && own.test.scenario)));
    const result = validate({ executionId, scenario, logs, bffService: SERVICE });
    results.set(executionId, { ...result, logs });
    if (results.size > 300) results.delete(results.keys().next().value);
    return { ...result, logs };
  }

  app.get('/api/v1/validacoes/:executionId', async (req, res) => {
    const r = await validateExecution(req.params.executionId, req.query.scenario);
    res.json(r);
  });

  app.get('/api/v1/validacoes', (_req, res) => {
    const list = [...results.values()].reverse().map(({ logs, ...rest }) => rest);
    res.json({ total: list.length, items: list.slice(0, 100) });
  });

  app.delete('/api/v1/validacoes', (_req, res) => {
    results.clear();
    res.status(204).end();
  });

  // Suíte completa server-side (usada pelo CI e pelo botão "rodar via backend").
  app.post('/api/v1/suite/executar', async (req, res) => {
    const ids = (req.body && req.body.scenarios) || SCENARIOS.map((s) => s.id);
    const out = [];
    for (const id of ids) {
      const scenario = SCENARIOS.find((s) => s.id === id);
      if (!scenario) continue;
      const run = await runJourney(`http://127.0.0.1:${PORT}`, scenario);
      const { logs, ...v } = await validateExecution(run.executionId, scenario.id);
      out.push(v);
    }
    res.json({
      ok: out.every((r) => r.validatorOk),
      total: out.length,
      validatorOk: out.filter((r) => r.validatorOk).length,
      results: out,
    });
  });

  app.get('/api/v1/metricas', (_req, res) => {
    const steps = journeyLogs().filter((l) => l.service === SERVICE);
    const stages = ['pagamento.iniciar', 'pagamento.autorizar', 'pagamento.confirmar'].map((stage) => {
      const s = steps.filter((l) => l.journey && l.journey.stage === stage);
      const durations = s.map((l) => l.duration_ms).filter((d) => typeof d === 'number');
      const tech = {};
      const biz = {};
      s.forEach((l) => {
        const t = (l.technical && l.technical.outcome) || 'unknown';
        const b = (l.business && l.business.outcome) || 'none';
        tech[t] = (tech[t] || 0) + 1;
        biz[b] = (biz[b] || 0) + 1;
      });
      const success = tech.success || 0;
      return {
        stage,
        total: s.length,
        executions: new Set(s.map((l) => l.test && l.test.execution_id)).size,
        successRate: s.length ? Math.round((success / s.length) * 1000) / 10 : null,
        p50: pct(durations, 50),
        p95: pct(durations, 95),
        limitMs: LATENCY_LIMITS_MS[stage],
        technical: tech,
        business: biz,
      };
    });
    const vals = [...results.values()];
    res.json({
      stages,
      validations: {
        total: vals.length,
        validatorOk: vals.filter((v) => v.validatorOk).length,
        journeyHealthy: vals.filter((v) => v.journeyHealthy).length,
      },
    });
  });

  app.get('/api/v1/status', async (_req, res) => {
    const health = async (url) => {
      const r = await callService(`${url}/health`, { method: 'GET', timeoutMs: 1500 });
      return r.ok ? 'up' : 'down';
    };
    const agent = await callService(`http://${AGENT_HOST}:8126/info`, { method: 'GET', timeoutMs: 800 });
    res.json({
      env: ENV,
      version: VERSION,
      site: process.env.DD_SITE || 'datadoghq.com',
      services: {
        [SERVICE]: 'up',
        [process.env.PAYMENT_SERVICE_NAME || 'loja-payment-service']: await health(PAYMENT_URL),
        [process.env.ACQUIRER_SERVICE_NAME || 'adquirente-mock']: await health(ACQUIRER_URL),
      },
      datadogAgent: agent.ok
        ? { reachable: true, version: agent.json.version || null, host: AGENT_HOST }
        : { reachable: false, host: AGENT_HOST },
    });
  });

  return app;
};

// Contrato mínimo de observabilidade da jornada de pagamento.
// Cada serviço emite UM log "journey.step" por requisição de etapa,
// com os mesmos campos, para que o Datadog consiga classificar e correlacionar.
const { randomUUID } = require('crypto');
const tracer = require('./tracer');
const { logger, unsafeLogger } = require('./logger');

function readCtx(req) {
  return {
    executionId: req.get('x-execution-id') || undefined,
    scenario: req.get('x-test-scenario') || 'none',
    sessionId: req.get('x-session-id') || undefined,
    correlationId: req.get('x-correlation-id') || randomUUID(),
    stage: req.get('x-journey-stage') || undefined,
    rumClient: req.get('x-client-rum') === 'true',
    rumTraceHeaders: Boolean(req.get('x-datadog-trace-id') || req.get('traceparent')),
  };
}

function deletePath(obj, path) {
  const parts = path.split('.');
  let cur = obj;
  for (let i = 0; i < parts.length - 1; i++) {
    if (!cur || typeof cur !== 'object') return;
    cur = cur[parts[i]];
  }
  if (cur && typeof cur === 'object') delete cur[parts[parts.length - 1]];
}

// Middleware: cria contexto, loggers filhos e o log journey.step ao final.
function journeyMiddleware(req, res, next) {
  if (/^\/(health|internal)/.test(req.path)) return next();

  const start = process.hrtime.bigint();
  const ctx = readCtx(req);
  const span = tracer.scope().active();
  const bindings = {
    test: { execution_id: ctx.executionId, scenario: ctx.scenario },
    correlation: { id: ctx.correlationId },
  };
  req.ctx = ctx;
  req.log = logger.child(bindings);
  req.unsafeLog = unsafeLogger.child(bindings);
  res.set('x-correlation-id', ctx.correlationId);

  res.on('finish', () => {
    const j = res.locals.journey;
    if (!j) return;
    const durationMs = Math.round((Number(process.hrtime.bigint() - start) / 1e6) * 10) / 10;
    const record = {
      event: 'journey.step',
      journey: { name: 'pagamento', stage: j.stage },
      session: { id: ctx.sessionId },
      order: { id: j.orderId },
      payment: { id: j.paymentId, method: j.method, amount: j.amount },
      http: { method: req.method, url_path: req.route ? req.baseUrl + req.route.path : req.path, status_code: res.statusCode },
      duration_ms: durationMs,
      technical: { outcome: j.technical },
      business: { outcome: j.business || 'none' },
      rum: { client: ctx.rumClient, trace_headers: ctx.rumTraceHeaders },
    };
    if (j.reason) record.business.reason = j.reason;
    (j.omit || []).forEach((p) => deletePath(record, p));

    if (span) {
      span.setTag('journey.stage', j.stage);
      span.setTag('technical.outcome', j.technical);
      span.setTag('business.outcome', j.business || 'none');
      span.setTag('payment.method', j.method);
      span.setTag('test.scenario', ctx.scenario);
    }
    const write = () => req.log.info(record, `journey ${j.stage} -> ${res.statusCode} (${j.technical}/${record.business.outcome})`);
    span ? tracer.scope().activate(span, write) : write();
  });

  next();
}

// Cabeçalhos propagados entre serviços (além dos headers de trace do dd-trace).
function forwardHeaders(ctx, stage, { dropCorrelation = false } = {}) {
  const h = {
    'content-type': 'application/json',
    'x-execution-id': ctx.executionId || '',
    'x-test-scenario': ctx.scenario,
    'x-session-id': ctx.sessionId || '',
    'x-journey-stage': stage,
  };
  if (!dropCorrelation) h['x-correlation-id'] = ctx.correlationId;
  return h;
}

// Chamada HTTP com timeout. detachTrace=true inicia um trace novo (simula quebra).
async function callService(url, { method = 'POST', body, headers, timeoutMs = 5000, detachTrace = false }) {
  const doFetch = () =>
    fetch(url, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
  try {
    const r = detachTrace ? await tracer.scope().activate(null, doFetch) : await doFetch();
    let json = {};
    try {
      json = await r.json();
    } catch (_) {
      /* corpo vazio */
    }
    return { ok: r.ok, status: r.status, json };
  } catch (err) {
    const timeout = err.name === 'TimeoutError' || err.name === 'AbortError';
    return { ok: false, status: timeout ? 504 : 502, json: {}, error: timeout ? 'timeout' : err.message, timeout };
  }
}

module.exports = { journeyMiddleware, forwardHeaders, callService };

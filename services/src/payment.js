// payment-service simulado: orquestra a autorização com o adquirente.
const express = require('express');
const { randomUUID } = require('crypto');
const { journeyMiddleware, forwardHeaders, callService } = require('./journey');

const ACQUIRER_URL = process.env.ACQUIRER_URL || 'http://acquirer:8082';
const ACQUIRER_TIMEOUT_MS = Number(process.env.ACQUIRER_TIMEOUT_MS || 2000);

module.exports = function paymentApp() {
  const app = express();
  app.use(express.json());
  app.use(journeyMiddleware);

  const payments = new Map();

  app.post('/payments', (req, res) => {
    const { orderId, method, amount } = req.body || {};
    const id = `pay_${randomUUID().slice(0, 12)}`;
    payments.set(id, { id, orderId, method, amount, status: 'created' });
    if (payments.size > 5000) payments.delete(payments.keys().next().value);
    res.locals.journey = { stage: 'pagamento.iniciar', paymentId: id, orderId, method, amount, technical: 'success' };
    res.status(201).json({ paymentId: id, status: 'created' });
  });

  app.post('/payments/:id/authorize', async (req, res) => {
    const p = payments.get(req.params.id);
    const ctx = req.ctx;
    const j = { stage: 'pagamento.autorizar', paymentId: req.params.id, technical: 'success' };
    res.locals.journey = j;
    if (!p) {
      j.technical = 'internal_error';
      return res.status(404).json({ error: 'payment_not_found', technical: j.technical });
    }
    const meta = { orderId: p.orderId, method: p.method, amount: p.amount };
    Object.assign(j, meta);

    const card = (req.body && req.body.card) || null;
    if (card) {
      // Logger padrão: o cartão sai como [REDACTED].
      req.log.info({ card }, 'dados do meio de pagamento recebidos');
      // Cenário de falha proposital: logger inseguro.
      if (ctx.scenario === 'vazamento_pan') {
        req.unsafeLog.warn({ card, debug: `payload=${JSON.stringify(card)}` }, 'DEBUG payload recebido do BFF');
      }
    }

    const broken = ctx.scenario === 'quebra_correlacao';
    const r = await callService(`${ACQUIRER_URL}/authorize`, {
      headers: forwardHeaders(ctx, 'pagamento.autorizar', { dropCorrelation: broken }),
      body: { paymentId: p.id, orderId: p.orderId, method: p.method, amount: p.amount, cardLast4: card ? String(card.number).slice(-4) : undefined },
      timeoutMs: ACQUIRER_TIMEOUT_MS,
      detachTrace: broken,
    });

    if (r.timeout) {
      j.technical = 'timeout';
      req.log.error({ error: { kind: 'AcquirerTimeout', timeout_ms: ACQUIRER_TIMEOUT_MS } }, 'timeout chamando adquirente');
      return res.status(504).json({ error: 'acquirer_timeout', technical: j.technical, ...meta });
    }
    if (!r.ok) {
      j.technical = 'dependency_error';
      req.log.error({ error: { kind: 'AcquirerError', upstream_status: r.status } }, 'adquirente devolveu erro');
      return res.status(502).json({ error: 'acquirer_error', technical: j.technical, upstreamStatus: r.status, ...meta });
    }

    p.status = r.json.decision;
    j.business = r.json.decision;
    if (r.json.reason) j.reason = r.json.reason;
    return res.json({ paymentId: p.id, status: p.status, reason: r.json.reason, technical: j.technical, ...meta });
  });

  app.post('/payments/:id/confirm', (req, res) => {
    const p = payments.get(req.params.id);
    const j = { stage: 'pagamento.confirmar', paymentId: req.params.id, technical: 'success' };
    res.locals.journey = j;
    if (!p) {
      j.technical = 'internal_error';
      return res.status(404).json({ error: 'payment_not_found', technical: j.technical });
    }
    const meta = { orderId: p.orderId, method: p.method, amount: p.amount };
    Object.assign(j, meta);
    if (p.status !== 'approved') {
      j.business = p.status;
      return res.status(409).json({ error: 'payment_not_approved', status: p.status, technical: j.technical, ...meta });
    }
    p.status = 'confirmed';
    j.business = 'approved';
    return res.json({ paymentId: p.id, status: 'confirmed', technical: j.technical, ...meta });
  });

  return app;
};

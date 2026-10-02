// Adquirente simulado (dependência externa da jornada).
const express = require('express');
const { journeyMiddleware } = require('./journey');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const jitter = (min, max) => Math.round(min + Math.random() * (max - min));

module.exports = function acquirerApp() {
  const app = express();
  app.use(express.json());
  app.use(journeyMiddleware);

  app.post('/authorize', async (req, res) => {
    const { paymentId, orderId, method, amount } = req.body || {};
    const scenario = req.ctx.scenario;
    const j = { stage: 'pagamento.autorizar', paymentId, orderId, method, amount, technical: 'success' };
    res.locals.journey = j;

    if (scenario === 'timeout_adquirente') await sleep(3000);
    else if (scenario === 'lentidao') await sleep(jitter(1350, 1500));
    else await sleep(jitter(60, 220));

    if (scenario === 'erro_adquirente') {
      j.technical = 'internal_error';
      req.log.error({ error: { kind: 'AcquirerUnavailable', message: 'falha interna simulada' } }, 'adquirente indisponível');
      return res.status(500).json({ error: 'acquirer_internal_error' });
    }
    if (scenario === 'recusado') {
      j.business = 'declined';
      j.reason = 'saldo_insuficiente';
      return res.json({ decision: 'declined', reason: 'saldo_insuficiente', authorizationCode: null });
    }
    if (scenario === 'pix_pendente' || method === 'pix') {
      j.business = 'pending';
      return res.json({ decision: 'pending', authorizationCode: null });
    }
    j.business = 'approved';
    return res.json({ decision: 'approved', authorizationCode: `AUT${Date.now().toString().slice(-6)}` });
  });

  return app;
};

// Executa a jornada de pagamento como o app faria (iniciar → autorizar → confirmar).
// Usado pela suíte server-side e pelo script de CI. O dashboard Flutter tem a
// mesma lógica em Dart, para que as chamadas saiam do navegador (RUM).
const { randomUUID } = require('crypto');

// Cartão de teste público (Visa de homologação). Nunca use dados reais aqui.
const TEST_CARD = { number: '4111111111111111', cvv: '123', expiry: '12/30', holder: 'TESTE LAB' };

async function runJourney(baseUrl, scenario, { sessionId } = {}) {
  const executionId = `exec_${randomUUID().slice(0, 8)}`;
  const headers = {
    'content-type': 'application/json',
    'x-execution-id': executionId,
    'x-test-scenario': scenario.id,
    'x-session-id': sessionId || `sess_cli_${randomUUID().slice(0, 8)}`,
    'x-correlation-id': randomUUID(),
    'x-client-rum': 'false',
  };
  const steps = [];
  const call = async (stage, path, body) => {
    const t = Date.now();
    let status = 0;
    let json = {};
    try {
      const r = await fetch(baseUrl + path, { method: 'POST', headers, body: JSON.stringify(body) });
      status = r.status;
      try {
        json = await r.json();
      } catch (_) {
        /* vazio */
      }
    } catch (err) {
      json = { error: err.message };
    }
    steps.push({ stage, status, ms: Date.now() - t, body: json });
    return { ok: status >= 200 && status < 300, json };
  };

  const orderId = `ord_${randomUUID().slice(0, 8)}`;
  const a = await call('pagamento.iniciar', '/api/v1/pagamento/iniciar', { orderId, method: scenario.metodo, amount: 129.9 });
  if (a.ok) {
    const pid = a.json.paymentId;
    const body = scenario.metodo === 'credit_card' ? { card: TEST_CARD } : {};
    const b = await call('pagamento.autorizar', `/api/v1/pagamento/${pid}/autorizar`, body);
    if (b.ok && b.json.status === 'approved') {
      await call('pagamento.confirmar', `/api/v1/pagamento/${pid}/confirmar`, {});
    }
  }
  return { executionId, steps };
}

module.exports = { runJourney, TEST_CARD };

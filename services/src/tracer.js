// Precisa ser o primeiro require do processo (ver src/index.js).
// Configuração por variáveis de ambiente (Unified Service Tagging):
//   DD_ENV, DD_SERVICE, DD_VERSION, DD_AGENT_HOST, DD_LOGS_INJECTION
const tracer = require('dd-trace').init({
  logInjection: true,
  runtimeMetrics: false,
  startupLogs: false,
});

// Rotas de infraestrutura do laboratório não devem poluir o APM.
const ignore = [
  /\/health/,
  /\/internal\//,
  /\/api\/v1\/status/,
  /\/api\/v1\/metricas/,
  /\/api\/v1\/validacoes/,
  /\/api\/v1\/cenarios$/,
  /:8126\//,
];
// A suíte server-side chama o próprio BFF; cada jornada deve começar um trace novo,
// como acontece quando o app não tem RUM.
const clientIgnore = [...ignore, /127\.0\.0\.1:\d+\/api\/v1\/pagamento/];

tracer.use('http', { server: { blocklist: ignore }, client: { blocklist: clientIgnore } });
tracer.use('fetch', { blocklist: clientIgnore });

module.exports = tracer;

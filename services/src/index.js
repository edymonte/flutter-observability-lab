// O tracer precisa ser carregado antes de express/http/fetch.
require('./tracer');
const { logger, logsByExecution, SERVICE } = require('./logger');

const ROLE = process.env.ROLE || 'bff';
const DEFAULT_PORTS = { bff: 8080, payment: 8081, acquirer: 8082 };
const PORT = Number(process.env.PORT || DEFAULT_PORTS[ROLE]);

const factories = {
  bff: () => require('./bff')(),
  payment: () => require('./payment')(),
  acquirer: () => require('./acquirer')(),
};
if (!factories[ROLE]) {
  logger.fatal({ role: ROLE }, 'ROLE inválido (use bff, payment ou acquirer)');
  process.exit(1);
}

const app = factories[ROLE]();

// Endpoints comuns (o BFF já define /health).
if (ROLE !== 'bff') app.get('/health', (_req, res) => res.json({ status: 'up', service: SERVICE }));
app.get('/internal/logs', (req, res) => res.json(logsByExecution(String(req.query.execution_id || ''))));

app.listen(PORT, () => logger.info({ role: ROLE, port: PORT }, `${SERVICE} ouvindo na porta ${PORT}`));

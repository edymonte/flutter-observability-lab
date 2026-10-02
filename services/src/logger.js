const pino = require('pino');
const { maskPanInString } = require('./sensitive');

const ENV = process.env.DD_ENV || 'lab';
const SERVICE = process.env.DD_SERVICE || 'unknown-service';
const VERSION = process.env.DD_VERSION || '0.1.0';

// Buffer em memória: permite que o validador leia os logs de cada serviço
// sem depender do Datadog. No ambiente real, essa leitura é feita no Log Explorer.
const RING_MAX = Number(process.env.LOG_RING_SIZE || 5000);
const ring = [];
const ringStream = {
  write(line) {
    try {
      ring.push(JSON.parse(line));
      if (ring.length > RING_MAX) ring.shift();
    } catch (_) {
      /* linha não-JSON: ignora */
    }
  },
};

const streams = pino.multistream([{ stream: process.stdout }, { stream: ringStream }]);

const baseOptions = {
  messageKey: 'message',
  timestamp: pino.stdTimeFunctions.isoTime,
  base: { env: ENV, service: SERVICE, version: VERSION },
  formatters: { level: (label) => ({ level: label }) },
};

// Logger padrão: redaction de campos sensíveis + máscara de PAN em mensagens.
const logger = pino(
  {
    ...baseOptions,
    redact: {
      paths: ['card.number', 'card.cvv', 'card.expiry', '*.card.number', '*.card.cvv', 'payer.cpf', '*.payer.cpf'],
      censor: '[REDACTED]',
    },
    hooks: {
      logMethod(args, method) {
        method.apply(
          this,
          args.map((a) => (typeof a === 'string' ? maskPanInString(a) : a)),
        );
      },
    },
  },
  streams,
);

// Logger SEM proteção. Existe apenas para o cenário "vazamento_pan", que simula
// um desenvolvedor contornando o logger padrão. Serve para provar que a
// validação de dados sensíveis detecta o problema.
const unsafeLogger = pino(baseOptions, streams);

function logsByExecution(executionId) {
  return ring.filter((l) => l.test && l.test.execution_id === executionId);
}

function journeyLogs() {
  return ring.filter((l) => l.event === 'journey.step');
}

module.exports = { logger, unsafeLogger, logsByExecution, journeyLogs, ENV, SERVICE, VERSION };

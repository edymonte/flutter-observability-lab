// Validador do contrato de observabilidade.
// Lê os logs de uma execução em todos os serviços e aplica as regras que
// depois serão aplicadas no Datadog (pipelines, monitors, Sensitive Data Scanner).
const { scanRecord } = require('./sensitive');

const LATENCY_LIMITS_MS = {
  'pagamento.iniciar': Number(process.env.SLO_INICIAR_MS || 500),
  'pagamento.autorizar': Number(process.env.SLO_AUTORIZAR_MS || 1000),
  'pagamento.confirmar': Number(process.env.SLO_CONFIRMAR_MS || 500),
};

const REQUIRED_FIELDS = [
  'journey.stage',
  'session.id',
  'order.id',
  'payment.id',
  'payment.method',
  'correlation.id',
  'http.status_code',
  'duration_ms',
  'technical.outcome',
  'business.outcome',
];

const CHECKS = {
  'tags.unificadas': 'Unified Service Tagging (env, service, version) em todos os logs',
  'contrato.campos': 'Campos obrigatórios do contrato em todo journey.step',
  'correlacao.trace': 'Mesmo trace_id em BFF → payment → adquirente, por etapa',
  'correlacao.id': 'Mesmo correlation.id em todos os serviços da execução',
  'correlacao.app_backend': 'Headers de trace do RUM chegando ao BFF (app → backend)',
  classificacao: 'Etapas e outcome técnico/negócio conforme esperado',
  dados_sensiveis: 'Nenhum PAN, CVV ou CPF em logs',
  latencia: 'Duração de cada etapa no BFF dentro do limite',
};

const get = (obj, path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);

function validate({ executionId, scenario, logs, bffService }) {
  const steps = logs.filter((l) => l.event === 'journey.step');
  const bffSteps = steps.filter((l) => l.service === bffService);
  const checks = [];
  const add = (id, status, detail, evidence) => {
    const expected = scenario && scenario.expectedFailures.includes(id) ? 'fail' : 'pass';
    checks.push({ id, title: CHECKS[id], status, expected, matched: status === 'skip' || status === expected, detail, evidence });
  };

  // 1. Unified Service Tagging
  const untagged = logs.filter((l) => !l.env || !l.service || !l.version);
  add('tags.unificadas', untagged.length ? 'fail' : 'pass',
    untagged.length ? `${untagged.length} log(s) sem env/service/version` : `${logs.length} log(s) com env/service/version`);

  // 2. Contrato mínimo
  const missing = [];
  steps.forEach((s) => {
    REQUIRED_FIELDS.forEach((f) => {
      const v = get(s, f);
      if (v === undefined || v === null || v === '') missing.push(`${s.service} ${get(s, 'journey.stage') || '?'}: ${f}`);
    });
  });
  add('contrato.campos', !steps.length ? 'fail' : missing.length ? 'fail' : 'pass',
    !steps.length ? 'nenhum journey.step encontrado' : missing.length ? `${missing.length} campo(s) ausente(s)` : `${steps.length} journey.step completos`,
    missing.slice(0, 20));

  // 3. Correlação por trace_id
  const byStage = {};
  steps.forEach((s) => {
    const st = get(s, 'journey.stage') || 'desconhecida';
    (byStage[st] = byStage[st] || []).push({ service: s.service, trace_id: get(s, 'dd.trace_id') || null });
  });
  const traceProblems = [];
  const traceEvidence = [];
  Object.entries(byStage).forEach(([stage, arr]) => {
    const ids = new Set(arr.map((a) => a.trace_id));
    traceEvidence.push({ stage, services: arr });
    if (ids.has(null)) traceProblems.push(`${stage}: log sem dd.trace_id (dd-trace/log injection)`);
    else if (ids.size > 1) traceProblems.push(`${stage}: ${ids.size} trace_ids diferentes entre ${arr.map((a) => a.service).join(', ')}`);
  });
  add('correlacao.trace', !steps.length || traceProblems.length ? 'fail' : 'pass',
    traceProblems.length ? traceProblems.join('; ') : `${Object.keys(byStage).length} etapa(s) com trace único`, traceEvidence);

  // 4. correlation.id
  const corrIds = [...new Set(logs.map((l) => get(l, 'correlation.id')).filter(Boolean))];
  add('correlacao.id', corrIds.length === 1 ? 'pass' : 'fail',
    corrIds.length === 1 ? `correlation.id ${corrIds[0]}` : `${corrIds.length} correlation.id distintos`, corrIds);

  // 5. App → backend (RUM)
  const rumClient = bffSteps.some((s) => get(s, 'rum.client') === true);
  if (!rumClient) {
    add('correlacao.app_backend', 'skip', 'RUM desativado no cliente (sem client token) ou execução via CLI');
  } else {
    const without = bffSteps.filter((s) => get(s, 'rum.trace_headers') !== true);
    add('correlacao.app_backend', without.length ? 'fail' : 'pass',
      without.length ? `${without.length} chamada(s) sem headers de trace do RUM (verifique allowedTracingUrls/firstPartyHosts)` : 'RUM injetou trace headers em todas as chamadas');
  }

  // 6. Classificação
  const stagesSeen = bffSteps.map((s) => get(s, 'journey.stage'));
  const auth = bffSteps.find((s) => get(s, 'journey.stage') === 'pagamento.autorizar');
  const classProblems = [];
  if (scenario) {
    if (JSON.stringify(stagesSeen) !== JSON.stringify(scenario.expectedStages)) {
      classProblems.push(`etapas: esperado [${scenario.expectedStages.join(', ')}], obtido [${stagesSeen.join(', ')}]`);
    }
    if (!auth) classProblems.push('etapa de autorização não encontrada no BFF');
    else {
      const t = get(auth, 'technical.outcome');
      const b = get(auth, 'business.outcome');
      if (t !== scenario.expectedOutcome.technical) classProblems.push(`technical.outcome: esperado ${scenario.expectedOutcome.technical}, obtido ${t}`);
      if (b !== scenario.expectedOutcome.business) classProblems.push(`business.outcome: esperado ${scenario.expectedOutcome.business}, obtido ${b}`);
    }
  }
  add('classificacao', classProblems.length ? 'fail' : 'pass',
    classProblems.length ? classProblems.join('; ') : `etapas [${stagesSeen.join(' → ')}], autorização ${auth ? `${get(auth, 'technical.outcome')}/${get(auth, 'business.outcome')}` : '-'}`);

  // 7. Dados sensíveis
  const findings = [];
  logs.forEach((l) => scanRecord(l).forEach((f) => findings.push({ service: l.service, message: l.message, ...f })));
  add('dados_sensiveis', findings.length ? 'fail' : 'pass',
    findings.length ? `${findings.length} ocorrência(s): ${[...new Set(findings.map((f) => `${f.type} em ${f.service}`))].join(', ')}` : `${logs.length} log(s) varridos, nada encontrado`,
    findings.slice(0, 10));

  // 8. Latência
  const slow = bffSteps
    .map((s) => ({ stage: get(s, 'journey.stage'), ms: s.duration_ms, limit: LATENCY_LIMITS_MS[get(s, 'journey.stage')] }))
    .filter((x) => x.limit && x.ms > x.limit);
  add('latencia', slow.length ? 'fail' : 'pass',
    slow.length ? slow.map((x) => `${x.stage} ${x.ms}ms > ${x.limit}ms`).join('; ') : 'todas as etapas dentro do limite',
    bffSteps.map((s) => ({ stage: get(s, 'journey.stage'), duration_ms: s.duration_ms })));

  const failed = checks.filter((c) => c.status === 'fail').map((c) => c.id);
  const validatorOk = checks.every((c) => c.matched);
  const traceId = bffSteps.length ? get(bffSteps[0], 'dd.trace_id') : null;

  return {
    executionId,
    scenario: scenario ? scenario.id : null,
    scenarioName: scenario ? scenario.nome : null,
    timestamp: new Date().toISOString(),
    validatorOk,
    journeyHealthy: failed.length === 0,
    failed,
    checks,
    stages: bffSteps.map((s) => ({
      stage: get(s, 'journey.stage'),
      status: get(s, 'http.status_code'),
      duration_ms: s.duration_ms,
      technical: get(s, 'technical.outcome'),
      business: get(s, 'business.outcome'),
      trace_id: get(s, 'dd.trace_id') || null,
    })),
    traceId,
    logCount: logs.length,
  };
}

module.exports = { validate, CHECKS, LATENCY_LIMITS_MS, REQUIRED_FIELDS };

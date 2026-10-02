List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

Map<String, int> _counts(dynamic v) {
  if (v is! Map) return {};
  return v.map((k, val) => MapEntry(k.toString(), (val as num).toInt()));
}

double? _num(dynamic v) => v is num ? v.toDouble() : null;

class Scenario {
  final String id;
  final String nome;
  final String grupo;
  final String metodo;
  final String descricao;
  final String objetivo;
  final List<String> expectedStages;
  final List<String> expectedFailures;
  final String expectedTechnical;
  final String expectedBusiness;

  Scenario({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.metodo,
    required this.descricao,
    required this.objetivo,
    required this.expectedStages,
    required this.expectedFailures,
    required this.expectedTechnical,
    required this.expectedBusiness,
  });

  factory Scenario.fromJson(Map<String, dynamic> j) {
    final outcome = (j['expectedOutcome'] as Map?) ?? {};
    return Scenario(
      id: j['id'] as String,
      nome: j['nome'] as String,
      grupo: (j['grupo'] as String?) ?? 'Outros',
      metodo: (j['metodo'] as String?) ?? 'credit_card',
      descricao: (j['descricao'] as String?) ?? '',
      objetivo: (j['objetivo'] as String?) ?? '',
      expectedStages: _strings(j['expectedStages']),
      expectedFailures: _strings(j['expectedFailures']),
      expectedTechnical: (outcome['technical'] ?? '-').toString(),
      expectedBusiness: (outcome['business'] ?? '-').toString(),
    );
  }
}

class Catalog {
  final List<Scenario> scenarios;
  final Map<String, String> checks;
  final Map<String, int> latencyLimitsMs;
  final List<String> requiredFields;

  Catalog({required this.scenarios, required this.checks, required this.latencyLimitsMs, required this.requiredFields});

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        scenarios: (j['scenarios'] as List).map((e) => Scenario.fromJson(e as Map<String, dynamic>)).toList(),
        checks: ((j['checks'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
        latencyLimitsMs: _counts(j['latencyLimitsMs']),
        requiredFields: _strings(j['requiredFields']),
      );
}

class CheckResult {
  final String id;
  final String title;
  final String status; // pass | fail | skip
  final String expected; // pass | fail
  final bool matched;
  final String detail;
  final dynamic evidence;

  CheckResult({
    required this.id,
    required this.title,
    required this.status,
    required this.expected,
    required this.matched,
    required this.detail,
    required this.evidence,
  });

  factory CheckResult.fromJson(Map<String, dynamic> j) => CheckResult(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? j['id'] as String,
        status: j['status'] as String,
        expected: (j['expected'] as String?) ?? 'pass',
        matched: j['matched'] == true,
        detail: (j['detail'] ?? '').toString(),
        evidence: j['evidence'],
      );
}

class StageResult {
  final String stage;
  final int? status;
  final double? durationMs;
  final String technical;
  final String business;
  final String? traceId;

  StageResult({
    required this.stage,
    required this.status,
    required this.durationMs,
    required this.technical,
    required this.business,
    required this.traceId,
  });

  factory StageResult.fromJson(Map<String, dynamic> j) => StageResult(
        stage: (j['stage'] ?? '?').toString(),
        status: (j['status'] as num?)?.toInt(),
        durationMs: _num(j['duration_ms']),
        technical: (j['technical'] ?? '-').toString(),
        business: (j['business'] ?? '-').toString(),
        traceId: j['trace_id'] as String?,
      );
}

class ClientStep {
  final String stage;
  final int status;
  final int ms;
  ClientStep(this.stage, this.status, this.ms);
}

class Validation {
  final String executionId;
  final String? scenario;
  final String? scenarioName;
  final DateTime timestamp;
  final bool validatorOk;
  final bool journeyHealthy;
  final List<String> failed;
  final List<CheckResult> checks;
  final List<StageResult> stages;
  final String? traceId;
  final List<Map<String, dynamic>> logs;
  final List<ClientStep> clientSteps;
  final String origin; // navegador | backend

  Validation({
    required this.executionId,
    required this.scenario,
    required this.scenarioName,
    required this.timestamp,
    required this.validatorOk,
    required this.journeyHealthy,
    required this.failed,
    required this.checks,
    required this.stages,
    required this.traceId,
    required this.logs,
    required this.clientSteps,
    required this.origin,
  });

  factory Validation.fromJson(Map<String, dynamic> j, {List<ClientStep> clientSteps = const [], String origin = 'backend'}) =>
      Validation(
        executionId: j['executionId'] as String,
        scenario: j['scenario'] as String?,
        scenarioName: j['scenarioName'] as String?,
        timestamp: DateTime.tryParse((j['timestamp'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        validatorOk: j['validatorOk'] == true,
        journeyHealthy: j['journeyHealthy'] == true,
        failed: _strings(j['failed']),
        checks: ((j['checks'] as List?) ?? []).map((e) => CheckResult.fromJson(e as Map<String, dynamic>)).toList(),
        stages: ((j['stages'] as List?) ?? []).map((e) => StageResult.fromJson(e as Map<String, dynamic>)).toList(),
        traceId: j['traceId'] as String?,
        logs: ((j['logs'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
        clientSteps: clientSteps,
        origin: origin,
      );
}

class StageMetric {
  final String stage;
  final int total;
  final int executions;
  final double? successRate;
  final double? p50;
  final double? p95;
  final int? limitMs;
  final Map<String, int> technical;
  final Map<String, int> business;

  StageMetric({
    required this.stage,
    required this.total,
    required this.executions,
    required this.successRate,
    required this.p50,
    required this.p95,
    required this.limitMs,
    required this.technical,
    required this.business,
  });

  factory StageMetric.fromJson(Map<String, dynamic> j) => StageMetric(
        stage: j['stage'] as String,
        total: (j['total'] as num?)?.toInt() ?? 0,
        executions: (j['executions'] as num?)?.toInt() ?? 0,
        successRate: _num(j['successRate']),
        p50: _num(j['p50']),
        p95: _num(j['p95']),
        limitMs: (j['limitMs'] as num?)?.toInt(),
        technical: _counts(j['technical']),
        business: _counts(j['business']),
      );
}

class Metrics {
  final List<StageMetric> stages;
  final int validationsTotal;
  final int validatorOk;
  final int journeyHealthy;

  Metrics({required this.stages, required this.validationsTotal, required this.validatorOk, required this.journeyHealthy});

  factory Metrics.fromJson(Map<String, dynamic> j) {
    final v = (j['validations'] as Map?) ?? {};
    return Metrics(
      stages: ((j['stages'] as List?) ?? []).map((e) => StageMetric.fromJson(e as Map<String, dynamic>)).toList(),
      validationsTotal: (v['total'] as num?)?.toInt() ?? 0,
      validatorOk: (v['validatorOk'] as num?)?.toInt() ?? 0,
      journeyHealthy: (v['journeyHealthy'] as num?)?.toInt() ?? 0,
    );
  }
}

class LabStatus {
  final String env;
  final String version;
  final String site;
  final Map<String, String> services;
  final bool agentReachable;
  final String? agentVersion;

  LabStatus({
    required this.env,
    required this.version,
    required this.site,
    required this.services,
    required this.agentReachable,
    required this.agentVersion,
  });

  factory LabStatus.fromJson(Map<String, dynamic> j) {
    final agent = (j['datadogAgent'] as Map?) ?? {};
    return LabStatus(
      env: (j['env'] ?? 'lab').toString(),
      version: (j['version'] ?? '-').toString(),
      site: (j['site'] ?? 'datadoghq.com').toString(),
      services: ((j['services'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      agentReachable: agent['reachable'] == true,
      agentVersion: agent['version']?.toString(),
    );
  }
}

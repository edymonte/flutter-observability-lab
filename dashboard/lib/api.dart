import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'obs_bridge.dart';

/// Cliente do BFF. As chamadas da jornada saem do navegador, como no app real,
/// para que o RUM (quando habilitado) injete os headers de trace.
class LabApi {
  final http.Client _client = http.Client();
  final Random _rnd = Random();

  // Cartão de teste público (Visa de homologação). Nunca use dados reais.
  static const testCard = {'number': '4111111111111111', 'cvv': '123', 'expiry': '12/30', 'holder': 'TESTE LAB'};

  Uri _u(String path) => Uri.base.resolve(path);

  String hex(int n) => List.generate(n, (_) => _rnd.nextInt(16).toRadixString(16)).join();
  String uuid() => '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';

  Future<Map<String, dynamic>> _getJson(String path) async {
    final r = await _client.get(_u(path));
    if (r.statusCode >= 400) throw Exception('GET $path -> ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<LabStatus> status() async => LabStatus.fromJson(await _getJson('/api/v1/status'));
  Future<Catalog> catalog() async => Catalog.fromJson(await _getJson('/api/v1/cenarios'));
  Future<Metrics> metrics() async => Metrics.fromJson(await _getJson('/api/v1/metricas'));

  Future<List<Validation>> history() async {
    final j = await _getJson('/api/v1/validacoes');
    return ((j['items'] as List?) ?? []).map((e) => Validation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> clearHistory() async {
    await _client.delete(_u('/api/v1/validacoes'));
  }

  /// Executa a suíte inteira pelo backend (sem RUM), igual ao CI.
  Future<List<Validation>> runSuiteBackend() async {
    final r = await _client.post(_u('/api/v1/suite/executar'), headers: {'content-type': 'application/json'}, body: '{}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return ((j['results'] as List?) ?? []).map((e) => Validation.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Executa a jornada iniciar -> autorizar -> confirmar a partir do navegador.
  Future<Validation> runJourney(Scenario s, {required String sessionId, required bool rum}) async {
    final executionId = 'exec_${hex(8)}';
    final headers = {
      'content-type': 'application/json',
      'x-execution-id': executionId,
      'x-test-scenario': s.id,
      'x-session-id': sessionId,
      'x-correlation-id': uuid(),
      'x-client-rum': rum ? 'true' : 'false',
    };
    final steps = <ClientStep>[];

    Future<Map<String, dynamic>?> call(String stage, String path, Map<String, dynamic> body) async {
      final sw = Stopwatch()..start();
      int status = 0;
      Map<String, dynamic> json = {};
      try {
        final r = await _client.post(_u(path), headers: headers, body: jsonEncode(body));
        status = r.statusCode;
        try {
          json = jsonDecode(r.body) as Map<String, dynamic>;
        } catch (_) {}
      } catch (e) {
        json = {'error': e.toString()};
      }
      sw.stop();
      steps.add(ClientStep(stage, status, sw.elapsedMilliseconds));
      final attrs = {
        'journey.stage': stage,
        'test.scenario': s.id,
        'test.execution_id': executionId,
        'http.status_code': status,
        'duration_ms': sw.elapsedMilliseconds,
      };
      if (status >= 200 && status < 300) {
        Obs.action('pagamento.etapa', attrs);
        return json;
      }
      Obs.error('Falha na etapa $stage', attrs);
      return null;
    }

    final orderId = 'ord_${hex(8)}';
    final a = await call('pagamento.iniciar', '/api/v1/pagamento/iniciar', {'orderId': orderId, 'method': s.metodo, 'amount': 129.9});
    if (a != null) {
      final pid = a['paymentId'];
      final b = await call(
        'pagamento.autorizar',
        '/api/v1/pagamento/$pid/autorizar',
        s.metodo == 'credit_card' ? {'card': testCard} : <String, dynamic>{},
      );
      if (b != null && b['status'] == 'approved') {
        await call('pagamento.confirmar', '/api/v1/pagamento/$pid/confirmar', {});
      }
    }

    final v = await _getJson('/api/v1/validacoes/$executionId?scenario=${s.id}');
    return Validation.fromJson(v, clientSteps: steps, origin: 'navegador');
  }
}

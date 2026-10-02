import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'obs_bridge.dart';
import 'widgets/common.dart';
import 'widgets/contract_view.dart';
import 'widgets/health_view.dart';
import 'widgets/scenario_panel.dart';
import 'widgets/validations_view.dart';

void main() => runApp(const LabApp());

class LabApp extends StatelessWidget {
  const LabApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          brightness: b,
          colorSchemeSeed: const Color(0xFF5B5BD6),
          visualDensity: VisualDensity.compact,
        );
    return MaterialApp(
      title: 'Payment Observability Lab',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = LabApi();
  late final String sessionId = 'sess_web_${api.hex(10)}';

  Catalog? catalog;
  Metrics? metrics;
  LabStatus? status;
  ObsInfo obs = ObsInfo.empty;
  String? error;
  final List<Validation> history = [];
  final Set<String> running = {};
  bool busy = false;
  int loadSize = 30;
  String? progress;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final c = await api.catalog();
      final h = await api.history();
      setState(() {
        catalog = c;
        history
          ..clear()
          ..addAll(h);
      });
    } catch (e) {
      setState(() => error = 'Não foi possível falar com o BFF: $e');
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await api.status();
      final m = await api.metrics();
      if (!mounted) return;
      setState(() {
        status = s;
        metrics = m;
        obs = Obs.info();
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'BFF indisponível: $e');
    }
  }

  bool get _rumActive => obs.rumLoaded;

  Future<Validation?> _runOne(Scenario s, {bool record = true}) async {
    setState(() => running.add(s.id));
    try {
      final v = await api.runJourney(s, sessionId: sessionId, rum: _rumActive);
      if (record) setState(() => history.insert(0, v));
      return v;
    } catch (e) {
      _snack('Erro executando ${s.nome}: $e');
      return null;
    } finally {
      if (mounted) setState(() => running.remove(s.id));
    }
  }

  Future<void> _guard(String label, Future<void> Function() body) async {
    setState(() {
      busy = true;
      progress = label;
    });
    try {
      await body();
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
      await _refresh();
    }
  }

  Future<void> _runSuite() => _guard('Rodando suíte…', () async {
        final c = catalog;
        if (c == null) return;
        var ok = 0;
        for (var i = 0; i < c.scenarios.length; i++) {
          setState(() => progress = 'Suíte ${i + 1}/${c.scenarios.length}: ${c.scenarios[i].nome}');
          final v = await _runOne(c.scenarios[i]);
          if (v?.validatorOk == true) ok++;
        }
        _snack('Suíte concluída: $ok/${c.scenarios.length} cenários com o validador conforme o esperado.');
      });

  Future<void> _runSuiteBackend() => _guard('Rodando suíte pelo backend…', () async {
        final r = await api.runSuiteBackend();
        setState(() => history.insertAll(0, r.reversed));
        final ok = r.where((v) => v.validatorOk).length;
        _snack('Suíte (backend): $ok/${r.length} conforme o esperado.');
      });

  Future<void> _runLoad() => _guard('Gerando volume…', () async {
        final c = catalog;
        if (c == null) return;
        // Mistura realista: maioria aprovada, um pouco de negócio e de falha técnica.
        const weights = {
          'aprovado': 60,
          'pix_pendente': 10,
          'recusado': 12,
          'erro_adquirente': 6,
          'lentidao': 8,
          'timeout_adquirente': 4,
        };
        final pool = <Scenario>[];
        weights.forEach((id, w) {
          final s = c.scenarios.where((x) => x.id == id);
          if (s.isNotEmpty) pool.addAll(List.filled(w, s.first));
        });
        final rnd = Random();
        const parallel = 5;
        var done = 0;
        while (done < loadSize) {
          final batch = min(parallel, loadSize - done);
          await Future.wait(List.generate(batch, (_) => _runOne(pool[rnd.nextInt(pool.length)], record: false)));
          done += batch;
          if (mounted) setState(() => progress = 'Volume: $done/$loadSize jornadas');
        }
        _snack('$loadSize jornadas executadas. Veja a aba "Saúde por etapa".');
      });

  Future<void> _clear() async {
    await api.clearHistory();
    setState(() => history.clear());
    await _refresh();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1100;
      final panel = ScenarioPanel(
        catalog: catalog,
        running: running,
        busy: busy,
        sessionId: sessionId,
        rumActive: _rumActive,
        loadSize: loadSize,
        onRun: (s) => _runOne(s).then((_) => _refresh()),
        onRunSuite: _runSuite,
        onRunSuiteBackend: _runSuiteBackend,
        onRunLoad: _runLoad,
        onLoadSizeChanged: (v) => setState(() => loadSize = v),
        onClear: _clear,
      );
      final tabs = <(String, IconData, Widget)>[
        if (!wide) ('Cenários', Icons.science_outlined, panel),
        ('Validações', Icons.fact_check_outlined, ValidationsView(items: history, datadogAppUrl: obs.appUrl, env: status?.env ?? obs.env)),
        ('Saúde por etapa', Icons.monitor_heart_outlined, HealthView(metrics: metrics)),
        ('Contrato', Icons.rule_folder_outlined, ContractView(catalog: catalog)),
      ];

      return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: const Text('Payment Observability Lab', style: TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              _StatusChips(status: status, obs: obs),
              IconButton(tooltip: 'Atualizar', onPressed: _refresh, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Column(children: [
                TabBar(isScrollable: !wide, tabs: [for (final t in tabs) Tab(icon: Icon(t.$2, size: 18), text: t.$1, height: 46)]),
                SizedBox(height: 4, child: busy ? const LinearProgressIndicator() : null),
              ]),
            ),
          ),
          body: Column(children: [
            if (error != null)
              MaterialBanner(
                content: Text(error!),
                leading: const Icon(Icons.cloud_off, color: Palette.bad),
                actions: [TextButton(onPressed: _bootstrap, child: const Text('Tentar de novo'))],
              ),
            if (progress != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(progress!, style: Theme.of(context).textTheme.bodySmall),
              ),
            Expanded(
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SizedBox(width: 400, child: panel),
                      const VerticalDivider(width: 1),
                      Expanded(child: TabBarView(children: [for (final t in tabs) t.$3])),
                    ])
                  : TabBarView(children: [for (final t in tabs) t.$3]),
            ),
          ]),
        ),
      );
    });
  }
}

class _StatusChips extends StatelessWidget {
  final LabStatus? status;
  final ObsInfo obs;
  const _StatusChips({required this.status, required this.obs});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final allUp = s != null && s.services.values.every((v) => v == 'up');
    final width = MediaQuery.of(context).size.width;
    final chips = <Widget>[
      Pill('env: ${s?.env ?? obs.env}', color: Palette.info),
      Tooltip(
        message: s == null ? 'aguardando' : s.services.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        child: Pill(allUp ? 'serviços ok' : 'serviço fora', color: allUp ? Palette.ok : Palette.bad, icon: Icons.dns_outlined),
      ),
      Tooltip(
        message: s?.agentReachable == true
            ? 'Datadog Agent ${s?.agentVersion ?? ''} recebendo traces e logs'
            : 'Agent não encontrado: tudo é validado localmente. Suba com --profile datadog para enviar ao Datadog.',
        child: Pill(s?.agentReachable == true ? 'Agent conectado' : 'modo local',
            color: s?.agentReachable == true ? Palette.ok : Palette.skip, icon: Icons.pets_outlined),
      ),
      Tooltip(
        message: obs.error ?? (obs.rumLoaded ? 'Sessão RUM ${obs.rumSessionId ?? ''}' : 'Defina DD_RUM_APPLICATION_ID e DD_RUM_CLIENT_TOKEN'),
        child: Pill(obs.rumLoaded ? 'RUM ativo' : 'RUM off',
            color: obs.rumLoaded ? Palette.ok : (obs.error != null ? Palette.bad : Palette.skip), icon: Icons.phone_android),
      ),
    ];
    if (width < 700) return chips[1];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final c in chips) Padding(padding: const EdgeInsets.only(left: 6), child: c),
    ]);
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../obs_bridge.dart';
import 'common.dart';

class ValidationsView extends StatelessWidget {
  final List<Validation> items;
  final String datadogAppUrl;
  final String env;
  const ValidationsView({super.key, required this.items, required this.datadogAppUrl, required this.env});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Nenhuma validação ainda. Execute um cenário ou a suíte completa.', textAlign: TextAlign.center),
        ),
      );
    }
    final ok = items.where((v) => v.validatorOk).length;
    final healthy = items.where((v) => v.journeyHealthy).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 200, child: Kpi(label: 'Execuções', value: '${items.length}')),
          SizedBox(
            width: 200,
            child: Kpi(
              label: 'Validador conforme o esperado',
              value: '$ok/${items.length}',
              color: ok == items.length ? Palette.ok : Palette.bad,
              hint: 'falhas esperadas foram detectadas',
            ),
          ),
          SizedBox(
            width: 200,
            child: Kpi(label: 'Jornadas 100% saudáveis', value: '$healthy/${items.length}', hint: 'sem nenhuma validação falhando'),
          ),
        ]),
        const SizedBox(height: 16),
        for (var i = 0; i < items.length; i++)
          _ValidationTile(v: items[i], initiallyExpanded: i == 0, appUrl: datadogAppUrl, env: env),
      ],
    );
  }
}

class _ValidationTile extends StatelessWidget {
  final Validation v;
  final bool initiallyExpanded;
  final String appUrl;
  final String env;
  const _ValidationTile({required this.v, required this.initiallyExpanded, required this.appUrl, required this.env});

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final expectedFails = v.checks.where((c) => c.status == 'fail' && c.expected == 'fail').length;
    final unexpected = v.checks.where((c) => !c.matched).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(v.executionId),
        initiallyExpanded: initiallyExpanded,
        leading: Icon(
          v.validatorOk ? Icons.verified_outlined : Icons.report_gmailerrorred,
          color: v.validatorOk ? Palette.ok : Palette.bad,
        ),
        title: Text(v.scenarioName ?? v.scenario ?? 'cenário desconhecido', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_time(v.timestamp)} · ${v.executionId} · via ${v.origin}', style: t.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (v.journeyHealthy) const Pill('jornada saudável', color: Palette.ok),
            if (!v.journeyHealthy && v.validatorOk) Pill('$expectedFails falha(s) esperada(s) detectada(s)', color: Palette.warn),
            if (!v.validatorOk) Pill('${unexpected.length} divergência(s)', color: Palette.bad, filled: true),
          ]),
        ]),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StagesRow(v: v),
          const SizedBox(height: 12),
          for (final c in v.checks) _CheckRow(c: c),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => Obs.open('$appUrl/logs?query=${Uri.encodeComponent('@test.execution_id:${v.executionId}')}'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Logs no Datadog'),
            ),
            if (v.traceId != null)
              OutlinedButton.icon(
                onPressed: () => Obs.open('$appUrl/apm/traces?query=${Uri.encodeComponent('env:$env @test.scenario:${v.scenario}')}'),
                icon: const Icon(Icons.account_tree_outlined, size: 16),
                label: const Text('Traces no Datadog'),
              ),
            if (v.traceId != null)
              SelectableText('trace_id (BFF): ${v.traceId}', style: t.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ]),
          if (v.logs.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Logs coletados (${v.logs.length})', style: t.textTheme.labelLarge),
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 420),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      v.logs.map((l) => const JsonEncoder.withIndent('  ').convert(l)).join('\n'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StagesRow extends StatelessWidget {
  final Validation v;
  const _StagesRow({required this.v});

  @override
  Widget build(BuildContext context) {
    if (v.stages.isEmpty) return const Text('Nenhuma etapa registrada no BFF.');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < v.stages.length; i++) ...[
          if (i > 0) const Icon(Icons.arrow_forward, size: 16),
          _StageChip(s: v.stages[i]),
        ],
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  final StageResult s;
  const _StageChip({required this.s});

  @override
  Widget build(BuildContext context) {
    final color = Palette.technical(s.technical);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(0.08),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(stageLabels[s.stage] ?? s.stage, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('HTTP ${s.status ?? '-'} · ${s.durationMs?.toStringAsFixed(0) ?? '-'} ms', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Pill(technicalLabels[s.technical] ?? s.technical, color: color),
          const SizedBox(width: 4),
          Pill(businessLabels[s.business] ?? s.business, color: Palette.business(s.business)),
        ]),
      ]),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final CheckResult c;
  const _CheckRow({required this.c});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (IconData icon, Color color) = switch (c.status) {
      'pass' => (Icons.check_circle, Palette.ok),
      'fail' => (Icons.cancel, c.matched ? Palette.warn : Palette.bad),
      _ => (Icons.remove_circle_outline, Palette.skip),
    };
    final verdict = c.status == 'skip'
        ? 'não aplicável'
        : c.matched
            ? (c.status == 'fail' ? 'falhou, como esperado' : 'ok')
            : (c.expected == 'fail' ? 'deveria falhar e passou' : 'falha inesperada');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: c.id, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              TextSpan(text: '  ${c.title}', style: t.textTheme.bodySmall),
            ])),
            Text(c.detail, style: t.textTheme.bodySmall),
            if (c.status == 'fail' && c.evidence is List && (c.evidence as List).isNotEmpty && c.id != 'latencia' && c.id != 'correlacao.trace')
              Text(
                (c.evidence as List).take(6).map((e) => e is Map ? e.entries.map((x) => '${x.key}=${x.value}').join(' ') : '$e').join('\n'),
                style: t.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: color),
              ),
            if (c.id == 'correlacao.trace' && c.evidence is List) _TraceEvidence(evidence: c.evidence as List),
          ]),
        ),
        const SizedBox(width: 8),
        Pill(verdict, color: c.matched ? (c.status == 'skip' ? Palette.skip : Palette.ok) : Palette.bad),
      ]),
    );
  }
}

class _TraceEvidence extends StatelessWidget {
  final List evidence;
  const _TraceEvidence({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in evidence.whereType<Map>()) ...[
          Text('${e['stage']}', style: style?.copyWith(fontWeight: FontWeight.w700)),
          for (final s in ((e['services'] as List?) ?? []).whereType<Map>())
            Text('  ${s['service']}: ${s['trace_id'] ?? '(sem trace_id)'}', style: style),
        ],
      ]),
    );
  }
}

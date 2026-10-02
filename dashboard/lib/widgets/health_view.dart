import 'package:flutter/material.dart';

import '../models.dart';
import 'common.dart';

/// Visão operacional: o que o dashboard do Datadog deve mostrar, calculado localmente.
class HealthView extends StatelessWidget {
  final Metrics? metrics;
  const HealthView({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    if (m == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context);
    final first = m.stages.isEmpty ? 0 : m.stages.first.executions;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Semáforo de sucesso técnico por etapa (< 80% vermelho, 80–90% amarelo, ≥ 90% verde). '
          'Recusa e pendência são resultado de negócio e não derrubam a taxa técnica.',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1000 ? 3 : (c.maxWidth > 640 ? 2 : 1);
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final s in m.stages) SizedBox(width: w, child: _StageCard(s: s)),
          ]);
        }),
        const SizedBox(height: 20),
        SectionTitle('Funil da jornada (execuções que chegaram a cada etapa)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              for (final s in m.stages)
                HBar(
                  label: stageLabels[s.stage] ?? s.stage,
                  value: s.executions.toDouble(),
                  max: first.toDouble(),
                  color: Palette.info,
                  trailing: first == 0 ? '-' : '${s.executions} (${(s.executions * 100 / first).toStringAsFixed(0)}%)',
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A queda entre Autorizar e Confirmar é esperada para recusas, pendências e erros. '
          'No Datadog, o funil só deve ser publicado quando a sequência de eventos estiver comprovada.',
          style: t.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  final StageMetric s;
  const _StageCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = Palette.successRate(s.successRate);
    final p95Bad = s.p95 != null && s.limitMs != null && s.p95! > s.limitMs!;
    final techMax = s.technical.values.fold<int>(0, (a, b) => a > b ? a : b);
    final bizMax = s.business.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 5))),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(stageLabels[s.stage] ?? s.stage, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            Text(s.stage, style: t.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _Metric(label: 'Sucesso técnico', value: s.successRate == null ? '-' : '${s.successRate!.toStringAsFixed(1)}%', color: color),
            _Metric(label: 'Volume', value: '${s.total}'),
            _Metric(label: 'p50', value: s.p50 == null ? '-' : '${s.p50!.toStringAsFixed(0)} ms'),
            _Metric(
              label: 'p95 (limite ${s.limitMs ?? '-'} ms)',
              value: s.p95 == null ? '-' : '${s.p95!.toStringAsFixed(0)} ms',
              color: p95Bad ? Palette.bad : null,
            ),
          ]),
          const SizedBox(height: 12),
          Text('technical.outcome', style: t.textTheme.labelSmall),
          for (final e in s.technical.entries)
            HBar(label: technicalLabels[e.key] ?? e.key, value: e.value.toDouble(), max: techMax.toDouble(), color: Palette.technical(e.key), trailing: '${e.value}'),
          const SizedBox(height: 8),
          Text('business.outcome', style: t.textTheme.labelSmall),
          for (final e in s.business.entries)
            HBar(label: businessLabels[e.key] ?? e.key, value: e.value.toDouble(), max: bizMax.toDouble(), color: Palette.business(e.key), trailing: '${e.value}'),
          if (s.total == 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Sem dados ainda.', style: t.textTheme.bodySmall)),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Metric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.textTheme.bodySmall, maxLines: 2),
        Text(value, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

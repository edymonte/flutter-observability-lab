import 'package:flutter/material.dart';

import '../models.dart';
import 'common.dart';

class ScenarioPanel extends StatelessWidget {
  final Catalog? catalog;
  final Set<String> running;
  final bool busy;
  final String sessionId;
  final bool rumActive;
  final int loadSize;
  final void Function(Scenario) onRun;
  final VoidCallback onRunSuite;
  final VoidCallback onRunSuiteBackend;
  final VoidCallback onRunLoad;
  final ValueChanged<int> onLoadSizeChanged;
  final VoidCallback onClear;

  const ScenarioPanel({
    super.key,
    required this.catalog,
    required this.running,
    required this.busy,
    required this.sessionId,
    required this.rumActive,
    required this.loadSize,
    required this.onRun,
    required this.onRunSuite,
    required this.onRunSuiteBackend,
    required this.onRunLoad,
    required this.onLoadSizeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = catalog;
    if (c == null) return const Center(child: CircularProgressIndicator());

    final groups = <String, List<Scenario>>{};
    for (final s in c.scenarios) {
      groups.putIfAbsent(s.grupo, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle('Executar'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Sessão: $sessionId', style: t.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
              const SizedBox(height: 4),
              Text(
                rumActive
                    ? 'Chamadas saem do navegador com RUM: a correlação app → backend será validada.'
                    : 'RUM desligado: a validação app → backend fica como "não aplicável".',
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : onRunSuite,
                icon: const Icon(Icons.playlist_play),
                label: Text('Rodar suíte completa (${c.scenarios.length})'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : onRunSuiteBackend,
                icon: const Icon(Icons.dns_outlined),
                label: const Text('Rodar suíte pelo backend (modo CI)'),
              ),
              const Divider(height: 24),
              Text('Gerar volume para o painel de saúde', style: t.textTheme.labelLarge),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: loadSize.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    label: '$loadSize',
                    onChanged: busy ? null : (v) => onLoadSizeChanged(v.round()),
                  ),
                ),
                SizedBox(width: 36, child: Text('$loadSize', textAlign: TextAlign.right)),
              ]),
              OutlinedButton.icon(
                onPressed: busy ? null : onRunLoad,
                icon: const Icon(Icons.bolt_outlined),
                label: Text('Rodar $loadSize jornadas mistas'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: busy ? null : onClear,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Limpar histórico de validações'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in groups.entries) ...[
          SectionTitle(entry.key),
          for (final s in entry.value) _ScenarioCard(s: s, running: running.contains(s.id), disabled: busy, onRun: () => onRun(s)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final Scenario s;
  final bool running;
  final bool disabled;
  final VoidCallback onRun;
  const _ScenarioCard({required this.s, required this.running, required this.disabled, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(s.nome, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Pill(s.metodo == 'pix' ? 'PIX' : 'Cartão', color: Palette.info),
              ]),
              const SizedBox(height: 4),
              Text(s.descricao, style: t.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text('Objetivo: ${s.objetivo}', style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                Pill('esperado: ${technicalLabels[s.expectedTechnical] ?? s.expectedTechnical} / ${businessLabels[s.expectedBusiness] ?? s.expectedBusiness}',
                    color: Palette.skip),
                for (final f in s.expectedFailures) Pill('deve falhar: $f', color: Palette.warn, icon: Icons.flag_outlined),
              ]),
            ]),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: running
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5))
                : IconButton(
                    tooltip: 'Executar cenário',
                    onPressed: disabled ? null : onRun,
                    icon: const Icon(Icons.play_circle_fill, size: 32),
                  ),
          ),
        ]),
      ),
    );
  }
}

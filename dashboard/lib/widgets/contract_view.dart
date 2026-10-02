import 'package:flutter/material.dart';

import '../models.dart';
import 'common.dart';

/// O que está sendo validado e como cada regra vira recurso no Datadog.
class ContractView extends StatelessWidget {
  final Catalog? catalog;
  const ContractView({super.key, required this.catalog});

  static const _datadogMap = [
    ('tags.unificadas', 'Unified Service Tagging', 'DD_ENV / DD_SERVICE / DD_VERSION nos serviços e labels com.datadoghq.tags.* nos containers'),
    ('contrato.campos', 'Log Pipeline + Monitor', 'Remappers para os atributos e monitor de logs journey.step sem @payment.method ou @session.id'),
    ('correlacao.trace', 'APM + Log injection', 'DD_LOGS_INJECTION=true; o trace deve conter BFF → payment → adquirente'),
    ('correlacao.id', 'Log Pipeline', 'Facet @correlation.id; header x-correlation-id propagado em todos os hops'),
    ('correlacao.app_backend', 'RUM ↔ APM', 'firstPartyHosts (Flutter) / allowedTracingUrls (web) apontando para o BFF'),
    ('classificacao', 'Category Processor', '@technical.outcome e @business.outcome separados; recusa não é erro técnico'),
    ('dados_sensiveis', 'Sensitive Data Scanner', 'Regras de PAN, CVV e CPF com ação de redact antes da indexação'),
    ('latencia', 'SLO / Monitor', 'p95 de @duration_ms por @journey.stage, só depois do baseline'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = catalog;
    final t = Theme.of(context);
    if (c == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle('Validações → recurso no Datadog'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              for (final (id, resource, how) in _datadogMap)
                ListTile(
                  dense: true,
                  title: Text.rich(TextSpan(children: [
                    TextSpan(text: id, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                    TextSpan(text: '  ${c.checks[id] ?? ''}'),
                  ])),
                  subtitle: Text('$resource — $how'),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle('Campos obrigatórios em todo journey.step'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in c.requiredFields) Pill(f, color: Palette.info),
        ]),
        const SizedBox(height: 16),
        SectionTitle('Limites de latência por etapa (BFF)'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in c.latencyLimitsMs.entries) Pill('${stageLabels[e.key] ?? e.key}: ${e.value} ms', color: Palette.skip),
        ]),
        const SizedBox(height: 16),
        Text(
          'Os limites são do laboratório (variáveis SLO_*_MS). Em produção, defina-os a partir do baseline real.',
          style: t.textTheme.bodySmall,
        ),
      ],
    );
  }
}

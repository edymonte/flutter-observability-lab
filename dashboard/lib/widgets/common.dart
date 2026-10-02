import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

class Palette {
  static const ok = Color(0xFF2E9E5B);
  static const warn = Color(0xFFE0A100);
  static const bad = Color(0xFFD9443B);
  static const skip = Color(0xFF8A8F98);
  static const info = Color(0xFF4F7CFF);

  /// Semáforo herdado do dashboard do técnico de campo: <80 vermelho, 80–90 amarelo, ≥90 verde.
  static Color successRate(double? v) {
    if (v == null) return skip;
    if (v < 80) return bad;
    if (v < 90) return warn;
    return ok;
  }

  static Color technical(String t) => switch (t) {
        'success' => ok,
        'timeout' => warn,
        _ => bad,
      };

  static Color business(String b) => switch (b) {
        'approved' => ok,
        'pending' => info,
        'declined' => warn,
        _ => skip,
      };
}

const stageLabels = {
  'pagamento.iniciar': 'Iniciar',
  'pagamento.autorizar': 'Autorizar',
  'pagamento.confirmar': 'Confirmar',
};

const technicalLabels = {
  'success': 'sucesso',
  'timeout': 'timeout',
  'dependency_error': 'erro de dependência',
  'internal_error': 'erro interno',
};

const businessLabels = {
  'approved': 'aprovado',
  'declined': 'recusado',
  'pending': 'pendente',
  'none': 'sem decisão',
};

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool filled;
  const Pill(this.text, {super.key, required this.color, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: filled ? Colors.white : color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: filled ? Colors.white : color)),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final String? hint;
  const Kpi({super.key, required this.label, required this.value, this.color, this.hint});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
          if (hint != null) ...[const SizedBox(height: 2), Text(hint!, style: t.textTheme.bodySmall)],
        ]),
      ),
    );
  }
}

/// Barra horizontal simples (sem dependências de gráficos).
class HBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final String trailing;
  const HBar({super.key, required this.label, required this.value, required this.max, required this.color, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 14, color: color.withOpacity(0.12)),
              FractionallySizedBox(widthFactor: frac, child: Container(height: 14, color: color)),
            ]),
          ),
        ),
        SizedBox(width: 64, child: Text(trailing, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum PillTone { teal, orange, blue, green }

/// Etiqueta redondeada para estados ("En revisión", "Paso 1 de 3", ...).
class StatusPill extends StatelessWidget {
  const StatusPill(this.texto, {super.key, this.tono = PillTone.teal});

  final String texto;
  final PillTone tono;

  @override
  Widget build(BuildContext context) {
    final c = context.acColors;
    final (fondo, frente) = switch (tono) {
      PillTone.teal => (c.tealBg, c.tealFg),
      PillTone.orange => (c.orangeBg, c.orangeFg),
      PillTone.blue => (c.blueBg, c.blueFg),
      PillTone.green => (c.greenBg, c.greenFg),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(texto, style: TextStyle(color: frente, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

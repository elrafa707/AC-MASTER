import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../models/equipo.dart';
import 'status_pill.dart';

/// Historial cronológico del equipo, del registro más reciente al más antiguo (RF-08).
class LineaTiempo extends StatelessWidget {
  const LineaTiempo({super.key, required this.registros});

  final List<RegistroHistorial> registros;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, r) in registros.indexed)
          _Elemento(registro: r, esUltimo: i == registros.length - 1),
      ],
    );
  }
}

class _Elemento extends StatelessWidget {
  const _Elemento({required this.registro, required this.esUltimo});

  final RegistroHistorial registro;
  final bool esUltimo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final (icono, tono, fondo, frente) = switch (registro.tipo) {
      TipoRegistro.instalacion => (Icons.home_repair_service_outlined, PillTone.blue, c.blueBg, c.blueFg),
      TipoRegistro.mantenimiento => (Icons.cleaning_services_outlined, PillTone.green, c.greenBg, c.greenFg),
      TipoRegistro.reparacion => (Icons.build_outlined, PillTone.orange, c.orangeBg, c.orangeFg),
      TipoRegistro.autoayuda => (Icons.check_circle_outline_rounded, PillTone.green, c.greenBg, c.greenFg),
      TipoRegistro.prediccion => (Icons.auto_awesome_outlined, PillTone.teal, c.tealBg, c.tealFg),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icono, size: 18, color: frente),
                ),
                if (!esUltimo)
                  Expanded(child: Container(width: 2, color: tema.colorScheme.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltimo ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(registro.tipo.etiqueta, tono: tono),
                      Text(fechaCorta(registro.fecha), style: tema.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(registro.titulo, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                  if (registro.descripcion != null) ...[
                    const SizedBox(height: 2),
                    Text(registro.descripcion!, style: tema.textTheme.bodySmall),
                  ],
                  if (registro.tecnicoNombre != null) ...[
                    const SizedBox(height: 2),
                    Text('Técnico: ${registro.tecnicoNombre}', style: tema.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

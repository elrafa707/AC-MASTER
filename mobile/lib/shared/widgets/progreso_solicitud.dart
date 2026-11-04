import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../models/solicitud.dart';

const _pasos = [EstadoSolicitud.enRevision, EstadoSolicitud.cotizado, EstadoSolicitud.enCamino, EstadoSolicitud.finalizado];

/// Avance de la solicitud en sus cuatro fases (RF-05).
class ProgresoSolicitud extends StatelessWidget {
  const ProgresoSolicitud({super.key, required this.estado});

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) {
    final c = context.acColors;
    final cs = Theme.of(context).colorScheme;
    if (estado == EstadoSolicitud.cancelada) {
      return Row(
        children: [
          Icon(Icons.cancel_outlined, color: c.orangeFg),
          const SizedBox(width: 8),
          Expanded(child: Text('Esta solicitud fue cancelada', style: TextStyle(color: c.orangeFg, fontWeight: FontWeight.w700))),
        ],
      );
    }
    // Cada fase ocupa el mismo ancho; las líneas que las unen se dibujan a los lados del círculo.
    Color color(bool hecho) => hecho ? cs.primary : cs.outlineVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, paso) in _pasos.indexed)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : color(paso.paso <= estado.paso))),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: paso.paso <= estado.paso ? cs.primary : cs.surfaceContainer,
                        border: Border.all(color: color(paso.paso <= estado.paso)),
                      ),
                      child: paso.paso < estado.paso || estado == EstadoSolicitud.finalizado
                          ? Icon(Icons.check_rounded, size: 16, color: cs.onPrimary)
                          : paso == estado
                              ? Icon(Icons.circle, size: 10, color: cs.onPrimary)
                              : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == _pasos.length - 1 ? Colors.transparent : color(_pasos[i + 1].paso <= estado.paso),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  paso.etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: paso == estado ? FontWeight.w700 : FontWeight.w500,
                    color: paso.paso <= estado.paso ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lista cronológica de eventos de la solicitud.
class EventosSolicitud extends StatelessWidget {
  const EventosSolicitud({super.key, required this.eventos});

  final List<EventoSolicitud> eventos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    final lista = eventos.reversed.toList();
    return Column(
      children: [
        for (final (i, e) in lista.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? cs.primary : cs.outline),
                      ),
                      if (i < lista.length - 1) Expanded(child: Container(width: 2, color: cs.outlineVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < lista.length - 1 ? 14 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.titulo, style: tema.textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                        if (e.detalle != null) Text(e.detalle!, style: tema.textTheme.bodySmall),
                        Text(fechaHora(e.fecha), style: tema.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

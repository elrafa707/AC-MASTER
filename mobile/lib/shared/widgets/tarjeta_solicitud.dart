import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/solicitud.dart';
import 'estado_pill.dart';

/// Fila de una solicitud en las listas. [mostrarCliente] la adapta a la vista del administrador.
class TarjetaSolicitud extends StatelessWidget {
  const TarjetaSolicitud({super.key, required this.solicitud, required this.alTocar, this.mostrarCliente = false});

  final ResumenSolicitud solicitud;
  final VoidCallback alTocar;
  final bool mostrarCliente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final s = solicitud;
    final linea = mostrarCliente ? '${s.clienteNombre} · ${s.colonia}' : s.equipo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        key: Key('solicitud-${s.id}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s.folio, style: tema.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    const Spacer(),
                    EstadoPill(s.estado),
                  ],
                ),
                const SizedBox(height: 8),
                Text(s.falla, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(linea, style: tema.textTheme.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (mostrarCliente) PrioridadPill(s.prioridad),
                    if (s.ventanaInicio != null && s.estado.activa)
                      _Dato(icono: Icons.event_outlined, texto: fechaHora(s.ventanaInicio!))
                    else
                      _Dato(icono: Icons.schedule_rounded, texto: fechaCorta(s.fechaCreacion)),
                    if (s.totalCotizacion != null && s.estado != EstadoSolicitud.enRevision)
                      _Dato(icono: Icons.payments_outlined, texto: pesos(s.totalCotizacion!)),
                    if (s.tecnicoNombre != null && mostrarCliente) _Dato(icono: Icons.engineering_outlined, texto: s.tecnicoNombre!),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icono, size: 14, color: estilo?.color), const SizedBox(width: 4), Text(texto, style: estilo)],
    );
  }
}

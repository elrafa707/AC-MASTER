import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/solicitud.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/estado_pill.dart';
import '../../shared/widgets/progreso_solicitud.dart';
import '../../shared/widgets/resumen_orden.dart';
import '../../shared/widgets/section_label.dart';
import 'calificar_servicio.dart';

/// Interfaz 4: seguimiento de la solicitud y respuesta a la cotización (RF-05).
class SeguimientoScreen extends ConsumerWidget {
  const SeguimientoScreen({super.key, required this.solicitudId});

  final int solicitudId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitud = ref.watch(solicitudProvider(solicitudId));
    return Scaffold(
      appBar: AppBar(title: Text(solicitud.value?.folio ?? 'Mi solicitud')),
      body: switch (solicitud) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.refresh(solicitudProvider(solicitudId).future),
            child: _Contenido(solicitud: value),
          ),
        AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(solicitudProvider(solicitudId))),
        _ => const Cargando(),
      },
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.solicitud});

  final Solicitud solicitud;

  Future<void> _actuar(BuildContext context, WidgetRef ref, Future<Solicitud> Function() accion, String exito) async {
    final ok = await ejecutarConAviso(context, () async {
      await accion();
      ref
        ..invalidate(solicitudProvider(solicitud.id))
        ..invalidate(misSolicitudesProvider)
        ..invalidate(notificacionesProvider);
    }, exito: exito);
    if (!ok) ref.invalidate(solicitudProvider(solicitud.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final s = solicitud;
    final repo = ref.read(solicitudesRepositoryProvider);
    final cotizacionPendiente = s.estado == EstadoSolicitud.cotizado && s.cotizacion != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(s.resumen.equipo, style: tema.textTheme.bodySmall)),
                    EstadoPill(s.estado),
                  ],
                ),
                const SizedBox(height: 8),
                Text(s.diagnostico.falla, style: tema.textTheme.titleLarge),
                const SizedBox(height: 18),
                ProgresoSolicitud(estado: s.estado),
              ],
            ),
          ),
        ),
        if (s.estado == EstadoSolicitud.enRevision) ...[
          const SizedBox(height: 12),
          _Aviso(
            icono: Icons.hourglass_top_rounded,
            texto: 'Estamos revisando tu caso para asignar al técnico adecuado y preparar la cotización.',
            fondo: c.blueBg,
            frente: c.blueFg,
          ),
        ],
        if (s.estado == EstadoSolicitud.enCamino) ...[
          const SizedBox(height: 12),
          s.resumen.llegada != null
              ? _Aviso(
                  icono: Icons.where_to_vote_rounded,
                  texto: 'Tu técnico llegó el ${fechaHora(s.resumen.llegada!)}.',
                  fondo: c.greenBg,
                  frente: c.greenFg,
                )
              : _Aviso(
                  icono: Icons.directions_car_outlined,
                  texto: 'Tu visita está confirmada. Te avisaremos cuando el técnico llegue.',
                  fondo: c.tealBg,
                  frente: c.tealFg,
                ),
        ],
        if (s.estado == EstadoSolicitud.finalizado) ...[
          const SizedBox(height: 18),
          const SectionLabel('Califica el servicio'),
          CalificarServicio(solicitud: s),
          if (s.orden != null) ...[
            const SizedBox(height: 18),
            const SectionLabel('Resumen del servicio'),
            ResumenOrden(orden: s.orden!),
          ],
        ],
        if (s.tecnico != null) ...[
          const SizedBox(height: 18),
          const SectionLabel('Tu técnico'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: c.tealBg,
                foregroundColor: c.tealFg,
                child: Text(s.tecnico!.nombre.characters.first),
              ),
              title: Text(s.tecnico!.nombre, style: tema.textTheme.titleMedium),
              subtitle: Text(
                [
                  '★ ${s.tecnico!.calificacion.toStringAsFixed(1)}',
                  if (s.resumen.ventanaInicio != null) fechaHora(s.resumen.ventanaInicio!),
                  if (s.tecnico!.telefono != null) 'Tel. ${s.tecnico!.telefono}',
                ].join(' · '),
                style: tema.textTheme.bodySmall,
              ),
            ),
          ),
          if (s.tecnico!.telefono == null && s.estado == EstadoSolicitud.cotizado)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Podrás contactarlo cuando apruebes la cotización.', style: tema.textTheme.bodySmall),
            ),
        ],
        if (s.cotizacion != null) ...[
          const SizedBox(height: 18),
          const SectionLabel('Cotización'),
          _TarjetaCotizacion(cotizacion: s.cotizacion!),
        ],
        if (cotizacionPendiente) ...[
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('boton-aprobar'),
            onPressed: () async {
              final ok = await confirmar(
                context,
                titulo: '¿Aprobar la cotización?',
                mensaje: 'Agendaremos la visita de ${s.tecnico?.nombre ?? 'tu técnico'} por ${pesos(s.cotizacion!.total)}.',
                textoConfirmar: 'Aprobar',
              );
              if (ok && context.mounted) _actuar(context, ref, () => repo.aprobar(s.id), 'Cotización aprobada');
            },
            child: const Text('Aprobar cotización'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('boton-rechazar'),
            onPressed: () async {
              final motivo = await pedirMotivo(context, titulo: '¿Rechazar la cotización?', textoConfirmar: 'Rechazar');
              if (motivo != null && context.mounted) {
                _actuar(context, ref, () => repo.rechazar(s.id, motivo: motivo.isEmpty ? null : motivo), 'Cotización rechazada');
              }
            },
            child: const Text('Rechazar'),
          ),
        ],
        const SizedBox(height: 18),
        const SectionLabel('Dirección del servicio'),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: const Icon(Icons.place_outlined),
            title: Text(s.direccion.alias, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
            subtitle: Text(s.direccion.completa, style: tema.textTheme.bodySmall),
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Línea de tiempo'),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: EventosSolicitud(eventos: s.eventos))),
        if (s.estado == EstadoSolicitud.enRevision) ...[
          const SizedBox(height: 12),
          TextButton(
            key: const Key('boton-cancelar-solicitud'),
            style: TextButton.styleFrom(foregroundColor: tema.colorScheme.error),
            onPressed: () async {
              final motivo = await pedirMotivo(context, titulo: '¿Cancelar la solicitud?', textoConfirmar: 'Sí, cancelar');
              if (motivo != null && context.mounted) {
                _actuar(context, ref, () => repo.cancelar(s.id, motivo: motivo.isEmpty ? null : motivo), 'Solicitud cancelada');
              }
            },
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ],
    );
  }
}

class _TarjetaCotizacion extends StatelessWidget {
  const _TarjetaCotizacion({required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: const Key('tarjeta-cotizacion'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final p in cotizacion.partidas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(p.cantidad > 1 ? '${p.concepto} × ${p.cantidad}' : p.concepto, style: tema.textTheme.bodyMedium)),
                    const SizedBox(width: 12),
                    Text(pesos(p.importe), style: tema.textTheme.bodyMedium),
                  ],
                ),
              ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: Text('Total', style: tema.textTheme.titleMedium)),
                Text(pesos(cotizacion.total), style: tema.textTheme.titleLarge),
              ],
            ),
            if (cotizacion.comentarioCliente != null) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text('Motivo del rechazo: ${cotizacion.comentarioCliente}', style: tema.textTheme.bodySmall)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, required this.fondo, required this.frente});

  final IconData icono;
  final String texto;
  final Color fondo;
  final Color frente;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: frente, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: TextStyle(color: frente, height: 1.4))),
          ],
        ),
      );
}

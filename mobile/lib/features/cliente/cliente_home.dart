import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/equipos_repository.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/equipo.dart';
import '../../models/usuario.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/rol_icono.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/tarjeta_solicitud.dart';

/// Panel del cliente: acceso al diagnóstico y lista de sus equipos.
class ClienteHome extends ConsumerWidget {
  const ClienteHome({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipos = ref.watch(misEquiposProvider);
    final solicitudes = ref.watch(misSolicitudesProvider);
    final activas = solicitudes.value?.where((s) => s.estado.activa).toList() ?? const [];
    final tema = Theme.of(context);
    final c = context.acColors;
    final hayEquipos = equipos.value?.isNotEmpty ?? false;

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(misSolicitudesProvider)
          ..invalidate(notificacionesProvider);
        ref.invalidate(misEquiposProvider);
        await ref.read(misEquiposProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: c.hero, borderRadius: BorderRadius.circular(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EncabezadoRol(rol: Rol.cliente, titulo: 'Tu espacio'),
                const SizedBox(height: 14),
                Text('Hola, ${usuario.primerNombre}', style: tema.textTheme.headlineMedium?.copyWith(color: c.heroForeground)),
                const SizedBox(height: 6),
                Text(
                  '¿Algo no anda bien con tu clima? Cuéntanos qué pasa y te orientamos en un par de minutos.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: c.heroMuted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('boton-diagnosticar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.tealBg,
                    foregroundColor: c.tealFg,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: hayEquipos ? () => context.push(Rutas.diagnostico) : null,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Diagnosticar mi equipo'),
                ),
                if (equipos.hasValue && !hayEquipos) ...[
                  const SizedBox(height: 8),
                  Text('Primero registra tu equipo.', style: tema.textTheme.bodySmall?.copyWith(color: c.heroMuted)),
                ],
              ],
            ),
          ),
          if (activas.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionLabel('Servicios en curso', accion: 'Ver todos', alPresionar: () => context.push(Rutas.misServicios)),
            for (final s in activas.take(3)) TarjetaSolicitud(solicitud: s, alTocar: () => context.push(Rutas.solicitud(s.id))),
          ],
          const SizedBox(height: 22),
          SectionLabel(
            'Mis equipos',
            accion: 'Agregar',
            alPresionar: () => context.push(Rutas.nuevoEquipo),
          ),
          switch (equipos) {
            AsyncData(:final value) when value.isEmpty => Vacio(
                icono: Icons.ac_unit_rounded,
                titulo: 'Registra tu primer equipo',
                mensaje: 'Con el número de serie llevamos su historial de servicios y diagnósticos.',
                accion: FilledButton(
                  key: const Key('boton-registrar-primero'),
                  style: FilledButton.styleFrom(minimumSize: const Size(200, 46)),
                  onPressed: () => context.push(Rutas.nuevoEquipo),
                  child: const Text('Registrar equipo'),
                ),
              ),
            AsyncData(:final value) => Column(children: [for (final e in value) _TarjetaEquipo(equipo: e)]),
            AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(misEquiposProvider)),
            _ => const Cargando(),
          },
          if ((solicitudes.value ?? const []).length > activas.length) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push(Rutas.misServicios),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Ver servicios anteriores'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaEquipo extends StatelessWidget {
  const _TarjetaEquipo({required this.equipo});

  final Equipo equipo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final detalle = [
      equipo.tipo,
      if (equipo.capacidadBTU != null) '${equipo.capacidadBTU} BTU',
      if (equipo.ubicacion != null) equipo.ubicacion!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Rutas.fichaEquipo(equipo.id)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: c.tealBg, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.ac_unit_rounded, color: c.tealFg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(equipo.nombre, style: tema.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(detalle, style: tema.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text('Serie ${equipo.numeroSerie}', style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/tecnico_repository.dart';
import '../../models/usuario.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/tarjeta_solicitud.dart';

/// Panel del técnico: disponibilidad, órdenes de hoy y próximas, y las terminadas.
class TecnicoHome extends ConsumerWidget {
  const TecnicoHome({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final disponible = ref.watch(disponibilidadProvider);
    final activas = ref.watch(ordenesProvider(false));
    final terminadas = ref.watch(ordenesProvider(true));

    Future<void> abrir(int id) async {
      await context.push(Rutas.solicitud(id));
      ref
        ..invalidate(ordenesProvider(false))
        ..invalidate(ordenesProvider(true));
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(disponibilidadProvider)
          ..invalidate(ordenesProvider(true))
          ..invalidate(ordenesProvider(false));
        await ref.read(ordenesProvider(false).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // Material (no Container) para que el SwitchListTile pueda pintar su efecto al tocarlo.
          Material(
            color: c.hero,
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RUTA DE HOY · TÉCNICO',
                    style: TextStyle(
                      color: c.heroMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hola, ${usuario.primerNombre}',
                    style: tema.textTheme.headlineSmall?.copyWith(
                      color: c.heroForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activas.hasValue
                        ? '${activas.value!.length} órdenes por atender'
                        : 'Cargando tus órdenes…',
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: c.heroMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const Key('switch-disponible'),
                    contentPadding: EdgeInsets.zero,
                    value: disponible.value ?? false,
                    onChanged: disponible.hasValue
                        ? (v) async {
                            final ok = await ejecutarConAviso(
                              context,
                              () => ref
                                  .read(tecnicoRepositoryProvider)
                                  .cambiarDisponibilidad(v),
                              exito: v
                                  ? 'Estás disponible para nuevas órdenes'
                                  : 'Marcado como ocupado',
                            );
                            if (ok) ref.invalidate(disponibilidadProvider);
                          }
                        : null,
                    title: Text(
                      (disponible.value ?? false) ? 'Disponible' : 'Ocupado',
                      style: TextStyle(
                        color: c.heroForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Los administradores priorizan a los técnicos disponibles.',
                      style: TextStyle(color: c.heroMuted, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Órdenes asignadas'),
          switch (activas) {
            AsyncData(:final value) when value.isEmpty => const Vacio(
              icono: Icons.assignment_turned_in_outlined,
              titulo: 'Sin órdenes pendientes',
              mensaje: 'Cuando un cliente apruebe una cotización asignada a ti, aparecerá aquí.',
            ),
            AsyncData(:final value) => Column(
              children: [
                for (final o in value)
                  TarjetaSolicitud(
                    solicitud: o,
                    mostrarCliente: true,
                    alTocar: () => abrir(o.id),
                  ),
              ],
            ),
            AsyncError(:final error) => ErrorConReintento(
              error: error,
              alReintentar: () => ref.invalidate(ordenesProvider(false)),
            ),
            _ => const Cargando(),
          },
          const SizedBox(height: 22),
          Card(
            child: ListTile(
              key: const Key('accion-buscar-serie'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Icon(Icons.qr_code_2_rounded, color: c.tealFg),
              title: Text(
                'Historial por número de serie',
                style: tema.textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Rutas.buscarEquipo),
            ),
          ),
          if (terminadas.value?.isNotEmpty ?? false) ...[
            const SizedBox(height: 22),
            const SectionLabel('Terminadas'),
            for (final o in terminadas.value!.take(5))
              TarjetaSolicitud(
                solicitud: o,
                mostrarCliente: true,
                alTocar: () => abrir(o.id),
              ),
          ],
        ],
      ),
    );
  }
}

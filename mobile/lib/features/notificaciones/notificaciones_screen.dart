import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/solicitud.dart';
import '../../shared/widgets/estado_carga.dart';

/// Avisos de la campana: cada cambio en una solicitud deja uno aquí.
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  Future<void> _abrir(BuildContext context, WidgetRef ref, Notificacion n) async {
    if (!n.leida) {
      await ref.read(solicitudesRepositoryProvider).marcarLeida(n.id).catchError((_) {});
      ref.invalidate(notificacionesProvider);
    }
    if (n.solicitudId != null && context.mounted) context.push(Rutas.solicitud(n.solicitudId!));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandeja = ref.watch(notificacionesProvider);
    final tema = Theme.of(context);
    final hayNoLeidas = (bandeja.value?.noLeidas ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (hayNoLeidas)
            TextButton(
              onPressed: () async {
                await ref.read(solicitudesRepositoryProvider).marcarTodasLeidas().catchError((_) {});
                ref.invalidate(notificacionesProvider);
              },
              child: const Text('Marcar todas'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificacionesProvider.future),
        child: switch (bandeja) {
          AsyncData(:final value) when value.notificaciones.isEmpty => ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                Vacio(icono: Icons.notifications_none_rounded, titulo: 'Sin avisos', mensaje: 'Aquí verás cada avance de tus servicios.'),
              ],
            ),
          AsyncData(:final value) => ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: value.notificaciones.length,
              separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
              itemBuilder: (context, i) {
                final n = value.notificaciones[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Icon(
                    n.leida ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                    color: n.leida ? tema.colorScheme.onSurfaceVariant : tema.colorScheme.primary,
                  ),
                  title: Text(n.titulo, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: n.leida ? FontWeight.w500 : FontWeight.w700)),
                  subtitle: Text('${n.cuerpo}\n${fechaHora(n.fecha)}', style: tema.textTheme.bodySmall),
                  isThreeLine: true,
                  onTap: () => _abrir(context, ref, n),
                );
              },
            ),
          AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(notificacionesProvider)),
          _ => const Cargando(),
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../data/solicitudes_repository.dart';

/// Ícono de notificaciones con el número de avisos sin leer.
class Campana extends ConsumerWidget {
  const Campana({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noLeidas = ref.watch(notificacionesProvider).value?.noLeidas ?? 0;
    return IconButton(
      key: const Key('boton-notificaciones'),
      tooltip: 'Notificaciones',
      onPressed: () => context.push(Rutas.notificaciones),
      icon: Badge(
        isLabelVisible: noLeidas > 0,
        label: Text(noLeidas > 9 ? '9+' : '$noLeidas'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

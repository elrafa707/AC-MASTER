import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/usuario.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/campana.dart';
import '../admin/admin_home.dart';
import '../auth/session_controller.dart';
import '../cliente/cliente_home.dart';
import '../tecnico/tecnico_home.dart';

/// Panel principal (interfaz 2), distinto según el rol.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sessionProvider).value;
    if (usuario == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            BrandMark(tamanio: 36),
            SizedBox(width: 12),
            Text('AC-Master'),
          ],
        ),
        actions: [
          const Campana(),
          IconButton(
            key: const Key('boton-cerrar-sesion'),
            tooltip: 'Cerrar sesión',
            onPressed: () => _confirmarCierre(context, ref),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (usuario.rol) {
        Rol.cliente => ClienteHome(usuario: usuario),
        Rol.administrador => AdminHome(usuario: usuario),
        Rol.tecnico => TecnicoHome(usuario: usuario),
      },
    );
  }

  Future<void> _confirmarCierre(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para consultar tus servicios.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar == true) await ref.read(sessionProvider.notifier).cerrarSesion();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/usuario.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/campana.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/status_pill.dart';
import '../admin/admin_home.dart';
import '../auth/session_controller.dart';
import '../cliente/cliente_home.dart';

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
        Rol.tecnico => _PersonalHome(usuario: usuario),
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

/// Panel provisional del técnico: por ahora la consulta de equipos por número de serie.
/// La etapa 4 agrega las órdenes de trabajo.
class _PersonalHome extends StatelessWidget {
  const _PersonalHome({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    const proximos = [
      ('Órdenes asignadas', 'Etapa 4', Icons.assignment_outlined),
      ('Evidencias y piezas', 'Etapa 4', Icons.photo_camera_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: c.hero, borderRadius: BorderRadius.circular(26)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(usuario.rol.etiqueta),
              const SizedBox(height: 14),
              Text('Hola, ${usuario.primerNombre}', style: tema.textTheme.headlineMedium?.copyWith(color: c.heroForeground)),
              const SizedBox(height: 6),
              Text(usuario.correo, style: tema.textTheme.bodyMedium?.copyWith(color: c.heroMuted)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Herramientas'),
        Card(
          child: ListTile(
            key: const Key('accion-buscar-serie'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _IconoModulo(icono: Icons.qr_code_2_rounded, fondo: c.tealBg, frente: c.tealFg),
            title: Text('Historial por número de serie', style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
            subtitle: Text('Consulta la ficha técnica y la línea de tiempo de cualquier equipo.', style: tema.textTheme.bodySmall),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Rutas.buscarEquipo),
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Próximamente'),
        for (final (titulo, etapa, icono) in proximos)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: _IconoModulo(icono: icono, fondo: c.tealBg, frente: c.tealFg),
                title: Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                trailing: StatusPill(etapa, tono: PillTone.blue),
              ),
            ),
          ),
      ],
    );
  }
}

class _IconoModulo extends StatelessWidget {
  const _IconoModulo({required this.icono, required this.fondo, required this.frente});

  final IconData icono;
  final Color fondo;
  final Color frente;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14)),
        child: Icon(icono, color: frente, size: 20),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/usuario.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/status_pill.dart';
import '../auth/session_controller.dart';

/// Panel provisional por rol. Las etapas 2 a 4 lo reemplazan por el Dashboard de cada rol (interfaz 2).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sessionProvider).value;
    if (usuario == null) return const SizedBox.shrink();

    final tema = Theme.of(context);
    final c = context.acColors;
    final modulos = switch (usuario.rol) {
      Rol.cliente => const [
          ('Diagnóstico inteligente', 'Etapa 2', Icons.ac_unit_rounded),
          ('Mis equipos e historial', 'Etapa 2', Icons.history_rounded),
          ('Seguimiento de solicitudes', 'Etapa 3', Icons.timeline_rounded),
        ],
      Rol.administrador => const [
          ('Bandeja de solicitudes', 'Etapa 3', Icons.inbox_outlined),
          ('Asignación de técnicos', 'Etapa 3', Icons.engineering_outlined),
          ('Cotizaciones', 'Etapa 3', Icons.request_quote_outlined),
        ],
      Rol.tecnico => const [
          ('Órdenes asignadas', 'Etapa 4', Icons.assignment_outlined),
          ('Evidencias y piezas', 'Etapa 4', Icons.photo_camera_outlined),
          ('Historial por número de serie', 'Etapa 4', Icons.qr_code_2_rounded),
        ],
    };

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
          IconButton(
            key: const Key('boton-cerrar-sesion'),
            tooltip: 'Cerrar sesión',
            onPressed: () => _confirmarCierre(context, ref),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
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
                Text(
                  'Hola, ${usuario.primerNombre}',
                  style: tema.textTheme.headlineMedium?.copyWith(color: c.heroForeground),
                ),
                const SizedBox(height: 6),
                Text(usuario.correo, style: tema.textTheme.bodyMedium?.copyWith(color: c.heroMuted)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Próximamente'),
          for (final (titulo, etapa, icono) in modulos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: c.tealBg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icono, color: c.tealFg, size: 20),
                  ),
                  title: Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                  trailing: StatusPill(etapa, tono: PillTone.blue),
                ),
              ),
            ),
        ],
      ),
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

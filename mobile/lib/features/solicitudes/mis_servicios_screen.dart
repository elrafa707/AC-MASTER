import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../data/solicitudes_repository.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/tarjeta_solicitud.dart';

/// Todas las solicitudes del cliente, activas y terminadas.
class MisServiciosScreen extends ConsumerWidget {
  const MisServiciosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(misSolicitudesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis servicios')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(misSolicitudesProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            switch (solicitudes) {
              AsyncData(:final value) when value.isEmpty => const Vacio(
                  icono: Icons.assignment_outlined,
                  titulo: 'Aún no tienes servicios',
                  mensaje: 'Cuando pidas un técnico desde un diagnóstico, aquí podrás seguir cada paso.',
                ),
              AsyncData(:final value) => Column(
                  children: [
                    for (final s in value) TarjetaSolicitud(solicitud: s, alTocar: () => context.push(Rutas.solicitud(s.id))),
                  ],
                ),
              AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(misSolicitudesProvider)),
              _ => const Cargando(),
            },
          ],
        ),
      ),
    );
  }
}

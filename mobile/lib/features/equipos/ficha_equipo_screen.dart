import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/equipos_repository.dart';
import '../../models/equipo.dart';
import '../../models/usuario.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/linea_tiempo.dart';
import '../../shared/widgets/section_label.dart';
import '../auth/session_controller.dart';

/// Interfaz 7: ficha técnica del equipo e historial digital (RF-08).
class FichaEquipoScreen extends ConsumerWidget {
  const FichaEquipoScreen({super.key, required this.equipoId});

  final int equipoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ficha = ref.watch(fichaEquipoProvider(equipoId));
    return Scaffold(
      appBar: AppBar(title: const Text('Historial digital')),
      body: switch (ficha) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.refresh(fichaEquipoProvider(equipoId).future),
            child: ContenidoFicha(ficha: value),
          ),
        AsyncError(:final error) => ErrorConReintento(
            error: error,
            alReintentar: () => ref.invalidate(fichaEquipoProvider(equipoId)),
          ),
        _ => const Cargando(),
      },
    );
  }
}

/// Cuerpo de la ficha; también lo usa la búsqueda por número de serie.
class ContenidoFicha extends ConsumerWidget {
  const ContenidoFicha({super.key, required this.ficha});

  final FichaEquipo ficha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final e = ficha.equipo;
    final esCliente = ref.watch(sessionProvider).value?.rol == Rol.cliente;

    final datos = [
      ('Número de serie', e.numeroSerie),
      ('Tipo', e.tipo),
      if (e.capacidadBTU != null) ('Capacidad', '${e.capacidadBTU} BTU'),
      if (e.refrigerante != null) ('Refrigerante', e.refrigerante!),
      if (e.ubicacion != null) ('Ubicación', e.ubicacion!),
      if (e.fechaInstalacion != null) ('Instalado', fechaLarga(e.fechaInstalacion!)),
      if (!esCliente && e.clienteNombre != null) ('Cliente', e.clienteNombre!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: c.hero, borderRadius: BorderRadius.circular(26)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FICHA DE EQUIPO', style: TextStyle(color: c.heroMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                    const SizedBox(height: 8),
                    Text(e.nombre, style: tema.textTheme.headlineSmall?.copyWith(color: c.heroForeground)),
                    const SizedBox(height: 4),
                    Text('${ficha.historial.length} registros en su historial', style: tema.textTheme.bodyMedium?.copyWith(color: c.heroMuted)),
                  ],
                ),
              ),
              Icon(Icons.ac_unit_rounded, size: 40, color: c.heroMuted),
            ],
          ),
        ),
        if (esCliente) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('boton-diagnosticar-equipo'),
            onPressed: () => context.push(Rutas.diagnosticoDe(e.id)),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Diagnosticar este equipo'),
          ),
        ],
        const SizedBox(height: 22),
        const SectionLabel('Datos técnicos'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final (i, (etiqueta, valor)) in datos.indexed) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(etiqueta, style: tema.textTheme.bodySmall)),
                        Flexible(
                          child: Text(valor, textAlign: TextAlign.end, style: tema.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Vida del equipo'),
        if (ficha.historial.isEmpty)
          const Vacio(
            icono: Icons.history_rounded,
            titulo: 'Sin registros todavía',
            mensaje: 'Aquí aparecerán los diagnósticos, mantenimientos y reparaciones.',
          )
        else
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: LineaTiempo(registros: ficha.historial)),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/admin_repository.dart';
import '../../models/solicitud.dart';
import '../../models/usuario.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/rol_icono.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/tarjeta_solicitud.dart';

typedef FiltroBandeja = ({EstadoSolicitud? estado, String texto});

final bandejaProvider = FutureProvider.family<List<ResumenSolicitud>, FiltroBandeja>(
  (ref, filtro) => ref.watch(adminRepositoryProvider).bandeja(estado: filtro.estado, texto: filtro.texto),
);

/// Panel del administrador: resumen de la operación y bandeja de solicitudes (interfaz 5).
class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  FiltroBandeja _filtro = (estado: EstadoSolicitud.enRevision, texto: '');
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _refrescar() async {
    ref.invalidate(resumenPanelProvider);
    ref.invalidate(bandejaProvider(_filtro));
    await ref.read(bandejaProvider(_filtro).future);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final resumen = ref.watch(resumenPanelProvider).value;
    final bandeja = ref.watch(bandejaProvider(_filtro));

    return RefreshIndicator(
      onRefresh: _refrescar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: c.hero, borderRadius: BorderRadius.circular(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EncabezadoRol(rol: Rol.administrador, titulo: 'Centro de operaciones'),
                const SizedBox(height: 14),
                Text('Hola, ${widget.usuario.primerNombre}', style: tema.textTheme.headlineSmall?.copyWith(color: c.heroForeground)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Contador(valor: resumen?.enRevision, etiqueta: 'En revisión'),
                    _Contador(valor: resumen?.urgentes, etiqueta: 'Urgentes'),
                    _Contador(valor: resumen?.enCamino, etiqueta: 'En camino'),
                    _Contador(
                      valor: resumen?.tecnicosDisponibles,
                      etiqueta: 'Técnicos libres',
                      sufijo: resumen == null ? '' : '/${resumen.tecnicosActivos}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Accion(icono: Icons.engineering_outlined, texto: 'Técnicos', alTocar: () => context.push(Rutas.adminTecnicos))),
              const SizedBox(width: 10),
              Expanded(child: _Accion(icono: Icons.people_outline_rounded, texto: 'Clientes', alTocar: () => context.push(Rutas.adminClientes))),
              const SizedBox(width: 10),
              Expanded(child: _Accion(icono: Icons.inventory_2_outlined, texto: 'Piezas', alTocar: () => context.push(Rutas.adminPiezas))),
              const SizedBox(width: 10),
              Expanded(child: _Accion(icono: Icons.qr_code_2_rounded, texto: 'Por serie', alTocar: () => context.push(Rutas.buscarEquipo))),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('Bandeja de solicitudes'),
          TextField(
            key: const Key('campo-buscar-solicitud'),
            controller: _busqueda,
            textInputAction: TextInputAction.search,
            onSubmitted: (t) => setState(() => _filtro = (estado: _filtro.estado, texto: t.trim())),
            decoration: InputDecoration(
              hintText: 'Folio, cliente o número de serie',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _filtro.texto.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _busqueda.clear();
                        setState(() => _filtro = (estado: _filtro.estado, texto: ''));
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final estado in <EstadoSolicitud?>[null, ...EstadoSolicitud.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('filtro-${estado?.api ?? 'TODAS'}'),
                      label: Text(estado?.etiqueta ?? 'Todas'),
                      selected: _filtro.estado == estado,
                      onSelected: (_) => setState(() => _filtro = (estado: estado, texto: _filtro.texto)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          switch (bandeja) {
            AsyncData(:final value) when value.isEmpty => const Vacio(
                icono: Icons.inbox_outlined,
                titulo: 'Sin solicitudes',
                mensaje: 'Prueba con otro estado o búsqueda.',
              ),
            AsyncData(:final value) => Column(
                children: [
                  for (final s in value)
                    TarjetaSolicitud(
                      solicitud: s,
                      mostrarCliente: true,
                      alTocar: () async {
                        await context.push(Rutas.solicitud(s.id));
                        ref
                          ..invalidate(bandejaProvider)
                          ..invalidate(resumenPanelProvider);
                      },
                    ),
                ],
              ),
            AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(bandejaProvider(_filtro))),
            _ => const Cargando(),
          },
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.etiqueta, this.sufijo = ''});

  final int? valor;
  final String etiqueta;
  final String sufijo;

  @override
  Widget build(BuildContext context) {
    final c = context.acColors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor == null ? '–' : '$valor$sufijo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: c.heroForeground)),
          Text(etiqueta, style: TextStyle(color: c.heroMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({required this.icono, required this.texto, required this.alTocar});

  final IconData icono;
  final String texto;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.acColors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icono, color: c.tealFg),
              const SizedBox(height: 6),
              Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/lanzador.dart';
import '../../core/theme/app_colors.dart';
import '../../data/solicitudes_repository.dart';
import '../../data/tecnico_repository.dart';
import '../../models/solicitud.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/estado_pill.dart';
import '../../shared/widgets/foto_autenticada.dart';
import '../../shared/widgets/resumen_orden.dart';
import '../../shared/widgets/section_label.dart';
import '../diagnostico/selector_fotos.dart';

/// Interfaz 6: orden de trabajo y diagnóstico de campo del técnico (RF-06, RF-07).
class OrdenScreen extends ConsumerWidget {
  const OrdenScreen({super.key, required this.solicitudId});

  final int solicitudId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitud = ref.watch(solicitudProvider(solicitudId));
    return Scaffold(
      appBar: AppBar(title: Text(solicitud.value?.resumen.ordenFolio ?? 'Orden de trabajo')),
      body: switch (solicitud) {
        AsyncData(:final value) => _Contenido(key: ValueKey(value.id), solicitud: value),
        AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(solicitudProvider(solicitudId))),
        _ => const Cargando(),
      },
    );
  }
}

class _Contenido extends ConsumerStatefulWidget {
  const _Contenido({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  ConsumerState<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends ConsumerState<_Contenido> {
  late final _diagnostico = TextEditingController(text: widget.solicitud.orden?.diagnosticoFinal ?? '');
  late final _notas = TextEditingController(text: widget.solicitud.orden?.notas ?? '');
  late List<PiezaUsada> _piezas = List.of(widget.solicitud.orden?.piezas ?? const []);
  bool _registroModificado = false;
  bool _piezasModificadas = false;
  bool _ocupado = false;

  Solicitud get s => widget.solicitud;
  OrdenTrabajo? get orden => s.orden;
  TecnicoRepository get _repo => ref.read(tecnicoRepositoryProvider);

  @override
  void dispose() {
    _diagnostico.dispose();
    _notas.dispose();
    super.dispose();
  }

  /// Ejecuta una acción y recarga la orden; los textos y piezas que el técnico no guardó se conservan.
  Future<bool> _accion(Future<void> Function() fn, {String? exito}) async {
    setState(() => _ocupado = true);
    final ok = await ejecutarConAviso(context, fn, exito: exito);
    if (mounted) setState(() => _ocupado = false);
    if (ok) ref.invalidate(solicitudProvider(s.id));
    return ok;
  }

  Future<void> _agregarEvidencia(ImageSource origen) async {
    final foto = await ref.read(elegirFotoProvider)(origen).catchError((_) => null);
    if (foto == null || !mounted) return;
    await _accion(() => _repo.subirEvidencias(s.id, [foto]), exito: 'Evidencia guardada');
  }

  Future<void> _elegirPieza() async {
    final catalogo = await ref.read(catalogoPiezasProvider.future).catchError((_) => <Pieza>[]);
    if (!mounted) return;
    final elegida = await showModalBottomSheet<Pieza>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SelectorPieza(catalogo: catalogo.where((p) => !_piezas.any((u) => u.piezaId == p.id)).toList()),
    );
    if (elegida == null) return;
    setState(() {
      _piezas = [..._piezas, PiezaUsada(piezaId: elegida.id, codigo: elegida.codigo, nombre: elegida.nombre, cantidad: 1, precioUnitario: elegida.precioUnitario)];
      _piezasModificadas = true;
    });
  }

  void _cambiarCantidad(int i, int delta) {
    final p = _piezas[i];
    final cantidad = p.cantidad + delta;
    setState(() {
      _piezas = [..._piezas];
      if (cantidad <= 0) {
        _piezas.removeAt(i);
      } else {
        _piezas[i] = PiezaUsada(piezaId: p.piezaId, codigo: p.codigo, nombre: p.nombre, cantidad: cantidad, precioUnitario: p.precioUnitario);
      }
      _piezasModificadas = true;
    });
  }

  Future<void> _cerrar() async {
    final faltantes = [
      if (_diagnostico.text.trim().length < 10) 'el diagnóstico final',
      if ((orden?.evidencias ?? const []).isEmpty) 'al menos una foto de evidencia',
    ];
    if (faltantes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Antes de cerrar registra ${faltantes.join(' y ')}.')));
      return;
    }
    final ok = await confirmar(
      context,
      titulo: '¿Cerrar la orden?',
      mensaje: 'El cliente recibirá el resumen del servicio y ya no podrás modificar el registro.',
      textoConfirmar: 'Cerrar orden',
    );
    if (!ok || !mounted) return;
    // Guarda primero lo que haya quedado sin guardar.
    if (_registroModificado) await _repo.guardarRegistro(s.id, diagnosticoFinal: _diagnostico.text.trim(), notas: _notas.text.trim());
    if (_piezasModificadas) await _repo.guardarPiezas(s.id, [for (final p in _piezas) (piezaId: p.piezaId, cantidad: p.cantidad)]);
    if (!mounted) return;
    final cerrado = await _accion(() => _repo.cerrar(s.id), exito: 'Orden cerrada. ¡Buen trabajo!');
    if (cerrado) ref.invalidate(ordenesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final d = s.diagnostico;
    final abierta = s.estado == EstadoSolicitud.enCamino;
    final llegada = orden?.fechaLlegada;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(solicitudProvider(s.id));
        await ref.read(solicitudProvider(s.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 6, children: [EstadoPill(s.estado), PrioridadPill(s.resumen.prioridad)]),
                  const SizedBox(height: 10),
                  Text(d.falla, style: tema.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('${s.resumen.equipo} · Serie ${s.numeroSerie} · ${s.folio}', style: tema.textTheme.bodySmall),
                  if (s.resumen.ventanaInicio != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.event_outlined, size: 16, color: c.tealFg),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Visita: ${fechaHora(s.resumen.ventanaInicio!)}', style: tema.textTheme.bodyMedium)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Cliente'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(s.resumen.clienteNombre),
                  subtitle: Text(s.clienteTelefono ?? 'Sin teléfono registrado'),
                  trailing: s.clienteTelefono == null
                      ? null
                      : IconButton.filledTonal(
                          key: const Key('boton-llamar'),
                          tooltip: 'Llamar',
                          onPressed: () => llamar(context, s.clienteTelefono!),
                          icon: const Icon(Icons.call_rounded),
                        ),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(s.direccion.alias),
                  subtitle: Text([s.direccion.completa, ?s.direccion.referencias].join('\n')),
                  trailing: IconButton.filledTonal(
                    key: const Key('boton-mapa'),
                    tooltip: 'Cómo llegar',
                    onPressed: () => abrirEnMapa(context, s.direccion),
                    icon: const Icon(Icons.directions_rounded),
                  ),
                ),
                if (s.descripcion != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text('Indicaciones: ${s.descripcion}', style: tema.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (abierta) ...[
            const SizedBox(height: 12),
            if (llegada == null)
              FilledButton.icon(
                key: const Key('boton-llegada'),
                onPressed: _ocupado ? null : () => _accion(() => _repo.registrarLlegada(s.id), exito: 'Avisamos al cliente que llegaste'),
                icon: const Icon(Icons.where_to_vote_outlined, size: 18),
                label: const Text('Llegué al domicilio'),
              )
            else
              Text('Llegaste el ${fechaHora(llegada)}', textAlign: TextAlign.center, style: tema.textTheme.bodySmall),
          ],
          const SizedBox(height: 18),
          const SectionLabel('Diagnóstico del asistente'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.porcentaje}% de confianza · ${d.especialidad ?? 'Sin especialidad'}', style: TextStyle(color: c.tealFg, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(d.descripcion, style: tema.textTheme.bodyMedium),
                  for (final causa in d.causas)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• ${causa.nombre} (${(causa.probabilidad * 100).round()}%)', style: tema.textTheme.bodySmall),
                    ),
                  if (d.fotos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [for (final f in d.fotos) FotoAutenticada(f, tamanio: 72)]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Kit sugerido'),
          Card(
            key: const Key('kit-sugerido'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: d.herramientas.isEmpty
                  ? Text('El asistente no sugirió herramientas específicas.', style: tema.textTheme.bodySmall)
                  : Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final h in d.herramientas) Chip(avatar: const Icon(Icons.build_outlined, size: 16), label: Text(h)),
                    ]),
            ),
          ),
          if (!abierta && orden != null) ...[
            const SizedBox(height: 18),
            const SectionLabel('Registro del servicio'),
            ResumenOrden(orden: orden!),
            if (s.calificacion != null) ...[
              const SizedBox(height: 12),
              Row(children: [Text('Calificación del cliente: ', style: tema.textTheme.bodyMedium), Estrellas(s.calificacion!)]),
              if (s.comentarioCalificacion != null) Text('"${s.comentarioCalificacion}"', style: tema.textTheme.bodySmall),
            ],
          ],
          if (abierta) ..._registro(tema),
        ],
      ),
    );
  }

  List<Widget> _registro(ThemeData tema) {
    final evidencias = orden?.evidencias ?? const [];
    final total = _piezas.fold<double>(0, (t, p) => t + p.importe);
    return [
      const SizedBox(height: 18),
      const SectionLabel('Diagnóstico de campo'),
      TextField(
        key: const Key('campo-diagnostico-final'),
        controller: _diagnostico,
        minLines: 3,
        maxLines: 6,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() => _registroModificado = true),
        decoration: const InputDecoration(labelText: 'Diagnóstico final', hintText: 'Qué encontraste y qué hiciste', alignLabelWithHint: true),
      ),
      TextField(
        controller: _notas,
        minLines: 2,
        maxLines: 4,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() => _registroModificado = true),
        decoration: const InputDecoration(labelText: 'Notas (opcional)', hintText: 'Recomendaciones para el cliente', alignLabelWithHint: true),
      ),
      if (_registroModificado)
        OutlinedButton(
          key: const Key('boton-guardar-registro'),
          onPressed: _ocupado
              ? null
              : () async {
                  final ok = await _accion(
                    () => _repo.guardarRegistro(s.id, diagnosticoFinal: _diagnostico.text.trim(), notas: _notas.text.trim()),
                    exito: 'Registro guardado',
                  );
                  if (ok && mounted) setState(() => _registroModificado = false);
                },
          child: const Text('Guardar registro'),
        ),
      const SizedBox(height: 18),
      SectionLabel('Evidencias · ${evidencias.length}'),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final e in evidencias)
            Stack(
              children: [
                FotoAutenticada(e.url, tamanio: 88),
                Positioned(
                  right: 2,
                  top: 2,
                  child: IconButton.filledTonal(
                    tooltip: 'Eliminar evidencia',
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: _ocupado ? null : () => _accion(() => _repo.eliminarEvidencia(s.id, e.id)),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('boton-evidencia-camara'),
              onPressed: _ocupado ? null : () => _agregarEvidencia(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Cámara'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('boton-evidencia-galeria'),
              onPressed: _ocupado ? null : () => _agregarEvidencia(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Galería'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const SectionLabel('Piezas utilizadas'),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Column(
            children: [
              if (_piezas.isEmpty)
                Padding(padding: const EdgeInsets.all(8), child: Text('Sin piezas registradas.', style: tema.textTheme.bodySmall)),
              for (final (i, p) in _piezas.indexed)
                Row(
                  key: Key('pieza-${p.piezaId}'),
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nombre, style: tema.textTheme.bodyMedium),
                          Text('${p.codigo} · ${pesos(p.precioUnitario)} c/u', style: tema.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(tooltip: 'Quitar una', onPressed: () => _cambiarCantidad(i, -1), icon: const Icon(Icons.remove_circle_outline_rounded)),
                    Text('${p.cantidad}', style: tema.textTheme.titleMedium),
                    IconButton(tooltip: 'Agregar una', onPressed: () => _cambiarCantidad(i, 1), icon: const Icon(Icons.add_circle_outline_rounded)),
                  ],
                ),
              if (_piezas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 8, 4),
                  child: Row(children: [const Expanded(child: Text('Total en piezas')), Text(pesos(total), style: tema.textTheme.titleMedium)]),
                ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: const Key('boton-agregar-pieza'),
                    onPressed: _elegirPieza,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar pieza'),
                  ),
                  if (_piezasModificadas)
                    FilledButton(
                      key: const Key('boton-guardar-piezas'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: _ocupado
                          ? null
                          : () async {
                              final ok = await _accion(
                                () => _repo.guardarPiezas(s.id, [for (final p in _piezas) (piezaId: p.piezaId, cantidad: p.cantidad)]),
                                exito: 'Piezas guardadas',
                              );
                              if (ok && mounted) setState(() => _piezasModificadas = false);
                            },
                      child: const Text('Guardar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 22),
      FilledButton.icon(
        key: const Key('boton-cerrar-orden'),
        onPressed: _ocupado ? null : _cerrar,
        icon: const Icon(Icons.task_alt_rounded, size: 18),
        label: const Text('Cerrar orden'),
      ),
      const SizedBox(height: 6),
      Text('Necesitas el diagnóstico final y al menos una foto de evidencia.', textAlign: TextAlign.center, style: tema.textTheme.bodySmall),
    ];
  }
}

class _SelectorPieza extends StatefulWidget {
  const _SelectorPieza({required this.catalogo});

  final List<Pieza> catalogo;

  @override
  State<_SelectorPieza> createState() => _SelectorPiezaState();
}

class _SelectorPiezaState extends State<_SelectorPieza> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final f = _filtro.toLowerCase();
    final lista = widget.catalogo.where((p) => p.nombre.toLowerCase().contains(f) || p.codigo.toLowerCase().contains(f)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              key: const Key('campo-buscar-pieza'),
              autofocus: true,
              onChanged: (t) => setState(() => _filtro = t),
              decoration: const InputDecoration(hintText: 'Buscar pieza o código', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final p in lista)
                  ListTile(
                    key: Key('opcion-pieza-${p.id}'),
                    title: Text(p.nombre),
                    subtitle: Text(p.codigo),
                    trailing: Text(pesos(p.precioUnitario)),
                    onTap: () => Navigator.pop(context, p),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

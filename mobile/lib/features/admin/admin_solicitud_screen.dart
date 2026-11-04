import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../data/admin_repository.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/admin.dart';
import '../../models/solicitud.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/estado_pill.dart';
import '../../shared/widgets/foto_autenticada.dart';
import '../../shared/widgets/progreso_solicitud.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/status_pill.dart';

/// Interfaz 5: detalle de la solicitud para el administrador, con asignación (RF-04) y cotización.
class AdminSolicitudScreen extends ConsumerWidget {
  const AdminSolicitudScreen({super.key, required this.solicitudId});

  final int solicitudId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitud = ref.watch(solicitudProvider(solicitudId));
    return Scaffold(
      appBar: AppBar(title: Text(solicitud.value?.folio ?? 'Solicitud')),
      body: switch (solicitud) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recomendadosProvider(solicitudId));
              ref.invalidate(solicitudProvider(solicitudId));
              await ref.read(solicitudProvider(solicitudId).future);
            },
            child: _Contenido(solicitud: value),
          ),
        AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(solicitudProvider(solicitudId))),
        _ => const Cargando(),
      },
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final s = solicitud;
    final d = s.diagnostico;
    final editable = s.estado == EstadoSolicitud.enRevision;

    void recargar() {
      ref
        ..invalidate(solicitudProvider(s.id))
        ..invalidate(recomendadosProvider(s.id))
        ..invalidate(resumenPanelProvider);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 6, children: [
                  EstadoPill(s.estado),
                  PrioridadPill(s.resumen.prioridad),
                  if (s.resumen.pedidaPorCliente) const StatusPill('Pedida por el cliente', tono: PillTone.blue),
                ]),
                const SizedBox(height: 12),
                Text(s.resumen.clienteNombre, style: tema.textTheme.titleLarge),
                Text([s.clienteCorreo, ?s.clienteTelefono].join(' · '), style: tema.textTheme.bodySmall),
                const SizedBox(height: 10),
                _Linea(icono: Icons.ac_unit_rounded, texto: '${s.resumen.equipo} · Serie ${s.numeroSerie}'),
                _Linea(icono: Icons.place_outlined, texto: s.direccion.completa),
                if (s.descripcion != null) _Linea(icono: Icons.notes_rounded, texto: s.descripcion!),
                const SizedBox(height: 16),
                ProgresoSolicitud(estado: s.estado),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Falla predicha por el asistente'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(d.falla, style: tema.textTheme.titleMedium)),
                    Text('${d.porcentaje}%', style: TextStyle(color: c.tealFg, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(d.descripcion, style: tema.textTheme.bodySmall),
                if (d.advertencia != null) ...[
                  const SizedBox(height: 8),
                  Text('⚠ ${d.advertencia}', style: TextStyle(color: c.orangeFg, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 10),
                Text(
                  'Especialidad: ${d.especialidad ?? '—'} · Estimado ${pesos(d.costoMin)} – ${pesos(d.costoMax)}',
                  style: tema.textTheme.bodySmall,
                ),
                if (d.herramientas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final h in d.herramientas) Chip(label: Text(h), visualDensity: VisualDensity.compact),
                  ]),
                ],
                if (d.fotos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final f in d.fotos) FotoAutenticada(f, tamanio: 72)]),
                ],
                if (d.analisisFoto != null) ...[
                  const SizedBox(height: 8),
                  Text(d.analisisFoto!, style: tema.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        if (editable) ...[
          const SizedBox(height: 18),
          const SectionLabel('Técnico y visita'),
          _Asignacion(solicitud: s, alAsignar: recargar),
          const SizedBox(height: 18),
          const SectionLabel('Cotización'),
          _EditorCotizacion(
            key: ValueKey(s.cotizacion?.partidas.length),
            solicitud: s,
            alGuardar: recargar,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('boton-enviar-cotizacion'),
            onPressed: s.tecnico == null
                ? null
                : () async {
                    final ok = await confirmar(
                      context,
                      titulo: '¿Enviar la cotización?',
                      mensaje: 'El cliente recibirá la cotización de ${pesos(s.cotizacion?.total ?? 0)} para aprobarla.',
                      textoConfirmar: 'Enviar',
                    );
                    if (!ok || !context.mounted) return;
                    final exito = await ejecutarConAviso(
                      context,
                      () => ref.read(adminRepositoryProvider).enviarCotizacion(s.id),
                      exito: 'Cotización enviada al cliente',
                    );
                    if (exito) recargar();
                  },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(s.tecnico == null ? 'Asigna un técnico para enviar' : 'Enviar cotización al cliente'),
          ),
        ] else ...[
          if (s.tecnico != null) ...[
            const SizedBox(height: 18),
            const SectionLabel('Técnico asignado'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.engineering_outlined),
                title: Text(s.tecnico!.nombre),
                subtitle: Text(s.resumen.ventanaInicio == null ? '' : fechaHora(s.resumen.ventanaInicio!)),
              ),
            ),
          ],
          if (s.cotizacion != null) ...[
            const SizedBox(height: 18),
            SectionLabel('Cotización · ${s.cotizacion!.estado.toLowerCase()}'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final p in s.cotizacion!.partidas)
                      Row(children: [Expanded(child: Text('${p.concepto} × ${p.cantidad}')), Text(pesos(p.importe))]),
                    const Divider(height: 20),
                    Row(children: [const Expanded(child: Text('Total')), Text(pesos(s.cotizacion!.total), style: tema.textTheme.titleMedium)]),
                    if (s.cotizacion!.comentarioCliente != null)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text('Cliente: ${s.cotizacion!.comentarioCliente}', style: tema.textTheme.bodySmall)),
                  ],
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 18),
        const SectionLabel('Línea de tiempo'),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: EventosSolicitud(eventos: s.eventos))),
        if (s.estado == EstadoSolicitud.enRevision || s.estado == EstadoSolicitud.cotizado) ...[
          const SizedBox(height: 12),
          TextButton(
            key: const Key('boton-cancelar-admin'),
            style: TextButton.styleFrom(foregroundColor: tema.colorScheme.error),
            onPressed: () async {
              final motivo = await pedirMotivo(context, titulo: '¿Cancelar la solicitud?', textoConfirmar: 'Sí, cancelar');
              if (motivo == null || !context.mounted) return;
              final exito = await ejecutarConAviso(
                context,
                () => ref.read(solicitudesRepositoryProvider).cancelar(s.id, motivo: motivo.isEmpty ? null : motivo),
                exito: 'Solicitud cancelada',
              );
              if (exito) recargar();
            },
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: estilo)),
        ],
      ),
    );
  }
}

/// Elige técnico del ranking y la ventana de visita.
class _Asignacion extends ConsumerStatefulWidget {
  const _Asignacion({required this.solicitud, required this.alAsignar});

  final Solicitud solicitud;
  final VoidCallback alAsignar;

  @override
  ConsumerState<_Asignacion> createState() => _AsignacionState();
}

class _AsignacionState extends ConsumerState<_Asignacion> {
  int? _tecnicoId;
  late DateTime _dia;
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  int _duracion = 2;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final s = widget.solicitud;
    _tecnicoId = s.tecnico?.id;
    final inicio = s.resumen.ventanaInicio;
    if (inicio != null) {
      _dia = DateTime(inicio.year, inicio.month, inicio.day);
      _hora = TimeOfDay.fromDateTime(inicio);
      _duracion = s.resumen.ventanaFin!.difference(inicio).inHours.clamp(1, 8);
    } else {
      final manana = DateTime.now().add(const Duration(days: 1));
      _dia = DateTime(manana.year, manana.month, manana.day);
    }
  }

  DateTime get _inicio => DateTime(_dia.year, _dia.month, _dia.day, _hora.hour, _hora.minute);

  Future<void> _asignar() async {
    setState(() => _guardando = true);
    final exito = await ejecutarConAviso(
      context,
      () => ref.read(adminRepositoryProvider).asignar(
            widget.solicitud.id,
            tecnicoId: _tecnicoId!,
            inicio: _inicio,
            fin: _inicio.add(Duration(hours: _duracion)),
          ),
      exito: 'Técnico asignado',
    );
    if (mounted) setState(() => _guardando = false);
    if (exito) widget.alAsignar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final recomendados = ref.watch(recomendadosProvider(widget.solicitud.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Técnicos recomendados', style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
            Text('Ordenados por especialidad, disponibilidad, carga y calificación.', style: tema.textTheme.bodySmall),
            const SizedBox(height: 10),
            switch (recomendados) {
              AsyncData(:final value) when value.isEmpty => Text('No hay técnicos activos. Da de alta uno en Técnicos.', style: tema.textTheme.bodySmall),
              AsyncData(:final value) => Column(
                  children: [
                    for (final (i, t) in value.indexed)
                      _OpcionTecnico(
                        tecnico: t,
                        mejor: i == 0,
                        elegido: t.id == _tecnicoId,
                        alElegir: () => setState(() => _tecnicoId = t.id),
                      ),
                  ],
                ),
              AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(recomendadosProvider(widget.solicitud.id))),
              _ => const Cargando(),
            },
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('boton-dia-visita'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: () async {
                      final hoy = DateTime.now();
                      final dia = await showDatePicker(
                        context: context,
                        initialDate: _dia.isBefore(hoy) ? hoy : _dia,
                        firstDate: DateTime(hoy.year, hoy.month, hoy.day),
                        lastDate: hoy.add(const Duration(days: 60)),
                      );
                      if (dia != null) setState(() => _dia = dia);
                    },
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(fechaCorta(_dia)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('boton-hora-visita'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: () async {
                      final hora = await showTimePicker(context: context, initialTime: _hora);
                      if (hora != null) setState(() => _hora = hora);
                    },
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_hora.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _duracion,
              decoration: const InputDecoration(labelText: 'Duración de la ventana'),
              items: [for (final h in [1, 2, 3, 4, 6, 8]) DropdownMenuItem(value: h, child: Text('$h h'))],
              onChanged: (v) => setState(() => _duracion = v ?? _duracion),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('boton-asignar'),
              onPressed: _tecnicoId == null || _guardando ? null : _asignar,
              child: Text(widget.solicitud.tecnico == null ? 'Asignar técnico' : 'Actualizar asignación'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionTecnico extends StatelessWidget {
  const _OpcionTecnico({required this.tecnico, required this.mejor, required this.elegido, required this.alElegir});

  final TecnicoRecomendado tecnico;
  final bool mejor;
  final bool elegido;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    final c = context.acColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: elegido ? c.tealBg : cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: elegido ? cs.outline : cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('tecnico-${tecnico.id}'),
          onTap: alElegir,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(tecnico.nombre, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                          if (mejor) const StatusPill('Recomendado', tono: PillTone.green),
                          if (tecnico.asignado) const StatusPill('Asignado'),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('★ ${tecnico.calificacion.toStringAsFixed(1)} · ${tecnico.razones.join(' · ')}', style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('${tecnico.puntaje}', style: TextStyle(color: c.tealFg, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Edición de las partidas del borrador generado a partir del diagnóstico.
class _EditorCotizacion extends ConsumerStatefulWidget {
  const _EditorCotizacion({super.key, required this.solicitud, required this.alGuardar});

  final Solicitud solicitud;
  final VoidCallback alGuardar;

  @override
  ConsumerState<_EditorCotizacion> createState() => _EditorCotizacionState();
}

class _FilaPartida {
  _FilaPartida(Partida? p)
      : concepto = TextEditingController(text: p?.concepto ?? ''),
        cantidad = TextEditingController(text: '${p?.cantidad ?? 1}'),
        precio = TextEditingController(text: p == null ? '' : p.precioUnitario.toStringAsFixed(0));

  final TextEditingController concepto;
  final TextEditingController cantidad;
  final TextEditingController precio;

  Partida? get partida {
    final c = int.tryParse(cantidad.text);
    final p = double.tryParse(precio.text);
    if (concepto.text.trim().length < 3 || c == null || c < 1 || p == null) return null;
    return Partida(concepto: concepto.text.trim(), cantidad: c, precioUnitario: p);
  }

  void dispose() {
    concepto.dispose();
    cantidad.dispose();
    precio.dispose();
  }
}

class _EditorCotizacionState extends ConsumerState<_EditorCotizacion> {
  late final List<_FilaPartida> _filas = [
    for (final p in widget.solicitud.cotizacion?.partidas ?? const <Partida>[]) _FilaPartida(p),
  ];
  bool _modificada = false;
  bool _guardando = false;

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  double get _total => _filas.fold(0, (s, f) => s + (f.partida?.importe ?? 0));

  Future<void> _guardar() async {
    final partidas = _filas.map((f) => f.partida).toList();
    if (partidas.isEmpty || partidas.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa las partidas: cada una necesita concepto, cantidad y precio.')),
      );
      return;
    }
    setState(() => _guardando = true);
    final exito = await ejecutarConAviso(
      context,
      () => ref.read(adminRepositoryProvider).guardarCotizacion(widget.solicitud.id, partidas.cast<Partida>()),
      exito: 'Cotización guardada',
    );
    if (!mounted) return;
    setState(() {
      _guardando = false;
      if (exito) _modificada = false;
    });
    if (exito) widget.alGuardar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cotizacion = widget.solicitud.cotizacion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cotizacion?.generadaAuto ?? false)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Borrador generado a partir del costo estimado por el asistente. Revísalo antes de enviarlo.',
                    style: tema.textTheme.bodySmall),
              ),
            for (final (i, f) in _filas.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: Key('partida-$i-concepto'),
                            controller: f.concepto,
                            onChanged: (_) => setState(() => _modificada = true),
                            decoration: const InputDecoration(labelText: 'Concepto', isDense: true),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar partida',
                          onPressed: () => setState(() {
                            _filas.removeAt(i).dispose();
                            _modificada = true;
                          }),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: TextField(
                            key: Key('partida-$i-cantidad'),
                            controller: f.cantidad,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() => _modificada = true),
                            decoration: const InputDecoration(labelText: 'Cant.', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: Key('partida-$i-precio'),
                            controller: f.precio,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            onChanged: (_) => setState(() => _modificada = true),
                            decoration: const InputDecoration(labelText: 'Precio unitario', prefixText: r'$ ', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              key: const Key('boton-agregar-partida'),
              onPressed: () => setState(() {
                _filas.add(_FilaPartida(null));
                _modificada = true;
              }),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar partida'),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: Text('Total', style: tema.textTheme.titleMedium)),
                Text(pesos(_total), style: tema.textTheme.titleLarge),
              ],
            ),
            if (_modificada) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('boton-guardar-cotizacion'),
                onPressed: _guardando ? null : _guardar,
                child: const Text('Guardar cambios'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

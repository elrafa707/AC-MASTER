import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/equipos_repository.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/diagnostico.dart';
import '../../models/solicitud.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/estado_pill.dart';
import '../../shared/widgets/section_label.dart';

/// Crea la solicitud de servicio a partir de un diagnóstico. Se permite aunque el asistente sugiriera autoayuda.
class SolicitarTecnicoScreen extends ConsumerStatefulWidget {
  const SolicitarTecnicoScreen({super.key, required this.diagnostico});

  final Diagnostico diagnostico;

  @override
  ConsumerState<SolicitarTecnicoScreen> createState() => _SolicitarTecnicoScreenState();
}

class _SolicitarTecnicoScreenState extends ConsumerState<SolicitarTecnicoScreen> {
  int? _direccionId;
  bool _agregando = false;
  bool _enviando = false;
  String? _error;
  final _descripcion = TextEditingController();

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final solicitud = await ref.read(solicitudesRepositoryProvider).crear(
            diagnosticoId: widget.diagnostico.id,
            direccionId: _direccionId!,
            descripcion: _descripcion.text,
          );
      ref
        ..invalidate(misSolicitudesProvider)
        ..invalidate(notificacionesProvider)
        ..invalidate(fichaEquipoProvider(widget.diagnostico.equipoId));
      if (!mounted) return;
      context
        ..go(Rutas.inicio)
        ..push(Rutas.solicitud(solicitud.id));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final d = widget.diagnostico;
    final direcciones = ref.watch(direccionesProvider);
    final lista = direcciones.value ?? const <Direccion>[];
    if (_direccionId == null && lista.isNotEmpty) {
      _direccionId = (lista.where((x) => x.principal).firstOrNull ?? lista.first).id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar técnico')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PrioridadPill(d.prioridad),
                          const SizedBox(height: 10),
                          Text(d.falla, style: tema.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Costo estimado: ${pesos(d.costoMin)} – ${pesos(d.costoMax)}', style: tema.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  if (!d.requiereTecnico) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: c.blueBg, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        'El asistente creía que podías resolverlo con la guía, pero un técnico puede revisarlo si lo prefieres.',
                        style: TextStyle(color: c.blueFg, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SectionLabel(
                    '¿Dónde está el equipo?',
                    accion: _agregando || lista.isEmpty ? null : 'Agregar',
                    alPresionar: () => setState(() => _agregando = true),
                  ),
                  switch (direcciones) {
                    AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(direccionesProvider)),
                    AsyncData() => Column(
                        children: [
                          for (final dir in lista)
                            _OpcionDireccion(
                              direccion: dir,
                              elegida: dir.id == _direccionId,
                              alElegir: () => setState(() => _direccionId = dir.id),
                            ),
                          if (_agregando || lista.isEmpty)
                            _NuevaDireccion(
                              alGuardar: (nueva) {
                                ref.invalidate(direccionesProvider);
                                setState(() {
                                  _direccionId = nueva.id;
                                  _agregando = false;
                                });
                              },
                              alCancelar: lista.isEmpty ? null : () => setState(() => _agregando = false),
                            ),
                        ],
                      ),
                    _ => const Cargando(),
                  },
                  const SizedBox(height: 18),
                  TextField(
                    key: const Key('campo-descripcion-solicitud'),
                    controller: _descripcion,
                    maxLength: 1000,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Indicaciones para el técnico (opcional)',
                      hintText: 'Horarios, acceso a la azotea, mascotas…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  Text(
                    'Un administrador asignará al técnico más adecuado y te enviará la cotización para que la apruebes.',
                    style: tema.textTheme.bodySmall,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, key: const Key('error-solicitud'), style: TextStyle(color: tema.colorScheme.error)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                key: const Key('boton-enviar-solicitud'),
                onPressed: _direccionId != null && !_enviando ? _enviar : null,
                child: _enviando
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                    : const Text('Enviar solicitud'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionDireccion extends StatelessWidget {
  const _OpcionDireccion({required this.direccion, required this.elegida, required this.alElegir});

  final Direccion direccion;
  final bool elegida;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: elegida ? context.acColors.tealBg : cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: elegida ? cs.outline : cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('direccion-${direccion.id}'),
          onTap: alElegir,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.place_outlined, color: elegida ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(direccion.alias, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                      Text(direccion.completa, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  elegida ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: elegida ? cs.primary : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NuevaDireccion extends ConsumerStatefulWidget {
  const _NuevaDireccion({required this.alGuardar, this.alCancelar});

  final ValueChanged<Direccion> alGuardar;
  final VoidCallback? alCancelar;

  @override
  ConsumerState<_NuevaDireccion> createState() => _NuevaDireccionState();
}

class _NuevaDireccionState extends ConsumerState<_NuevaDireccion> {
  final _formKey = GlobalKey<FormState>();
  final _alias = TextEditingController(text: 'Casa');
  final _calle = TextEditingController();
  final _colonia = TextEditingController();
  final _ciudad = TextEditingController(text: 'Monterrey');
  final _cp = TextEditingController();
  bool _guardando = false;
  Map<String, String> _errores = const {};

  @override
  void dispose() {
    for (final c in [_alias, _calle, _colonia, _ciudad, _cp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _errores = const {};
    });
    try {
      final nueva = await ref.read(solicitudesRepositoryProvider).agregarDireccion(
            alias: _alias.text.trim(),
            calle: _calle.text.trim(),
            colonia: _colonia.text.trim(),
            ciudad: _ciudad.text.trim(),
            cp: _cp.text.trim(),
          );
      widget.alGuardar(nueva);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errores = e.detalles.isEmpty ? {'calle': e.mensaje} : e.detalles);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _requerido(String? v, String mensaje) => (v == null || v.trim().length < 2) ? mensaje : null;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nueva dirección', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alias,
                decoration: const InputDecoration(labelText: 'Nombre (Casa, Oficina…)'),
                forceErrorText: _errores['alias'],
                validator: (v) => _requerido(v, 'Ponle un nombre'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('campo-calle'),
                controller: _calle,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Calle y número'),
                forceErrorText: _errores['calle'],
                validator: (v) => (v == null || v.trim().length < 3) ? 'Escribe la calle y el número' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('campo-colonia'),
                controller: _colonia,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Colonia'),
                forceErrorText: _errores['colonia'],
                validator: (v) => _requerido(v, 'Escribe la colonia'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _ciudad,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Ciudad'),
                      forceErrorText: _errores['ciudad'],
                      validator: (v) => _requerido(v, 'Escribe la ciudad'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cp,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                      decoration: const InputDecoration(labelText: 'C.P.'),
                      forceErrorText: _errores['cp'],
                      validator: (v) => (v == null || v.isEmpty || v.length == 5) ? null : '5 dígitos',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.alCancelar != null) TextButton(onPressed: widget.alCancelar, child: const Text('Cancelar')),
                  const Spacer(),
                  FilledButton(
                    key: const Key('boton-guardar-direccion'),
                    style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
                    onPressed: _guardando ? null : _guardar,
                    child: const Text('Guardar dirección'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

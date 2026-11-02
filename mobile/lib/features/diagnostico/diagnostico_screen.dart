import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../data/diagnosticos_repository.dart';
import '../../data/equipos_repository.dart';
import '../../models/diagnostico.dart';
import '../../models/equipo.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/status_pill.dart';
import 'resultado_diagnostico.dart';
import 'selector_fotos.dart';

enum _Paso { sintomas, preguntas, fotos, analizando, resultado }

const _maxFotos = 3;

/// Interfaz 3: diagnóstico predictivo y cuestionario inteligente (RF-02, RF-03).
class DiagnosticoScreen extends ConsumerStatefulWidget {
  const DiagnosticoScreen({super.key, this.equipoId});

  final int? equipoId;

  @override
  ConsumerState<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _DiagnosticoScreenState extends ConsumerState<DiagnosticoScreen> {
  _Paso _paso = _Paso.sintomas;
  int? _equipoId;
  final _sintomas = <String>{};
  List<Pregunta> _preguntas = const [];
  final _respuestas = <String, String>{};
  final _fotos = <FotoSeleccionada>[];
  final _descripcion = TextEditingController();
  Diagnostico? _diagnostico;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _equipoId = widget.equipoId;
  }

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _irAPreguntas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cuestionario = await ref.read(diagnosticosRepositoryProvider).cuestionario(_sintomas.toList());
      if (!mounted) return;
      setState(() {
        _preguntas = cuestionario.preguntas;
        _respuestas.removeWhere((id, _) => !_preguntas.any((p) => p.id == id));
        _paso = _Paso.preguntas;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _agregarFoto(ImageSource origen) async {
    try {
      final foto = await ref.read(elegirFotoProvider)(origen);
      if (foto != null && mounted) setState(() => _fotos.add(foto));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos abrir la cámara o la galería. Revisa los permisos de la app.')),
        );
      }
    }
  }

  Future<void> _analizar() async {
    setState(() {
      _paso = _Paso.analizando;
      _error = null;
    });
    try {
      final diagnostico = await ref.read(diagnosticosRepositoryProvider).diagnosticar(
            equipoId: _equipoId!,
            sintomas: _sintomas.toList(),
            respuestas: Map.of(_respuestas),
            fotos: List.of(_fotos),
            descripcion: _descripcion.text,
          );
      ref.invalidate(fichaEquipoProvider(_equipoId!));
      if (!mounted) return;
      setState(() {
        _diagnostico = diagnostico;
        _paso = _Paso.resultado;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _paso = _Paso.fotos;
      });
    }
  }

  void _atras() {
    setState(() {
      _error = null;
      _paso = switch (_paso) {
        _Paso.preguntas => _Paso.sintomas,
        _Paso.fotos => _Paso.preguntas,
        _ => _paso,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final puedeRegresar = _paso == _Paso.preguntas || _paso == _Paso.fotos;
    return PopScope(
      canPop: !puedeRegresar && _paso != _Paso.analizando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && puedeRegresar) _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diagnóstico'),
          automaticallyImplyLeading: _paso != _Paso.analizando,
        ),
        body: SafeArea(
          child: switch (_paso) {
            _Paso.sintomas => _pasoSintomas(),
            _Paso.preguntas => _pasoPreguntas(),
            _Paso.fotos => _pasoFotos(),
            _Paso.analizando => const _Analizando(),
            _Paso.resultado => VistaResultado(diagnostico: _diagnostico!),
          },
        ),
      ),
    );
  }

  Widget _pasoSintomas() {
    final equipos = ref.watch(misEquiposProvider);
    final catalogo = ref.watch(catalogoSintomasProvider);
    final listo = _equipoId != null && _sintomas.isNotEmpty;

    if (equipos.hasError || catalogo.hasError) {
      return ErrorConReintento(
        error: equipos.error ?? catalogo.error!,
        alReintentar: () => ref
          ..invalidate(misEquiposProvider)
          ..invalidate(catalogoSintomasProvider),
      );
    }
    if (!equipos.hasValue || !catalogo.hasValue) return const Cargando();

    final listaEquipos = equipos.value!;
    if (_equipoId == null && listaEquipos.length == 1) _equipoId = listaEquipos.first.id;

    return _Pantalla(
      paso: 1,
      titulo: 'Vamos a encontrar la causa.',
      subtitulo: 'Responde con calma. Tus respuestas ayudan a preparar una solución más precisa.',
      error: _error,
      boton: FilledButton(
        key: const Key('boton-continuar-sintomas'),
        onPressed: listo && !_cargando ? _irAPreguntas : null,
        child: _cargando ? const _Spinner() : const Text('Continuar'),
      ),
      children: [
        const SectionLabel('Equipo a revisar'),
        for (final e in listaEquipos) _OpcionEquipo(equipo: e, elegido: e.id == _equipoId, alElegir: () => setState(() => _equipoId = e.id)),
        const SizedBox(height: 18),
        SectionLabel('Cuéntanos qué pasa${_sintomas.isEmpty ? '' : ' · ${_sintomas.length}'}'),
        for (final s in catalogo.value!)
          _OpcionSintoma(
            sintoma: s,
            elegido: _sintomas.contains(s.clave),
            alCambiar: () => setState(() => _sintomas.contains(s.clave) ? _sintomas.remove(s.clave) : _sintomas.add(s.clave)),
          ),
      ],
    );
  }

  Widget _pasoPreguntas() {
    final faltan = _preguntas.where((p) => !_respuestas.containsKey(p.id)).length;
    return _Pantalla(
      paso: 2,
      titulo: 'Unas preguntas rápidas.',
      subtitulo: 'Nos ayudan a distinguir entre causas que se ven parecidas.',
      error: _error,
      boton: FilledButton(
        key: const Key('boton-continuar-preguntas'),
        onPressed: faltan == 0 ? () => setState(() => _paso = _Paso.fotos) : null,
        child: Text(faltan == 0 ? 'Continuar' : 'Faltan $faltan respuestas'),
      ),
      children: [
        for (final p in _preguntas)
          _TarjetaPregunta(
            pregunta: p,
            respuesta: _respuestas[p.id],
            alResponder: (r) => setState(() => _respuestas[p.id] = r),
          ),
      ],
    );
  }

  Widget _pasoFotos() {
    final tema = Theme.of(context);
    final c = context.acColors;
    return _Pantalla(
      paso: 3,
      titulo: 'Una foto ayuda mucho.',
      subtitulo: 'Fotografía la unidad exterior (el compresor) de frente y con buena luz. Puedes agregar hasta 3.',
      error: _error,
      boton: FilledButton.icon(
        key: const Key('boton-analizar'),
        onPressed: _analizar,
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: const Text('Analizar con el asistente'),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.tealBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tema.colorScheme.outline.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_fotos.isNotEmpty) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (i, f) in _fotos.indexed)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(Uint8List.fromList(f.bytes), width: 88, height: 88, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: IconButton.filledTonal(
                              tooltip: 'Quitar foto',
                              visualDensity: VisualDensity.compact,
                              iconSize: 16,
                              onPressed: () => setState(() => _fotos.removeAt(i)),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              if (_fotos.length < _maxFotos)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('boton-camara'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: tema.colorScheme.surfaceContainerLowest),
                        onPressed: () => _agregarFoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Cámara'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('boton-galeria'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: tema.colorScheme.surfaceContainerLowest),
                        onPressed: () => _agregarFoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                )
              else
                Text('Ya agregaste el máximo de $_maxFotos fotos.', style: tema.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('campo-descripcion'),
          controller: _descripcion,
          maxLength: 1000,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: '¿Algo más que debamos saber? (opcional)',
            hintText: 'Ej. Empezó después de un apagón; hace un clic al encender.',
            alignLabelWithHint: true,
          ),
        ),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text('El resultado es orientativo. Un técnico confirma la causa en sitio.', style: tema.textTheme.bodySmall)),
          ],
        ),
      ],
    );
  }
}

/// Estructura común de los tres pasos: encabezado con progreso, contenido y botón fijo abajo.
class _Pantalla extends StatelessWidget {
  const _Pantalla({
    required this.paso,
    required this.titulo,
    required this.subtitulo,
    required this.children,
    required this.boton,
    this.error,
  });

  final int paso;
  final String titulo;
  final String subtitulo;
  final List<Widget> children;
  final Widget boton;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: c.hero, borderRadius: BorderRadius.circular(26)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill('Paso $paso de 3'),
                    const SizedBox(height: 14),
                    Text(titulo, style: tema.textTheme.headlineSmall?.copyWith(color: c.heroForeground)),
                    const SizedBox(height: 6),
                    Text(subtitulo, style: tema.textTheme.bodyMedium?.copyWith(color: c.heroMuted)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: paso / 3,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        color: const Color(0xFF72D4D0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...children,
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const Key('aviso-error-diagnostico'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(error!, style: TextStyle(color: tema.colorScheme.error, fontSize: 12.5)),
                ),
              ],
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: boton),
      ],
    );
  }
}

class _OpcionEquipo extends StatelessWidget {
  const _OpcionEquipo({required this.equipo, required this.elegido, required this.alElegir});

  final Equipo equipo;
  final bool elegido;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return _Seleccionable(
      elegido: elegido,
      alTocar: alElegir,
      icono: Icons.ac_unit_rounded,
      titulo: equipo.nombre,
      detalle: [equipo.ubicacion, 'Serie ${equipo.numeroSerie}'].whereType<String>().join(' · '),
      marca: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          elegido ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
          color: elegido ? tema.colorScheme.primary : tema.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _OpcionSintoma extends StatelessWidget {
  const _OpcionSintoma({required this.sintoma, required this.elegido, required this.alCambiar});

  final Sintoma sintoma;
  final bool elegido;
  final VoidCallback alCambiar;

  static const _iconos = {
    'NO_ENFRIA': Icons.thermostat_rounded,
    'NO_ENCIENDE': Icons.power_settings_new_rounded,
    'GOTEA': Icons.water_drop_outlined,
    'RUIDO': Icons.graphic_eq_rounded,
    'MAL_OLOR': Icons.air_rounded,
  };

  @override
  Widget build(BuildContext context) => _Seleccionable(
        key: Key('sintoma-${sintoma.clave}'),
        elegido: elegido,
        alTocar: alCambiar,
        icono: _iconos[sintoma.clave] ?? Icons.help_outline_rounded,
        titulo: sintoma.etiqueta,
        detalle: sintoma.detalle,
        marca: Checkbox(value: elegido, onChanged: (_) => alCambiar()),
      );
}

class _Seleccionable extends StatelessWidget {
  const _Seleccionable({
    super.key,
    required this.elegido,
    required this.alTocar,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.marca,
  });

  final bool elegido;
  final VoidCallback alTocar;
  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget marca;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    final c = context.acColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: elegido ? c.tealBg : cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: BorderSide(color: elegido ? cs.outline : cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: elegido ? cs.primary : cs.surfaceContainer, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icono, size: 19, color: elegido ? cs.onPrimary : c.label),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(detalle, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
                marca,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaPregunta extends StatelessWidget {
  const _TarjetaPregunta({required this.pregunta, required this.respuesta, required this.alResponder});

  final Pregunta pregunta;
  final String? respuesta;
  final ValueChanged<String> alResponder;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: Key('pregunta-${pregunta.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pregunta.texto, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
              if (pregunta.ayuda != null) ...[
                const SizedBox(height: 4),
                Text(pregunta.ayuda!, style: tema.textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in pregunta.opciones)
                    ChoiceChip(
                      label: Text(o),
                      selected: respuesta == o,
                      onSelected: (_) => alResponder(o),
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

class _Analizando extends StatelessWidget {
  const _Analizando();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(color: c.tealBg, shape: BoxShape.circle),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(dimension: 110, child: CircularProgressIndicator(strokeWidth: 3, color: c.tealFg)),
                  Icon(Icons.ac_unit_rounded, size: 36, color: c.tealFg),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const StatusPill('Analizando tu caso'),
            const SizedBox(height: 14),
            Text('Un momento, estamos\nordenando las señales.', textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'El asistente cruza tus síntomas, las respuestas, la antigüedad del equipo y las fotos. Puede tardar hasta un minuto.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2));
}

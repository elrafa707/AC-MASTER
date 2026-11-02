import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../data/equipos_repository.dart';
import '../../models/equipo.dart';

const _tipos = ['Minisplit', 'Ventana', 'Central', 'Portátil'];
const _refrigerantes = ['R-410A', 'R-32', 'R-22', 'Otro'];
const _capacidades = {
  9000: '9,000 BTU (¾ t)',
  12000: '12,000 BTU (1 t)',
  18000: '18,000 BTU (1.5 t)',
  24000: '24,000 BTU (2 t)',
  36000: '36,000 BTU (3 t)',
};

/// Registro de un equipo del cliente. El número de serie es la llave de su historial (RF-08).
class NuevoEquipoScreen extends ConsumerStatefulWidget {
  const NuevoEquipoScreen({super.key});

  @override
  ConsumerState<NuevoEquipoScreen> createState() => _NuevoEquipoScreenState();
}

class _NuevoEquipoScreenState extends ConsumerState<NuevoEquipoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serie = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _ubicacion = TextEditingController();

  String _tipo = _tipos.first;
  int? _capacidad;
  String? _refrigerante;
  DateTime? _instalacion;
  bool _guardando = false;
  String? _error;
  Map<String, String> _erroresCampo = const {};

  @override
  void dispose() {
    _serie.dispose();
    _marca.dispose();
    _modelo.dispose();
    _ubicacion.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _instalacion ?? hoy,
      firstDate: DateTime(1995),
      lastDate: hoy,
      helpText: 'Fecha de instalación',
    );
    if (fecha != null) setState(() => _instalacion = fecha);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _erroresCampo = const {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      final ficha = await ref.read(equiposRepositoryProvider).registrar(
            NuevoEquipo(
              numeroSerie: _serie.text.trim().toUpperCase(),
              marca: _marca.text.trim(),
              modelo: _modelo.text.trim(),
              tipo: _tipo,
              capacidadBTU: _capacidad,
              refrigerante: _refrigerante,
              ubicacion: _ubicacion.text.trim(),
              fechaInstalacion: _instalacion,
            ),
          );
      ref.invalidate(misEquiposProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ficha.equipo.nombre} registrado')));
      context.pushReplacement(Rutas.fichaEquipo(ficha.equipo.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.detalles.isEmpty ? e.mensaje : null;
        _erroresCampo = e.detalles;
        if (e.codigo == 'SERIE_REGISTRADA') _erroresCampo = {'numeroSerie': e.mensaje};
      });
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar equipo')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Text(
                'El número de serie viene en una etiqueta a un costado de la unidad interior o exterior.',
                style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('campo-serie'),
                controller: _serie,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]'))],
                decoration: const InputDecoration(labelText: 'Número de serie', prefixIcon: Icon(Icons.qr_code_2_rounded)),
                forceErrorText: _erroresCampo['numeroSerie'],
                validator: (v) => (v == null || v.trim().length < 4) ? 'Mínimo 4 caracteres' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('campo-marca'),
                      controller: _marca,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Marca', hintText: 'Mirage, LG…'),
                      forceErrorText: _erroresCampo['marca'],
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Escribe la marca' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('campo-modelo'),
                      controller: _modelo,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Modelo'),
                      forceErrorText: _erroresCampo['modelo'],
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el modelo' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de equipo'),
                items: [for (final t in _tipos) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _capacidad,
                      decoration: const InputDecoration(labelText: 'Capacidad'),
                      isExpanded: true,
                      items: [
                        for (final MapEntry(:key, :value) in _capacidades.entries)
                          DropdownMenuItem(value: key, child: Text(value, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _capacidad = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _refrigerante,
                      decoration: const InputDecoration(labelText: 'Refrigerante'),
                      items: [for (final r in _refrigerantes) DropdownMenuItem(value: r, child: Text(r))],
                      onChanged: (v) => setState(() => _refrigerante = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ubicacion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Ubicación (opcional)', hintText: 'Sala, recámara principal…'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('boton-fecha'),
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: _elegirFecha,
                icon: const Icon(Icons.event_outlined),
                label: Text(_instalacion == null ? 'Fecha de instalación (opcional)' : 'Instalado el ${fechaLarga(_instalacion!)}'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TextStyle(color: tema.colorScheme.error)),
              ],
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('boton-guardar-equipo'),
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                    : const Text('Guardar equipo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../data/admin_repository.dart';
import '../../models/admin.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/estado_carga.dart';
import '../../shared/widgets/status_pill.dart';

/// Alta y administración de técnicos: especialidades y cuentas activas.
class TecnicosScreen extends ConsumerWidget {
  const TecnicosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tecnicos = ref.watch(tecnicosProvider);
    final especialidades = {for (final e in ref.watch(especialidadesProvider).value ?? const <Especialidad>[]) e.clave: e.nombre};

    return Scaffold(
      appBar: AppBar(title: const Text('Técnicos')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton-nuevo-tecnico'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NuevoTecnicoScreen())),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nuevo técnico'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tecnicosProvider.future),
        child: switch (tecnicos) {
          AsyncData(:final value) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              children: [
                if (value.isEmpty)
                  const Vacio(icono: Icons.engineering_outlined, titulo: 'Sin técnicos', mensaje: 'Da de alta al primero con el botón de abajo.'),
                for (final t in value) _TarjetaTecnico(tecnico: t, nombres: especialidades),
              ],
            ),
          AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(tecnicosProvider)),
          _ => const Cargando(),
        },
      ),
    );
  }
}

class _TarjetaTecnico extends ConsumerWidget {
  const _TarjetaTecnico({required this.tecnico, required this.nombres});

  final TecnicoCuenta tecnico;
  final Map<String, String> nombres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final t = tecnico;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        key: Key('tarjeta-tecnico-${t.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.nombre, style: tema.textTheme.titleMedium),
                        Text(t.correo, style: tema.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Switch(
                    key: Key('switch-tecnico-${t.id}'),
                    value: t.activo,
                    onChanged: (activo) async {
                      final ok = await ejecutarConAviso(
                        context,
                        () => ref.read(adminRepositoryProvider).editarTecnico(t.id, activo: activo),
                        exito: activo ? 'Cuenta activada' : 'Cuenta desactivada',
                      );
                      if (ok) ref.invalidate(tecnicosProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (!t.activo) const StatusPill('Inactivo', tono: PillTone.orange)
                  else StatusPill(t.disponible ? 'Disponible' : 'Ocupado', tono: t.disponible ? PillTone.green : PillTone.blue),
                  for (final e in t.especialidades) StatusPill(nombres[e] ?? e),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '★ ${t.calificacion.toStringAsFixed(1)} · ${cantidad(t.serviciosActivos, 'activo', 'activos')} · ${cantidad(t.serviciosFinalizados, 'terminado', 'terminados')}',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final nuevas = await _elegirEspecialidades(context, ref, t.especialidades.toSet());
                      if (nuevas == null || !context.mounted) return;
                      final ok = await ejecutarConAviso(
                        context,
                        () => ref.read(adminRepositoryProvider).editarTecnico(t.id, especialidades: nuevas.toList()),
                        exito: 'Especialidades actualizadas',
                      );
                      if (ok) ref.invalidate(tecnicosProvider);
                    },
                    child: const Text('Especialidades'),
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

Future<Set<String>?> _elegirEspecialidades(BuildContext context, WidgetRef ref, Set<String> actuales) async {
  final todas = await ref.read(especialidadesProvider.future);
  if (!context.mounted) return null;
  final elegidas = {...actuales};
  return showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Especialidades'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in todas)
              FilterChip(
                label: Text(e.nombre),
                selected: elegidas.contains(e.clave),
                onSelected: (v) => setState(() => v ? elegidas.add(e.clave) : elegidas.remove(e.clave)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: elegidas.isEmpty ? null : () => Navigator.pop(context, elegidas),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

/// Alta de un técnico: el administrador le da una contraseña inicial.
class NuevoTecnicoScreen extends ConsumerStatefulWidget {
  const NuevoTecnicoScreen({super.key});

  @override
  ConsumerState<NuevoTecnicoScreen> createState() => _NuevoTecnicoScreenState();
}

class _NuevoTecnicoScreenState extends ConsumerState<NuevoTecnicoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();
  final _especialidades = <String>{};
  bool _guardando = false;
  Map<String, String> _errores = const {};
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _telefono, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _errores = const {};
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    if (_especialidades.isEmpty) {
      setState(() => _error = 'Elige al menos una especialidad');
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref.read(adminRepositoryProvider).crearTecnico(
            nombre: _nombre.text.trim(),
            correo: _correo.text.trim(),
            telefono: _telefono.text.trim(),
            password: _password.text,
            especialidades: _especialidades.toList(),
          );
      ref.invalidate(tecnicosProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cuenta de ${_nombre.text.trim()} creada')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errores = e.codigo == 'CORREO_REGISTRADO' ? {'correo': e.mensaje} : e.detalles;
          _error = _errores.isEmpty ? e.mensaje : null;
        });
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final especialidades = ref.watch(especialidadesProvider);
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo técnico')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              TextFormField(
                key: const Key('campo-nombre-tecnico'),
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                forceErrorText: _errores['nombre'],
                validator: (v) => (v == null || v.trim().length < 3) ? 'Escribe el nombre completo' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('campo-correo-tecnico'),
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Correo'),
                forceErrorText: _errores['correo'],
                validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                forceErrorText: _errores['telefono'],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('campo-password-tecnico'),
                controller: _password,
                decoration: const InputDecoration(labelText: 'Contraseña inicial', helperText: 'Compártela con el técnico en persona.'),
                forceErrorText: _errores['password'],
                validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
              ),
              const SizedBox(height: 18),
              Text('Especialidades', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in especialidades.value ?? const <Especialidad>[])
                    FilterChip(
                      key: Key('especialidad-${e.clave}'),
                      label: Text(e.nombre),
                      selected: _especialidades.contains(e.clave),
                      onSelected: (v) => setState(() => v ? _especialidades.add(e.clave) : _especialidades.remove(e.clave)),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: tema.colorScheme.error)),
              ],
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('boton-crear-tecnico'),
                onPressed: _guardando ? null : _guardar,
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

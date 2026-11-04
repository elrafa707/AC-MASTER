import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/admin_repository.dart';
import '../../models/solicitud.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/estado_carga.dart';

/// Catálogo de piezas que el técnico puede registrar en una orden.
class PiezasScreen extends ConsumerWidget {
  const PiezasScreen({super.key});

  Future<void> _editar(BuildContext context, WidgetRef ref, {Pieza? pieza}) async {
    final datos = await showDialog<({String codigo, String nombre, double precio})>(
      context: context,
      builder: (_) => _DialogoPieza(pieza: pieza),
    );
    if (datos == null || !context.mounted) return;
    final repo = ref.read(adminRepositoryProvider);
    final ok = await ejecutarConAviso(
      context,
      () => pieza == null
          ? repo.crearPieza(codigo: datos.codigo, nombre: datos.nombre, precio: datos.precio)
          : repo.editarPieza(pieza.id, nombre: datos.nombre, precio: datos.precio),
      exito: pieza == null ? 'Pieza agregada' : 'Pieza actualizada',
    );
    if (ok) ref.invalidate(piezasAdminProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final piezas = ref.watch(piezasAdminProvider);
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de piezas')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton-nueva-pieza'),
        onPressed: () => _editar(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva pieza'),
      ),
      body: switch (piezas) {
        AsyncData(:final value) => ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
            itemBuilder: (context, i) {
              final p = value[i];
              return ListTile(
                contentPadding: const EdgeInsets.only(left: 20, right: 8),
                title: Text(p.nombre, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14, color: p.activo ? null : tema.disabledColor)),
                subtitle: Text('${p.codigo} · ${pesos(p.precioUnitario)}', style: tema.textTheme.bodySmall),
                onTap: () => _editar(context, ref, pieza: p),
                trailing: Switch(
                  value: p.activo,
                  onChanged: (activo) async {
                    final ok = await ejecutarConAviso(context, () => ref.read(adminRepositoryProvider).editarPieza(p.id, activo: activo));
                    if (ok) ref.invalidate(piezasAdminProvider);
                  },
                ),
              );
            },
          ),
        AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(piezasAdminProvider)),
        _ => const Cargando(),
      },
    );
  }
}

class _DialogoPieza extends StatefulWidget {
  const _DialogoPieza({this.pieza});

  final Pieza? pieza;

  @override
  State<_DialogoPieza> createState() => _DialogoPiezaState();
}

class _DialogoPiezaState extends State<_DialogoPieza> {
  final _formKey = GlobalKey<FormState>();
  late final _codigo = TextEditingController(text: widget.pieza?.codigo ?? '');
  late final _nombre = TextEditingController(text: widget.pieza?.nombre ?? '');
  late final _precio = TextEditingController(text: widget.pieza?.precioUnitario.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nueva = widget.pieza == null;
    return AlertDialog(
      title: Text(nueva ? 'Nueva pieza' : 'Editar pieza'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _codigo,
              enabled: nueva,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]'))],
              decoration: const InputDecoration(labelText: 'Código'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Escribe el nombre' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _precio,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Precio unitario', prefixText: r'$ '),
              validator: (v) => double.tryParse(v ?? '') == null ? 'Precio inválido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (codigo: _codigo.text.trim().toUpperCase(), nombre: _nombre.text.trim(), precio: double.parse(_precio.text)));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

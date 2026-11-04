import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';

/// Pregunta sí/no. Devuelve true solo si el usuario confirma.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String textoConfirmar,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('boton-confirmar'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Pide un texto opcional (p. ej. el motivo de una cancelación). Devuelve null si el usuario se arrepiente.
Future<String?> pedirMotivo(BuildContext context, {required String titulo, required String textoConfirmar}) =>
    showDialog<String>(context: context, builder: (_) => _DialogoMotivo(titulo: titulo, textoConfirmar: textoConfirmar));

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({required this.titulo, required this.textoConfirmar});

  final String titulo;
  final String textoConfirmar;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

// El controlador vive con el diálogo: si se liberara al cerrar, la animación de salida lo usaría ya liberado.
class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.titulo),
        content: TextField(
          key: const Key('campo-motivo'),
          controller: _motivo,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
          FilledButton(
            key: const Key('boton-confirmar'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, _motivo.text.trim()),
            child: Text(widget.textoConfirmar),
          ),
        ],
      );
}

/// Ejecuta una acción contra la API mostrando el error, si lo hay, en un SnackBar. Devuelve true si salió bien.
Future<bool> ejecutarConAviso(BuildContext context, Future<void> Function() accion, {String? exito}) async {
  final mensajero = ScaffoldMessenger.of(context);
  try {
    await accion();
    if (exito != null) mensajero.showSnackBar(SnackBar(content: Text(exito)));
    return true;
  } on ApiException catch (e) {
    mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    return false;
  }
}

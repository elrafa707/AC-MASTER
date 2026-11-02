import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session/token_storage.dart';

/// Muestra una foto del backend; las fotos son privadas y se piden con el token de la sesión.
class FotoAutenticada extends ConsumerWidget {
  const FotoAutenticada(this.ruta, {super.key, this.tamanio = 72});

  final String ruta;
  final double tamanio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(tokenStorageProvider).actual;
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        urlDelServidor(ruta),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
        width: tamanio,
        height: tamanio,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: tamanio,
          height: tamanio,
          color: cs.surfaceContainer,
          child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

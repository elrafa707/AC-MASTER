import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';

/// Indicador de carga centrado.
class Cargando extends StatelessWidget {
  const Cargando({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      );
}

/// Mensaje de error con botón para reintentar.
class ErrorConReintento extends StatelessWidget {
  const ErrorConReintento({super.key, required this.error, required this.alReintentar});

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              error is ApiException ? (error as ApiException).mensaje : 'Algo salió mal al cargar la información.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
              onPressed: alReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje cuando una lista está vacía.
class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.icono, required this.titulo, required this.mensaje, this.accion});

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icono, size: 36, color: tema.colorScheme.primary),
            const SizedBox(height: 10),
            Text(titulo, style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(mensaje, style: tema.textTheme.bodySmall, textAlign: TextAlign.center),
            if (accion != null) ...[const SizedBox(height: 14), accion!],
          ],
        ),
      ),
    );
  }
}

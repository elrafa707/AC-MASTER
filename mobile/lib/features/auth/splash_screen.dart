import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../shared/widgets/brand_mark.dart';
import 'session_controller.dart';

/// Se muestra mientras se restaura la sesión guardada, o si el servidor no respondió al intentarlo.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sessionProvider);
    final tema = Theme.of(context);
    final error = sesion.error;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(tamanio: 64),
              const SizedBox(height: 18),
              Text('AC-Master', style: tema.textTheme.headlineMedium),
              const SizedBox(height: 24),
              if (error == null)
                const CircularProgressIndicator()
              else ...[
                Text(
                  error is ApiException ? error.mensaje : 'No pudimos recuperar tu sesión.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(sessionProvider),
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: () => ref.read(sessionProvider.notifier).cerrarSesion(),
                  child: const Text('Entrar con otra cuenta'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

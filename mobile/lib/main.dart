import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'features/auth/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        // Si el backend rechaza el token de una sesión activa, se cierra la sesión y el router manda al login.
        alExpirarSesionProvider.overrideWith(
          (ref) => () {
            if (ref.read(sessionProvider).value != null) {
              ref.read(sessionProvider.notifier).cerrarSesion();
            }
          },
        ),
      ],
      child: const AcMasterApp(),
    ),
  );
}

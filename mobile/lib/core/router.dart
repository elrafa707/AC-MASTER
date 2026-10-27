import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/splash_screen.dart';
import '../features/home/home_screen.dart';

abstract final class Rutas {
  static const splash = '/';
  static const login = '/login';
  static const inicio = '/inicio';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Avisa a go_router que vuelva a evaluar redirect cada vez que cambia la sesión.
  final cambiosSesion = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => cambiosSesion.value++);
  ref.onDispose(cambiosSesion.dispose);

  final router = GoRouter(
    initialLocation: Rutas.splash,
    refreshListenable: cambiosSesion,
    redirect: (context, state) {
      final sesion = ref.read(sessionProvider);
      final ruta = state.matchedLocation;

      if (sesion.isLoading && !sesion.hasValue || sesion.hasError) {
        return ruta == Rutas.splash ? null : Rutas.splash;
      }
      final usuario = sesion.value;
      if (usuario == null) return ruta == Rutas.login ? null : Rutas.login;
      if (ruta == Rutas.login || ruta == Rutas.splash) return Rutas.inicio;
      return null;
    },
    routes: [
      GoRoute(path: Rutas.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Rutas.inicio, builder: (_, _) => const HomeScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

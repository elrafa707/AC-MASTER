import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/splash_screen.dart';
import '../features/diagnostico/autoayuda_screen.dart';
import '../features/diagnostico/diagnostico_screen.dart';
import '../features/equipos/buscar_serie_screen.dart';
import '../features/equipos/ficha_equipo_screen.dart';
import '../features/equipos/nuevo_equipo_screen.dart';
import '../features/home/home_screen.dart';
import '../models/diagnostico.dart';
import '../models/usuario.dart';

abstract final class Rutas {
  static const splash = '/';
  static const login = '/login';
  static const inicio = '/inicio';
  static const nuevoEquipo = '/equipos/nuevo';
  static const buscarEquipo = '/equipos/buscar';
  static const diagnostico = '/diagnostico';
  static const autoayuda = '/diagnostico/autoayuda';

  static String fichaEquipo(int id) => '/equipos/$id';
  static String diagnosticoDe(int equipoId) => '$diagnostico?equipo=$equipoId';
}

/// Rutas exclusivas de un rol; el resto solo exige sesión.
const _soloCliente = {Rutas.nuevoEquipo, Rutas.diagnostico, Rutas.autoayuda};
const _soloPersonal = {Rutas.buscarEquipo};

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

      final esCliente = usuario.rol == Rol.cliente;
      if (_soloCliente.contains(ruta) && !esCliente) return Rutas.inicio;
      if (_soloPersonal.contains(ruta) && esCliente) return Rutas.inicio;
      return null;
    },
    routes: [
      GoRoute(path: Rutas.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Rutas.inicio, builder: (_, _) => const HomeScreen()),
      GoRoute(path: Rutas.nuevoEquipo, builder: (_, _) => const NuevoEquipoScreen()),
      GoRoute(path: Rutas.buscarEquipo, builder: (_, _) => const BuscarSerieScreen()),
      GoRoute(
        path: '/equipos/:id',
        redirect: (_, state) => int.tryParse(state.pathParameters['id']!) == null ? Rutas.inicio : null,
        builder: (_, state) => FichaEquipoScreen(equipoId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: Rutas.diagnostico,
        builder: (_, state) => DiagnosticoScreen(equipoId: int.tryParse(state.uri.queryParameters['equipo'] ?? '')),
      ),
      GoRoute(
        path: Rutas.autoayuda,
        // La guía necesita el diagnóstico en memoria; si se pierde (p. ej. al reiniciar la app) se vuelve al inicio.
        redirect: (_, state) => state.extra is Diagnostico ? null : Rutas.inicio,
        builder: (_, state) => AutoayudaScreen(diagnostico: state.extra! as Diagnostico),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

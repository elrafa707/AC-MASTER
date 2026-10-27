import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/session/token_storage.dart';
import '../../data/auth_repository.dart';
import '../../models/usuario.dart';

/// Usuario con sesión activa, o null si nadie ha iniciado sesión.
/// Al arrancar restaura la sesión guardada validando el token contra /me.
class SessionController extends AsyncNotifier<Usuario?> {
  TokenStorage get _tokens => ref.read(tokenStorageProvider);
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  @override
  Future<Usuario?> build() async {
    final token = await _tokens.leer();
    if (token == null) return null;
    try {
      return await _auth.perfil();
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _tokens.borrar();
        return null;
      }
      rethrow;
    }
  }

  /// Los errores se propagan para que la pantalla los muestre junto al formulario.
  Future<void> iniciarSesion({required String correo, required String password}) async {
    final sesion = await _auth.iniciarSesion(correo: correo, password: password);
    await _tokens.guardar(sesion.token);
    state = AsyncData(sesion.usuario);
  }

  Future<void> registrar({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
  }) async {
    final sesion = await _auth.registrar(nombre: nombre, correo: correo, password: password, telefono: telefono);
    await _tokens.guardar(sesion.token);
    state = AsyncData(sesion.usuario);
  }

  Future<void> cerrarSesion() async {
    await _tokens.borrar();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, Usuario?>(
  SessionController.new,
  // Sin reintentos automáticos: si el servidor no responde, la pantalla de inicio ofrece reintentar.
  retry: (_, _) => null,
);

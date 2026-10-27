import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el JWT en el almacenamiento cifrado del dispositivo (Keystore en Android).
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _clave = 'acmaster.jwt';
  final FlutterSecureStorage _storage;
  String? _enMemoria;

  Future<String?> leer() async => _enMemoria ??= await _storage.read(key: _clave);

  /// Valor ya cargado, para el interceptor HTTP (que no puede esperar a leer del disco).
  String? get actual => _enMemoria;

  Future<void> guardar(String token) async {
    _enMemoria = token;
    await _storage.write(key: _clave, value: token);
  }

  Future<void> borrar() async {
    _enMemoria = null;
    await _storage.delete(key: _clave);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

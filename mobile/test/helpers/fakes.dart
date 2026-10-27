import 'package:ac_master/app.dart';
import 'package:ac_master/core/api/api_exception.dart';
import 'package:ac_master/core/session/token_storage.dart';
import 'package:ac_master/data/auth_repository.dart';
import 'package:ac_master/models/usuario.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const clienteDemo = Usuario(id: 3, nombre: 'Rafael Báez', correo: 'cliente@acmaster.mx', rol: Rol.cliente);

class FakeTokenStorage extends TokenStorage {
  FakeTokenStorage([this._token]);

  String? _token;

  @override
  Future<String?> leer() async => _token;

  @override
  String? get actual => _token;

  @override
  Future<void> guardar(String token) async => _token = token;

  @override
  Future<void> borrar() async => _token = null;
}

/// Repositorio en memoria: acepta clienteDemo con la contraseña "AcMaster2026!".
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(Dio());

  final registrados = <String>{clienteDemo.correo};

  @override
  Future<Sesion> iniciarSesion({required String correo, required String password}) async {
    if (correo == clienteDemo.correo && password == 'AcMaster2026!') {
      return (token: 'token-demo', usuario: clienteDemo);
    }
    throw const ApiException('Correo o contraseña incorrectos', codigo: 'CREDENCIALES_INVALIDAS', status: 401);
  }

  @override
  Future<Sesion> registrar({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
  }) async {
    if (registrados.contains(correo)) {
      throw const ApiException(
        'Ya existe una cuenta con ese correo',
        codigo: 'CORREO_REGISTRADO',
        status: 409,
      );
    }
    registrados.add(correo);
    return (token: 'token-nuevo', usuario: Usuario(id: 99, nombre: nombre, correo: correo, rol: Rol.cliente));
  }

  @override
  Future<Usuario> perfil() async => clienteDemo;
}

Widget appDePrueba({FakeTokenStorage? tokens, FakeAuthRepository? auth}) => ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens ?? FakeTokenStorage()),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      ],
      child: const AcMasterApp(),
    );

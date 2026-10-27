import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/usuario.dart';

typedef Sesion = ({String token, Usuario usuario});

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<Sesion> iniciarSesion({required String correo, required String password}) =>
      _sesion('/auth/login', {'correo': correo, 'password': password});

  Future<Sesion> registrar({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
  }) =>
      _sesion('/auth/register', {
        'nombre': nombre,
        'correo': correo,
        'password': password,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      });

  Future<Usuario> perfil() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me');
      return Usuario.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }

  Future<Sesion> _sesion(String ruta, Map<String, dynamic> cuerpo) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(ruta, data: cuerpo);
      final data = res.data!;
      return (token: data['token'] as String, usuario: Usuario.fromJson(data['usuario'] as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));

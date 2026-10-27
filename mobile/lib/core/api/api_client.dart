import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../session/token_storage.dart';

/// Se invoca cuando el backend responde 401 a una petición autenticada (token vencido o cuenta desactivada).
typedef AlExpirarSesion = void Function();

final alExpirarSesionProvider = Provider<AlExpirarSesion>((ref) => () {});

final dioProvider = Provider<Dio>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokens.actual;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        final conToken = error.requestOptions.headers.containsKey('Authorization');
        if (conToken && error.response?.statusCode == 401) {
          ref.read(alExpirarSesionProvider)();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});

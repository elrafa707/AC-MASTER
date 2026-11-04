import 'package:dio/dio.dart';

import '../core/api/api_exception.dart';

/// Convierte los errores de Dio en [ApiException] para que las pantallas solo manejen un tipo de error.
Future<T> llamarApi<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } on DioException catch (e) {
    throw ApiException.desdeDio(e);
  }
}

typedef Json = Map<String, dynamic>;

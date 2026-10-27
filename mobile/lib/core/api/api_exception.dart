import 'package:dio/dio.dart';

/// Error de la API ya traducido a un mensaje que se puede mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.mensaje, {this.codigo, this.status, this.detalles = const {}});

  final String mensaje;
  final String? codigo;
  final int? status;

  /// Errores de validación por campo, tal como los regresa el backend.
  final Map<String, String> detalles;

  bool get sinConexion => codigo == 'SIN_CONEXION';

  factory ApiException.desdeDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(
          'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
          codigo: 'SIN_CONEXION',
        );
      default:
        break;
    }

    final data = e.response?.data;
    final error = data is Map ? data['error'] : null;
    if (error is Map) {
      final detalles = <String, String>{
        for (final d in (error['detalles'] as List? ?? const []))
          if (d is Map) '${d['campo']}': '${d['mensaje']}',
      };
      return ApiException(
        '${error['mensaje'] ?? 'Ocurrió un error'}',
        codigo: error['codigo'] as String?,
        status: e.response?.statusCode,
        detalles: detalles,
      );
    }
    return ApiException('Ocurrió un error inesperado. Inténtalo más tarde.', status: e.response?.statusCode);
  }

  @override
  String toString() => 'ApiException($status, $codigo): $mensaje';
}

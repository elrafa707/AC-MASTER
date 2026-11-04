import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../features/auth/session_controller.dart';
import '../models/solicitud.dart';
import 'api_base.dart';

/// Solicitudes vistas por el cliente, más lo que comparten todos los roles (detalle y notificaciones).
class SolicitudesRepository {
  SolicitudesRepository(this._dio);

  final Dio _dio;

  Future<List<Direccion>> direcciones() => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/me/direcciones');
        return [for (final d in res.data!) Direccion.fromJson(d as Json)];
      });

  Future<Direccion> agregarDireccion({
    required String alias,
    required String calle,
    required String colonia,
    required String ciudad,
    String? cp,
    String? referencias,
  }) =>
      llamarApi(() async {
        final res = await _dio.post<Json>('/me/direcciones', data: {
          'alias': alias,
          'calle': calle,
          'colonia': colonia,
          'ciudad': ciudad,
          if (cp != null && cp.isNotEmpty) 'cp': cp,
          if (referencias != null && referencias.isNotEmpty) 'referencias': referencias,
        });
        return Direccion.fromJson(res.data!);
      });

  Future<Solicitud> crear({required int diagnosticoId, required int direccionId, String? descripcion}) => llamarApi(() async {
        final res = await _dio.post<Json>('/solicitudes', data: {
          'diagnosticoId': diagnosticoId,
          'direccionId': direccionId,
          if (descripcion != null && descripcion.trim().isNotEmpty) 'descripcion': descripcion.trim(),
        });
        return Solicitud.fromJson(res.data!);
      });

  Future<List<ResumenSolicitud>> mias() => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/solicitudes');
        return [for (final s in res.data!) ResumenSolicitud.fromJson(s as Json)];
      });

  Future<Solicitud> detalle(int id) => _solicitud(() => _dio.get<Json>('/solicitudes/$id'));

  Future<Solicitud> aprobar(int id) => _solicitud(() => _dio.post<Json>('/solicitudes/$id/cotizacion/aprobar'));

  Future<Solicitud> rechazar(int id, {String? motivo}) =>
      _solicitud(() => _dio.post<Json>('/solicitudes/$id/cotizacion/rechazar', data: {'motivo': ?motivo}));

  Future<Solicitud> cancelar(int id, {String? motivo}) =>
      _solicitud(() => _dio.post<Json>('/solicitudes/$id/cancelar', data: {'motivo': ?motivo}));

  Future<Solicitud> calificar(int id, {required int calificacion, String? comentario}) => _solicitud(
        () => _dio.post<Json>('/solicitudes/$id/calificar', data: {
          'calificacion': calificacion,
          if (comentario != null && comentario.trim().isNotEmpty) 'comentario': comentario.trim(),
        }),
      );

  Future<BandejaNotificaciones> notificaciones() => llamarApi(() async {
        final res = await _dio.get<Json>('/notificaciones');
        return BandejaNotificaciones.fromJson(res.data!);
      });

  Future<void> marcarLeida(int id) => llamarApi(() => _dio.post<void>('/notificaciones/$id/leida'));

  Future<void> marcarTodasLeidas() => llamarApi(() => _dio.post<void>('/notificaciones/leidas'));

  Future<Solicitud> _solicitud(Future<Response<Json>> Function() peticion) => llamarApi(() async {
        final res = await peticion();
        return Solicitud.fromJson(res.data!);
      });
}

final solicitudesRepositoryProvider = Provider<SolicitudesRepository>((ref) => SolicitudesRepository(ref.watch(dioProvider)));

int? _usuarioActual(Ref ref) => ref.watch(sessionProvider.select((s) => s.value?.id));

final misSolicitudesProvider = FutureProvider<List<ResumenSolicitud>>((ref) {
  _usuarioActual(ref);
  return ref.watch(solicitudesRepositoryProvider).mias();
});

final solicitudProvider = FutureProvider.family<Solicitud, int>((ref, id) {
  _usuarioActual(ref);
  return ref.watch(solicitudesRepositoryProvider).detalle(id);
});

final direccionesProvider = FutureProvider<List<Direccion>>((ref) {
  _usuarioActual(ref);
  return ref.watch(solicitudesRepositoryProvider).direcciones();
});

final notificacionesProvider = FutureProvider<BandejaNotificaciones>((ref) {
  _usuarioActual(ref);
  return ref.watch(solicitudesRepositoryProvider).notificaciones();
});

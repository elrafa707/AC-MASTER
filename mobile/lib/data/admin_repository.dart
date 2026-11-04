import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../features/auth/session_controller.dart';
import '../models/admin.dart';
import '../models/solicitud.dart';
import 'api_base.dart';

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<ResumenPanel> resumen() => llamarApi(() async {
        final res = await _dio.get<Json>('/admin/resumen');
        return ResumenPanel.fromJson(res.data!);
      });

  Future<List<ResumenSolicitud>> bandeja({EstadoSolicitud? estado, String? texto}) => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/admin/solicitudes', queryParameters: {
          if (estado != null) 'estado': estado.api,
          if (texto != null && texto.trim().isNotEmpty) 'q': texto.trim(),
        });
        return [for (final s in res.data!) ResumenSolicitud.fromJson(s as Json)];
      });

  Future<List<TecnicoRecomendado>> recomendados(int solicitudId) => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/admin/solicitudes/$solicitudId/tecnicos-recomendados');
        return [for (final t in res.data!) TecnicoRecomendado.fromJson(t as Json)];
      });

  Future<Solicitud> asignar(int solicitudId, {required int tecnicoId, required DateTime inicio, required DateTime fin}) =>
      _solicitud(() => _dio.post<Json>('/admin/solicitudes/$solicitudId/asignar', data: {
            'tecnicoId': tecnicoId,
            'ventanaInicio': inicio.toUtc().toIso8601String(),
            'ventanaFin': fin.toUtc().toIso8601String(),
          }));

  Future<Solicitud> guardarCotizacion(int solicitudId, List<Partida> partidas) => _solicitud(
        () => _dio.put<Json>('/admin/solicitudes/$solicitudId/cotizacion', data: {'partidas': [for (final p in partidas) p.toJson()]}),
      );

  Future<Solicitud> enviarCotizacion(int solicitudId) =>
      _solicitud(() => _dio.post<Json>('/admin/solicitudes/$solicitudId/cotizacion/enviar'));

  Future<List<Especialidad>> especialidades() => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/especialidades');
        return [for (final e in res.data!) Especialidad.fromJson(e as Json)];
      });

  Future<List<TecnicoCuenta>> tecnicos() => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/admin/tecnicos');
        return [for (final t in res.data!) TecnicoCuenta.fromJson(t as Json)];
      });

  Future<TecnicoCuenta> crearTecnico({
    required String nombre,
    required String correo,
    required String password,
    required List<String> especialidades,
    String? telefono,
  }) =>
      llamarApi(() async {
        final res = await _dio.post<Json>('/admin/tecnicos', data: {
          'nombre': nombre,
          'correo': correo,
          'password': password,
          'especialidades': especialidades,
          if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
        });
        return TecnicoCuenta.fromJson(res.data!);
      });

  Future<TecnicoCuenta> editarTecnico(int id, {List<String>? especialidades, bool? activo}) => llamarApi(() async {
        final res = await _dio.patch<Json>('/admin/tecnicos/$id', data: {
          'especialidades': ?especialidades,
          'activo': ?activo,
        });
        return TecnicoCuenta.fromJson(res.data!);
      });

  Future<List<ClienteCuenta>> clientes({String? texto}) => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/admin/clientes', queryParameters: {
          if (texto != null && texto.trim().isNotEmpty) 'q': texto.trim(),
        });
        return [for (final c in res.data!) ClienteCuenta.fromJson(c as Json)];
      });

  Future<void> cambiarEstadoCliente(int id, {required bool activo}) =>
      llamarApi(() => _dio.patch<void>('/admin/clientes/$id', data: {'activo': activo}));

  Future<List<Pieza>> piezas() => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/admin/piezas');
        return [for (final p in res.data!) Pieza.fromJson(p as Json)];
      });

  Future<Pieza> crearPieza({required String codigo, required String nombre, required double precio}) => llamarApi(() async {
        final res = await _dio.post<Json>('/admin/piezas', data: {'codigo': codigo, 'nombre': nombre, 'precioUnitario': precio});
        return Pieza.fromJson(res.data!);
      });

  Future<Pieza> editarPieza(int id, {String? nombre, double? precio, bool? activo}) => llamarApi(() async {
        final res = await _dio.patch<Json>('/admin/piezas/$id', data: {'nombre': ?nombre, 'precioUnitario': ?precio, 'activo': ?activo});
        return Pieza.fromJson(res.data!);
      });

  Future<Solicitud> _solicitud(Future<Response<Json>> Function() peticion) => llamarApi(() async {
        final res = await peticion();
        return Solicitud.fromJson(res.data!);
      });
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository(ref.watch(dioProvider)));

final resumenPanelProvider = FutureProvider<ResumenPanel>((ref) {
  ref.watch(sessionProvider.select((s) => s.value?.id));
  return ref.watch(adminRepositoryProvider).resumen();
});

final tecnicosProvider = FutureProvider<List<TecnicoCuenta>>((ref) {
  ref.watch(sessionProvider.select((s) => s.value?.id));
  return ref.watch(adminRepositoryProvider).tecnicos();
});

final piezasAdminProvider = FutureProvider<List<Pieza>>((ref) => ref.watch(adminRepositoryProvider).piezas());

final especialidadesProvider = FutureProvider<List<Especialidad>>((ref) => ref.watch(adminRepositoryProvider).especialidades());

final recomendadosProvider = FutureProvider.family<List<TecnicoRecomendado>, int>(
  (ref, solicitudId) => ref.watch(adminRepositoryProvider).recomendados(solicitudId),
);

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../features/auth/session_controller.dart';
import '../models/diagnostico.dart';
import '../models/solicitud.dart';
import 'api_base.dart';

/// Operaciones del técnico sobre sus órdenes de trabajo (RF-06, RF-07).
class TecnicoRepository {
  TecnicoRepository(this._dio);

  final Dio _dio;

  Future<List<ResumenSolicitud>> ordenes({bool finalizadas = false}) => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/tecnico/ordenes', queryParameters: {'vista': finalizadas ? 'finalizadas' : 'activas'});
        return [for (final o in res.data!) ResumenSolicitud.fromJson(o as Json)];
      });

  Future<bool> disponible() => llamarApi(() async {
        final res = await _dio.get<Json>('/tecnico/disponibilidad');
        return res.data!['disponible'] as bool;
      });

  Future<void> cambiarDisponibilidad(bool disponible) =>
      llamarApi(() => _dio.put<void>('/tecnico/disponibilidad', data: {'disponible': disponible}));

  Future<Solicitud> registrarLlegada(int id) => _solicitud(() => _dio.post<Json>('/tecnico/ordenes/$id/llegada'));

  Future<Solicitud> guardarRegistro(int id, {String? diagnosticoFinal, String? notas}) =>
      _solicitud(() => _dio.patch<Json>('/tecnico/ordenes/$id', data: {'diagnosticoFinal': ?diagnosticoFinal, 'notas': ?notas}));

  Future<Solicitud> subirEvidencias(int id, List<FotoSeleccionada> fotos) => _solicitud(
        () => _dio.post<Json>(
          '/tecnico/ordenes/$id/evidencias',
          data: FormData.fromMap({
            'fotos': [
              for (final f in fotos)
                MultipartFile.fromBytes(f.bytes, filename: f.nombre, contentType: DioMediaType.parse(f.mimeType)),
            ],
          }),
          options: Options(sendTimeout: const Duration(minutes: 2)),
        ),
      );

  Future<Solicitud> eliminarEvidencia(int id, int fotoId) => _solicitud(() => _dio.delete<Json>('/tecnico/ordenes/$id/evidencias/$fotoId'));

  /// Reemplaza las piezas usadas: lista de (piezaId, cantidad).
  Future<Solicitud> guardarPiezas(int id, List<({int piezaId, int cantidad})> piezas) => _solicitud(
        () => _dio.put<Json>('/tecnico/ordenes/$id/piezas', data: {
          'piezas': [for (final p in piezas) {'piezaId': p.piezaId, 'cantidad': p.cantidad}],
        }),
      );

  Future<Solicitud> cerrar(int id) => _solicitud(() => _dio.post<Json>('/tecnico/ordenes/$id/cerrar'));

  Future<List<Pieza>> catalogo() => llamarApi(() async {
        final res = await _dio.get<List<dynamic>>('/piezas');
        return [for (final p in res.data!) Pieza.fromJson(p as Json)];
      });

  Future<Solicitud> _solicitud(Future<Response<Json>> Function() peticion) => llamarApi(() async {
        final res = await peticion();
        return Solicitud.fromJson(res.data!);
      });
}

final tecnicoRepositoryProvider = Provider<TecnicoRepository>((ref) => TecnicoRepository(ref.watch(dioProvider)));

final ordenesProvider = FutureProvider.family<List<ResumenSolicitud>, bool>((ref, finalizadas) {
  ref.watch(sessionProvider.select((s) => s.value?.id));
  return ref.watch(tecnicoRepositoryProvider).ordenes(finalizadas: finalizadas);
});

final disponibilidadProvider = FutureProvider<bool>((ref) {
  ref.watch(sessionProvider.select((s) => s.value?.id));
  return ref.watch(tecnicoRepositoryProvider).disponible();
});

final catalogoPiezasProvider = FutureProvider<List<Pieza>>((ref) => ref.watch(tecnicoRepositoryProvider).catalogo());

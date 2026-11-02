import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../features/auth/session_controller.dart';
import '../models/equipo.dart';

class EquiposRepository {
  EquiposRepository(this._dio);

  final Dio _dio;

  Future<List<Equipo>> listar() => _llamar(() async {
        final res = await _dio.get<List<dynamic>>('/equipos');
        return [for (final e in res.data!) Equipo.fromJson(e as Map<String, dynamic>)];
      });

  Future<FichaEquipo> ficha(int id) => _llamar(() async {
        final res = await _dio.get<Map<String, dynamic>>('/equipos/$id');
        return FichaEquipo.fromJson(res.data!);
      });

  Future<FichaEquipo> fichaPorSerie(String numeroSerie) => _llamar(() async {
        final res = await _dio.get<Map<String, dynamic>>('/equipos/serie/${Uri.encodeComponent(numeroSerie)}');
        return FichaEquipo.fromJson(res.data!);
      });

  Future<FichaEquipo> registrar(NuevoEquipo equipo) => _llamar(() async {
        final res = await _dio.post<Map<String, dynamic>>('/equipos', data: equipo.toJson());
        return FichaEquipo.fromJson(res.data!);
      });

  Future<T> _llamar<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final equiposRepositoryProvider = Provider<EquiposRepository>((ref) => EquiposRepository(ref.watch(dioProvider)));

/// Equipos del cliente con sesión. Se recalcula al cambiar de usuario.
final misEquiposProvider = FutureProvider<List<Equipo>>((ref) {
  ref.watch(sessionProvider.select((s) => s.value?.id));
  return ref.watch(equiposRepositoryProvider).listar();
});

final fichaEquipoProvider = FutureProvider.family<FichaEquipo, int>((ref, id) {
  ref.watch(sessionProvider.select((s) => s.value?.id));
  return ref.watch(equiposRepositoryProvider).ficha(id);
});

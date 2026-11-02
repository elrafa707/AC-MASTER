import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/diagnostico.dart';

class DiagnosticosRepository {
  DiagnosticosRepository(this._dio);

  final Dio _dio;

  Future<Cuestionario> cuestionario(List<String> sintomas) => _llamar(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/diagnosticos/cuestionario',
          queryParameters: {if (sintomas.isNotEmpty) 'sintomas': sintomas.join(',')},
        );
        return Cuestionario.fromJson(res.data!);
      });

  /// Envía síntomas, respuestas y fotos al asistente (RF-02, RF-03). Puede tardar hasta un minuto.
  Future<Diagnostico> diagnosticar({
    required int equipoId,
    required List<String> sintomas,
    required Map<String, String> respuestas,
    required List<FotoSeleccionada> fotos,
    String? descripcion,
  }) =>
      _llamar(() async {
        final datos = FormData.fromMap({
          'equipoId': '$equipoId',
          'sintomas': jsonEncode(sintomas),
          'respuestas': jsonEncode(respuestas),
          if (descripcion != null && descripcion.trim().isNotEmpty) 'descripcion': descripcion.trim(),
          'fotos': [
            for (final f in fotos)
              MultipartFile.fromBytes(f.bytes, filename: f.nombre, contentType: DioMediaType.parse(f.mimeType)),
          ],
        });
        final res = await _dio.post<Map<String, dynamic>>(
          '/diagnosticos',
          data: datos,
          options: Options(sendTimeout: const Duration(minutes: 2), receiveTimeout: const Duration(minutes: 3)),
        );
        return Diagnostico.fromJson(res.data!);
      });

  Future<Diagnostico> registrarAutoayuda(int id, {required bool resuelto}) => _llamar(() async {
        final res = await _dio.post<Map<String, dynamic>>('/diagnosticos/$id/autoayuda', data: {'resuelto': resuelto});
        return Diagnostico.fromJson(res.data!);
      });

  Future<T> _llamar<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final diagnosticosRepositoryProvider =
    Provider<DiagnosticosRepository>((ref) => DiagnosticosRepository(ref.watch(dioProvider)));

/// Catálogo de síntomas (sin preguntas específicas).
final catalogoSintomasProvider = FutureProvider<List<Sintoma>>(
  (ref) async => (await ref.watch(diagnosticosRepositoryProvider).cuestionario(const [])).sintomas,
);

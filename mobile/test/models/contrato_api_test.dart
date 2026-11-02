// Comprueba que los modelos de la app interpretan respuestas reales del backend.
// Los JSON de test/fixtures se capturaron del API de la etapa 2 (asistente en modo simulado).
import 'dart:convert';
import 'dart:io';

import 'package:ac_master/models/diagnostico.dart';
import 'package:ac_master/models/equipo.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture(String nombre) =>
    jsonDecode(File('test/fixtures/$nombre.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Diagnostico.fromJson interpreta la respuesta de POST /diagnosticos', () {
    final d = Diagnostico.fromJson(_fixture('diagnostico'));

    expect(d.falla, 'Filtros saturados de polvo');
    expect(d.requiereTecnico, isFalse);
    expect(d.tieneAutoayuda, isTrue);
    expect(d.especialidad, 'Mantenimiento');
    expect(d.resultado, ResultadoDiagnostico.pendiente);
    expect(d.simulado, isTrue);
    expect(d.fotos.single, startsWith('/api/v1/fotos/'));
    expect(d.causas, isNotEmpty);
    expect(d.costoMax, greaterThanOrEqualTo(d.costoMin));
  });

  test('FichaEquipo.fromJson interpreta GET /equipos/:id con su historial', () {
    final f = FichaEquipo.fromJson(_fixture('ficha_equipo'));

    expect(f.equipo.nombre, 'Mirage MRG123');
    expect(f.equipo.capacidadBTU, 12000);
    expect(f.equipo.fechaInstalacion, DateTime(2024, 3, 18));
    expect(f.historial.map((r) => r.tipo), [TipoRegistro.prediccion, TipoRegistro.instalacion]);
  });

  test('Cuestionario.fromJson interpreta GET /diagnosticos/cuestionario', () {
    final c = Cuestionario.fromJson(_fixture('cuestionario'));

    expect(c.sintomas.map((s) => s.clave), contains('NO_ENFRIA'));
    expect(c.preguntas.first.opciones, isNotEmpty);
    expect(c.preguntas.any((p) => p.ayuda != null), isTrue);
  });
}

// Comprueba que los modelos de la app interpretan respuestas reales del backend.
// Los JSON de test/fixtures son respuestas reales del API (asistente simulado); se regeneran con
// backend/scripts/generar-fixtures-app.mjs.
import 'dart:convert';
import 'dart:io';

import 'package:ac_master/models/diagnostico.dart';
import 'package:ac_master/models/admin.dart';
import 'package:ac_master/models/equipo.dart';
import 'package:ac_master/models/solicitud.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic _json(String nombre) => jsonDecode(File('test/fixtures/$nombre.json').readAsStringSync());
Map<String, dynamic> _fixture(String nombre) => _json(nombre) as Map<String, dynamic>;

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

  test('Solicitud.fromJson interpreta el detalle que ve el administrador y el cliente', () {
    final admin = Solicitud.fromJson(_fixture('solicitud_en_revision_admin'));
    expect(admin.estado, EstadoSolicitud.enRevision);
    expect(admin.cotizacion!.estado, 'BORRADOR');
    expect(admin.cotizacion!.generadaAuto, isTrue);
    expect(admin.tecnico, isNull);

    final cliente = Solicitud.fromJson(_fixture('solicitud_cotizada_cliente'));
    expect(cliente.estado, EstadoSolicitud.cotizado);
    expect(cliente.tecnico!.telefono, isNull, reason: 'el teléfono se comparte hasta aprobar');
    expect(cliente.cotizacion!.total, cliente.cotizacion!.partidas.fold<double>(0, (s, p) => s + p.importe));
    expect(cliente.eventos.map((e) => e.titulo), contains('Cotización enviada'));
    expect(cliente.resumen.ventanaInicio, isNotNull);
  });

  test('listas del administrador y del cliente', () {
    final bandeja = [for (final s in _json('bandeja_admin') as List) ResumenSolicitud.fromJson(s as Map<String, dynamic>)];
    expect(bandeja.single.folio, startsWith('AC-'));

    final ranking = [for (final t in _json('tecnicos_recomendados') as List) TecnicoRecomendado.fromJson(t as Map<String, dynamic>)];
    expect(ranking.first.puntaje, greaterThanOrEqualTo(ranking.last.puntaje));

    final avisos = BandejaNotificaciones.fromJson(_fixture('notificaciones'));
    expect(avisos.noLeidas, avisos.notificaciones.where((n) => !n.leida).length);

    final tecnicos = [for (final t in _json('tecnicos_admin') as List) TecnicoCuenta.fromJson(t as Map<String, dynamic>)];
    expect(tecnicos.single.especialidades, isNotEmpty);
  });

  test('orden de trabajo: lo que ve el técnico en curso y el cliente al terminar', () {
    final enCamino = Solicitud.fromJson(_fixture('orden_en_camino_tecnico'));
    expect(enCamino.estado, EstadoSolicitud.enCamino);
    expect(enCamino.orden!.folio, startsWith('ORD-'));
    expect(enCamino.orden!.fechaLlegada, isNotNull);
    expect(enCamino.clienteTelefono, isNotNull, reason: 'el técnico puede llamar al cliente');

    final finalizada = Solicitud.fromJson(_fixture('solicitud_finalizada_cliente'));
    expect(finalizada.estado, EstadoSolicitud.finalizado);
    expect(finalizada.orden!.evidencias, isNotEmpty);
    expect(finalizada.orden!.totalPiezas, finalizada.orden!.piezas.fold<double>(0, (s, p) => s + p.importe));
    expect(finalizada.calificacion, isNull);

    final ordenes = [for (final o in _json('ordenes_tecnico') as List) ResumenSolicitud.fromJson(o as Map<String, dynamic>)];
    expect(ordenes.single.ordenFolio, enCamino.orden!.folio);
    final piezas = [for (final p in _json('piezas') as List) Pieza.fromJson(p as Map<String, dynamic>)];
    expect(piezas.every((p) => p.activo), isTrue);
  });
}

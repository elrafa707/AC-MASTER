import 'package:ac_master/models/solicitud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  void pantallaTelefono(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
  }

  Future<void> tocar(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  final enCamino = fixture('orden_en_camino_tecnico') as Map<String, dynamic>;

  Widget appTecnico(FakeTecnicoRepository tecnico) => appDePrueba(
        tokens: FakeTokenStorage('t'),
        auth: FakeAuthRepository(usuarioSesion: tecnicoDemo),
        tecnico: tecnico,
        solicitudes: FakeSolicitudesRepository(detalle: Solicitud.fromJson(enCamino)),
      );

  testWidgets('el panel del técnico muestra sus órdenes y cambia su disponibilidad', (tester) async {
    pantallaTelefono(tester);
    final tecnico = FakeTecnicoRepository();
    await tester.pumpWidget(appTecnico(tecnico));
    await tester.pumpAndSettle();

    expect(find.text('RUTA DE HOY'), findsOneWidget);
    expect(find.byKey(const Key('rol-icono-tecnico')), findsOneWidget);
    expect(find.text('1 orden por atender'), findsOneWidget);
    expect(find.byKey(Key('solicitud-${enCamino['id']}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('switch-disponible')));
    await tester.pumpAndSettle();
    expect(tecnico.llamadas, ['disponible:false']);
  });

  testWidgets('la orden muestra cliente, kit sugerido y permite registrar y cerrar', (tester) async {
    pantallaTelefono(tester);
    final tecnico = FakeTecnicoRepository();
    await tester.pumpWidget(appTecnico(tecnico));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('solicitud-${enCamino['id']}')));
    await tester.pumpAndSettle();

    expect(find.text(enCamino['orden']['folio'] as String), findsOneWidget, reason: 'el folio de la orden va en la barra');
    expect(find.byKey(const Key('boton-llamar')), findsOneWidget);
    expect(find.byKey(const Key('boton-mapa')), findsOneWidget);
    expect(find.textContaining('Llegaste el'), findsOneWidget, reason: 'la llegada ya está registrada en la fixture');

    await tester.scrollUntilVisible(find.byKey(const Key('kit-sugerido')), 300, scrollable: find.byType(Scrollable).first);
    for (final h in (enCamino['diagnostico']['herramientas'] as List).take(2)) {
      expect(find.text(h as String), findsOneWidget);
    }

    // Sin diagnóstico ni evidencias no deja cerrar.
    await tocar(tester, find.byKey(const Key('boton-cerrar-orden')));
    expect(find.textContaining('Antes de cerrar registra el diagnóstico final y al menos una foto'), findsOneWidget);
    expect(tecnico.llamadas.where((l) => l.startsWith('cerrar')), isEmpty);

    await tester.scrollUntilVisible(find.byKey(const Key('campo-diagnostico-final')), -300, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('campo-diagnostico-final')), 'Se reemplazó el capacitor del ventilador.');
    await tester.pumpAndSettle();
    await tocar(tester, find.byKey(const Key('boton-guardar-registro')));
    expect(tecnico.llamadas.last, 'registro:Se reemplazó el capacitor del ventilador.');

    await tocar(tester, find.byKey(const Key('boton-evidencia-galeria')));
    expect(tecnico.llamadas.last, 'evidencias:1');

    await tocar(tester, find.byKey(const Key('boton-agregar-pieza')));
    final pieza = (fixture('piezas') as List).first as Map;
    await tester.tap(find.byKey(Key('opcion-pieza-${pieza['id']}')));
    await tester.pumpAndSettle();
    await tocar(tester, find.byKey(const Key('boton-guardar-piezas')));
    expect(tecnico.llamadas.last, 'piezas:${pieza['id']}x1');
  });

  testWidgets('el cliente ve el resumen final y califica al técnico', (tester) async {
    pantallaTelefono(tester);
    final finalizada = Solicitud.fromJson(fixture('solicitud_finalizada_cliente') as Map<String, dynamic>);
    final solicitudes = FakeSolicitudesRepository(detalle: finalizada);
    await tester.pumpWidget(appDePrueba(tokens: FakeTokenStorage('t'), solicitudes: solicitudes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver servicios anteriores'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('solicitud-${finalizada.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tarjeta-calificar')), findsOneWidget);
    final calificar = find.byKey(const Key('boton-calificar'));
    expect(tester.widget<FilledButton>(calificar).onPressed, isNull, reason: 'primero hay que elegir estrellas');
    await tester.tap(find.byKey(const Key('estrella-4')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(calificar).onPressed, isNotNull);

    await tester.scrollUntilVisible(find.byKey(const Key('resumen-orden')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text(finalizada.orden!.diagnosticoFinal!), findsOneWidget);
    expect(find.textContaining(finalizada.orden!.piezas.first.nombre), findsOneWidget);
  });
}

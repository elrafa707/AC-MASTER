import 'package:ac_master/models/equipo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  Future<void> tocar(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> abrirDiagnostico(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tocar(tester, find.byKey(const Key('boton-diagnosticar')));
  }

  Future<void> completarCuestionario(WidgetTester tester) async {
    await tocar(tester, find.byKey(const Key('sintoma-NO_ENFRIA')));
    await tocar(tester, find.byKey(const Key('boton-continuar-sintomas')));

    expect(find.text('Faltan 2 respuestas'), findsOneWidget);
    await tocar(tester, find.widgetWithText(ChoiceChip, 'Sí'));
    await tocar(tester, find.widgetWithText(ChoiceChip, 'Hace más de 6 meses'));
    await tocar(tester, find.byKey(const Key('boton-continuar-preguntas')));
  }

  testWidgets('el cliente sin equipos no puede diagnosticar y se le invita a registrar uno', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appDePrueba(tokens: FakeTokenStorage('t'), equipos: FakeEquiposRepository(equipos: [])));
    await tester.pumpAndSettle();

    final boton = tester.widget<FilledButton>(find.byKey(const Key('boton-diagnosticar')));
    expect(boton.onPressed, isNull);
    expect(find.text('Registra tu primer equipo'), findsOneWidget);
  });

  testWidgets('flujo completo: síntomas, cuestionario, foto, resultado y autoayuda resuelta', (tester) async {
    final diagnosticos = FakeDiagnosticosRepository();
    await abrirDiagnostico(tester, appDePrueba(tokens: FakeTokenStorage('t'), diagnosticos: diagnosticos));

    expect(find.text('Paso 1 de 3'), findsOneWidget);
    expect(find.text('Mirage MRG123'), findsOneWidget, reason: 'con un solo equipo queda preseleccionado');
    await completarCuestionario(tester);

    expect(find.text('Paso 3 de 3'), findsOneWidget);
    await tocar(tester, find.byKey(const Key('boton-galeria')));
    expect(find.byType(Image), findsOneWidget, reason: 'muestra la miniatura de la foto elegida');
    await tocar(tester, find.byKey(const Key('boton-analizar')));

    expect(diagnosticos.ultimoEnvio, {
      'equipoId': equipoDemo.id,
      'sintomas': ['NO_ENFRIA'],
      'respuestas': {'modo_frio': 'Sí', 'ultima_limpieza_filtros': 'Hace más de 6 meses'},
      'fotos': 1,
    });
    expect(find.text('Filtros saturados de polvo'), findsOneWidget);
    expect(find.text('82% de confianza'), findsOneWidget);
    expect(find.text('Puedes intentar resolverlo tú mismo'), findsOneWidget);
    expect(find.text('Se ve polvo acumulado en la rejilla.'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('boton-guia')));
    expect(find.text('0 de 2 pasos'), findsOneWidget);
    final resuelto = find.byKey(const Key('boton-resuelto'));
    expect(tester.widget<FilledButton>(resuelto).onPressed, isNull, reason: 'primero hay que completar los pasos');

    await tocar(tester, find.byKey(const Key('paso-0')));
    await tocar(tester, find.byKey(const Key('paso-1')));
    await tocar(tester, resuelto);

    expect(diagnosticos.autoayudaResuelta, isTrue);
    expect(find.text('¡Listo, quedó resuelto!'), findsOneWidget);
  });

  testWidgets('si se requiere técnico muestra la advertencia y no ofrece guía', (tester) async {
    final diagnosticos = FakeDiagnosticosRepository(
      resultado: diagnosticoDemo(requiereTecnico: true, advertencia: 'Apaga el equipo de inmediato.'),
    );
    await abrirDiagnostico(tester, appDePrueba(tokens: FakeTokenStorage('t'), diagnosticos: diagnosticos));
    await completarCuestionario(tester);
    await tocar(tester, find.byKey(const Key('boton-analizar')));

    expect(find.text('Recomendamos la visita de un técnico'), findsOneWidget);
    expect(find.text('Apaga el equipo de inmediato.'), findsOneWidget);
    expect(find.text('Multímetro'), findsOneWidget);
    expect(find.byKey(const Key('boton-guia')), findsNothing);
    expect(diagnosticos.ultimoEnvio!['fotos'], 0);
  });

  testWidgets('registra un equipo nuevo y abre su ficha', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final equipos = FakeEquiposRepository(equipos: []);
    await tester.pumpWidget(appDePrueba(tokens: FakeTokenStorage('t'), equipos: equipos));
    await tester.pumpAndSettle();

    await tocar(tester, find.byKey(const Key('boton-registrar-primero')));
    await tocar(tester, find.byKey(const Key('boton-guardar-equipo')));
    expect(find.text('Mínimo 4 caracteres'), findsOneWidget);
    expect(find.text('Escribe la marca'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-serie')), 'lg-2026-001');
    await tester.enterText(find.byKey(const Key('campo-marca')), 'LG');
    await tester.enterText(find.byKey(const Key('campo-modelo')), 'DualCool');
    await tocar(tester, find.byKey(const Key('boton-guardar-equipo')));

    expect(equipos.equipos.single.numeroSerie, 'LG-2026-001');
    expect(find.text('Historial digital'), findsOneWidget);
    expect(find.text('LG DualCool'), findsOneWidget);
  });

  testWidgets('el técnico consulta la ficha de un equipo por número de serie', (tester) async {
    final equipos = FakeEquiposRepository()
      ..historial[equipoDemo.id] = [
        RegistroHistorial(
          id: 1,
          tipo: TipoRegistro.autoayuda,
          titulo: 'Resuelto con el asistente: Filtros saturados',
          fecha: DateTime(2026, 10, 20),
        ),
        RegistroHistorial(id: 2, tipo: TipoRegistro.instalacion, titulo: 'Instalación del equipo', fecha: DateTime(2024, 3, 18)),
      ];
    await tester.pumpWidget(
      appDePrueba(tokens: FakeTokenStorage('t'), auth: FakeAuthRepository(usuarioSesion: tecnicoDemo), equipos: equipos),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton-diagnosticar')), findsNothing);

    await tocar(tester, find.byKey(const Key('accion-buscar-serie')));
    await tester.enterText(find.byKey(const Key('campo-buscar-serie')), 'NO-EXISTE');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No encontramos ese equipo'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-buscar-serie')), 'mrg24-031802');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Mirage MRG123'), findsOneWidget);
    expect(find.text('Rafael Báez'), findsOneWidget, reason: 'el técnico ve a quién pertenece el equipo');
    await tester.scrollUntilVisible(
      find.text('Instalación del equipo'),
      200,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('Resuelto con el asistente: Filtros saturados'), findsOneWidget);
  });
}

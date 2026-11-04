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
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> llegarAlResultado(WidgetTester tester) async {
    await tocar(tester, find.byKey(const Key('boton-diagnosticar')));
    await tocar(tester, find.byKey(const Key('sintoma-NO_ENFRIA')));
    await tocar(tester, find.byKey(const Key('boton-continuar-sintomas')));
    await tocar(tester, find.widgetWithText(ChoiceChip, 'Sí'));
    await tocar(tester, find.widgetWithText(ChoiceChip, 'Hace más de 6 meses'));
    await tocar(tester, find.byKey(const Key('boton-continuar-preguntas')));
    await tocar(tester, find.byKey(const Key('boton-analizar')));
  }

  group('Cliente', () {
    testWidgets('pide técnico desde el resultado aunque el asistente sugiera autoayuda', (tester) async {
      pantallaTelefono(tester);
      final solicitudes = FakeSolicitudesRepository();
      await tester.pumpWidget(appDePrueba(tokens: FakeTokenStorage('t'), solicitudes: solicitudes));
      await tester.pumpAndSettle();
      await llegarAlResultado(tester);

      expect(find.text('Prefiero que venga un técnico'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('boton-solicitar-tecnico')));

      expect(find.textContaining('El asistente creía que podías resolverlo'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget, reason: 'la dirección principal viene preseleccionada');
      await tocar(tester, find.byKey(const Key('boton-enviar-solicitud')));

      expect(solicitudes.llamadas, ['crear:50:${(fixture('direcciones') as List).first['id']}']);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Aprobar cotización'), findsOneWidget, reason: 'abre el seguimiento de la solicitud creada');
    });

    testWidgets('sin direcciones, el formulario para agregar una aparece de inmediato', (tester) async {
      pantallaTelefono(tester);
      final solicitudes = FakeSolicitudesRepository(direcciones: []);
      await tester.pumpWidget(appDePrueba(tokens: FakeTokenStorage('t'), solicitudes: solicitudes));
      await tester.pumpAndSettle();
      await llegarAlResultado(tester);
      await tocar(tester, find.byKey(const Key('boton-solicitar-tecnico')));

      final enviar = find.byKey(const Key('boton-enviar-solicitud'));
      expect(tester.widget<FilledButton>(enviar).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('campo-calle')), 'Hidalgo 245');
      await tester.enterText(find.byKey(const Key('campo-colonia')), 'Centro');
      await tocar(tester, find.byKey(const Key('boton-guardar-direccion')));

      expect(solicitudes.llamadas, ['direccion:Hidalgo 245']);
      expect(tester.widget<FilledButton>(enviar).onPressed, isNotNull);
    });

    testWidgets('el seguimiento muestra avance, técnico y cotización, y permite aprobarla', (tester) async {
      pantallaTelefono(tester);
      final solicitudes = FakeSolicitudesRepository();
      await tester.pumpWidget(appDePrueba(tokens: FakeTokenStorage('t'), solicitudes: solicitudes));
      await tester.pumpAndSettle();

      expect(find.text('SERVICIOS EN CURSO'), findsOneWidget);
      await tocar(tester, find.byKey(Key('solicitud-${(fixture('solicitud_cotizada_cliente') as Map)['id']}')));

      expect(find.text('Mariela Ríos'), findsOneWidget);
      expect(find.text('Podrás contactarlo cuando apruebes la cotización.'), findsOneWidget);
      expect(find.byKey(const Key('tarjeta-cotizacion')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Cotización enviada'), 300, scrollable: find.byType(Scrollable).first);
      await tester.scrollUntilVisible(find.byKey(const Key('boton-aprobar')), -300, scrollable: find.byType(Scrollable).first);

      await tocar(tester, find.byKey(const Key('boton-aprobar')));
      await tocar(tester, find.byKey(const Key('boton-confirmar')));
      expect(solicitudes.llamadas.last, startsWith('aprobar:'));
    });

    testWidgets('rechazar pide un motivo opcional', (tester) async {
      pantallaTelefono(tester);
      final solicitudes = FakeSolicitudesRepository();
      await tester.pumpWidget(appDePrueba(tokens: FakeTokenStorage('t'), solicitudes: solicitudes));
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(Key('solicitud-${(fixture('solicitud_cotizada_cliente') as Map)['id']}')));
      await tocar(tester, find.byKey(const Key('boton-rechazar')));
      await tester.enterText(find.byKey(const Key('campo-motivo')), 'Muy cara');
      await tocar(tester, find.byKey(const Key('boton-confirmar')));
      expect(solicitudes.llamadas.last, endsWith(':Muy cara'));
    });

    testWidgets('la campana muestra los avisos sin leer', (tester) async {
      await tester.pumpWidget(appDePrueba(tokens: FakeTokenStorage('t')));
      await tester.pumpAndSettle();
      final noLeidas = (fixture('notificaciones') as Map)['noLeidas'] as int;
      expect(find.text('$noLeidas'), findsOneWidget);

      await tocar(tester, find.byKey(const Key('boton-notificaciones')));
      expect(find.text('Marcar todas'), findsOneWidget);
    });
  });

  group('Administrador', () {
    Widget appAdmin(FakeAdminRepository admin, {FakeSolicitudesRepository? solicitudes}) => appDePrueba(
          tokens: FakeTokenStorage('t'),
          auth: FakeAuthRepository(usuarioSesion: adminDemo),
          admin: admin,
          solicitudes: solicitudes ??
              FakeSolicitudesRepository(
                detalle: Solicitud.fromJson(fixture('solicitud_en_revision_admin') as Map<String, dynamic>),
              ),
        );

    testWidgets('el panel muestra el resumen y la bandeja con la falla predicha', (tester) async {
      pantallaTelefono(tester);
      await tester.pumpWidget(appAdmin(FakeAdminRepository()));
      await tester.pumpAndSettle();

      expect(find.text('CENTRO DE OPERACIONES'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget, reason: 'técnicos libres / activos');
      final falla = ((fixture('bandeja_admin') as List).first as Map)['falla'] as String;
      expect(find.text(falla), findsOneWidget);
    });

    testWidgets('asigna al técnico recomendado, ajusta la cotización y la envía', (tester) async {
      pantallaTelefono(tester);
      final admin = FakeAdminRepository();
      final enRevision = fixture('solicitud_en_revision_admin') as Map<String, dynamic>;
      await tester.pumpWidget(appAdmin(admin));
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(Key('solicitud-${enRevision['id']}')));

      expect(find.text('FALLA PREDICHA POR EL ASISTENTE'), findsOneWidget);
      expect(find.text('Recomendado'), findsOneWidget);
      final enviar = find.byKey(const Key('boton-enviar-cotizacion'));
      await tester.scrollUntilVisible(enviar, 300, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<ButtonStyleButton>(enviar).onPressed, isNull, reason: 'sin técnico asignado no se puede enviar');

      final primero = (fixture('tecnicos_recomendados') as List).first as Map;
      await tocar(tester, find.byKey(Key('tecnico-${primero['id']}')));
      await tocar(tester, find.byKey(const Key('boton-asignar')));
      expect(admin.llamadas, ['asignar:${primero['id']}:2h']);

      await tocar(tester, find.byKey(const Key('boton-agregar-partida')));
      final nueva = (enRevision['cotizacion']['partidas'] as List).length;
      await tester.enterText(find.byKey(Key('partida-$nueva-concepto')), 'Carga de gas R-410A');
      await tester.enterText(find.byKey(Key('partida-$nueva-precio')), '650');
      await tocar(tester, find.byKey(const Key('boton-guardar-cotizacion')));
      expect(admin.llamadas.last, contains('Carga de gas R-410A=650'));
    });

    testWidgets('da de alta un técnico con sus especialidades', (tester) async {
      pantallaTelefono(tester);
      final admin = FakeAdminRepository();
      await tester.pumpWidget(appAdmin(admin));
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Técnicos'));
      expect(find.text('Mariela Ríos'), findsOneWidget);

      await tocar(tester, find.byKey(const Key('boton-nuevo-tecnico')));
      await tester.enterText(find.byKey(const Key('campo-nombre-tecnico')), 'Diego Ramírez');
      await tester.enterText(find.byKey(const Key('campo-correo-tecnico')), 'diego@acmaster.mx');
      await tester.enterText(find.byKey(const Key('campo-password-tecnico')), 'Temporal2026');
      await tocar(tester, find.byKey(const Key('boton-crear-tecnico')));
      expect(find.text('Elige al menos una especialidad'), findsOneWidget);

      await tocar(tester, find.byKey(const Key('especialidad-ELECTRICO')));
      await tocar(tester, find.byKey(const Key('boton-crear-tecnico')));
      expect(admin.llamadas, ['tecnico:diego@acmaster.mx:ELECTRICO']);
    });
  });
}

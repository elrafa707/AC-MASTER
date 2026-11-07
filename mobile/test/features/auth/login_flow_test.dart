import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  Future<void> escribir(WidgetTester tester, String campo, String texto) =>
      tester.enterText(find.byKey(Key('campo-$campo')), texto);

  Future<void> enviar(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('boton-enviar')));
    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin sesión guardada muestra el login', (tester) async {
    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.text('Volver a tu espacio'), findsOneWidget);
    expect(find.text('Entrar como cliente'), findsOneWidget);
    expect(find.byKey(const Key('logo-completo')), findsOneWidget);
  });

  testWidgets('valida el formulario antes de llamar al servidor', (tester) async {
    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await enviar(tester);
    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);

    await escribir(tester, 'correo', 'no-es-correo');
    await enviar(tester);
    expect(find.text('Correo inválido'), findsOneWidget);
  });

  testWidgets('con credenciales correctas entra al panel y guarda el token', (tester) async {
    final tokens = FakeTokenStorage();
    await tester.pumpWidget(appDePrueba(tokens: tokens));
    await tester.pumpAndSettle();

    await escribir(tester, 'correo', 'cliente@acmaster.mx');
    await escribir(tester, 'password', 'AcMaster2026!');
    await enviar(tester);

    expect(find.text('Hola, Rafael'), findsOneWidget);
    expect(find.text('MIS EQUIPOS'), findsOneWidget);
    expect(tokens.actual, 'token-demo');
  });

  testWidgets('muestra el mensaje del servidor si las credenciales fallan', (tester) async {
    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await escribir(tester, 'correo', 'cliente@acmaster.mx');
    await escribir(tester, 'password', 'incorrecta');
    await enviar(tester);

    expect(find.byKey(const Key('aviso-error')), findsOneWidget);
    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
  });

  testWidgets('registra un cliente nuevo y valida sus campos', (tester) async {
    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('boton-cambiar-modo')));
    await tester.tap(find.byKey(const Key('boton-cambiar-modo')));
    await tester.pumpAndSettle();
    expect(find.text('Crear una cuenta'), findsWidgets);

    await escribir(tester, 'nombre', 'Lu');
    await escribir(tester, 'correo', 'laura@correo.com');
    await escribir(tester, 'telefono', '81123');
    await escribir(tester, 'password', 'corta');
    await enviar(tester);
    expect(find.text('Escribe tu nombre completo'), findsOneWidget);
    expect(find.text('Deben ser 10 dígitos'), findsOneWidget);
    expect(find.text('Mínimo 8 caracteres'), findsWidgets);

    await escribir(tester, 'nombre', 'Laura Méndez');
    await escribir(tester, 'telefono', '8112345678');
    await escribir(tester, 'password', 'Segura2026');
    await enviar(tester);
    expect(find.text('Hola, Laura'), findsOneWidget);
  });

  testWidgets('restaura la sesión guardada y permite cerrarla', (tester) async {
    final tokens = FakeTokenStorage('token-guardado');
    await tester.pumpWidget(appDePrueba(tokens: tokens));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Rafael'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton-cerrar-sesion')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Volver a tu espacio'), findsOneWidget);
    expect(tokens.actual, isNull);
  });

  group('Perfil de ingreso', () {
    setUp(() {
      final vista = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      vista.physicalSize = const Size(1080, 2400);
      vista.devicePixelRatio = 2.6;
    });
    tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

    Future<void> elegirPerfil(WidgetTester tester, String perfil) async {
      await tester.tap(find.byKey(const Key('selector-perfil')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(Key('perfil-$perfil')).last, matching: find.byType(Text)).first);
      await tester.pumpAndSettle();
    }

    testWidgets('el desplegable ofrece los tres perfiles con su ícono', (tester) async {
      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('selector-perfil')));
      await tester.pumpAndSettle();

      for (final perfil in ['cliente', 'tecnico', 'administrador']) {
        expect(find.byKey(Key('rol-icono-$perfil')), findsWidgets);
      }
      expect(find.text('Atiende tus órdenes de trabajo'), findsOneWidget);
    });

    testWidgets('con el perfil de técnico no se ofrece crear cuenta y se entra a su panel', (tester) async {
      final tokens = FakeTokenStorage();
      await tester.pumpWidget(appDePrueba(tokens: tokens, auth: FakeAuthRepository(usuarioSesion: tecnicoDemo)));
      await tester.pumpAndSettle();
      await elegirPerfil(tester, 'tecnico');

      expect(find.byKey(const Key('boton-cambiar-modo')), findsNothing);
      expect(find.textContaining('las crea el administrador'), findsOneWidget);

      await escribir(tester, 'correo', 'tecnico@acmaster.mx');
      await escribir(tester, 'password', 'AcMaster2026!');
      await enviar(tester);
      expect(find.text('RUTA DE HOY'), findsOneWidget);
      expect(tokens.actual, 'token-tecnico');
    });

    testWidgets('si la cuenta es de otro perfil, avisa y no guarda la sesión', (tester) async {
      final tokens = FakeTokenStorage();
      await tester.pumpWidget(appDePrueba(tokens: tokens));
      await tester.pumpAndSettle();
      await elegirPerfil(tester, 'administrador');

      await escribir(tester, 'correo', 'cliente@acmaster.mx');
      await escribir(tester, 'password', 'AcMaster2026!');
      await enviar(tester);

      expect(find.text('Esta cuenta es de cliente. Elige ese perfil para entrar.'), findsOneWidget);
      expect(tokens.actual, isNull);
    });
  });
}

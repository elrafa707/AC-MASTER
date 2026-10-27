import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/status_pill.dart';
import 'session_controller.dart';

/// Interfaz 1: inicio de sesión y registro de clientes (RF-01).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();

  bool _registro = false;
  bool _verPassword = false;
  bool _enviando = false;
  String? _error;
  Map<String, String> _erroresCampo = const {};

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _telefono.dispose();
    _password.dispose();
    super.dispose();
  }

  void _cambiarModo() {
    setState(() {
      _registro = !_registro;
      _error = null;
      _erroresCampo = const {};
    });
    _formKey.currentState?.reset();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _erroresCampo = const {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    final sesion = ref.read(sessionProvider.notifier);
    try {
      if (_registro) {
        await sesion.registrar(
          nombre: _nombre.text.trim(),
          correo: _correo.text.trim(),
          telefono: _telefono.text.trim(),
          password: _password.text,
        );
      } else {
        await sesion.iniciarSesion(correo: _correo.text.trim(), password: _password.text);
      }
      // Al cambiar la sesión, el router lleva al usuario a su panel.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.detalles.isEmpty ? e.mensaje : null;
        _erroresCampo = e.detalles;
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Portada(),
                  const SizedBox(height: 22),
                  Text(
                    _registro ? 'Crear una cuenta' : 'Volver a tu espacio',
                    style: tema.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _registro
                        ? 'Solo necesitaremos unos datos para empezar.'
                        : 'Tus servicios, reunidos en un solo lugar.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_registro) ...[
                            TextFormField(
                              key: const Key('campo-nombre'),
                              controller: _nombre,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Nombre completo',
                                hintText: 'Ej. Laura Méndez',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              forceErrorText: _erroresCampo['nombre'],
                              validator: (v) =>
                                  (v == null || v.trim().length < 3) ? 'Escribe tu nombre completo' : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            key: const Key('campo-correo'),
                            controller: _correo,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'nombre@correo.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            forceErrorText: _erroresCampo['correo'],
                            validator: (v) {
                              final valor = v?.trim() ?? '';
                              if (valor.isEmpty) return 'Escribe tu correo';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor)) return 'Correo inválido';
                              return null;
                            },
                          ),
                          if (_registro) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('campo-telefono'),
                              controller: _telefono,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                              decoration: const InputDecoration(
                                labelText: 'Teléfono (opcional)',
                                hintText: '10 dígitos',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              forceErrorText: _erroresCampo['telefono'],
                              validator: (v) {
                                final valor = v?.trim() ?? '';
                                return valor.isEmpty || valor.length == 10 ? null : 'Deben ser 10 dígitos';
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('campo-password'),
                            controller: _password,
                            obscureText: !_verPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: [_registro ? AutofillHints.newPassword : AutofillHints.password],
                            onFieldSubmitted: (_) => _enviando ? null : _enviar(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              hintText: _registro ? 'Mínimo 8 caracteres' : null,
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _verPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                                onPressed: () => setState(() => _verPassword = !_verPassword),
                                icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              ),
                            ),
                            forceErrorText: _erroresCampo['password'],
                            validator: (v) {
                              final valor = v ?? '';
                              if (valor.isEmpty) return 'Escribe tu contraseña';
                              if (_registro && valor.length < 8) return 'Mínimo 8 caracteres';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _AvisoError(_error!),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const Key('boton-enviar'),
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: cs.onPrimary),
                              ),
                              const SizedBox(width: 10),
                              Text(_registro ? 'Creando tu cuenta…' : 'Validando acceso…'),
                            ],
                          )
                        : Text(_registro ? 'Crear mi cuenta' : 'Entrar a AC-Master'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _registro ? '¿Ya tienes cuenta?' : '¿Es tu primera vez?',
                        style: tema.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      TextButton(
                        key: const Key('boton-cambiar-modo'),
                        onPressed: _enviando ? null : _cambiarModo,
                        child: Text(_registro ? 'Iniciar sesión' : 'Crear una cuenta'),
                      ),
                    ],
                  ),
                  if (!_registro)
                    Text(
                      'Las cuentas de técnicos las crea el administrador.',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Portada extends StatelessWidget {
  const _Portada();

  @override
  Widget build(BuildContext context) {
    final c = context.acColors;
    final tema = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        color: c.hero,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(right: -70, top: -70, child: _Aro(tamanio: 150, grosor: 18, color: const Color(0x333EC1C3))),
            Positioned(right: 30, bottom: -90, child: _Aro(tamanio: 130, grosor: 14, color: const Color(0x26F3B27E))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AC-Master',
                        style: tema.textTheme.headlineSmall?.copyWith(color: c.heroForeground, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const StatusPill('24/7 seguimiento'),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Del aviso a la solución.',
                  style: tema.textTheme.headlineMedium?.copyWith(color: c.heroForeground),
                ),
                const SizedBox(height: 6),
                Text(
                  'Diagnóstico inteligente, técnico adecuado y cada paso de tu servicio a la vista.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: c.heroMuted),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _Paso(icono: Icons.assignment_outlined, texto: 'Solicitud', color: c.heroMuted),
                    _Conector(color: c.heroMuted),
                    _Paso(icono: Icons.directions_car_outlined, texto: 'Visita', color: c.heroMuted),
                    _Conector(color: c.heroMuted),
                    _Paso(icono: Icons.check_circle_outline_rounded, texto: 'Resuelto', color: c.heroMuted),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Aro extends StatelessWidget {
  const _Aro({required this.tamanio, required this.grosor, required this.color});

  final double tamanio;
  final double grosor;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: tamanio,
        height: tamanio,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: grosor)),
      );
}

class _Paso extends StatelessWidget {
  const _Paso({required this.icono, required this.texto, required this.color});

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 4),
          Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );
}

class _Conector extends StatelessWidget {
  const _Conector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
          child: Divider(color: color.withValues(alpha: 0.35), thickness: 1),
        ),
      );
}

class _AvisoError extends StatelessWidget {
  const _AvisoError(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('aviso-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(mensaje, style: TextStyle(color: cs.error, fontSize: 12.5, height: 1.4))),
        ],
      ),
    );
  }
}

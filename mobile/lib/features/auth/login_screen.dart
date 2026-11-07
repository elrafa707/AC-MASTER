import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../models/usuario.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/rol_icono.dart';
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
  Rol _perfil = Rol.cliente;
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
      _perfil = Rol.cliente;
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
        await sesion.iniciarSesion(correo: _correo.text.trim(), password: _password.text, perfil: _perfil);
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
                  const Center(child: LogoCompleto()),
                  const SizedBox(height: 24),
                  Text(_registro ? 'Crear una cuenta' : 'Volver a tu espacio', style: tema.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    _registro ? 'Solo necesitaremos unos datos para empezar.' : 'Tus servicios, reunidos en un solo lugar.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  if (!_registro) ...[
                    _SelectorPerfil(
                      perfil: _perfil,
                      alCambiar: (rol) => setState(() {
                        _perfil = rol;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                              validator: (v) => (v == null || v.trim().length < 3) ? 'Escribe tu nombre completo' : null,
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
                  if (_error != null) ...[const SizedBox(height: 14), _AvisoError(_error!)],
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
                        : Text(_registro ? 'Crear mi cuenta' : 'Entrar como ${_perfil.etiqueta.toLowerCase()}'),
                  ),
                  const SizedBox(height: 10),
                  if (_registro || _perfil == Rol.cliente)
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
                  if (!_registro && _perfil != Rol.cliente)
                    Text(
                      'Las cuentas de técnicos y administradores las crea el administrador de AC-Master.',
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

/// Desplegable para elegir con qué perfil se entra; cada opción lleva su ícono de rol.
class _SelectorPerfil extends StatelessWidget {
  const _SelectorPerfil({required this.perfil, required this.alCambiar});

  final Rol perfil;
  final ValueChanged<Rol> alCambiar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return DropdownButtonFormField<Rol>(
      key: const Key('selector-perfil'),
      initialValue: perfil,
      isExpanded: true,
      itemHeight: 64,
      decoration: InputDecoration(
        labelText: 'Ingresar como',
        prefixIcon: Padding(padding: const EdgeInsets.all(8), child: RolIcono(perfil, tamanio: 34)),
      ),
      selectedItemBuilder: (_) => [
        for (final rol in Rol.values) Align(alignment: Alignment.centerLeft, child: Text(rol.etiqueta)),
      ],
      items: [
        for (final rol in Rol.values)
          DropdownMenuItem(
            key: Key('perfil-${rol.name}'),
            value: rol,
            child: Row(
              children: [
                RolIcono(rol, tamanio: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rol.etiqueta, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                      Text(RolIcono.descripcion(rol), style: tema.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (rol) {
        if (rol != null) alCambiar(rol);
      },
    );
  }
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
          Expanded(
            child: Text(mensaje, style: TextStyle(color: cs.error, fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

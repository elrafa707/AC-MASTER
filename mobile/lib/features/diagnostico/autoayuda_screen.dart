import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/diagnosticos_repository.dart';
import '../../data/equipos_repository.dart';
import '../../models/diagnostico.dart';
import '../../shared/widgets/status_pill.dart';

enum _Estado { guia, enviando, resuelto, noResuelto }

/// Guía paso a paso para que el cliente resuelva la falla sin técnico.
class AutoayudaScreen extends ConsumerStatefulWidget {
  const AutoayudaScreen({super.key, required this.diagnostico});

  final Diagnostico diagnostico;

  @override
  ConsumerState<AutoayudaScreen> createState() => _AutoayudaScreenState();
}

class _AutoayudaScreenState extends ConsumerState<AutoayudaScreen> {
  late final _hechos = List<bool>.filled(widget.diagnostico.pasosAutoayuda.length, false);
  _Estado _estado = _Estado.guia;
  String? _error;

  Future<void> _terminar({required bool resuelto}) async {
    setState(() {
      _estado = _Estado.enviando;
      _error = null;
    });
    try {
      await ref.read(diagnosticosRepositoryProvider).registrarAutoayuda(widget.diagnostico.id, resuelto: resuelto);
      ref.invalidate(fichaEquipoProvider(widget.diagnostico.equipoId));
      if (mounted) setState(() => _estado = resuelto ? _Estado.resuelto : _Estado.noResuelto);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _estado = _Estado.guia;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guía de autoayuda')),
      body: SafeArea(
        child: switch (_estado) {
          _Estado.resuelto => _Final(
              icono: Icons.check_circle_rounded,
              titulo: '¡Listo, quedó resuelto!',
              mensaje: 'Lo registramos en el historial de tu equipo para tenerlo presente en futuros servicios.',
              equipoId: widget.diagnostico.equipoId,
            ),
          _Estado.noResuelto => _Final(
              icono: Icons.engineering_rounded,
              titulo: 'Te recomendamos un técnico',
              mensaje: 'Los pasos no bastaron. En la siguiente etapa podrás solicitar la visita directamente desde aquí.',
              equipoId: widget.diagnostico.equipoId,
            ),
          _ => _guia(),
        },
      ),
    );
  }

  Widget _guia() {
    final tema = Theme.of(context);
    final c = context.acColors;
    final d = widget.diagnostico;
    final completos = _hechos.every((h) => h);
    final enviando = _estado == _Estado.enviando;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              StatusPill('${_hechos.where((h) => h).length} de ${_hechos.length} pasos'),
              const SizedBox(height: 10),
              Text(d.falla, style: tema.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('Marca cada paso cuando lo termines.', style: tema.textTheme.bodySmall),
              if (d.advertencia != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.orangeBg, borderRadius: BorderRadius.circular(18)),
                  child: Text(d.advertencia!, style: TextStyle(color: c.orangeFg, fontWeight: FontWeight.w600, height: 1.4)),
                ),
              ],
              const SizedBox(height: 16),
              for (final (i, paso) in d.pasosAutoayuda.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    key: Key('paso-$i'),
                    color: _hechos[i] ? c.greenBg : null,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enviando ? null : () => setState(() => _hechos[i] = !_hechos[i]),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _hechos[i] ? c.greenFg : tema.colorScheme.primary,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: _hechos[i]
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                  : Text('${i + 1}', style: TextStyle(color: tema.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(paso.titulo, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                                  const SizedBox(height: 3),
                                  Text(paso.detalle, style: tema.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_error != null) Text(_error!, style: TextStyle(color: tema.colorScheme.error)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                completos ? '¿Se resolvió el problema?' : 'Completa los pasos para continuar',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 10),
              FilledButton(
                key: const Key('boton-resuelto'),
                onPressed: completos && !enviando ? () => _terminar(resuelto: true) : null,
                child: const Text('Sí, ya funciona'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('boton-no-resuelto'),
                // Se puede rendir antes de terminar todos los pasos: siempre puede pedir técnico.
                onPressed: enviando ? null : () => _terminar(resuelto: false),
                child: const Text('No se resolvió'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({required this.icono, required this.titulo, required this.mensaje, required this.equipoId});

  final IconData icono;
  final String titulo;
  final String mensaje;
  final int equipoId;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icono, size: 64, color: tema.colorScheme.primary),
            const SizedBox(height: 16),
            Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('boton-ver-historial'),
              onPressed: () => context
                ..go(Rutas.inicio)
                ..push(Rutas.fichaEquipo(equipoId)),
              child: const Text('Ver historial del equipo'),
            ),
            TextButton(onPressed: () => context.go(Rutas.inicio), child: const Text('Volver al inicio')),
          ],
        ),
      ),
    );
  }
}

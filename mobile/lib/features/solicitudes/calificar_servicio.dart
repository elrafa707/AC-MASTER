import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/solicitudes_repository.dart';
import '../../models/solicitud.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/resumen_orden.dart';

/// Calificación del técnico al terminar el servicio (1 a 5 estrellas y un comentario opcional).
class CalificarServicio extends ConsumerStatefulWidget {
  const CalificarServicio({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  ConsumerState<CalificarServicio> createState() => _CalificarServicioState();
}

class _CalificarServicioState extends ConsumerState<CalificarServicio> {
  int _estrellas = 0;
  final _comentario = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final ok = await ejecutarConAviso(
      context,
      () => ref.read(solicitudesRepositoryProvider).calificar(widget.solicitud.id, calificacion: _estrellas, comentario: _comentario.text),
      exito: '¡Gracias por tu calificación!',
    );
    if (mounted) setState(() => _enviando = false);
    if (ok) ref.invalidate(solicitudProvider(widget.solicitud.id));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final s = widget.solicitud;
    if (s.calificacion != null) {
      return Card(
        child: ListTile(
          title: const Text('Tu calificación'),
          subtitle: s.comentarioCalificacion == null ? null : Text(s.comentarioCalificacion!),
          trailing: Estrellas(s.calificacion!),
        ),
      );
    }
    return Card(
      key: const Key('tarjeta-calificar'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cómo te atendió ${s.tecnico?.nombre ?? 'el técnico'}?', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: Key('estrella-$i'),
                    tooltip: '$i de 5',
                    iconSize: 34,
                    onPressed: () => setState(() => _estrellas = i),
                    icon: Icon(i <= _estrellas ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFE0A526)),
                  ),
              ],
            ),
            TextField(
              controller: _comentario,
              maxLength: 400,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
            ),
            FilledButton(
              key: const Key('boton-calificar'),
              onPressed: _estrellas == 0 || _enviando ? null : _enviar,
              child: const Text('Enviar calificación'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/solicitud.dart';
import 'foto_autenticada.dart';

/// Lo que registró el técnico: diagnóstico final, evidencias y piezas. Lo ven cliente y administrador al cierre.
class ResumenOrden extends StatelessWidget {
  const ResumenOrden({super.key, required this.orden});

  final OrdenTrabajo orden;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: const Key('resumen-orden'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Orden ${orden.folio}', style: tema.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            if (orden.fechaCierre != null) Text('Cerrada el ${fechaHora(orden.fechaCierre!)}', style: tema.textTheme.bodySmall),
            if (orden.diagnosticoFinal != null) ...[
              const SizedBox(height: 10),
              Text('Diagnóstico del técnico', style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Text(orden.diagnosticoFinal!, style: tema.textTheme.bodyMedium),
            ],
            if (orden.evidencias.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final e in orden.evidencias) FotoAutenticada(e.url, tamanio: 72)]),
            ],
            if (orden.piezas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Piezas utilizadas', style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
              const SizedBox(height: 6),
              for (final p in orden.piezas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('${p.nombre} × ${p.cantidad}', style: tema.textTheme.bodyMedium)),
                      Text(pesos(p.importe), style: tema.textTheme.bodyMedium),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estrellas de solo lectura.
class Estrellas extends StatelessWidget {
  const Estrellas(this.valor, {super.key, this.tamanio = 20});

  final int valor;
  final double tamanio;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= valor ? Icons.star_rounded : Icons.star_outline_rounded, size: tamanio, color: const Color(0xFFE0A526)),
        ],
      );
}

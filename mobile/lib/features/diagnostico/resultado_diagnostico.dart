import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/diagnostico.dart';
import '../../shared/widgets/foto_autenticada.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/status_pill.dart';

/// Resultado del asistente y la decisión: guía de autoayuda o visita de un técnico.
class VistaResultado extends StatelessWidget {
  const VistaResultado({super.key, required this.diagnostico});

  final Diagnostico diagnostico;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final d = diagnostico;

    return ListView(
      key: const Key('resultado-diagnostico'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.greenBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.greenFg.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  const StatusPill('Resultado preliminar', tono: PillTone.green),
                  if (d.simulado) const StatusPill('Modo simulado', tono: PillTone.orange),
                ],
              ),
              const SizedBox(height: 14),
              Text(d.falla, style: tema.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(d.descripcion, style: tema.textTheme.bodyMedium),
            ],
          ),
        ),
        if (d.advertencia != null) ...[
          const SizedBox(height: 14),
          Container(
            key: const Key('advertencia'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.orangeBg, borderRadius: BorderRadius.circular(18)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: c.orangeFg),
                const SizedBox(width: 10),
                Expanded(child: Text(d.advertencia!, style: TextStyle(color: c.orangeFg, fontWeight: FontWeight.w600, height: 1.4))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: SectionLabel('Lectura del diagnóstico')),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('${d.porcentaje}% de confianza', style: TextStyle(color: c.tealFg, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: d.confianza, minHeight: 8, color: c.tealFg, backgroundColor: c.tealBg),
                ),
                const SizedBox(height: 14),
                for (final causa in d.causas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: c.label),
                        const SizedBox(width: 10),
                        Expanded(child: Text(causa.nombre, style: tema.textTheme.bodyMedium)),
                        Text('${(causa.probabilidad * 100).round()}%', style: tema.textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (d.analisisFoto != null || d.fotos.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Lo que vimos en tus fotos'),
                  if (d.fotos.isNotEmpty)
                    Wrap(spacing: 8, runSpacing: 8, children: [for (final f in d.fotos) FotoAutenticada(f, tamanio: 64)]),
                  if (d.analisisFoto != null) ...[
                    const SizedBox(height: 10),
                    Text(d.analisisFoto!, style: tema.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _Decision(diagnostico: d),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.go(Rutas.inicio), child: const Text('Volver al inicio')),
      ],
    );
  }
}

class _Decision extends StatelessWidget {
  const _Decision({required this.diagnostico});

  final Diagnostico diagnostico;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = context.acColors;
    final d = diagnostico;
    final costo = d.costoMin == d.costoMax ? pesos(d.costoMin) : '${pesos(d.costoMin)} – ${pesos(d.costoMax)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Qué sigue'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: d.requiereTecnico ? c.orangeBg : c.greenBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                    d.requiereTecnico ? Icons.engineering_outlined : Icons.handyman_outlined,
                    size: 19,
                    color: d.requiereTecnico ? c.orangeFg : c.greenFg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.requiereTecnico ? 'Recomendamos la visita de un técnico' : 'Puedes intentar resolverlo tú mismo',
                        style: tema.textTheme.titleMedium?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.requiereTecnico
                            ? 'Un técnico${d.especialidad == null ? '' : ' de ${d.especialidad!.toLowerCase()}'} llegaría con lo necesario para esta falla.'
                            : 'Te guiamos con ${d.pasosAutoayuda.length} pasos seguros, sin herramientas.',
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (d.requiereTecnico && d.herramientas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final h in d.herramientas) Chip(label: Text(h), visualDensity: VisualDensity.compact)],
              ),
            ],
            const Divider(height: 28),
            Row(
              children: [
                Expanded(child: Text(d.requiereTecnico ? 'Costo estimado' : 'Si necesitas un técnico', style: tema.textTheme.bodySmall)),
                Text(costo, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            if (d.tieneAutoayuda)
              FilledButton(
                key: const Key('boton-guia'),
                style: d.requiereTecnico ? FilledButton.styleFrom(backgroundColor: c.tealBg, foregroundColor: c.tealFg) : null,
                onPressed: () => context.push(Rutas.autoayuda, extra: d),
                child: Text(d.requiereTecnico ? 'Ver qué puedo revisar mientras' : 'Seguir la guía paso a paso'),
              ),
            const SizedBox(height: 8),
            // El cliente siempre puede pedir técnico, aunque el asistente sugiera autoayuda.
            if (d.requiereTecnico)
              FilledButton(
                key: const Key('boton-solicitar-tecnico'),
                onPressed: () => context.push(Rutas.solicitarTecnico, extra: d),
                child: const Text('Solicitar técnico'),
              )
            else
              OutlinedButton(
                key: const Key('boton-solicitar-tecnico'),
                onPressed: () => context.push(Rutas.solicitarTecnico, extra: d),
                child: const Text('Prefiero que venga un técnico'),
              ),
          ],
        ),
      ),
    );
  }
}

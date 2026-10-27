import 'package:flutter/material.dart';

/// Ícono de marca: cuadro redondeado con la llave, como en el encabezado del prototipo.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.tamanio = 40});

  final double tamanio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: tamanio,
      height: tamanio,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(tamanio * 0.4),
        boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Icon(Icons.build_rounded, color: cs.onPrimary, size: tamanio * 0.48),
    );
  }
}

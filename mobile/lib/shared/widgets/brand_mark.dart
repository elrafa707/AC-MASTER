import 'package:flutter/material.dart';

/// Ícono de marca: el minisplit del logo sobre un cuadro blanco redondeado (se ve igual en tema claro y oscuro).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.tamanio = 40});

  final double tamanio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: tamanio,
      height: tamanio,
      padding: EdgeInsets.all(tamanio * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(tamanio * 0.3),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Image.asset('assets/images/logo_icono.png', fit: BoxFit.contain, semanticLabel: 'AC-Master'),
    );
  }
}

/// Logo completo (ícono, nombre y lema). En tema oscuro va sobre una tarjeta blanca para conservar el contraste.
class LogoCompleto extends StatelessWidget {
  const LogoCompleto({super.key, this.alto = 170});

  final double alto;

  @override
  Widget build(BuildContext context) {
    final imagen = Image.asset(
      'assets/images/logo.png',
      key: const Key('logo-completo'),
      height: alto,
      fit: BoxFit.contain,
      semanticLabel: 'AC Master, soporte técnico y reparación',
    );
    if (Theme.of(context).brightness == Brightness.light) return imagen;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: imagen,
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/usuario.dart';

/// Ícono propio de cada perfil: cliente (casa con persona), técnico (casco de trabajo) y
/// administrador (escudo de control). Se usa en el inicio de sesión y en el panel de cada rol.
class RolIcono extends StatelessWidget {
  const RolIcono(this.rol, {super.key, this.tamanio = 44});

  final Rol rol;
  final double tamanio;

  static IconData icono(Rol rol) => switch (rol) {
        Rol.cliente => Icons.home_rounded,
        Rol.tecnico => Icons.engineering_rounded,
        Rol.administrador => Icons.admin_panel_settings_rounded,
      };

  /// Fondo y color del ícono, tomados de la paleta de la app para distinguir los perfiles de un vistazo.
  static (Color fondo, Color frente) colores(BuildContext context, Rol rol) {
    final c = context.acColors;
    return switch (rol) {
      Rol.cliente => (c.tealBg, c.tealFg),
      Rol.tecnico => (c.orangeBg, c.orangeFg),
      Rol.administrador => (c.blueBg, c.blueFg),
    };
  }

  static String descripcion(Rol rol) => switch (rol) {
        Rol.cliente => 'Solicita y sigue tus servicios',
        Rol.tecnico => 'Atiende tus órdenes de trabajo',
        Rol.administrador => 'Coordina solicitudes y técnicos',
      };

  @override
  Widget build(BuildContext context) {
    final (fondo, frente) = colores(context, rol);
    return Container(
      key: Key('rol-icono-${rol.name}'),
      width: tamanio,
      height: tamanio,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(tamanio * 0.32),
        border: Border.all(color: frente.withValues(alpha: 0.35), width: 1.4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icono(rol), color: frente, size: tamanio * 0.56),
          // Pequeño distintivo con el copo de nieve de la marca en la esquina.
          Positioned(
            right: tamanio * 0.06,
            bottom: tamanio * 0.06,
            child: Container(
              width: tamanio * 0.3,
              height: tamanio * 0.3,
              decoration: BoxDecoration(color: frente, shape: BoxShape.circle, border: Border.all(color: fondo, width: 1.5)),
              child: Icon(Icons.ac_unit_rounded, color: fondo, size: tamanio * 0.19),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de los paneles: ícono del rol, una etiqueta corta y el nombre del perfil.
class EncabezadoRol extends StatelessWidget {
  const EncabezadoRol({super.key, required this.rol, required this.titulo});

  final Rol rol;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final c = context.acColors;
    return Row(
      children: [
        RolIcono(rol, tamanio: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo.toUpperCase(), style: TextStyle(color: c.heroMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
              Text(rol.etiqueta, style: TextStyle(color: c.heroForeground, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

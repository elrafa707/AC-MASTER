import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Encabezado de sección en mayúsculas espaciadas, con acción opcional a la derecha.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.texto, {super.key, this.accion, this.alPresionar});

  final String texto;
  final String? accion;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto.toUpperCase(),
              style: TextStyle(
                color: context.acColors.label,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
          if (accion != null)
            TextButton(
              onPressed: alPresionar,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              child: Text(accion!),
            ),
        ],
      ),
    );
  }
}

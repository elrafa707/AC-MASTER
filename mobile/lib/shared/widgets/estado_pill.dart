import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import 'status_pill.dart';

/// Etiqueta de color para el estado de una solicitud.
class EstadoPill extends StatelessWidget {
  const EstadoPill(this.estado, {super.key});

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) => StatusPill(
        estado.etiqueta,
        tono: switch (estado) {
          EstadoSolicitud.enRevision => PillTone.blue,
          EstadoSolicitud.cotizado || EstadoSolicitud.cancelada => PillTone.orange,
          EstadoSolicitud.enCamino => PillTone.teal,
          EstadoSolicitud.finalizado => PillTone.green,
        },
      );
}

/// Etiqueta para la prioridad (baja, media, alta).
class PrioridadPill extends StatelessWidget {
  const PrioridadPill(this.prioridad, {super.key});

  final String prioridad;

  @override
  Widget build(BuildContext context) => StatusPill(
        'Prioridad $prioridad',
        tono: switch (prioridad) {
          'alta' => PillTone.orange,
          'media' => PillTone.blue,
          _ => PillTone.green,
        },
      );
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/solicitud.dart';

/// Abre el marcador del teléfono con el número indicado.
Future<void> llamar(BuildContext context, String telefono) =>
    _abrir(context, Uri(scheme: 'tel', path: telefono), 'No se pudo abrir el marcador');

/// Abre la dirección en Google Maps (app o navegador).
Future<void> abrirEnMapa(BuildContext context, Direccion d) => _abrir(
      context,
      Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': d.completa}),
      'No se pudo abrir el mapa',
    );

Future<void> _abrir(BuildContext context, Uri uri, String error) async {
  final mensajero = ScaffoldMessenger.of(context);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) mensajero.showSnackBar(SnackBar(content: Text(error)));
}

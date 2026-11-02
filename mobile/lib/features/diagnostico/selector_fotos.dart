import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/diagnostico.dart';

typedef ElegirFoto = Future<FotoSeleccionada?> Function(ImageSource origen);

/// Abre la cámara o la galería y devuelve la foto reducida (máx. 1600 px) lista para enviar.
/// Es un provider para poder reemplazarlo en las pruebas.
final elegirFotoProvider = Provider<ElegirFoto>((ref) {
  final picker = ImagePicker();
  return (origen) async {
    final archivo = await picker.pickImage(source: origen, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
    if (archivo == null) return null;
    final nombre = archivo.name.toLowerCase();
    final mime = archivo.mimeType ??
        (nombre.endsWith('.png')
            ? 'image/png'
            : nombre.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg');
    return FotoSeleccionada(bytes: await archivo.readAsBytes(), nombre: archivo.name, mimeType: mime);
  };
});

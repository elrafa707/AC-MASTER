class Sintoma {
  const Sintoma({required this.clave, required this.etiqueta, required this.detalle});

  final String clave;
  final String etiqueta;
  final String detalle;

  factory Sintoma.fromJson(Map<String, dynamic> json) => Sintoma(
        clave: json['clave'] as String,
        etiqueta: json['etiqueta'] as String,
        detalle: json['detalle'] as String,
      );
}

class Pregunta {
  const Pregunta({required this.id, required this.texto, required this.opciones, this.ayuda});

  final String id;
  final String texto;
  final List<String> opciones;
  final String? ayuda;

  factory Pregunta.fromJson(Map<String, dynamic> json) => Pregunta(
        id: json['id'] as String,
        texto: json['texto'] as String,
        opciones: [for (final o in json['opciones'] as List) o as String],
        ayuda: json['ayuda'] as String?,
      );
}

class Cuestionario {
  const Cuestionario({required this.sintomas, required this.preguntas});

  final List<Sintoma> sintomas;
  final List<Pregunta> preguntas;

  factory Cuestionario.fromJson(Map<String, dynamic> json) => Cuestionario(
        sintomas: [for (final s in json['sintomas'] as List) Sintoma.fromJson(s as Map<String, dynamic>)],
        preguntas: [for (final p in json['preguntas'] as List) Pregunta.fromJson(p as Map<String, dynamic>)],
      );
}

class CausaProbable {
  const CausaProbable(this.nombre, this.probabilidad);

  final String nombre;
  final double probabilidad;
}

class PasoGuia {
  const PasoGuia(this.titulo, this.detalle);

  final String titulo;
  final String detalle;
}

enum ResultadoDiagnostico { pendiente, resueltoAutoayuda, escalado }

/// Resultado del asistente inteligente (RF-03).
class Diagnostico {
  const Diagnostico({
    required this.id,
    required this.equipoId,
    required this.falla,
    required this.descripcion,
    required this.confianza,
    required this.causas,
    required this.requiereTecnico,
    required this.pasosAutoayuda,
    required this.herramientas,
    required this.prioridad,
    required this.costoMin,
    required this.costoMax,
    required this.resultado,
    required this.modelo,
    required this.fotos,
    this.especialidad,
    this.advertencia,
    this.analisisFoto,
  });

  final int id;
  final int equipoId;
  final String falla;
  final String descripcion;
  final double confianza;
  final List<CausaProbable> causas;
  final bool requiereTecnico;
  final List<PasoGuia> pasosAutoayuda;
  final List<String> herramientas;
  final String? especialidad;
  final String prioridad;
  final double costoMin;
  final double costoMax;
  final String? advertencia;
  final String? analisisFoto;
  final ResultadoDiagnostico resultado;
  final String modelo;

  /// Rutas relativas (/api/v1/fotos/{id}) que requieren el token para descargarse.
  final List<String> fotos;

  int get porcentaje => (confianza * 100).round();
  bool get tieneAutoayuda => pasosAutoayuda.isNotEmpty;
  bool get simulado => modelo.startsWith('simulado');

  factory Diagnostico.fromJson(Map<String, dynamic> json) => Diagnostico(
        id: json['id'] as int,
        equipoId: json['equipoId'] as int,
        falla: json['falla'] as String,
        descripcion: json['descripcion'] as String,
        confianza: (json['confianza'] as num).toDouble(),
        causas: [
          for (final c in json['causas'] as List)
            CausaProbable(c['nombre'] as String, (c['probabilidad'] as num).toDouble()),
        ],
        requiereTecnico: json['requiereTecnico'] as bool,
        pasosAutoayuda: [
          for (final p in json['pasosAutoayuda'] as List) PasoGuia(p['titulo'] as String, p['detalle'] as String),
        ],
        herramientas: [for (final h in json['herramientas'] as List) h as String],
        especialidad: (json['especialidad'] as Map?)?['nombre'] as String?,
        prioridad: json['prioridad'] as String,
        costoMin: (json['costoMin'] as num).toDouble(),
        costoMax: (json['costoMax'] as num).toDouble(),
        advertencia: json['advertencia'] as String?,
        analisisFoto: json['analisisFoto'] as String?,
        resultado: switch (json['resultado']) {
          'RESUELTO_AUTOAYUDA' => ResultadoDiagnostico.resueltoAutoayuda,
          'ESCALADO' => ResultadoDiagnostico.escalado,
          _ => ResultadoDiagnostico.pendiente,
        },
        modelo: json['modelo'] as String,
        fotos: [for (final f in json['fotos'] as List) f['url'] as String],
      );
}

/// Foto elegida por el cliente, lista para enviarse.
class FotoSeleccionada {
  const FotoSeleccionada({required this.bytes, required this.nombre, required this.mimeType});

  final List<int> bytes;
  final String nombre;
  final String mimeType;
}

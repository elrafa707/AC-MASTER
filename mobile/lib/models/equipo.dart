enum TipoRegistro {
  instalacion('INSTALACION', 'Instalación'),
  mantenimiento('MANTENIMIENTO', 'Mantenimiento'),
  reparacion('REPARACION', 'Reparación'),
  autoayuda('AUTOAYUDA', 'Resuelto con asistente'),
  prediccion('PREDICCION', 'Diagnóstico');

  const TipoRegistro(this.api, this.etiqueta);
  final String api;
  final String etiqueta;

  static TipoRegistro desdeApi(String valor) =>
      values.firstWhere((t) => t.api == valor, orElse: () => TipoRegistro.prediccion);
}

class Equipo {
  const Equipo({
    required this.id,
    required this.numeroSerie,
    required this.marca,
    required this.modelo,
    required this.tipo,
    this.clienteNombre,
    this.capacidadBTU,
    this.refrigerante,
    this.ubicacion,
    this.fechaInstalacion,
    this.ultimoRegistro,
  });

  final int id;
  final String numeroSerie;
  final String marca;
  final String modelo;
  final String tipo;
  final String? clienteNombre;
  final int? capacidadBTU;
  final String? refrigerante;
  final String? ubicacion;
  final DateTime? fechaInstalacion;
  final DateTime? ultimoRegistro;

  String get nombre => '$marca $modelo';

  factory Equipo.fromJson(Map<String, dynamic> json) => Equipo(
        id: json['id'] as int,
        numeroSerie: json['numeroSerie'] as String,
        marca: json['marca'] as String,
        modelo: json['modelo'] as String,
        tipo: json['tipo'] as String,
        clienteNombre: json['clienteNombre'] as String?,
        capacidadBTU: json['capacidadBTU'] as int?,
        refrigerante: json['refrigerante'] as String?,
        ubicacion: json['ubicacion'] as String?,
        fechaInstalacion: _fecha(json['fechaInstalacion']),
        ultimoRegistro: _fecha(json['ultimoRegistro']),
      );
}

class RegistroHistorial {
  const RegistroHistorial({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.fecha,
    this.descripcion,
    this.diagnosticoId,
    this.tecnicoNombre,
  });

  final int id;
  final TipoRegistro tipo;
  final String titulo;
  final String? descripcion;
  final DateTime fecha;
  final int? diagnosticoId;
  final String? tecnicoNombre;

  factory RegistroHistorial.fromJson(Map<String, dynamic> json) => RegistroHistorial(
        id: json['id'] as int,
        tipo: TipoRegistro.desdeApi(json['tipo'] as String),
        titulo: json['titulo'] as String,
        descripcion: json['descripcion'] as String?,
        fecha: DateTime.parse(json['fecha'] as String).toLocal(),
        diagnosticoId: json['diagnosticoId'] as int?,
        tecnicoNombre: json['tecnicoNombre'] as String?,
      );
}

/// Ficha técnica de un equipo con su historial cronológico (RF-08).
class FichaEquipo {
  const FichaEquipo({required this.equipo, required this.historial});

  final Equipo equipo;
  final List<RegistroHistorial> historial;

  factory FichaEquipo.fromJson(Map<String, dynamic> json) => FichaEquipo(
        equipo: Equipo.fromJson(json),
        historial: [
          for (final r in json['historial'] as List) RegistroHistorial.fromJson(r as Map<String, dynamic>),
        ],
      );
}

/// Datos para registrar un equipo nuevo.
class NuevoEquipo {
  const NuevoEquipo({
    required this.numeroSerie,
    required this.marca,
    required this.modelo,
    required this.tipo,
    this.capacidadBTU,
    this.refrigerante,
    this.ubicacion,
    this.fechaInstalacion,
  });

  final String numeroSerie;
  final String marca;
  final String modelo;
  final String tipo;
  final int? capacidadBTU;
  final String? refrigerante;
  final String? ubicacion;
  final DateTime? fechaInstalacion;

  Map<String, dynamic> toJson() => {
        'numeroSerie': numeroSerie,
        'marca': marca,
        'modelo': modelo,
        'tipo': tipo,
        'capacidadBTU': ?capacidadBTU,
        'refrigerante': ?refrigerante,
        if (ubicacion != null && ubicacion!.isNotEmpty) 'ubicacion': ubicacion,
        if (fechaInstalacion != null) 'fechaInstalacion': fechaInstalacion!.toIso8601String().substring(0, 10),
      };
}

DateTime? _fecha(Object? valor) => valor is String ? DateTime.parse(valor).toLocal() : null;

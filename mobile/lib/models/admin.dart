class ResumenPanel {
  const ResumenPanel({
    required this.enRevision,
    required this.cotizadas,
    required this.enCamino,
    required this.finalizadas,
    required this.urgentes,
    required this.tecnicosDisponibles,
    required this.tecnicosActivos,
  });

  final int enRevision;
  final int cotizadas;
  final int enCamino;
  final int finalizadas;
  final int urgentes;
  final int tecnicosDisponibles;
  final int tecnicosActivos;

  factory ResumenPanel.fromJson(Map<String, dynamic> j) => ResumenPanel(
        enRevision: j['enRevision'] as int,
        cotizadas: j['cotizadas'] as int,
        enCamino: j['enCamino'] as int,
        finalizadas: j['finalizadas'] as int,
        urgentes: j['urgentes'] as int,
        tecnicosDisponibles: j['tecnicosDisponibles'] as int,
        tecnicosActivos: j['tecnicosActivos'] as int,
      );
}

/// Candidato del ranking de RF-04.
class TecnicoRecomendado {
  const TecnicoRecomendado({
    required this.id,
    required this.nombre,
    required this.especialidades,
    required this.disponible,
    required this.calificacion,
    required this.serviciosActivos,
    required this.tieneEspecialidad,
    required this.puntaje,
    required this.asignado,
    required this.razones,
  });

  final int id;
  final String nombre;
  final List<String> especialidades;
  final bool disponible;
  final double calificacion;
  final int serviciosActivos;
  final bool tieneEspecialidad;
  final int puntaje;
  final bool asignado;
  final List<String> razones;

  factory TecnicoRecomendado.fromJson(Map<String, dynamic> j) => TecnicoRecomendado(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        especialidades: [for (final e in j['especialidades'] as List) e as String],
        disponible: j['disponible'] as bool,
        calificacion: (j['calificacion'] as num).toDouble(),
        serviciosActivos: j['serviciosActivos'] as int,
        tieneEspecialidad: j['tieneEspecialidad'] as bool,
        puntaje: j['puntaje'] as int,
        asignado: j['asignado'] as bool,
        razones: [for (final r in j['razones'] as List) r as String],
      );
}

class Especialidad {
  const Especialidad(this.clave, this.nombre);

  final String clave;
  final String nombre;

  factory Especialidad.fromJson(Map<String, dynamic> j) => Especialidad(j['clave'] as String, j['nombre'] as String);
}

class TecnicoCuenta {
  const TecnicoCuenta({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.activo,
    required this.disponible,
    required this.calificacion,
    required this.especialidades,
    required this.serviciosActivos,
    required this.serviciosFinalizados,
    this.telefono,
  });

  final int id;
  final String nombre;
  final String correo;
  final String? telefono;
  final bool activo;
  final bool disponible;
  final double calificacion;
  final List<String> especialidades;
  final int serviciosActivos;
  final int serviciosFinalizados;

  factory TecnicoCuenta.fromJson(Map<String, dynamic> j) => TecnicoCuenta(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        correo: j['correo'] as String,
        telefono: j['telefono'] as String?,
        activo: j['activo'] as bool,
        disponible: j['disponible'] as bool,
        calificacion: (j['calificacion'] as num).toDouble(),
        especialidades: [for (final e in j['especialidades'] as List) e as String],
        serviciosActivos: j['serviciosActivos'] as int,
        serviciosFinalizados: j['serviciosFinalizados'] as int,
      );
}

class ClienteCuenta {
  const ClienteCuenta({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.activo,
    required this.equipos,
    required this.solicitudes,
    this.telefono,
  });

  final int id;
  final String nombre;
  final String correo;
  final String? telefono;
  final bool activo;
  final int equipos;
  final int solicitudes;

  factory ClienteCuenta.fromJson(Map<String, dynamic> j) => ClienteCuenta(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        correo: j['correo'] as String,
        telefono: j['telefono'] as String?,
        activo: j['activo'] as bool,
        equipos: j['equipos'] as int,
        solicitudes: j['solicitudes'] as int,
      );
}

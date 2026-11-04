import 'diagnostico.dart';

enum EstadoSolicitud {
  enRevision('EN_REVISION', 'En revisión'),
  cotizado('COTIZADO', 'Cotizado'),
  enCamino('EN_CAMINO', 'En camino'),
  finalizado('FINALIZADO', 'Finalizado'),
  cancelada('CANCELADA', 'Cancelada');

  const EstadoSolicitud(this.api, this.etiqueta);
  final String api;
  final String etiqueta;

  bool get activa => this == enRevision || this == cotizado || this == enCamino;

  /// Posición en el avance normal del servicio (la cancelación no tiene).
  int get paso => switch (this) {
        enRevision => 0,
        cotizado => 1,
        enCamino => 2,
        finalizado => 3,
        cancelada => -1,
      };

  static EstadoSolicitud desdeApi(String valor) => values.firstWhere((e) => e.api == valor, orElse: () => enRevision);
}

DateTime? _fecha(Object? v) => v is String ? DateTime.parse(v).toLocal() : null;
double? _numero(Object? v) => v is num ? v.toDouble() : null;

/// Fila de las listas: "Mis servicios", bandeja del administrador y órdenes del técnico.
class ResumenSolicitud {
  const ResumenSolicitud({
    required this.id,
    required this.folio,
    required this.estado,
    required this.prioridad,
    required this.falla,
    required this.equipo,
    required this.clienteNombre,
    required this.colonia,
    required this.fechaCreacion,
    required this.pedidaPorCliente,
    this.tecnicoNombre,
    this.ventanaInicio,
    this.ventanaFin,
    this.totalCotizacion,
  });

  final int id;
  final String folio;
  final EstadoSolicitud estado;
  final String prioridad;
  final String falla;
  final String equipo;
  final String clienteNombre;
  final String colonia;
  final DateTime fechaCreacion;
  final bool pedidaPorCliente;
  final String? tecnicoNombre;
  final DateTime? ventanaInicio;
  final DateTime? ventanaFin;
  final double? totalCotizacion;

  factory ResumenSolicitud.fromJson(Map<String, dynamic> j) => ResumenSolicitud(
        id: j['id'] as int,
        folio: j['folio'] as String,
        estado: EstadoSolicitud.desdeApi(j['estado'] as String),
        prioridad: j['prioridad'] as String,
        falla: j['falla'] as String,
        equipo: (j['equipo'] as Map<String, dynamic>)['nombre'] as String,
        clienteNombre: j['clienteNombre'] as String,
        colonia: j['colonia'] as String,
        fechaCreacion: _fecha(j['fechaCreacion'])!,
        pedidaPorCliente: j['pedidaPorCliente'] as bool,
        tecnicoNombre: j['tecnicoNombre'] as String?,
        ventanaInicio: _fecha(j['ventanaInicio']),
        ventanaFin: _fecha(j['ventanaFin']),
        totalCotizacion: _numero(j['totalCotizacion']),
      );
}

class Direccion {
  const Direccion({
    required this.id,
    required this.alias,
    required this.calle,
    required this.colonia,
    required this.ciudad,
    this.cp,
    this.referencias,
    this.principal = false,
  });

  final int id;
  final String alias;
  final String calle;
  final String colonia;
  final String ciudad;
  final String? cp;
  final String? referencias;
  final bool principal;

  String get completa => [calle, colonia, [ciudad, if (cp != null) cp].join(' ')].join(', ');

  factory Direccion.fromJson(Map<String, dynamic> j) => Direccion(
        id: j['id'] as int,
        alias: j['alias'] as String,
        calle: j['calle'] as String,
        colonia: j['colonia'] as String,
        ciudad: j['ciudad'] as String,
        cp: j['cp'] as String?,
        referencias: j['referencias'] as String?,
        principal: j['principal'] as bool? ?? false,
      );
}

class Partida {
  const Partida({required this.concepto, required this.cantidad, required this.precioUnitario});

  final String concepto;
  final int cantidad;
  final double precioUnitario;

  double get importe => cantidad * precioUnitario;

  factory Partida.fromJson(Map<String, dynamic> j) => Partida(
        concepto: j['concepto'] as String,
        cantidad: j['cantidad'] as int,
        precioUnitario: (j['precioUnitario'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'concepto': concepto, 'cantidad': cantidad, 'precioUnitario': precioUnitario};
}

class Cotizacion {
  const Cotizacion({
    required this.estado,
    required this.generadaAuto,
    required this.partidas,
    required this.total,
    this.comentarioCliente,
  });

  /// BORRADOR, ENVIADA, APROBADA o RECHAZADA.
  final String estado;
  final bool generadaAuto;
  final List<Partida> partidas;
  final double total;
  final String? comentarioCliente;

  factory Cotizacion.fromJson(Map<String, dynamic> j) => Cotizacion(
        estado: j['estado'] as String,
        generadaAuto: j['generadaAuto'] as bool,
        partidas: [for (final p in j['partidas'] as List) Partida.fromJson(p as Map<String, dynamic>)],
        total: (j['total'] as num).toDouble(),
        comentarioCliente: j['comentarioCliente'] as String?,
      );
}

class EventoSolicitud {
  const EventoSolicitud({required this.estado, required this.titulo, required this.fecha, this.detalle});

  final EstadoSolicitud estado;
  final String titulo;
  final String? detalle;
  final DateTime fecha;

  factory EventoSolicitud.fromJson(Map<String, dynamic> j) => EventoSolicitud(
        estado: EstadoSolicitud.desdeApi(j['estado'] as String),
        titulo: j['titulo'] as String,
        detalle: j['detalle'] as String?,
        fecha: _fecha(j['fecha'])!,
      );
}

class TecnicoAsignado {
  const TecnicoAsignado({required this.id, required this.nombre, required this.calificacion, this.telefono});

  final int id;
  final String nombre;
  final double calificacion;
  final String? telefono;

  factory TecnicoAsignado.fromJson(Map<String, dynamic> j) => TecnicoAsignado(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        calificacion: (j['calificacion'] as num).toDouble(),
        telefono: j['telefono'] as String?,
      );
}

/// Detalle completo de una solicitud (interfaces 4 y 5).
class Solicitud {
  const Solicitud({
    required this.resumen,
    required this.clienteId,
    required this.clienteTelefono,
    required this.clienteCorreo,
    required this.equipoId,
    required this.numeroSerie,
    required this.direccion,
    required this.diagnostico,
    required this.eventos,
    this.descripcion,
    this.tecnico,
    this.cotizacion,
    this.calificacion,
    this.comentarioCalificacion,
  });

  final ResumenSolicitud resumen;
  final int clienteId;
  final String? clienteTelefono;
  final String clienteCorreo;
  final int equipoId;
  final String numeroSerie;
  final Direccion direccion;
  final Diagnostico diagnostico;
  final List<EventoSolicitud> eventos;
  final String? descripcion;
  final TecnicoAsignado? tecnico;
  final Cotizacion? cotizacion;
  final int? calificacion;
  final String? comentarioCalificacion;

  int get id => resumen.id;
  String get folio => resumen.folio;
  EstadoSolicitud get estado => resumen.estado;

  factory Solicitud.fromJson(Map<String, dynamic> j) {
    final cliente = j['cliente'] as Map<String, dynamic>;
    final equipo = j['equipo'] as Map<String, dynamic>;
    return Solicitud(
      resumen: ResumenSolicitud.fromJson(j),
      clienteId: cliente['id'] as int,
      clienteTelefono: cliente['telefono'] as String?,
      clienteCorreo: cliente['correo'] as String,
      equipoId: equipo['id'] as int,
      numeroSerie: equipo['numeroSerie'] as String,
      direccion: Direccion.fromJson(j['direccion'] as Map<String, dynamic>),
      diagnostico: Diagnostico.fromJson(j['diagnostico'] as Map<String, dynamic>),
      eventos: [for (final e in j['eventos'] as List) EventoSolicitud.fromJson(e as Map<String, dynamic>)],
      descripcion: j['descripcion'] as String?,
      tecnico: j['tecnico'] == null ? null : TecnicoAsignado.fromJson(j['tecnico'] as Map<String, dynamic>),
      cotizacion: j['cotizacion'] == null ? null : Cotizacion.fromJson(j['cotizacion'] as Map<String, dynamic>),
      calificacion: j['calificacion'] as int?,
      comentarioCalificacion: j['comentarioCalificacion'] as String?,
    );
  }
}

class Notificacion {
  const Notificacion({required this.id, required this.titulo, required this.cuerpo, required this.leida, required this.fecha, this.solicitudId});

  final int id;
  final String titulo;
  final String cuerpo;
  final bool leida;
  final DateTime fecha;
  final int? solicitudId;

  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
        id: j['id'] as int,
        titulo: j['titulo'] as String,
        cuerpo: j['cuerpo'] as String,
        leida: j['leida'] as bool,
        fecha: _fecha(j['fecha'])!,
        solicitudId: j['solicitudId'] as int?,
      );
}

class BandejaNotificaciones {
  const BandejaNotificaciones({required this.noLeidas, required this.notificaciones});

  final int noLeidas;
  final List<Notificacion> notificaciones;

  factory BandejaNotificaciones.fromJson(Map<String, dynamic> j) => BandejaNotificaciones(
        noLeidas: j['noLeidas'] as int,
        notificaciones: [for (final n in j['notificaciones'] as List) Notificacion.fromJson(n as Map<String, dynamic>)],
      );
}

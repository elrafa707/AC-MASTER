import 'dart:convert';
import 'dart:io';

import 'package:ac_master/app.dart';
import 'package:ac_master/core/api/api_exception.dart';
import 'package:ac_master/core/session/token_storage.dart';
import 'package:ac_master/data/admin_repository.dart';
import 'package:ac_master/data/auth_repository.dart';
import 'package:ac_master/data/diagnosticos_repository.dart';
import 'package:ac_master/data/equipos_repository.dart';
import 'package:ac_master/data/solicitudes_repository.dart';
import 'package:ac_master/data/tecnico_repository.dart';
import 'package:ac_master/features/diagnostico/selector_fotos.dart';
import 'package:ac_master/models/admin.dart';
import 'package:ac_master/models/diagnostico.dart';
import 'package:ac_master/models/equipo.dart';
import 'package:ac_master/models/solicitud.dart';
import 'package:ac_master/models/usuario.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const clienteDemo = Usuario(id: 3, nombre: 'Rafael Báez', correo: 'cliente@acmaster.mx', rol: Rol.cliente);
const tecnicoDemo = Usuario(id: 2, nombre: 'Mariela Ríos', correo: 'tecnico@acmaster.mx', rol: Rol.tecnico);
const adminDemo = Usuario(id: 1, nombre: 'Administrador AC-Master', correo: 'admin@acmaster.mx', rol: Rol.administrador);

class FakeTokenStorage extends TokenStorage {
  FakeTokenStorage([this._token]);

  String? _token;

  @override
  Future<String?> leer() async => _token;

  @override
  String? get actual => _token;

  @override
  Future<void> guardar(String token) async => _token = token;

  @override
  Future<void> borrar() async => _token = null;
}

/// Repositorio en memoria: acepta clienteDemo con la contraseña "AcMaster2026!".
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.usuarioSesion = clienteDemo}) : super(Dio());

  final Usuario usuarioSesion;
  final registrados = <String>{clienteDemo.correo};

  @override
  Future<Sesion> iniciarSesion({required String correo, required String password}) async {
    if (correo == clienteDemo.correo && password == 'AcMaster2026!') {
      return (token: 'token-demo', usuario: clienteDemo);
    }
    if (correo == tecnicoDemo.correo && password == 'AcMaster2026!') {
      return (token: 'token-tecnico', usuario: tecnicoDemo);
    }
    throw const ApiException('Correo o contraseña incorrectos', codigo: 'CREDENCIALES_INVALIDAS', status: 401);
  }

  @override
  Future<Sesion> registrar({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
  }) async {
    if (registrados.contains(correo)) {
      throw const ApiException(
        'Ya existe una cuenta con ese correo',
        codigo: 'CORREO_REGISTRADO',
        status: 409,
      );
    }
    registrados.add(correo);
    return (token: 'token-nuevo', usuario: Usuario(id: 99, nombre: nombre, correo: correo, rol: Rol.cliente));
  }

  @override
  Future<Usuario> perfil() async => usuarioSesion;
}

final equipoDemo = Equipo(
  id: 10,
  numeroSerie: 'MRG24-031802',
  marca: 'Mirage',
  modelo: 'MRG123',
  tipo: 'Minisplit',
  capacidadBTU: 12000,
  ubicacion: 'Sala',
  fechaInstalacion: DateTime(2024, 3, 18),
  clienteNombre: 'Rafael Báez',
);

class FakeEquiposRepository extends EquiposRepository {
  FakeEquiposRepository({List<Equipo>? equipos}) : equipos = equipos ?? [equipoDemo], super(Dio());

  final List<Equipo> equipos;
  final historial = <int, List<RegistroHistorial>>{};

  @override
  Future<List<Equipo>> listar() async => List.of(equipos);

  @override
  Future<FichaEquipo> ficha(int id) async =>
      FichaEquipo(equipo: equipos.firstWhere((e) => e.id == id), historial: historial[id] ?? const []);

  @override
  Future<FichaEquipo> fichaPorSerie(String numeroSerie) async {
    final equipo = equipos.where((e) => e.numeroSerie == numeroSerie).firstOrNull;
    if (equipo == null) {
      throw const ApiException('No encontramos ese equipo', codigo: 'EQUIPO_NO_ENCONTRADO', status: 404);
    }
    return ficha(equipo.id);
  }

  @override
  Future<FichaEquipo> registrar(NuevoEquipo nuevo) async {
    if (equipos.any((e) => e.numeroSerie == nuevo.numeroSerie)) {
      throw const ApiException('Ya hay un equipo registrado con ese número de serie', codigo: 'SERIE_REGISTRADA', status: 409);
    }
    final equipo = Equipo(
      id: 100 + equipos.length,
      numeroSerie: nuevo.numeroSerie,
      marca: nuevo.marca,
      modelo: nuevo.modelo,
      tipo: nuevo.tipo,
      fechaInstalacion: nuevo.fechaInstalacion,
    );
    equipos.add(equipo);
    return ficha(equipo.id);
  }
}

const _sintomas = [
  Sintoma(clave: 'NO_ENFRIA', etiqueta: 'No enfría', detalle: 'El aire sale, pero no baja la temperatura'),
  Sintoma(clave: 'MAL_OLOR', etiqueta: 'Huele raro', detalle: 'Olor a humedad o a quemado'),
];

const _preguntas = [
  Pregunta(id: 'modo_frio', texto: '¿Está en modo frío?', opciones: ['Sí', 'No']),
  Pregunta(id: 'ultima_limpieza_filtros', texto: '¿Cuándo limpiaste los filtros?', opciones: ['Hace poco', 'Hace más de 6 meses']),
];

Diagnostico diagnosticoDemo({bool requiereTecnico = false, String? advertencia}) => Diagnostico(
      id: 50,
      equipoId: equipoDemo.id,
      falla: requiereTecnico ? 'Posible falla eléctrica' : 'Filtros saturados de polvo',
      descripcion: 'Explicación para el cliente.',
      confianza: 0.82,
      causas: const [CausaProbable('Filtros sucios', 0.7), CausaProbable('Baja carga de gas', 0.2)],
      requiereTecnico: requiereTecnico,
      pasosAutoayuda: requiereTecnico
          ? const []
          : const [PasoGuia('Apaga el equipo', 'Bájale al interruptor.'), PasoGuia('Lava los filtros', 'Con agua tibia.')],
      herramientas: const ['Multímetro'],
      especialidad: 'Eléctrico',
      prioridad: requiereTecnico ? 'alta' : 'baja',
      costoMin: 450,
      costoMax: 900,
      advertencia: advertencia,
      analisisFoto: 'Se ve polvo acumulado en la rejilla.',
      resultado: ResultadoDiagnostico.pendiente,
      modelo: 'claude-opus-5-5',
      fotos: const [],
    );

class FakeDiagnosticosRepository extends DiagnosticosRepository {
  FakeDiagnosticosRepository({Diagnostico? resultado}) : resultado = resultado ?? diagnosticoDemo(), super(Dio());

  final Diagnostico resultado;
  Map<String, Object?>? ultimoEnvio;
  bool? autoayudaResuelta;

  @override
  Future<Cuestionario> cuestionario(List<String> sintomas) async =>
      Cuestionario(sintomas: _sintomas, preguntas: sintomas.isEmpty ? const [] : _preguntas);

  @override
  Future<Diagnostico> diagnosticar({
    required int equipoId,
    required List<String> sintomas,
    required Map<String, String> respuestas,
    required List<FotoSeleccionada> fotos,
    String? descripcion,
  }) async {
    ultimoEnvio = {'equipoId': equipoId, 'sintomas': sintomas, 'respuestas': respuestas, 'fotos': fotos.length};
    return resultado;
  }

  @override
  Future<Diagnostico> registrarAutoayuda(int id, {required bool resuelto}) async {
    autoayudaResuelta = resuelto;
    return resultado;
  }
}

/// PNG de 1x1 píxel para simular una foto elegida.
const pngDemo = [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, //
  137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 218, 99, 100, 248, 207, 80, 15, 0, 3, 134, 1, 128, 90, 52, 125, 107, 0, 0, //
  0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
];

/// Respuestas reales del API capturadas en test/fixtures.
dynamic fixture(String nombre) => jsonDecode(File('test/fixtures/$nombre.json').readAsStringSync());

class FakeSolicitudesRepository extends SolicitudesRepository {
  FakeSolicitudesRepository({Solicitud? detalle, List<Direccion>? direcciones})
      : _detalle = detalle ?? Solicitud.fromJson(fixture('solicitud_cotizada_cliente') as Map<String, dynamic>),
        _direcciones = direcciones ?? [for (final d in fixture('direcciones') as List) Direccion.fromJson(d as Map<String, dynamic>)],
        super(Dio());

  Solicitud _detalle;
  final List<Direccion> _direcciones;
  final llamadas = <String>[];

  @override
  Future<List<Direccion>> direcciones() async => List.of(_direcciones);

  @override
  Future<Direccion> agregarDireccion({
    required String alias,
    required String calle,
    required String colonia,
    required String ciudad,
    String? cp,
    String? referencias,
  }) async {
    final d = Direccion(id: 900 + _direcciones.length, alias: alias, calle: calle, colonia: colonia, ciudad: ciudad, cp: cp);
    _direcciones.add(d);
    llamadas.add('direccion:$calle');
    return d;
  }

  @override
  Future<Solicitud> crear({required int diagnosticoId, required int direccionId, String? descripcion}) async {
    llamadas.add('crear:$diagnosticoId:$direccionId');
    return _detalle;
  }

  @override
  Future<List<ResumenSolicitud>> mias() async => [_detalle.resumen];

  @override
  Future<Solicitud> detalle(int id) async => _detalle;

  @override
  Future<Solicitud> aprobar(int id) async {
    llamadas.add('aprobar:$id');
    return _detalle;
  }

  @override
  Future<Solicitud> rechazar(int id, {String? motivo}) async {
    llamadas.add('rechazar:$id:${motivo ?? ''}');
    return _detalle;
  }

  @override
  Future<Solicitud> cancelar(int id, {String? motivo}) async {
    llamadas.add('cancelar:$id');
    return _detalle;
  }

  set detalleActual(Solicitud s) => _detalle = s;

  @override
  Future<Solicitud> calificar(int id, {required int calificacion, String? comentario}) async {
    llamadas.add('calificar:$id:$calificacion');
    return _detalle;
  }

  @override
  Future<BandejaNotificaciones> notificaciones() async =>
      BandejaNotificaciones.fromJson(fixture('notificaciones') as Map<String, dynamic>);

  @override
  Future<void> marcarLeida(int id) async => llamadas.add('leida:$id');

  @override
  Future<void> marcarTodasLeidas() async => llamadas.add('leidas');
}

class FakeAdminRepository extends AdminRepository {
  FakeAdminRepository() : super(Dio());

  final llamadas = <String>[];

  @override
  Future<ResumenPanel> resumen() async => const ResumenPanel(
        enRevision: 3,
        cotizadas: 1,
        enCamino: 2,
        finalizadas: 8,
        urgentes: 1,
        tecnicosDisponibles: 2,
        tecnicosActivos: 3,
      );

  @override
  Future<List<ResumenSolicitud>> bandeja({EstadoSolicitud? estado, String? texto}) async => [
        for (final s in fixture('bandeja_admin') as List) ResumenSolicitud.fromJson(s as Map<String, dynamic>),
      ];

  @override
  Future<List<TecnicoRecomendado>> recomendados(int solicitudId) async => [
        for (final t in fixture('tecnicos_recomendados') as List) TecnicoRecomendado.fromJson(t as Map<String, dynamic>),
      ];

  Solicitud get _enRevision => Solicitud.fromJson(fixture('solicitud_en_revision_admin') as Map<String, dynamic>);

  @override
  Future<Solicitud> asignar(int solicitudId, {required int tecnicoId, required DateTime inicio, required DateTime fin}) async {
    llamadas.add('asignar:$tecnicoId:${fin.difference(inicio).inHours}h');
    return _enRevision;
  }

  @override
  Future<Solicitud> guardarCotizacion(int solicitudId, List<Partida> partidas) async {
    llamadas.add('cotizacion:${partidas.map((p) => '${p.concepto}=${p.importe.round()}').join('|')}');
    return _enRevision;
  }

  @override
  Future<Solicitud> enviarCotizacion(int solicitudId) async {
    llamadas.add('enviar:$solicitudId');
    return _enRevision;
  }

  @override
  Future<List<Especialidad>> especialidades() async =>
      const [Especialidad('ELECTRICO', 'Eléctrico'), Especialidad('REFRIGERACION', 'Refrigeración')];

  @override
  Future<List<TecnicoCuenta>> tecnicos() async => [
        for (final t in fixture('tecnicos_admin') as List) TecnicoCuenta.fromJson(t as Map<String, dynamic>),
      ];

  @override
  Future<TecnicoCuenta> crearTecnico({
    required String nombre,
    required String correo,
    required String password,
    required List<String> especialidades,
    String? telefono,
  }) async {
    llamadas.add('tecnico:$correo:${especialidades.join(',')}');
    return (await tecnicos()).first;
  }
}

class FakeTecnicoRepository extends TecnicoRepository {
  FakeTecnicoRepository() : super(Dio());

  final llamadas = <String>[];
  bool _disponible = true;

  @override
  Future<List<ResumenSolicitud>> ordenes({bool finalizadas = false}) async => finalizadas
      ? const []
      : [for (final o in fixture('ordenes_tecnico') as List) ResumenSolicitud.fromJson(o as Map<String, dynamic>)];

  @override
  Future<bool> disponible() async => _disponible;

  @override
  Future<void> cambiarDisponibilidad(bool disponible) async {
    _disponible = disponible;
    llamadas.add('disponible:$disponible');
  }

  Solicitud get _orden => Solicitud.fromJson(fixture('orden_en_camino_tecnico') as Map<String, dynamic>);

  @override
  Future<Solicitud> registrarLlegada(int id) async => _orden;

  @override
  Future<Solicitud> guardarRegistro(int id, {String? diagnosticoFinal, String? notas}) async {
    llamadas.add('registro:${diagnosticoFinal ?? ''}');
    return _orden;
  }

  @override
  Future<Solicitud> subirEvidencias(int id, List<FotoSeleccionada> fotos) async {
    llamadas.add('evidencias:${fotos.length}');
    return _orden;
  }

  @override
  Future<Solicitud> guardarPiezas(int id, List<({int piezaId, int cantidad})> piezas) async {
    llamadas.add('piezas:${piezas.map((p) => '${p.piezaId}x${p.cantidad}').join(',')}');
    return _orden;
  }

  @override
  Future<Solicitud> cerrar(int id) async {
    llamadas.add('cerrar:$id');
    return _orden;
  }

  @override
  Future<List<Pieza>> catalogo() async => [for (final p in fixture('piezas') as List) Pieza.fromJson(p as Map<String, dynamic>)];
}

Widget appDePrueba({
  FakeTokenStorage? tokens,
  FakeAuthRepository? auth,
  FakeEquiposRepository? equipos,
  FakeDiagnosticosRepository? diagnosticos,
  FakeSolicitudesRepository? solicitudes,
  FakeAdminRepository? admin,
  FakeTecnicoRepository? tecnico,
}) =>
    ProviderScope(
      overrides: [
        tecnicoRepositoryProvider.overrideWithValue(tecnico ?? FakeTecnicoRepository()),
        solicitudesRepositoryProvider.overrideWithValue(solicitudes ?? FakeSolicitudesRepository()),
        adminRepositoryProvider.overrideWithValue(admin ?? FakeAdminRepository()),
        tokenStorageProvider.overrideWithValue(tokens ?? FakeTokenStorage()),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        equiposRepositoryProvider.overrideWithValue(equipos ?? FakeEquiposRepository()),
        diagnosticosRepositoryProvider.overrideWithValue(diagnosticos ?? FakeDiagnosticosRepository()),
        elegirFotoProvider.overrideWithValue(
          (_) async => const FotoSeleccionada(bytes: pngDemo, nombre: 'compresor.png', mimeType: 'image/png'),
        ),
      ],
      child: const AcMasterApp(),
    );

import 'package:ac_master/app.dart';
import 'package:ac_master/core/api/api_exception.dart';
import 'package:ac_master/core/session/token_storage.dart';
import 'package:ac_master/data/auth_repository.dart';
import 'package:ac_master/data/diagnosticos_repository.dart';
import 'package:ac_master/data/equipos_repository.dart';
import 'package:ac_master/features/diagnostico/selector_fotos.dart';
import 'package:ac_master/models/diagnostico.dart';
import 'package:ac_master/models/equipo.dart';
import 'package:ac_master/models/usuario.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const clienteDemo = Usuario(id: 3, nombre: 'Rafael Báez', correo: 'cliente@acmaster.mx', rol: Rol.cliente);
const tecnicoDemo = Usuario(id: 2, nombre: 'Mariela Ríos', correo: 'tecnico@acmaster.mx', rol: Rol.tecnico);

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

Widget appDePrueba({
  FakeTokenStorage? tokens,
  FakeAuthRepository? auth,
  FakeEquiposRepository? equipos,
  FakeDiagnosticosRepository? diagnosticos,
}) =>
    ProviderScope(
      overrides: [
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

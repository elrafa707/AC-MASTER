import 'package:ac_master/core/api/api_exception.dart';
import 'package:ac_master/models/usuario.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final opciones = RequestOptions(path: '/auth/register');

  test('traduce el error estándar del backend con sus detalles por campo', () {
    final e = ApiException.desdeDio(
      DioException(
        requestOptions: opciones,
        response: Response(
          requestOptions: opciones,
          statusCode: 400,
          data: {
            'error': {
              'codigo': 'VALIDACION',
              'mensaje': 'Revisa los datos enviados',
              'detalles': [
                {'campo': 'correo', 'mensaje': 'Correo electrónico inválido'},
              ],
            },
          },
        ),
      ),
    );

    expect(e.status, 400);
    expect(e.codigo, 'VALIDACION');
    expect(e.detalles, {'correo': 'Correo electrónico inválido'});
  });

  test('reconoce cuando no hay conexión con el servidor', () {
    final e = ApiException.desdeDio(DioException.connectionError(requestOptions: opciones, reason: 'refused'));
    expect(e.sinConexion, isTrue);
  });

  test('Usuario.fromJson interpreta el rol de la API', () {
    final u = Usuario.fromJson({
      'id': 1,
      'nombre': 'Mariela Ríos',
      'correo': 'tecnico@acmaster.mx',
      'telefono': null,
      'rol': 'tecnico',
    });
    expect(u.rol, Rol.tecnico);
    expect(u.primerNombre, 'Mariela');
  });
}

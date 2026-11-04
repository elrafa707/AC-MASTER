// Pruebas de integración de equipos, diagnósticos, autoayuda e historial (RF-02, RF-03, RF-08).
// Requieren SQL Server corriendo. Usan el asistente simulado, así que no consumen la API de Anthropic.
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import request from 'supertest';

import { DOMINIO_PRUEBAS, PNG_1X1, crearApp, db, limpiarDatosDePrueba } from './helpers.js';

const app = crearApp();
const sufijo = Date.now();
const serie = `TST-${sufijo}`;

let tokenCliente;
let tokenOtroCliente;
let tokenTecnico;
let equipoId;

const auth = (token) => ({ Authorization: `Bearer ${token}` });

async function registrar(nombre) {
  const res = await request(app)
    .post('/api/v1/auth/register')
    .send({ nombre, correo: `${nombre.toLowerCase().replace(/\s/g, '.')}.${sufijo}${DOMINIO_PRUEBAS}`, password: 'Secreta123' })
    .expect(201);
  return res.body.token;
}

const RESPUESTAS_FILTROS = {
  modo_frio: 'Sí',
  sale_aire: 'Sí, pero muy débil',
  ventilador_exterior: 'Sí',
  hielo_tuberia: 'No',
  ultima_limpieza_filtros: 'Hace más de 6 meses',
  desde_cuando: 'Esta semana',
};

function enviarDiagnostico(token, { sintomas = ['NO_ENFRIA'], respuestas = RESPUESTAS_FILTROS, fotos = [], equipo = equipoId } = {}) {
  const peticion = request(app)
    .post('/api/v1/diagnosticos')
    .set(auth(token))
    .field('equipoId', String(equipo))
    .field('sintomas', JSON.stringify(sintomas))
    .field('respuestas', JSON.stringify(respuestas))
    .field('descripcion', 'Desde el lunes casi no enfría la recámara.');
  for (const [i, foto] of fotos.entries()) peticion.attach('fotos', foto.buffer, { filename: `foto${i}.${foto.ext}`, contentType: foto.tipo });
  return peticion;
}

describe('Equipos, diagnóstico e historial', () => {
  before(async () => {
    tokenCliente = await registrar('Cliente Diagnostico');
    tokenOtroCliente = await registrar('Otro Cliente');
    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ correo: 'tecnico@acmaster.mx', password: 'AcMaster2026!' })
      .expect(200);
    tokenTecnico = login.body.token;
  });

  after(async () => {
    await limpiarDatosDePrueba();
    await db.cerrarPool();
  });

  describe('Equipos', () => {
    test('registra un equipo y crea el registro de instalación', async () => {
      const res = await request(app)
        .post('/api/v1/equipos')
        .set(auth(tokenCliente))
        .send({
          numeroSerie: serie.toLowerCase(),
          marca: 'Mirage',
          modelo: 'MRG123',
          capacidadBTU: 12000,
          refrigerante: 'R-410A',
          ubicacion: 'Recámara',
          fechaInstalacion: '2021-05-10',
        })
        .expect(201);

      equipoId = res.body.id;
      assert.equal(res.body.numeroSerie, serie, 'el número de serie se guarda en mayúsculas');
      assert.equal(res.body.tipo, 'Minisplit');
      assert.equal(res.body.historial.length, 1);
      assert.equal(res.body.historial[0].tipo, 'INSTALACION');
    });

    test('rechaza un número de serie repetido', async () => {
      const res = await request(app)
        .post('/api/v1/equipos')
        .set(auth(tokenOtroCliente))
        .send({ numeroSerie: serie, marca: 'LG', modelo: 'X' })
        .expect(409);
      assert.equal(res.body.error.codigo, 'SERIE_REGISTRADA');
    });

    test('valida los datos del equipo', async () => {
      const res = await request(app)
        .post('/api/v1/equipos')
        .set(auth(tokenCliente))
        .send({ numeroSerie: 'a b', marca: '', modelo: 'X', capacidadBTU: 10, fechaInstalacion: '2999-01-01' })
        .expect(400);
      const campos = [...new Set(res.body.error.detalles.map((d) => d.campo))].sort();
      assert.deepEqual(campos, ['capacidadBTU', 'fechaInstalacion', 'marca', 'numeroSerie']);
    });

    test('cada cliente lista solo sus equipos', async () => {
      const propios = await request(app).get('/api/v1/equipos').set(auth(tokenCliente)).expect(200);
      assert.equal(propios.body.length, 1);
      const ajenos = await request(app).get('/api/v1/equipos').set(auth(tokenOtroCliente)).expect(200);
      assert.equal(ajenos.body.length, 0);
    });

    test('el técnico no registra equipos', async () => {
      await request(app).post('/api/v1/equipos').set(auth(tokenTecnico)).send({ numeroSerie: 'ABCD1', marca: 'LG', modelo: 'X' }).expect(403);
    });
  });

  describe('Cuestionario', () => {
    test('devuelve las preguntas de los síntomas elegidos más las generales', async () => {
      const res = await request(app)
        .get('/api/v1/diagnosticos/cuestionario?sintomas=NO_ENFRIA,RUIDO')
        .set(auth(tokenCliente))
        .expect(200);
      const ids = res.body.preguntas.map((p) => p.id);
      assert.ok(ids.includes('hielo_tuberia'));
      assert.ok(ids.includes('tipo_ruido'));
      assert.ok(ids.includes('ultima_limpieza_filtros'));
      assert.equal(res.body.sintomas.length, 5);
    });

    test('rechaza síntomas desconocidos', async () => {
      await request(app).get('/api/v1/diagnosticos/cuestionario?sintomas=EXPLOTA').set(auth(tokenCliente)).expect(400);
    });
  });

  describe('Diagnóstico y autoayuda', () => {
    let diagnosticoId;

    test('diagnostica con foto, guarda la foto y registra la predicción en el historial', async () => {
      const res = await enviarDiagnostico(tokenCliente, { fotos: [{ buffer: PNG_1X1, ext: 'png', tipo: 'image/png' }] }).expect(201);

      diagnosticoId = res.body.id;
      assert.equal(res.body.falla, 'Filtros saturados de polvo');
      assert.equal(res.body.requiereTecnico, false);
      assert.ok(res.body.pasosAutoayuda.length > 0);
      assert.equal(res.body.especialidad.clave, 'MANTENIMIENTO');
      assert.equal(res.body.resultado, 'PENDIENTE');
      assert.equal(res.body.modelo, 'simulado-reglas');
      assert.equal(res.body.fotos.length, 1);
      assert.equal(res.body.respuestas[0].respuesta, 'Sí');

      const ficha = await request(app).get(`/api/v1/equipos/${equipoId}`).set(auth(tokenCliente)).expect(200);
      assert.equal(ficha.body.historial[0].tipo, 'PREDICCION');
    });

    test('sirve la foto solo a quien tiene permiso', async () => {
      const diag = await request(app).get(`/api/v1/diagnosticos/${diagnosticoId}`).set(auth(tokenCliente)).expect(200);
      const url = diag.body.fotos[0].url;

      const foto = await request(app).get(url).set(auth(tokenCliente)).expect(200);
      assert.equal(foto.headers['content-type'], 'image/png');
      assert.ok(Buffer.from(foto.body).equals(PNG_1X1));

      await request(app).get(url).set(auth(tokenOtroCliente)).expect(404);
      // Un técnico sin la orden asignada no la ve.
      await request(app).get(url).set(auth(tokenTecnico)).expect(404);
      await request(app).get(url).expect(401);
    });

    test('otro cliente no puede ver el diagnóstico', async () => {
      await request(app).get(`/api/v1/diagnosticos/${diagnosticoId}`).set(auth(tokenOtroCliente)).expect(404);
    });

    test('al confirmar la autoayuda queda resuelto y en el historial', async () => {
      const res = await request(app)
        .post(`/api/v1/diagnosticos/${diagnosticoId}/autoayuda`)
        .set(auth(tokenCliente))
        .send({ resuelto: true })
        .expect(200);
      assert.equal(res.body.resultado, 'RESUELTO_AUTOAYUDA');

      const ficha = await request(app).get(`/api/v1/equipos/${equipoId}`).set(auth(tokenCliente)).expect(200);
      assert.equal(ficha.body.historial[0].tipo, 'AUTOAYUDA');

      const otraVez = await request(app)
        .post(`/api/v1/diagnosticos/${diagnosticoId}/autoayuda`)
        .set(auth(tokenCliente))
        .send({ resuelto: true })
        .expect(409);
      assert.equal(otraVez.body.error.codigo, 'DIAGNOSTICO_CERRADO');
    });

    test('si la autoayuda no funcionó, el diagnóstico sigue pendiente', async () => {
      const diag = await enviarDiagnostico(tokenCliente).expect(201);
      const res = await request(app)
        .post(`/api/v1/diagnosticos/${diag.body.id}/autoayuda`)
        .set(auth(tokenCliente))
        .send({ resuelto: false })
        .expect(200);
      assert.equal(res.body.resultado, 'PENDIENTE');
    });

    test('una señal de peligro exige técnico aunque haya otro síntoma leve', async () => {
      const res = await enviarDiagnostico(tokenCliente, {
        sintomas: ['RUIDO', 'MAL_OLOR'],
        respuestas: {
          unidad_ruido: 'Interior',
          tipo_ruido: 'Crujidos al encender o apagar',
          tipo_olor: 'A quemado o plástico caliente',
          ultima_limpieza_filtros: 'Hace menos de 3 meses',
          desde_cuando: 'Hoy',
        },
      }).expect(201);
      assert.equal(res.body.requiereTecnico, true);
      assert.equal(res.body.prioridad, 'alta');
      assert.ok(res.body.advertencia);
    });

    test('exige responder todo el cuestionario', async () => {
      const res = await enviarDiagnostico(tokenCliente, { respuestas: { modo_frio: 'Sí' } }).expect(400);
      assert.equal(res.body.error.codigo, 'CUESTIONARIO_INCOMPLETO');
    });

    test('rechaza archivos que no son imágenes aunque digan serlo', async () => {
      const falso = Buffer.from('esto no es una imagen, solo texto disfrazado');
      const res = await enviarDiagnostico(tokenCliente, { fotos: [{ buffer: falso, ext: 'jpg', tipo: 'image/jpeg' }] }).expect(400);
      assert.equal(res.body.error.codigo, 'ARCHIVO_INVALIDO');
    });

    test('rechaza más de 3 fotos', async () => {
      const foto = { buffer: PNG_1X1, ext: 'png', tipo: 'image/png' };
      await enviarDiagnostico(tokenCliente, { fotos: [foto, foto, foto, foto] }).expect(400);
    });

    test('no permite diagnosticar el equipo de otro cliente', async () => {
      const res = await enviarDiagnostico(tokenOtroCliente).expect(404);
      assert.equal(res.body.error.codigo, 'EQUIPO_NO_ENCONTRADO');
    });
  });

  describe('Ficha por número de serie (RF-08)', () => {
    test('el técnico consulta cualquier equipo con su historial cronológico', async () => {
      const res = await request(app).get(`/api/v1/equipos/serie/${serie}`).set(auth(tokenTecnico)).expect(200);
      assert.equal(res.body.id, equipoId);
      assert.equal(res.body.clienteNombre, 'Cliente Diagnostico');
      const fechas = res.body.historial.map((h) => new Date(h.fecha).getTime());
      assert.deepEqual(fechas, [...fechas].sort((a, b) => b - a), 'del más reciente al más antiguo');
      assert.equal(res.body.historial.at(-1).tipo, 'INSTALACION');
    });

    test('un cliente ajeno recibe 404 aunque el número exista', async () => {
      await request(app).get(`/api/v1/equipos/serie/${serie}`).set(auth(tokenOtroCliente)).expect(404);
    });
  });
});

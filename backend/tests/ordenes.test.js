// Pruebas de integración de la etapa 4: orden de trabajo del técnico, cierre y calificación (RF-06, RF-07).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import request from 'supertest';

import { DOMINIO_PRUEBAS, PNG_1X1, crearApp, db, iniciarSesion, limpiarDatosDePrueba, registrarCliente } from './helpers.js';

const app = crearApp();
const sufijo = Date.now();
const auth = (token) => ({ Authorization: `Bearer ${token}` });

let cliente;
let otroCliente;
let admin;
let tecnico;
let otroTecnico;
let tecnicoId;
let equipoId;
let direccionId;

const RESPUESTAS = {
  modo_frio: 'Sí',
  sale_aire: 'Sí, con fuerza',
  ventilador_exterior: 'No',
  hielo_tuberia: 'No',
  ultima_limpieza_filtros: 'Hace menos de 3 meses',
  desde_cuando: 'Hoy',
};

/** Lleva una solicitud hasta EN_CAMINO con el técnico de prueba y devuelve su detalle. */
async function ordenEnCamino() {
  const diag = await request(app)
    .post('/api/v1/diagnosticos')
    .set(auth(cliente))
    .field('equipoId', String(equipoId))
    .field('sintomas', JSON.stringify(['NO_ENFRIA']))
    .field('respuestas', JSON.stringify(RESPUESTAS))
    .attach('fotos', PNG_1X1, { filename: 'compresor.png', contentType: 'image/png' })
    .expect(201);
  const s = await request(app).post('/api/v1/solicitudes').set(auth(cliente)).send({ diagnosticoId: diag.body.id, direccionId }).expect(201);
  const inicio = new Date(Date.now() + 3 * 3600_000);
  await request(app)
    .post(`/api/v1/admin/solicitudes/${s.body.id}/asignar`)
    .set(auth(admin))
    .send({ tecnicoId, ventanaInicio: inicio.toISOString(), ventanaFin: new Date(inicio.getTime() + 7200_000).toISOString() })
    .expect(200);
  await request(app).post(`/api/v1/admin/solicitudes/${s.body.id}/cotizacion/enviar`).set(auth(admin)).expect(200);
  const aprobada = await request(app).post(`/api/v1/solicitudes/${s.body.id}/cotizacion/aprobar`).set(auth(cliente)).expect(200);
  return aprobada.body;
}

const subirEvidencia = (id, token = tecnico) =>
  request(app)
    .post(`/api/v1/tecnico/ordenes/${id}/evidencias`)
    .set(auth(token))
    .attach('fotos', PNG_1X1, { filename: 'antes.png', contentType: 'image/png' })
    .attach('fotos', PNG_1X1, { filename: 'despues.png', contentType: 'image/png' });

describe('Orden de trabajo, cierre y calificación', () => {
  before(async () => {
    cliente = await registrarCliente(request, app, 'Cliente Orden', sufijo);
    otroCliente = await registrarCliente(request, app, 'Cliente Curioso', sufijo);
    admin = await iniciarSesion(request, app, 'admin@acmaster.mx');
    for (const [nombre, clave] of [['Técnico Eléctrico', 'ELECTRICO'], ['Técnico Ajeno', 'DRENAJE']]) {
      const res = await request(app)
        .post('/api/v1/admin/tecnicos')
        .set(auth(admin))
        .send({ nombre, correo: `${clave.toLowerCase()}.${sufijo}${DOMINIO_PRUEBAS}`, password: 'Tecnico2026', especialidades: [clave] })
        .expect(201);
      if (clave === 'ELECTRICO') tecnicoId = res.body.id;
    }
    tecnico = await iniciarSesion(request, app, `electrico.${sufijo}${DOMINIO_PRUEBAS}`, 'Tecnico2026');
    otroTecnico = await iniciarSesion(request, app, `drenaje.${sufijo}${DOMINIO_PRUEBAS}`, 'Tecnico2026');

    const dir = await request(app)
      .post('/api/v1/me/direcciones')
      .set(auth(cliente))
      .send({ alias: 'Casa', calle: 'Morelos 300', colonia: 'Centro', ciudad: 'Monterrey' })
      .expect(201);
    direccionId = dir.body.id;
    const eq = await request(app)
      .post('/api/v1/equipos')
      .set(auth(cliente))
      .send({ numeroSerie: `ORD-${sufijo}`, marca: 'Carrier', modelo: 'XPower' })
      .expect(201);
    equipoId = eq.body.id;
  });

  after(async () => {
    await limpiarDatosDePrueba();
    await db.cerrarPool();
  });

  test('flujo completo de la orden: llegada, registro, evidencias, piezas, cierre e historial', async () => {
    const s = await ordenEnCamino();

    const activas = await request(app).get('/api/v1/tecnico/ordenes').set(auth(tecnico)).expect(200);
    const fila = activas.body.find((o) => o.id === s.id);
    assert.match(fila.ordenFolio, /^ORD-\d{6}$/);

    const detalle = await request(app).get(`/api/v1/tecnico/ordenes/${s.id}`).set(auth(tecnico)).expect(200);
    assert.ok(detalle.body.diagnostico.herramientas.length, 'el técnico ve el kit sugerido (RF-06)');
    assert.equal(detalle.body.cliente.nombre, 'Cliente Orden');
    const fotoCliente = detalle.body.diagnostico.fotos[0].url;
    await request(app).get(fotoCliente).set(auth(tecnico)).expect(200);
    await request(app).get(fotoCliente).set(auth(otroTecnico)).expect(404);

    const incompleta = await request(app).post(`/api/v1/tecnico/ordenes/${s.id}/cerrar`).set(auth(tecnico)).expect(400);
    assert.equal(incompleta.body.error.codigo, 'ORDEN_INCOMPLETA');
    assert.match(incompleta.body.error.mensaje, /diagnóstico final y al menos una foto/);

    const llegada = await request(app).post(`/api/v1/tecnico/ordenes/${s.id}/llegada`).set(auth(tecnico)).expect(200);
    assert.ok(llegada.body.orden.fechaLlegada);
    assert.equal(llegada.body.eventos.at(-1).titulo, 'El técnico llegó');
    await request(app).post(`/api/v1/tecnico/ordenes/${s.id}/llegada`).set(auth(tecnico)).expect(200);
    const eventos = (await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(cliente))).body.eventos;
    assert.equal(eventos.filter((e) => e.titulo === 'El técnico llegó').length, 1, 'la llegada se registra una sola vez');

    const vistaCliente = await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(cliente)).expect(200);
    assert.equal(vistaCliente.body.orden, null, 'el cliente ve el registro del técnico hasta el cierre');
    assert.ok(vistaCliente.body.tecnico.telefono !== undefined);

    await request(app)
      .patch(`/api/v1/tecnico/ordenes/${s.id}`)
      .set(auth(tecnico))
      .send({ diagnosticoFinal: 'Capacitor del ventilador exterior inflado; se reemplazó y se midió el consumo.', notas: 'Revisar en 6 meses' })
      .expect(200);

    const conFotos = await subirEvidencia(s.id).expect(201);
    assert.equal(conFotos.body.orden.evidencias.length, 2);
    const sinUna = await request(app)
      .delete(`/api/v1/tecnico/ordenes/${s.id}/evidencias/${conFotos.body.orden.evidencias[0].id}`)
      .set(auth(tecnico))
      .expect(200);
    assert.equal(sinUna.body.orden.evidencias.length, 1);

    const catalogo = (await request(app).get('/api/v1/piezas').set(auth(tecnico)).expect(200)).body;
    const capacitor = catalogo.find((p) => p.codigo === 'REP-CAP-FAN');
    const cinta = catalogo.find((p) => p.codigo === 'INS-CINTA');
    const conPiezas = await request(app)
      .put(`/api/v1/tecnico/ordenes/${s.id}/piezas`)
      .set(auth(tecnico))
      .send({ piezas: [{ piezaId: capacitor.id, cantidad: 1 }, { piezaId: cinta.id, cantidad: 2 }] })
      .expect(200);
    assert.equal(conPiezas.body.orden.totalPiezas, capacitor.precioUnitario + 2 * cinta.precioUnitario);

    const invalida = await request(app)
      .put(`/api/v1/tecnico/ordenes/${s.id}/piezas`)
      .set(auth(tecnico))
      .send({ piezas: [{ piezaId: capacitor.id, cantidad: 1 }, { piezaId: 999999, cantidad: 1 }] })
      .expect(400);
    assert.equal(invalida.body.error.codigo, 'PIEZA_INVALIDA');
    const tras = await request(app).get(`/api/v1/tecnico/ordenes/${s.id}`).set(auth(tecnico)).expect(200);
    assert.equal(tras.body.orden.piezas.length, 2, 'un error no borra las piezas que ya estaban');

    await request(app).post(`/api/v1/tecnico/ordenes/${s.id}/cerrar`).set(auth(otroTecnico)).expect(404);
    const cerrada = await request(app).post(`/api/v1/tecnico/ordenes/${s.id}/cerrar`).set(auth(tecnico)).expect(200);
    assert.equal(cerrada.body.estado, 'FINALIZADO');
    assert.ok(cerrada.body.orden.fechaCierre);

    const final = await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(cliente)).expect(200);
    assert.equal(final.body.orden.piezas.length, 2, 'el cliente ve el resumen al terminar');
    await request(app).get(final.body.orden.evidencias[0].url).set(auth(cliente)).expect(200);
    await request(app).get(final.body.orden.evidencias[0].url).set(auth(otroCliente)).expect(404);

    const ficha = await request(app).get(`/api/v1/equipos/${equipoId}`).set(auth(cliente)).expect(200);
    const registro = ficha.body.historial[0];
    assert.equal(registro.tipo, 'REPARACION');
    assert.equal(registro.tecnicoNombre, 'Técnico Eléctrico');
    assert.match(registro.descripcion, /Capacitor de ventilador/);

    await request(app).patch(`/api/v1/tecnico/ordenes/${s.id}`).set(auth(tecnico)).send({ notas: 'tarde' }).expect(409);

    const finalizadas = await request(app).get('/api/v1/tecnico/ordenes?vista=finalizadas').set(auth(tecnico)).expect(200);
    assert.ok(finalizadas.body.some((o) => o.id === s.id));
  });

  test('calificación: una sola vez, de 1 a 5, y actualiza el promedio del técnico', async () => {
    const s = await ordenEnCamino();
    await request(app).post(`/api/v1/solicitudes/${s.id}/calificar`).set(auth(cliente)).send({ calificacion: 5 }).expect(409);

    await request(app).patch(`/api/v1/tecnico/ordenes/${s.id}`).set(auth(tecnico)).send({ diagnosticoFinal: 'Limpieza profunda del serpentín.' }).expect(200);
    await subirEvidencia(s.id).expect(201);
    await request(app).post(`/api/v1/tecnico/ordenes/${s.id}/cerrar`).set(auth(tecnico)).expect(200);

    await request(app).post(`/api/v1/solicitudes/${s.id}/calificar`).set(auth(cliente)).send({ calificacion: 0 }).expect(400);
    await request(app).post(`/api/v1/solicitudes/${s.id}/calificar`).set(auth(otroCliente)).send({ calificacion: 1 }).expect(404);
    const res = await request(app)
      .post(`/api/v1/solicitudes/${s.id}/calificar`)
      .set(auth(cliente))
      .send({ calificacion: 4, comentario: 'Puntual y limpio' })
      .expect(200);
    assert.equal(res.body.calificacion, 4);
    await request(app).post(`/api/v1/solicitudes/${s.id}/calificar`).set(auth(cliente)).send({ calificacion: 5 }).expect(409);

    const tecnicos = await request(app).get('/api/v1/admin/tecnicos').set(auth(admin)).expect(200);
    assert.equal(tecnicos.body.find((t) => t.id === tecnicoId).calificacion, 4);

    const ficha = await request(app).get(`/api/v1/equipos/${equipoId}`).set(auth(cliente)).expect(200);
    assert.equal(ficha.body.historial[0].tipo, 'MANTENIMIENTO', 'una limpieza queda como mantenimiento');
  });

  test('disponibilidad del técnico', async () => {
    await request(app).put('/api/v1/tecnico/disponibilidad').set(auth(tecnico)).send({ disponible: false }).expect(200);
    const res = await request(app).get('/api/v1/tecnico/disponibilidad').set(auth(tecnico)).expect(200);
    assert.equal(res.body.disponible, false);
    await request(app).put('/api/v1/tecnico/disponibilidad').set(auth(cliente)).send({ disponible: true }).expect(403);
  });

  test('catálogo de piezas: alta, código único, precio y baja', async () => {
    const nueva = await request(app)
      .post('/api/v1/admin/piezas')
      .set(auth(admin))
      .send({ codigo: `tst-${sufijo}`.slice(0, 30), nombre: 'Válvula de servicio 1/4', precioUnitario: 280 })
      .expect(201);
    assert.equal(nueva.body.codigo, `TST-${sufijo}`.slice(0, 30));
    await request(app).post('/api/v1/admin/piezas').set(auth(admin)).send({ codigo: nueva.body.codigo, nombre: 'Otra', precioUnitario: 1 }).expect(409);

    const editada = await request(app).patch(`/api/v1/admin/piezas/${nueva.body.id}`).set(auth(admin)).send({ precioUnitario: 310 }).expect(200);
    assert.equal(editada.body.precioUnitario, 310);

    await request(app).patch(`/api/v1/admin/piezas/${nueva.body.id}`).set(auth(admin)).send({ activo: false }).expect(200);
    const catalogo = await request(app).get('/api/v1/piezas').set(auth(tecnico)).expect(200);
    assert.ok(!catalogo.body.some((p) => p.id === nueva.body.id), 'las piezas dadas de baja no se ofrecen al técnico');
    await request(app).post('/api/v1/admin/piezas').set(auth(tecnico)).send({ codigo: 'X-1', nombre: 'X', precioUnitario: 1 }).expect(403);
  });
});

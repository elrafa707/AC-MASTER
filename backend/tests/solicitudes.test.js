// Pruebas de integración de la etapa 3: solicitudes, cotización, asignación y línea de tiempo (RF-04, RF-05).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import request from 'supertest';

import { DOMINIO_PRUEBAS, crearApp, db, iniciarSesion, limpiarDatosDePrueba, registrarCliente } from './helpers.js';

const app = crearApp();
const sufijo = Date.now();
const auth = (token) => ({ Authorization: `Bearer ${token}` });

let cliente;
let otroCliente;
let admin;
let tecnicoId;
let tecnicoToken;
let direccionId;
let equipoId;

const RESPUESTAS_FUGA = {
  modo_frio: 'Sí',
  sale_aire: 'Sí, con fuerza',
  ventilador_exterior: 'Sí',
  hielo_tuberia: 'Sí',
  ultima_limpieza_filtros: 'Hace menos de 3 meses',
  desde_cuando: 'Esta semana',
};

async function nuevoDiagnostico(token = cliente, respuestas = RESPUESTAS_FUGA) {
  const res = await request(app)
    .post('/api/v1/diagnosticos')
    .set(auth(token))
    .field('equipoId', String(equipoId))
    .field('sintomas', JSON.stringify(['NO_ENFRIA']))
    .field('respuestas', JSON.stringify(respuestas))
    .expect(201);
  return res.body;
}

async function nuevaSolicitud() {
  const diag = await nuevoDiagnostico();
  const res = await request(app).post('/api/v1/solicitudes').set(auth(cliente)).send({ diagnosticoId: diag.id, direccionId }).expect(201);
  return res.body;
}

function ventana(horasDesdeAhora = 24, duracion = 2) {
  const inicio = new Date(Date.now() + horasDesdeAhora * 3600_000);
  return { ventanaInicio: inicio.toISOString(), ventanaFin: new Date(inicio.getTime() + duracion * 3600_000).toISOString() };
}

describe('Solicitudes, cotización y asignación', () => {
  before(async () => {
    cliente = await registrarCliente(request, app, 'Cliente Solicitud', sufijo);
    otroCliente = await registrarCliente(request, app, 'Cliente Ajeno', sufijo);
    admin = await iniciarSesion(request, app, 'admin@acmaster.mx');

    const tec = await request(app)
      .post('/api/v1/admin/tecnicos')
      .set(auth(admin))
      .send({ nombre: 'Técnico Refrigeración', correo: `tec.${sufijo}${DOMINIO_PRUEBAS}`, password: 'Tecnico2026', especialidades: ['REFRIGERACION'] })
      .expect(201);
    tecnicoId = tec.body.id;
    tecnicoToken = await iniciarSesion(request, app, `tec.${sufijo}${DOMINIO_PRUEBAS}`, 'Tecnico2026');

    const dir = await request(app)
      .post('/api/v1/me/direcciones')
      .set(auth(cliente))
      .send({ alias: 'Casa', calle: 'Av. Universidad 100', colonia: 'Centro', ciudad: 'Monterrey', cp: '64000' })
      .expect(201);
    direccionId = dir.body.id;
    assert.equal(dir.body.principal, true, 'la primera dirección queda como principal');

    const eq = await request(app)
      .post('/api/v1/equipos')
      .set(auth(cliente))
      .send({ numeroSerie: `SOL-${sufijo}`, marca: 'LG', modelo: 'DualCool' })
      .expect(201);
    equipoId = eq.body.id;
  });

  after(async () => {
    await limpiarDatosDePrueba();
    await db.cerrarPool();
  });

  test('el cliente crea la solicitud y queda en revisión con cotización automática oculta', async () => {
    const s = await nuevaSolicitud();

    assert.match(s.folio, /^AC-\d{6}$/);
    assert.equal(s.estado, 'EN_REVISION');
    assert.equal(s.pedidaPorCliente, false, 'el asistente sí recomendaba técnico');
    assert.equal(s.cotizacion, null, 'el borrador no se muestra al cliente');
    assert.equal(s.tecnico, null);
    assert.equal(s.eventos[0].titulo, 'Solicitud recibida');
    assert.equal(s.diagnostico.resultado, 'ESCALADO');

    const lista = await request(app).get('/api/v1/solicitudes').set(auth(cliente)).expect(200);
    assert.equal(lista.body[0].id, s.id);
  });

  test('no se puede pedir dos veces técnico para el mismo diagnóstico ni usar una dirección ajena', async () => {
    const diag = await nuevoDiagnostico();
    await request(app).post('/api/v1/solicitudes').set(auth(cliente)).send({ diagnosticoId: diag.id, direccionId }).expect(201);
    const repetida = await request(app).post('/api/v1/solicitudes').set(auth(cliente)).send({ diagnosticoId: diag.id, direccionId }).expect(409);
    assert.equal(repetida.body.error.codigo, 'DIAGNOSTICO_CERRADO');

    const otroDiag = await nuevoDiagnostico();
    const ajena = await request(app).post('/api/v1/me/direcciones').set(auth(otroCliente)).send({ alias: 'Otra', calle: 'Calle 1', colonia: 'Mitras', ciudad: 'Monterrey' })
      .expect(201);
    const res = await request(app)
      .post('/api/v1/solicitudes')
      .set(auth(cliente))
      .send({ diagnosticoId: otroDiag.id, direccionId: ajena.body.id })
      .expect(400);
    assert.equal(res.body.error.codigo, 'DIRECCION_INVALIDA');
  });

  test('si el asistente sugería autoayuda, la solicitud queda marcada como pedida por el cliente', async () => {
    const diag = await nuevoDiagnostico(cliente, { ...RESPUESTAS_FUGA, hielo_tuberia: 'No', ultima_limpieza_filtros: 'Hace más de 6 meses' });
    assert.equal(diag.requiereTecnico, false);
    const res = await request(app).post('/api/v1/solicitudes').set(auth(cliente)).send({ diagnosticoId: diag.id, direccionId }).expect(201);
    assert.equal(res.body.pedidaPorCliente, true);
  });

  test('flujo completo: ranking, asignación, cotización, aprobación y orden de trabajo', async () => {
    const s = await nuevaSolicitud();

    const bandeja = await request(app).get('/api/v1/admin/solicitudes?estado=EN_REVISION').set(auth(admin)).expect(200);
    assert.ok(bandeja.body.some((x) => x.id === s.id));

    const detalleAdmin = await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(admin)).expect(200);
    assert.equal(detalleAdmin.body.cotizacion.estado, 'BORRADOR');
    assert.equal(detalleAdmin.body.cotizacion.generadaAuto, true);
    assert.equal(detalleAdmin.body.cotizacion.partidas[0].precioUnitario, 350);

    const ranking = await request(app).get(`/api/v1/admin/solicitudes/${s.id}/tecnicos-recomendados`).set(auth(admin)).expect(200);
    const propio = ranking.body.find((t) => t.id === tecnicoId);
    assert.ok(propio.tieneEspecialidad, 'la falla predicha es de refrigeración');
    assert.ok(propio.razones.includes('Tiene la especialidad de la falla'));
    const sinEspecialidad = ranking.body.filter((t) => !t.tieneEspecialidad && t.disponible && t.serviciosActivos === propio.serviciosActivos);
    for (const t of sinEspecialidad) assert.ok(propio.puntaje > t.puntaje);

    const sinTecnico = await request(app).post(`/api/v1/admin/solicitudes/${s.id}/cotizacion/enviar`).set(auth(admin)).expect(400);
    assert.equal(sinTecnico.body.error.codigo, 'FALTA_TECNICO');

    await request(app)
      .post(`/api/v1/admin/solicitudes/${s.id}/asignar`)
      .set(auth(admin))
      .send({ tecnicoId, ...ventana(-5) })
      .expect(400);
    await request(app).post(`/api/v1/admin/solicitudes/${s.id}/asignar`).set(auth(admin)).send({ tecnicoId, ...ventana() }).expect(200);

    const antesDeEnviar = await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(cliente)).expect(200);
    assert.equal(antesDeEnviar.body.tecnico, null, 'el cliente aún no ve al técnico');

    const editada = await request(app)
      .put(`/api/v1/admin/solicitudes/${s.id}/cotizacion`)
      .set(auth(admin))
      .send({
        partidas: [
          { concepto: 'Visita de diagnóstico a domicilio', cantidad: 1, precioUnitario: 350 },
          { concepto: 'Carga de refrigerante R-410A', cantidad: 2, precioUnitario: 650 },
        ],
      })
      .expect(200);
    assert.equal(editada.body.cotizacion.total, 1650);
    assert.equal(editada.body.cotizacion.generadaAuto, false);

    const enviada = await request(app).post(`/api/v1/admin/solicitudes/${s.id}/cotizacion/enviar`).set(auth(admin)).expect(200);
    assert.equal(enviada.body.estado, 'COTIZADO');

    const vistaCliente = await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(cliente)).expect(200);
    assert.equal(vistaCliente.body.cotizacion.total, 1650);
    assert.equal(vistaCliente.body.tecnico.nombre, 'Técnico Refrigeración');
    assert.equal(vistaCliente.body.tecnico.telefono, null, 'el teléfono se comparte hasta aprobar');

    await request(app).put(`/api/v1/admin/solicitudes/${s.id}/cotizacion`).set(auth(admin)).send({ partidas: [{ concepto: 'Otra', cantidad: 1, precioUnitario: 1 }] }).expect(409);
    await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(tecnicoToken)).expect(404);

    const aprobada = await request(app).post(`/api/v1/solicitudes/${s.id}/cotizacion/aprobar`).set(auth(cliente)).expect(200);
    assert.equal(aprobada.body.estado, 'EN_CAMINO');
    assert.equal(aprobada.body.cotizacion.estado, 'APROBADA');
    assert.deepEqual(
      aprobada.body.eventos.map((e) => e.titulo),
      ['Solicitud recibida', 'Técnico asignado', 'Cotización enviada', 'Cotización aprobada'],
    );

    const vistaTecnico = await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(tecnicoToken)).expect(200);
    assert.equal(vistaTecnico.body.cliente.nombre, 'Cliente Solicitud');

    const { recordset } = await db.consulta('SELECT Folio FROM dbo.OrdenesTrabajo WHERE SolicitudId = @id', { id: [db.sql.Int, s.id] });
    assert.match(recordset[0].Folio, /^ORD-\d{6}$/);

    const avisosTecnico = await request(app).get('/api/v1/notificaciones').set(auth(tecnicoToken)).expect(200);
    assert.ok(avisosTecnico.body.notificaciones.some((n) => n.titulo.startsWith('Nueva orden ORD-')));

    await request(app).post(`/api/v1/solicitudes/${s.id}/cancelar`).set(auth(cliente)).send({}).expect(409);
  });

  test('el cliente puede rechazar la cotización y queda cancelada con su motivo', async () => {
    const s = await nuevaSolicitud();
    await request(app).post(`/api/v1/admin/solicitudes/${s.id}/asignar`).set(auth(admin)).send({ tecnicoId, ...ventana(48) }).expect(200);
    await request(app).post(`/api/v1/admin/solicitudes/${s.id}/cotizacion/enviar`).set(auth(admin)).expect(200);

    const res = await request(app)
      .post(`/api/v1/solicitudes/${s.id}/cotizacion/rechazar`)
      .set(auth(cliente))
      .send({ motivo: 'Está muy cara' })
      .expect(200);
    assert.equal(res.body.estado, 'CANCELADA');
    assert.equal(res.body.cotizacion.estado, 'RECHAZADA');
    assert.equal(res.body.cotizacion.comentarioCliente, 'Está muy cara');
  });

  test('el cliente cancela una solicitud en revisión y el administrador recibe el aviso', async () => {
    const s = await nuevaSolicitud();
    const res = await request(app).post(`/api/v1/solicitudes/${s.id}/cancelar`).set(auth(cliente)).expect(200);
    assert.equal(res.body.estado, 'CANCELADA');

    const avisos = await request(app).get('/api/v1/notificaciones').set(auth(admin)).expect(200);
    assert.ok(avisos.body.notificaciones.some((n) => n.titulo === `Solicitud cancelada ${s.folio}`));
  });

  test('permisos: otros clientes y técnicos no ven ni administran solicitudes ajenas', async () => {
    const s = await nuevaSolicitud();
    await request(app).get(`/api/v1/solicitudes/${s.id}`).set(auth(otroCliente)).expect(404);
    await request(app).post(`/api/v1/solicitudes/${s.id}/cancelar`).set(auth(otroCliente)).expect(404);
    await request(app).get('/api/v1/admin/solicitudes').set(auth(cliente)).expect(403);
    await request(app).get('/api/v1/admin/solicitudes').set(auth(tecnicoToken)).expect(403);
    await request(app).post(`/api/v1/solicitudes/${s.id}/cotizacion/aprobar`).set(auth(admin)).expect(403);
  });

  test('notificaciones: se marcan como leídas una por una o todas', async () => {
    const inicial = await request(app).get('/api/v1/notificaciones').set(auth(cliente)).expect(200);
    assert.ok(inicial.body.noLeidas > 0);
    await request(app).post(`/api/v1/notificaciones/${inicial.body.notificaciones[0].id}/leida`).set(auth(cliente)).expect(204);
    await request(app).post(`/api/v1/notificaciones/${inicial.body.notificaciones[0].id}/leida`).set(auth(otroCliente)).expect(404);
    await request(app).post('/api/v1/notificaciones/leidas').set(auth(cliente)).expect(204);
    const final = await request(app).get('/api/v1/notificaciones').set(auth(cliente)).expect(200);
    assert.equal(final.body.noLeidas, 0);
  });

  describe('Gestión de usuarios', () => {
    test('valida el alta de técnicos y evita correos repetidos', async () => {
      const sinEsp = await request(app)
        .post('/api/v1/admin/tecnicos')
        .set(auth(admin))
        .send({ nombre: 'Sin Especialidad', correo: `sin.${sufijo}${DOMINIO_PRUEBAS}`, password: 'Tecnico2026', especialidades: [] })
        .expect(400);
      assert.equal(sinEsp.body.error.detalles[0].campo, 'especialidades');

      await request(app)
        .post('/api/v1/admin/tecnicos')
        .set(auth(admin))
        .send({ nombre: 'Repetido', correo: `tec.${sufijo}${DOMINIO_PRUEBAS}`, password: 'Tecnico2026', especialidades: ['ELECTRICO'] })
        .expect(409);
    });

    test('no se desactiva un técnico con servicios activos, pero sí se cambian sus especialidades', async () => {
      const res = await request(app).patch(`/api/v1/admin/tecnicos/${tecnicoId}`).set(auth(admin)).send({ activo: false }).expect(409);
      assert.equal(res.body.error.codigo, 'TECNICO_CON_SERVICIOS');

      const editado = await request(app)
        .patch(`/api/v1/admin/tecnicos/${tecnicoId}`)
        .set(auth(admin))
        .send({ especialidades: ['REFRIGERACION', 'ELECTRICO'] })
        .expect(200);
      assert.deepEqual(editado.body.especialidades.sort(), ['ELECTRICO', 'REFRIGERACION']);
    });

    test('un cliente desactivado ya no puede iniciar sesión', async () => {
      const lista = await request(app).get(`/api/v1/admin/clientes?q=Cliente Ajeno`).set(auth(admin)).expect(200);
      const ajeno = lista.body.find((c) => c.correo.startsWith('cliente.ajeno'));
      await request(app).patch(`/api/v1/admin/clientes/${ajeno.id}`).set(auth(admin)).send({ activo: false }).expect(200);
      await request(app).post('/api/v1/auth/login').send({ correo: ajeno.correo, password: 'Secreta123' }).expect(403);
    });

    test('el resumen del panel cuenta solicitudes y técnicos', async () => {
      const res = await request(app).get('/api/v1/admin/resumen').set(auth(admin)).expect(200);
      assert.ok(res.body.enRevision >= 1);
      assert.ok(res.body.tecnicosActivos >= 2);
    });
  });
});

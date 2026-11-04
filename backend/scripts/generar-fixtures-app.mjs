// Regenera los JSON de mobile/test/fixtures con respuestas reales del API (asistente simulado).
// Úsalo cuando cambie la forma de alguna respuesta, para que las pruebas de la app sigan al backend.
import { writeFileSync } from 'node:fs';
import request from 'supertest';
process.env.NODE_ENV = 'test';
process.env.ASISTENTE_MODO = 'simulado';
// Uso: node scripts/generar-fixtures-app.mjs (con la base de datos corriendo).
const raiz = new URL('../..', import.meta.url).pathname.replace(/\/$/, '');
const { crearApp } = await import(`${raiz}/backend/src/app.js`);
const { cerrarPool } = await import(`${raiz}/backend/src/config/db.js`);
const { limpiarDatosDePrueba } = await import(`${raiz}/backend/tests/helpers.js`);
const app = crearApp();
const destino = `${raiz}/mobile/test/fixtures`;
const guardar = (n, d) => writeFileSync(`${destino}/${n}.json`, JSON.stringify(d, null, 2) + '\n');
const a = (t) => ({ Authorization: `Bearer ${t}` });
const login = async (correo, password) => (await request(app).post('/api/v1/auth/login').send({ correo, password })).body.token;

try {
  const cli = (await request(app).post('/api/v1/auth/register').send({ nombre: 'Laura Méndez', correo: 'laura.fixture@acmaster.test', password: 'Secreta123', telefono: '8112345678' })).body.token;
  const admin = await login('admin@acmaster.mx', 'AcMaster2026!');
  const dir = (await request(app).post('/api/v1/me/direcciones').set(a(cli)).send({ alias: 'Casa', calle: 'Av. Universidad 1500', colonia: 'Ciudad Universitaria', ciudad: 'San Nicolás de los Garza', cp: '66455' })).body;
  guardar('direcciones', [dir]);
  const eq = (await request(app).post('/api/v1/equipos').set(a(cli)).send({ numeroSerie: 'FIX-SOL-01', marca: 'Mirage', modelo: 'MRG123' })).body;
  const diag = (await request(app).post('/api/v1/diagnosticos').set(a(cli)).field('equipoId', String(eq.id)).field('sintomas', '["NO_ENFRIA"]')
    .field('respuestas', JSON.stringify({ modo_frio: 'Sí', sale_aire: 'Sí, con fuerza', ventilador_exterior: 'Sí', hielo_tuberia: 'Sí', ultima_limpieza_filtros: 'Hace menos de 3 meses', desde_cuando: 'Hoy' }))).body;
  const sol = (await request(app).post('/api/v1/solicitudes').set(a(cli)).send({ diagnosticoId: diag.id, direccionId: dir.id })).body;
  guardar('solicitud_en_revision_admin', (await request(app).get(`/api/v1/solicitudes/${sol.id}`).set(a(admin))).body);
  guardar('tecnicos_recomendados', (await request(app).get(`/api/v1/admin/solicitudes/${sol.id}/tecnicos-recomendados`).set(a(admin))).body);
  const mariela = (await request(app).get('/api/v1/admin/tecnicos').set(a(admin))).body.find((t) => t.correo === 'tecnico@acmaster.mx');
  const inicio = new Date(Date.now() + 26 * 3600_000);
  await request(app).post(`/api/v1/admin/solicitudes/${sol.id}/asignar`).set(a(admin)).send({ tecnicoId: mariela.id, ventanaInicio: inicio, ventanaFin: new Date(inicio.getTime() + 2 * 3600_000) });
  await request(app).post(`/api/v1/admin/solicitudes/${sol.id}/cotizacion/enviar`).set(a(admin));
  guardar('solicitud_cotizada_cliente', (await request(app).get(`/api/v1/solicitudes/${sol.id}`).set(a(cli))).body);
  guardar('bandeja_admin', (await request(app).get('/api/v1/admin/solicitudes').set(a(admin))).body.filter((s) => s.id === sol.id));
  guardar('notificaciones', (await request(app).get('/api/v1/notificaciones').set(a(cli))).body);
  guardar('tecnicos_admin', [mariela]);

  // Etapa 4: la orden del técnico en curso y el servicio terminado visto por el cliente.
  await request(app).post(`/api/v1/solicitudes/${sol.id}/cotizacion/aprobar`).set(a(cli));
  const tec = await login('tecnico@acmaster.mx', 'AcMaster2026!');
  await request(app).post(`/api/v1/tecnico/ordenes/${sol.id}/llegada`).set(a(tec));
  const catalogo = (await request(app).get('/api/v1/piezas').set(a(tec))).body;
  guardar('piezas', catalogo.slice(0, 4));
  guardar('ordenes_tecnico', (await request(app).get('/api/v1/tecnico/ordenes').set(a(tec))).body.filter((o) => o.id === sol.id));
  guardar('orden_en_camino_tecnico', (await request(app).get(`/api/v1/tecnico/ordenes/${sol.id}`).set(a(tec))).body);
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');
  await request(app).patch(`/api/v1/tecnico/ordenes/${sol.id}`).set(a(tec)).send({ diagnosticoFinal: 'Fuga en la conexión de la válvula de servicio; se reparó y se cargó gas.' });
  await request(app).post(`/api/v1/tecnico/ordenes/${sol.id}/evidencias`).set(a(tec)).attach('fotos', png, { filename: 'evidencia.png', contentType: 'image/png' });
  await request(app).put(`/api/v1/tecnico/ordenes/${sol.id}/piezas`).set(a(tec)).send({ piezas: [{ piezaId: catalogo[0].id, cantidad: 1 }] });
  await request(app).post(`/api/v1/tecnico/ordenes/${sol.id}/cerrar`).set(a(tec));
  guardar('solicitud_finalizada_cliente', (await request(app).get(`/api/v1/solicitudes/${sol.id}`).set(a(cli))).body);
  console.log('fixtures listos');
} finally {
  await limpiarDatosDePrueba();
  await cerrarPool();
}

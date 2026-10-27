// Pruebas de integración: requieren SQL Server corriendo (docker compose up -d en la raíz).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import request from 'supertest';

process.env.NODE_ENV = 'test';
const { crearApp } = await import('../src/app.js');
const { cerrarPool, consulta, sql } = await import('../src/config/db.js');

const app = crearApp();
const correo = `prueba.${Date.now()}@acmaster.test`;
const password = 'Secreta123';

describe('Autenticación (RF-01)', () => {
  before(async () => {
    await consulta('SELECT 1');
  });

  after(async () => {
    await consulta('DELETE FROM dbo.Usuarios WHERE Correo LIKE @patron', {
      patron: [sql.NVarChar(160), '%@acmaster.test'],
    });
    await cerrarPool();
  });

  test('GET /health confirma la conexión a la base', async () => {
    const res = await request(app).get('/health').expect(200);
    assert.equal(res.body.baseDeDatos, 'ok');
  });

  test('registra un cliente nuevo y devuelve token', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ nombre: 'Cliente de Prueba', correo: correo.toUpperCase(), telefono: '8112345678', password })
      .expect(201);

    assert.ok(res.body.token);
    assert.equal(res.body.usuario.correo, correo, 'el correo se normaliza a minúsculas');
    assert.equal(res.body.usuario.rol, 'cliente');
    assert.equal(res.body.usuario.passwordHash, undefined);
  });

  test('rechaza un correo ya registrado', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ nombre: 'Otro Cliente', correo, password })
      .expect(409);
    assert.equal(res.body.error.codigo, 'CORREO_REGISTRADO');
  });

  test('valida los datos del registro', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ nombre: 'Al', correo: 'no-es-correo', password: '123' })
      .expect(400);
    const campos = res.body.error.detalles.map((d) => d.campo);
    assert.deepEqual(campos.sort(), ['correo', 'nombre', 'password']);
  });

  test('el registro público no permite elegir rol', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ nombre: 'Intento Admin', correo: `admin.${correo}`, password, rol: 'administrador' })
      .expect(201);
    assert.equal(res.body.usuario.rol, 'cliente');
  });

  test('inicia sesión y consulta /me con el token', async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ correo, password }).expect(200);
    const me = await request(app)
      .get('/api/v1/me')
      .set('Authorization', `Bearer ${login.body.token}`)
      .expect(200);
    assert.equal(me.body.correo, correo);
  });

  test('rechaza una contraseña incorrecta', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ correo, password: 'incorrecta' })
      .expect(401);
    assert.equal(res.body.error.codigo, 'CREDENCIALES_INVALIDAS');
  });

  test('rechaza a un usuario desactivado', async () => {
    await consulta('UPDATE dbo.Usuarios SET Activo = 0 WHERE Correo = @correo', {
      correo: [sql.NVarChar(160), correo],
    });
    const res = await request(app).post('/api/v1/auth/login').send({ correo, password }).expect(403);
    assert.equal(res.body.error.codigo, 'CUENTA_INACTIVA');
  });

  test('/me exige token válido', async () => {
    await request(app).get('/api/v1/me').expect(401);
    const res = await request(app).get('/api/v1/me').set('Authorization', 'Bearer basura').expect(401);
    assert.equal(res.body.error.codigo, 'TOKEN_INVALIDO');
  });

  test('responde 404 en JSON para rutas inexistentes', async () => {
    const res = await request(app).get('/api/v1/no-existe').expect(404);
    assert.equal(res.body.error.codigo, 'RUTA_NO_ENCONTRADA');
  });
});

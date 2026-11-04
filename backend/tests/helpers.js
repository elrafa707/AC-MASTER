import { rmSync } from 'node:fs';
import { mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

// Se configura antes de importar la app: pruebas sin rate limit, asistente simulado y uploads temporales.
process.env.NODE_ENV = 'test';
process.env.ASISTENTE_MODO = 'simulado';
process.env.UPLOADS_DIR = await mkdtemp(path.join(tmpdir(), 'acmaster-uploads-'));
process.on('exit', () => rmSync(process.env.UPLOADS_DIR, { recursive: true, force: true }));

export const { crearApp } = await import('../src/app.js');
export const db = await import('../src/config/db.js');

export const DOMINIO_PRUEBAS = '@acmaster.test';

/** PNG válido de 1x1 píxel. */
export const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64',
);

/** Borra todo lo creado por usuarios de prueba, respetando el orden de las llaves foráneas. */
export async function limpiarDatosDePrueba() {
  const { consulta, sql } = db;
  const usuarios = `SELECT UsuarioId FROM dbo.Usuarios WHERE Correo LIKE @patron`;
  const equipos = `SELECT EquipoId FROM dbo.Equipos WHERE ClienteId IN (${usuarios})`;
  const solicitudes = `SELECT SolicitudId FROM dbo.Solicitudes WHERE ClienteId IN (${usuarios}) OR TecnicoId IN (${usuarios})`;
  const ordenes = `SELECT OrdenId FROM dbo.OrdenesTrabajo WHERE SolicitudId IN (${solicitudes})`;
  await consulta(
    `DELETE FROM dbo.Notificaciones WHERE UsuarioId IN (${usuarios}) OR SolicitudId IN (${solicitudes});
     DELETE FROM dbo.Fotos WHERE OrdenId IN (${ordenes});
     DELETE FROM dbo.OrdenPiezas WHERE OrdenId IN (${ordenes});
     DELETE FROM dbo.OrdenesTrabajo WHERE OrdenId IN (${ordenes});
     DELETE FROM dbo.EventosSolicitud WHERE SolicitudId IN (${solicitudes});
     DELETE FROM dbo.CotizacionPartidas WHERE CotizacionId IN (SELECT CotizacionId FROM dbo.Cotizaciones WHERE SolicitudId IN (${solicitudes}));
     DELETE FROM dbo.Cotizaciones WHERE SolicitudId IN (${solicitudes});
     DELETE FROM dbo.HistorialEquipo WHERE EquipoId IN (${equipos}) OR SolicitudId IN (${solicitudes});
     DELETE FROM dbo.Solicitudes WHERE SolicitudId IN (${solicitudes});
     DELETE FROM dbo.Fotos WHERE DiagnosticoId IN (SELECT DiagnosticoId FROM dbo.Diagnosticos WHERE EquipoId IN (${equipos}));
     DELETE FROM dbo.Diagnosticos WHERE EquipoId IN (${equipos});
     DELETE FROM dbo.Equipos WHERE EquipoId IN (${equipos});
     DELETE FROM dbo.Direcciones WHERE UsuarioId IN (${usuarios});
     DELETE FROM dbo.TecnicoEspecialidades WHERE TecnicoId IN (${usuarios});
     DELETE FROM dbo.Tecnicos WHERE TecnicoId IN (${usuarios});
     DELETE FROM dbo.Usuarios WHERE UsuarioId IN (${usuarios});
     DELETE FROM dbo.OrdenPiezas WHERE PiezaId IN (SELECT PiezaId FROM dbo.Piezas WHERE Codigo LIKE 'TST-%');
     DELETE FROM dbo.Piezas WHERE Codigo LIKE 'TST-%';`,
    { patron: [sql.NVarChar(160), `%${DOMINIO_PRUEBAS}`] },
  );
}

/** Registra un cliente de prueba y devuelve su token. */
export async function registrarCliente(request, app, nombre, sufijo) {
  const res = await request(app)
    .post('/api/v1/auth/register')
    .send({ nombre, correo: `${nombre.toLowerCase().replace(/\s/g, '.')}.${sufijo}${DOMINIO_PRUEBAS}`, password: 'Secreta123' })
    .expect(201);
  return res.body.token;
}

export async function iniciarSesion(request, app, correo, password = 'AcMaster2026!') {
  const res = await request(app).post('/api/v1/auth/login').send({ correo, password }).expect(200);
  return res.body.token;
}

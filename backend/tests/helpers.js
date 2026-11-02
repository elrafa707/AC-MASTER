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
  const patron = { patron: [sql.NVarChar(160), `%${DOMINIO_PRUEBAS}`] };
  const equiposDePrueba = `SELECT e.EquipoId FROM dbo.Equipos e JOIN dbo.Usuarios u ON u.UsuarioId = e.ClienteId WHERE u.Correo LIKE @patron`;
  await consulta(
    `DELETE FROM dbo.Fotos WHERE DiagnosticoId IN (SELECT DiagnosticoId FROM dbo.Diagnosticos WHERE EquipoId IN (${equiposDePrueba}));
     DELETE FROM dbo.HistorialEquipo WHERE EquipoId IN (${equiposDePrueba});
     DELETE FROM dbo.Diagnosticos WHERE EquipoId IN (${equiposDePrueba});
     DELETE FROM dbo.Equipos WHERE EquipoId IN (${equiposDePrueba});
     DELETE FROM dbo.Usuarios WHERE Correo LIKE @patron;`,
    patron,
  );
}

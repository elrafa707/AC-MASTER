import sql from 'mssql';
import { env } from './env.js';

const config = {
  server: env.DB_HOST,
  port: env.DB_PORT,
  user: env.DB_USER,
  password: env.DB_PASSWORD,
  database: env.DB_NAME,
  pool: { max: 10, min: 0, idleTimeoutMillis: 30_000 },
  options: {
    encrypt: true,
    trustServerCertificate: env.DB_TRUST_CERT,
  },
};

let poolPromise;

/** Devuelve el pool compartido; se conecta la primera vez que se pide. */
export function obtenerPool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(config).connect().catch((err) => {
      poolPromise = undefined;
      throw err;
    });
  }
  return poolPromise;
}

/** Atajo para una consulta parametrizada: consulta('SELECT ... @id', { id: [sql.Int, 5] }). */
export async function consulta(texto, parametros = {}) {
  const pool = await obtenerPool();
  const request = pool.request();
  for (const [nombre, [tipo, valor]] of Object.entries(parametros)) {
    request.input(nombre, tipo, valor);
  }
  return request.query(texto);
}

export async function cerrarPool() {
  if (!poolPromise) return;
  const pool = await poolPromise;
  poolPromise = undefined;
  await pool.close();
}

export { sql };

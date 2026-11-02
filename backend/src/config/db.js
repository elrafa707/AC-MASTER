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

function ejecutar(request, texto, parametros) {
  for (const [nombre, [tipo, valor]] of Object.entries(parametros)) {
    request.input(nombre, tipo, valor);
  }
  return request.query(texto);
}

/** Atajo para una consulta parametrizada: consulta('SELECT ... @id', { id: [sql.Int, 5] }). */
export async function consulta(texto, parametros = {}) {
  const pool = await obtenerPool();
  return ejecutar(pool.request(), texto, parametros);
}

/**
 * Ejecuta fn dentro de una transacción. fn recibe una función con la misma firma que consulta();
 * si fn lanza un error se hace rollback y el error se propaga.
 */
export async function enTransaccion(fn) {
  const pool = await obtenerPool();
  const transaccion = new sql.Transaction(pool);
  await transaccion.begin();
  try {
    const resultado = await fn((texto, parametros = {}) => ejecutar(transaccion.request(), texto, parametros));
    await transaccion.commit();
    return resultado;
  } catch (err) {
    await transaccion.rollback().catch(() => {});
    throw err;
  }
}

export async function cerrarPool() {
  if (!poolPromise) return;
  const pool = await poolPromise;
  poolPromise = undefined;
  await pool.close();
}

export { sql };

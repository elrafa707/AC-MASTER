import { crearApp } from './app.js';
import { cerrarPool, obtenerPool } from './config/db.js';
import { env } from './config/env.js';

const app = crearApp();

const servidor = app.listen(env.PORT, '0.0.0.0', () => {
  console.log(`AC-Master API escuchando en http://localhost:${env.PORT}/api/v1`);
});

obtenerPool()
  .then(() => console.log(`Conectado a SQL Server (${env.DB_HOST}:${env.DB_PORT}/${env.DB_NAME})`))
  .catch((err) => console.error(`No se pudo conectar a SQL Server: ${err.message}`));

async function apagar() {
  servidor.close();
  await cerrarPool();
  process.exit(0);
}

process.on('SIGINT', apagar);
process.on('SIGTERM', apagar);

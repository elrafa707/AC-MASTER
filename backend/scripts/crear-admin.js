// Crea el primer administrador. Los técnicos los dará de alta el administrador desde la app.
// Uso interactivo:      npm run crear-admin
// Uso sin preguntas:    ADMIN_NOMBRE="..." ADMIN_CORREO="..." ADMIN_PASSWORD="..." npm run crear-admin
import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { cerrarPool } from '../src/config/db.js';
import { hashPassword } from '../src/modules/auth/auth.service.js';
import { esquemaRegistro } from '../src/modules/auth/auth.schemas.js';
import * as usuarios from '../src/modules/usuarios/usuarios.repository.js';

async function pedirDatos() {
  const { ADMIN_NOMBRE, ADMIN_CORREO, ADMIN_PASSWORD } = process.env;
  if (ADMIN_NOMBRE && ADMIN_CORREO && ADMIN_PASSWORD) {
    return { nombre: ADMIN_NOMBRE, correo: ADMIN_CORREO, password: ADMIN_PASSWORD };
  }
  const rl = createInterface({ input: stdin, output: stdout });
  const nombre = await rl.question('Nombre completo: ');
  const correo = await rl.question('Correo: ');
  const password = await rl.question('Contraseña (mín. 8 caracteres): ');
  rl.close();
  return { nombre, correo, password };
}

try {
  const datos = esquemaRegistro.parse(await pedirDatos());
  if (await usuarios.buscarPorCorreo(datos.correo)) {
    console.error(`Ya existe un usuario con el correo ${datos.correo}`);
    process.exitCode = 1;
  } else {
    const fila = await usuarios.crear({
      ...datos,
      passwordHash: await hashPassword(datos.password),
      rol: 'ADMIN',
    });
    console.log(`Administrador creado: ${fila.Nombre} <${fila.Correo}> (id ${fila.UsuarioId})`);
  }
} catch (err) {
  console.error(err.issues ? err.issues.map((i) => i.message).join('\n') : err.message);
  process.exitCode = 1;
} finally {
  await cerrarPool();
}

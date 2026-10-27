import { consulta, sql } from '../../config/db.js';

const ROL_API = { CLIENTE: 'cliente', TECNICO: 'tecnico', ADMIN: 'administrador' };

const COLUMNAS = 'UsuarioId, Nombre, Correo, Telefono, Rol, Activo, FechaRegistro';

/** Convierte una fila de dbo.Usuarios al formato público de la API (sin el hash). */
export function aUsuarioApi(fila) {
  return {
    id: fila.UsuarioId,
    nombre: fila.Nombre,
    correo: fila.Correo,
    telefono: fila.Telefono,
    rol: ROL_API[fila.Rol],
    activo: fila.Activo,
    fechaRegistro: fila.FechaRegistro,
  };
}

export async function buscarPorCorreo(correo) {
  const { recordset } = await consulta(
    `SELECT ${COLUMNAS}, PasswordHash FROM dbo.Usuarios WHERE Correo = @correo`,
    { correo: [sql.NVarChar(160), correo] },
  );
  return recordset[0] ?? null;
}

export async function buscarPorId(id) {
  const { recordset } = await consulta(`SELECT ${COLUMNAS} FROM dbo.Usuarios WHERE UsuarioId = @id`, {
    id: [sql.Int, id],
  });
  return recordset[0] ?? null;
}

export async function crear({ nombre, correo, telefono, passwordHash, rol }) {
  const { recordset } = await consulta(
    `INSERT INTO dbo.Usuarios (Nombre, Correo, Telefono, PasswordHash, Rol)
     OUTPUT INSERTED.UsuarioId, INSERTED.Nombre, INSERTED.Correo, INSERTED.Telefono,
            INSERTED.Rol, INSERTED.Activo, INSERTED.FechaRegistro
     VALUES (@nombre, @correo, @telefono, @hash, @rol)`,
    {
      nombre: [sql.NVarChar(120), nombre],
      correo: [sql.NVarChar(160), correo],
      telefono: [sql.NVarChar(20), telefono ?? null],
      hash: [sql.NVarChar(100), passwordHash],
      rol: [sql.VarChar(10), rol],
    },
  );
  return recordset[0];
}

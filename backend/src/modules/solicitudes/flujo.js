// Flujo de estados de una solicitud. Todo cambio de estado pasa por cambiarEstado(), que valida la
// transición, deja el evento en la línea de tiempo y crea los avisos de la campana en la misma transacción.
import { sql } from '../../config/db.js';
import { HttpError } from '../../utils/http-error.js';

export const ESTADOS = ['EN_REVISION', 'COTIZADO', 'EN_CAMINO', 'FINALIZADO', 'CANCELADA'];

const TRANSICIONES = {
  EN_REVISION: ['COTIZADO', 'CANCELADA'],
  COTIZADO: ['EN_CAMINO', 'CANCELADA'],
  EN_CAMINO: ['FINALIZADO'],
  FINALIZADO: [],
  CANCELADA: [],
};

export function verificarTransicion(actual, nuevo) {
  if (!TRANSICIONES[actual]?.includes(nuevo)) {
    throw HttpError.conflict(`La solicitud no puede pasar de ${actual} a ${nuevo}`, 'TRANSICION_INVALIDA');
  }
}

export async function registrarEvento(q, { solicitudId, estado, titulo, detalle, usuarioId }) {
  await q(
    `INSERT INTO dbo.EventosSolicitud (SolicitudId, Estado, Titulo, Detalle, UsuarioId)
     VALUES (@solicitudId, @estado, @titulo, @detalle, @usuarioId)`,
    {
      solicitudId: [sql.Int, solicitudId],
      estado: [sql.VarChar(12), estado],
      titulo: [sql.NVarChar(120), titulo],
      detalle: [sql.NVarChar(400), detalle ?? null],
      usuarioId: [sql.Int, usuarioId ?? null],
    },
  );
}

/**
 * Cambia el estado validando la transición. El UPDATE comprueba el estado actual para que dos
 * personas que actúan al mismo tiempo no puedan aplicar dos cambios incompatibles.
 */
export async function cambiarEstado(q, { solicitudId, actual, nuevo, usuarioId, titulo, detalle }) {
  verificarTransicion(actual, nuevo);
  const { rowsAffected } = await q(
    `UPDATE dbo.Solicitudes SET Estado = @nuevo, FechaActualizacion = SYSUTCDATETIME()
     WHERE SolicitudId = @id AND Estado = @actual`,
    { id: [sql.Int, solicitudId], nuevo: [sql.VarChar(12), nuevo], actual: [sql.VarChar(12), actual] },
  );
  if (rowsAffected[0] !== 1) {
    throw HttpError.conflict('La solicitud cambió mientras tanto. Actualiza e inténtalo de nuevo.', 'SOLICITUD_MODIFICADA');
  }
  await registrarEvento(q, { solicitudId, estado: nuevo, titulo, detalle, usuarioId });
}

/** Crea avisos en la campana. En la etapa 5 este mismo punto enviará también la notificación push. */
export async function notificar(q, usuarioIds, { titulo, cuerpo, solicitudId }) {
  for (const usuarioId of new Set(usuarioIds.filter(Boolean))) {
    await q(
      `INSERT INTO dbo.Notificaciones (UsuarioId, SolicitudId, Titulo, Cuerpo)
       VALUES (@usuarioId, @solicitudId, @titulo, @cuerpo)`,
      {
        usuarioId: [sql.Int, usuarioId],
        solicitudId: [sql.Int, solicitudId ?? null],
        titulo: [sql.NVarChar(120), titulo],
        cuerpo: [sql.NVarChar(400), cuerpo],
      },
    );
  }
}

export async function idsAdministradores(q) {
  const { recordset } = await q(`SELECT UsuarioId FROM dbo.Usuarios WHERE Rol = 'ADMIN' AND Activo = 1`);
  return recordset.map((f) => f.UsuarioId);
}

import { Router } from 'express';
import { consulta, sql } from '../../config/db.js';
import { autenticar } from '../../middlewares/auth.js';
import { validar } from '../../middlewares/validate.js';
import { HttpError } from '../../utils/http-error.js';
import { esquemaIdRuta } from '../equipos/equipos.schemas.js';

export const notificacionesRouter = Router();

notificacionesRouter.get('/notificaciones', autenticar, async (req, res) => {
  const { recordset } = await consulta(
    `SELECT TOP (50) NotificacionId, SolicitudId, Titulo, Cuerpo, Leida, Fecha
     FROM dbo.Notificaciones WHERE UsuarioId = @u ORDER BY Fecha DESC, NotificacionId DESC`,
    { u: [sql.Int, req.usuario.id] },
  );
  res.json({
    noLeidas: recordset.filter((f) => !f.Leida).length,
    notificaciones: recordset.map((f) => ({
      id: f.NotificacionId,
      solicitudId: f.SolicitudId,
      titulo: f.Titulo,
      cuerpo: f.Cuerpo,
      leida: f.Leida,
      fecha: f.Fecha,
    })),
  });
});

notificacionesRouter.post('/notificaciones/:id/leida', autenticar, validar(esquemaIdRuta, 'params'), async (req, res) => {
  const { rowsAffected } = await consulta('UPDATE dbo.Notificaciones SET Leida = 1 WHERE NotificacionId = @id AND UsuarioId = @u', {
    id: [sql.Int, req.params.id],
    u: [sql.Int, req.usuario.id],
  });
  if (rowsAffected[0] !== 1) throw HttpError.notFound('Notificación no encontrada', 'NOTIFICACION_NO_ENCONTRADA');
  res.status(204).end();
});

notificacionesRouter.post('/notificaciones/leidas', autenticar, async (req, res) => {
  await consulta('UPDATE dbo.Notificaciones SET Leida = 1 WHERE UsuarioId = @u AND Leida = 0', { u: [sql.Int, req.usuario.id] });
  res.status(204).end();
});

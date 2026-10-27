import { Router } from 'express';
import { autenticar } from '../../middlewares/auth.js';
import { HttpError } from '../../utils/http-error.js';
import * as usuarios from './usuarios.repository.js';

export const usuariosRouter = Router();

usuariosRouter.get('/me', autenticar, async (req, res) => {
  const fila = await usuarios.buscarPorId(req.usuario.id);
  if (!fila || !fila.Activo) throw HttpError.unauthorized('Tu cuenta ya no está disponible', 'CUENTA_INACTIVA');
  res.json(usuarios.aUsuarioApi(fila));
});

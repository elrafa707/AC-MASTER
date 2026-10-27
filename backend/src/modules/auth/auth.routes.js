import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { env } from '../../config/env.js';
import { validar } from '../../middlewares/validate.js';
import { esquemaLogin, esquemaRegistro } from './auth.schemas.js';
import * as authService from './auth.service.js';

export const authRouter = Router();

// Frena intentos de fuerza bruta sobre login y registro.
const limitador = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  skip: () => env.NODE_ENV === 'test',
  message: { error: { codigo: 'DEMASIADOS_INTENTOS', mensaje: 'Demasiados intentos, espera unos minutos' } },
});

authRouter.post('/register', limitador, validar(esquemaRegistro), async (req, res) => {
  res.status(201).json(await authService.registrarCliente(req.body));
});

authRouter.post('/login', limitador, validar(esquemaLogin), async (req, res) => {
  res.json(await authService.iniciarSesion(req.body));
});

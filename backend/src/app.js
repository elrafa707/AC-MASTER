import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { consulta } from './config/db.js';
import { env } from './config/env.js';
import { manejadorErrores, rutaNoEncontrada } from './middlewares/error-handler.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { usuariosRouter } from './modules/usuarios/usuarios.routes.js';

export function crearApp() {
  const app = express();
  const origenes = env.CORS_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean);

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: origenes.length ? origenes : false }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', async (_req, res) => {
    try {
      await consulta('SELECT 1 AS ok');
      res.json({ estado: 'ok', baseDeDatos: 'ok' });
    } catch {
      res.status(503).json({ estado: 'degradado', baseDeDatos: 'sin conexión' });
    }
  });

  const api = express.Router();
  api.use('/auth', authRouter);
  api.use(usuariosRouter);
  app.use('/api/v1', api);

  app.use(rutaNoEncontrada);
  app.use(manejadorErrores);
  return app;
}

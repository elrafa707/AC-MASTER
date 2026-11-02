import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { env } from '../../config/env.js';
import { autenticar, permitir } from '../../middlewares/auth.js';
import { recibirFotos } from '../../middlewares/upload.js';
import { validar } from '../../middlewares/validate.js';
import { rutaAbsoluta } from '../../services/almacenamiento.js';
import { HttpError } from '../../utils/http-error.js';
import { esquemaIdRuta } from '../equipos/equipos.schemas.js';
import { SINTOMAS, preguntasPara } from './cuestionario.js';
import { esquemaAutoayuda, esquemaCuestionario, esquemaNuevoDiagnostico } from './diagnosticos.schemas.js';
import * as diagnosticos from './diagnosticos.repository.js';
import * as servicio from './diagnosticos.service.js';

export const diagnosticosRouter = Router();

// Cada diagnóstico consume la API de Anthropic: se limita por usuario.
const limitarDiagnosticos = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 15,
  keyGenerator: (req) => `usuario-${req.usuario.id}`,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  skip: () => env.NODE_ENV === 'test',
  message: { error: { codigo: 'DEMASIADOS_DIAGNOSTICOS', mensaje: 'Has hecho muchos diagnósticos seguidos. Inténtalo en una hora.' } },
});

diagnosticosRouter.get('/diagnosticos/cuestionario', autenticar, permitir('cliente'), validar(esquemaCuestionario, 'query'), (req, res) => {
  res.json({
    sintomas: Object.entries(SINTOMAS).map(([clave, s]) => ({ clave, ...s })),
    preguntas: preguntasPara(req.consulta.sintomas),
  });
});

diagnosticosRouter.post(
  '/diagnosticos',
  autenticar,
  permitir('cliente'),
  limitarDiagnosticos,
  recibirFotos,
  validar(esquemaNuevoDiagnostico),
  async (req, res) => {
    const diagnostico = await servicio.diagnosticar({
      usuarioId: req.usuario.id,
      ...req.body,
      archivos: req.files ?? [],
    });
    res.status(201).json(diagnostico);
  },
);

diagnosticosRouter.get('/diagnosticos/:id', autenticar, validar(esquemaIdRuta, 'params'), async (req, res) => {
  const diagnostico = await servicio.obtener(req.params.id);
  servicio.verificarAcceso(diagnostico, req.usuario);
  res.json(diagnostico);
});

diagnosticosRouter.post(
  '/diagnosticos/:id/autoayuda',
  autenticar,
  permitir('cliente'),
  validar(esquemaIdRuta, 'params'),
  validar(esquemaAutoayuda),
  async (req, res) => {
    res.json(await servicio.registrarAutoayuda({ usuario: req.usuario, id: req.params.id, resuelto: req.body.resuelto }));
  },
);

// Las fotos no se publican como archivos estáticos: se sirven después de revisar permisos.
// TODO(etapa 4): limitar al técnico asignado cuando existan las órdenes de trabajo.
diagnosticosRouter.get('/fotos/:id', autenticar, validar(esquemaIdRuta, 'params'), async (req, res) => {
  const foto = await diagnosticos.buscarFoto(req.params.id);
  if (!foto || (req.usuario.rol === 'cliente' && foto.ClienteId !== req.usuario.id)) {
    throw HttpError.notFound('Foto no encontrada', 'FOTO_NO_ENCONTRADA');
  }
  res.set('Cache-Control', 'private, max-age=86400');
  res.type(foto.MimeType).sendFile(rutaAbsoluta(foto.Ruta));
});

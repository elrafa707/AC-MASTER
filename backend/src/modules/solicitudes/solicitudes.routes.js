import { Router } from 'express';
import { z } from 'zod';
import { autenticar, permitir } from '../../middlewares/auth.js';
import { validar } from '../../middlewares/validate.js';
import { esquemaIdRuta } from '../equipos/equipos.schemas.js';
import * as repo from './solicitudes.repository.js';
import * as servicio from './solicitudes.service.js';

export const solicitudesRouter = Router();

const esquemaNueva = z.object({
  diagnosticoId: z.number().int().positive(),
  direccionId: z.number().int().positive('Elige la dirección del servicio'),
  descripcion: z.preprocess((v) => (v === '' ? undefined : v), z.string().trim().max(1000).optional()),
});

const esquemaMotivo = z.object({
  motivo: z.preprocess((v) => (v === '' || v === null ? undefined : v), z.string().trim().max(300).optional()),
});

solicitudesRouter.post('/solicitudes', autenticar, permitir('cliente'), validar(esquemaNueva), async (req, res) => {
  res.status(201).json(await servicio.crear({ usuario: req.usuario, ...req.body }));
});

solicitudesRouter.get('/solicitudes', autenticar, permitir('cliente'), async (req, res) => {
  res.json(await repo.listar({ clienteId: req.usuario.id }));
});

solicitudesRouter.get('/solicitudes/:id', autenticar, validar(esquemaIdRuta, 'params'), async (req, res) => {
  res.json(await servicio.detalle(req.usuario, req.params.id));
});

solicitudesRouter.post(
  '/solicitudes/:id/cotizacion/aprobar',
  autenticar,
  permitir('cliente'),
  validar(esquemaIdRuta, 'params'),
  async (req, res) => {
    res.json(await servicio.aprobar({ usuario: req.usuario, id: req.params.id }));
  },
);

solicitudesRouter.post(
  '/solicitudes/:id/cotizacion/rechazar',
  autenticar,
  permitir('cliente'),
  validar(esquemaIdRuta, 'params'),
  validar(esquemaMotivo),
  async (req, res) => {
    res.json(await servicio.cancelar({ usuario: req.usuario, id: req.params.id, motivo: req.body.motivo, rechazo: true }));
  },
);

solicitudesRouter.post(
  '/solicitudes/:id/cancelar',
  autenticar,
  permitir('cliente', 'administrador'),
  validar(esquemaIdRuta, 'params'),
  validar(esquemaMotivo),
  async (req, res) => {
    res.json(await servicio.cancelar({ usuario: req.usuario, id: req.params.id, motivo: req.body.motivo }));
  },
);

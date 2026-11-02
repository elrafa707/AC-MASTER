import { Router } from 'express';
import { enTransaccion } from '../../config/db.js';
import { autenticar, permitir } from '../../middlewares/auth.js';
import { validar } from '../../middlewares/validate.js';
import { HttpError } from '../../utils/http-error.js';
import { esquemaEquipo, esquemaIdRuta, esquemaNumeroSerie } from './equipos.schemas.js';
import * as equipos from './equipos.repository.js';

export const equiposRouter = Router();

const VIOLACION_UNIQUE = new Set([2627, 2601]);

/**
 * El cliente solo ve sus equipos; técnico y administrador ven cualquiera (RF-08).
 * A un cliente ajeno se le responde 404 para no revelar que el número de serie existe.
 */
function verificarAcceso(fila, usuario) {
  if (!fila || (usuario.rol === 'cliente' && fila.ClienteId !== usuario.id)) {
    throw HttpError.notFound('No encontramos ese equipo', 'EQUIPO_NO_ENCONTRADO');
  }
}

async function ficha(fila) {
  return { ...equipos.aEquipoApi(fila), historial: await equipos.historial(fila.EquipoId) };
}

equiposRouter.get('/equipos', autenticar, permitir('cliente'), async (req, res) => {
  res.json(await equipos.listarDeCliente(req.usuario.id));
});

equiposRouter.post('/equipos', autenticar, permitir('cliente'), validar(esquemaEquipo), async (req, res) => {
  try {
    const id = await enTransaccion((q) => equipos.crear(q, req.usuario.id, req.body));
    res.status(201).json(await ficha(await equipos.buscarPorId(id)));
  } catch (err) {
    if (VIOLACION_UNIQUE.has(err.number)) {
      throw HttpError.conflict('Ya hay un equipo registrado con ese número de serie', 'SERIE_REGISTRADA');
    }
    throw err;
  }
});

// Va antes de /equipos/:id para que "serie" no se interprete como id.
equiposRouter.get('/equipos/serie/:numeroSerie', autenticar, async (req, res) => {
  const serie = esquemaNumeroSerie.safeParse(req.params.numeroSerie);
  if (!serie.success) throw HttpError.badRequest('Número de serie inválido', 'VALIDACION');
  const fila = await equipos.buscarPorSerie(serie.data);
  verificarAcceso(fila, req.usuario);
  res.json(await ficha(fila));
});

equiposRouter.get('/equipos/:id', autenticar, validar(esquemaIdRuta, 'params'), async (req, res) => {
  const fila = await equipos.buscarPorId(req.params.id);
  verificarAcceso(fila, req.usuario);
  res.json(await ficha(fila));
});

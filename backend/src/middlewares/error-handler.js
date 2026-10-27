import { env } from '../config/env.js';
import { HttpError } from '../utils/http-error.js';

export function rutaNoEncontrada(req, _res, next) {
  next(HttpError.notFound(`No existe la ruta ${req.method} ${req.path}`, 'RUTA_NO_ENCONTRADA'));
}

// Express identifica el manejador de errores por sus 4 parámetros, aunque no use next.
export function manejadorErrores(err, _req, res, _next) {
  if (err instanceof HttpError) {
    return res.status(err.status).json({
      error: { codigo: err.codigo, mensaje: err.message, ...(err.detalles && { detalles: err.detalles }) },
    });
  }

  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { codigo: 'JSON_INVALIDO', mensaje: 'El cuerpo no es JSON válido' } });
  }

  if (env.NODE_ENV !== 'test') console.error(err);
  res.status(500).json({ error: { codigo: 'ERROR_INTERNO', mensaje: 'Ocurrió un error inesperado' } });
}

import { HttpError } from '../utils/http-error.js';

/** Valida req[origen] con un esquema zod y reemplaza el valor por el resultado ya normalizado. */
export function validar(esquema, origen = 'body') {
  return (req, _res, next) => {
    const resultado = esquema.safeParse(req[origen]);
    if (!resultado.success) {
      const error = HttpError.badRequest('Revisa los datos enviados', 'VALIDACION');
      error.detalles = resultado.error.issues.map((i) => ({ campo: i.path.join('.'), mensaje: i.message }));
      return next(error);
    }
    // En Express 5 req.query es de solo lectura; guardamos lo validado aparte.
    if (origen === 'query') req.consulta = resultado.data;
    else req[origen] = resultado.data;
    next();
  };
}

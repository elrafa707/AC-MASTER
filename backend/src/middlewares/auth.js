import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { HttpError } from '../utils/http-error.js';

export function firmarToken(usuario) {
  return jwt.sign({ rol: usuario.rol }, env.JWT_SECRET, {
    subject: String(usuario.id),
    expiresIn: env.JWT_EXPIRES_IN,
  });
}

/** Exige un Bearer JWT válido y deja { id, rol } en req.usuario. */
export function autenticar(req, _res, next) {
  const [esquema, token] = (req.headers.authorization ?? '').split(' ');
  if (esquema !== 'Bearer' || !token) {
    return next(HttpError.unauthorized());
  }
  try {
    const payload = jwt.verify(token, env.JWT_SECRET);
    req.usuario = { id: Number(payload.sub), rol: payload.rol };
    next();
  } catch {
    next(HttpError.unauthorized('Tu sesión expiró, vuelve a iniciar sesión', 'TOKEN_INVALIDO'));
  }
}

/** Restringe la ruta a los roles indicados. Usar después de autenticar. */
export function permitir(...roles) {
  return (req, _res, next) => {
    if (!roles.includes(req.usuario?.rol)) return next(HttpError.forbidden());
    next();
  };
}

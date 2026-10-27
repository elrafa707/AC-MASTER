import bcrypt from 'bcryptjs';
import { firmarToken } from '../../middlewares/auth.js';
import { HttpError } from '../../utils/http-error.js';
import * as usuarios from '../usuarios/usuarios.repository.js';

const RONDAS_BCRYPT = 10;
// Hash de referencia para comparar aunque el correo no exista y no filtrar cuentas por tiempo de respuesta.
const HASH_FALSO = bcrypt.hashSync('contrasena-inexistente', RONDAS_BCRYPT);

const VIOLACION_UNIQUE = new Set([2627, 2601]);

export function hashPassword(password) {
  return bcrypt.hash(password, RONDAS_BCRYPT);
}

/** Registro público: solo crea cuentas de cliente (RF-01). */
export async function registrarCliente({ nombre, correo, telefono, password }) {
  const passwordHash = await hashPassword(password);
  try {
    const fila = await usuarios.crear({ nombre, correo, telefono, passwordHash, rol: 'CLIENTE' });
    const usuario = usuarios.aUsuarioApi(fila);
    return { token: firmarToken(usuario), usuario };
  } catch (err) {
    if (VIOLACION_UNIQUE.has(err.number)) {
      throw HttpError.conflict('Ya existe una cuenta con ese correo', 'CORREO_REGISTRADO');
    }
    throw err;
  }
}

export async function iniciarSesion({ correo, password }) {
  const fila = await usuarios.buscarPorCorreo(correo);
  const valida = await bcrypt.compare(password, fila?.PasswordHash ?? HASH_FALSO);

  if (!fila || !valida) {
    throw HttpError.unauthorized('Correo o contraseña incorrectos', 'CREDENCIALES_INVALIDAS');
  }
  if (!fila.Activo) {
    throw HttpError.forbidden('Tu cuenta está desactivada. Contacta al administrador', 'CUENTA_INACTIVA');
  }

  const usuario = usuarios.aUsuarioApi(fila);
  return { token: firmarToken(usuario), usuario };
}

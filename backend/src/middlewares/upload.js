import multer from 'multer';
import { HttpError } from '../utils/http-error.js';

export const MAX_FOTOS = 3;
const MAX_BYTES = 4 * 1024 * 1024;
const TIPOS = new Set(['image/jpeg', 'image/png', 'image/webp']);

const subida = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES, files: MAX_FOTOS, fields: 10, fieldSize: 64 * 1024 },
  fileFilter: (_req, archivo, cb) => {
    if (TIPOS.has(archivo.mimetype)) return cb(null, true);
    cb(HttpError.badRequest('Solo se aceptan fotos JPG, PNG o WebP', 'ARCHIVO_INVALIDO'));
  },
});

const MENSAJES = {
  LIMIT_FILE_SIZE: 'Cada foto debe pesar menos de 4 MB',
  LIMIT_FILE_COUNT: `Puedes enviar hasta ${MAX_FOTOS} fotos`,
  LIMIT_UNEXPECTED_FILE: `Puedes enviar hasta ${MAX_FOTOS} fotos en el campo "fotos"`,
};

/** Recibe hasta MAX_FOTOS imágenes en el campo multipart "fotos" y traduce los errores de multer. */
export function recibirFotos(req, res, next) {
  subida.array('fotos', MAX_FOTOS)(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      return next(HttpError.badRequest(MENSAJES[err.code] ?? 'No se pudieron recibir las fotos', 'ARCHIVO_INVALIDO'));
    }
    next(err);
  });
}

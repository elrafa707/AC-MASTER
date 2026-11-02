import { randomUUID } from 'node:crypto';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { env } from '../config/env.js';
import { HttpError } from '../utils/http-error.js';

const RAIZ = path.resolve(env.UPLOADS_DIR);

// Firmas binarias: no basta con confiar en el Content-Type que manda el cliente.
const FIRMAS = [
  { mime: 'image/jpeg', ext: 'jpg', coincide: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  { mime: 'image/png', ext: 'png', coincide: (b) => b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) },
  { mime: 'image/webp', ext: 'webp', coincide: (b) => b.subarray(0, 4).toString('ascii') === 'RIFF' && b.subarray(8, 12).toString('ascii') === 'WEBP' },
];

/** Detecta el tipo real de la imagen o lanza 400 si no es JPEG, PNG o WebP. */
export function tipoDeImagen(buffer) {
  const tipo = FIRMAS.find((f) => buffer.length > 12 && f.coincide(buffer));
  if (!tipo) throw HttpError.badRequest('Solo se aceptan fotos JPG, PNG o WebP', 'ARCHIVO_INVALIDO');
  return tipo;
}

/** Guarda la imagen con un nombre aleatorio y devuelve su ruta relativa (la que se guarda en la BD). */
export async function guardarImagen(buffer, carpeta) {
  const { ext } = tipoDeImagen(buffer);
  const relativa = path.posix.join(carpeta, `${randomUUID()}.${ext}`);
  await mkdir(path.join(RAIZ, carpeta), { recursive: true });
  await writeFile(path.join(RAIZ, relativa), buffer);
  return relativa;
}

/** Ruta absoluta de un archivo guardado, sin permitir salir de la carpeta de uploads. */
export function rutaAbsoluta(relativa) {
  const absoluta = path.resolve(RAIZ, relativa);
  if (!absoluta.startsWith(RAIZ + path.sep)) throw HttpError.notFound('Foto no encontrada');
  return absoluta;
}

export async function eliminarArchivos(relativas) {
  await Promise.all(relativas.map((r) => rm(rutaAbsoluta(r), { force: true })));
}

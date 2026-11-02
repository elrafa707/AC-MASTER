import { z } from 'zod';
import { SINTOMAS } from './cuestionario.js';

const CLAVES_SINTOMA = Object.keys(SINTOMAS);

// En multipart todo llega como texto: sintomas y respuestas vienen como JSON serializado.
const json = (esquema) =>
  z.preprocess((v) => {
    if (typeof v !== 'string') return v;
    try {
      return JSON.parse(v);
    } catch {
      return v;
    }
  }, esquema);

const listaSintomas = z
  .array(z.enum(CLAVES_SINTOMA, 'Síntoma desconocido'))
  .min(1, 'Elige al menos un síntoma')
  .max(CLAVES_SINTOMA.length)
  .transform((s) => [...new Set(s)]);

export const esquemaCuestionario = z.object({
  sintomas: z
    .string()
    .optional()
    .transform((v) => (v ? v.split(',').map((s) => s.trim()).filter(Boolean) : []))
    .pipe(z.array(z.enum(CLAVES_SINTOMA, 'Síntoma desconocido'))),
});

export const esquemaNuevoDiagnostico = z.object({
  equipoId: z.coerce.number().int().positive('Elige un equipo'),
  sintomas: json(listaSintomas),
  respuestas: json(z.record(z.string(), z.string())),
  descripcion: z.preprocess((v) => (v === '' ? undefined : v), z.string().trim().max(1000).optional()),
});

export const esquemaAutoayuda = z.object({
  resuelto: z.boolean('Indica si se resolvió el problema'),
});

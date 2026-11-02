import { z } from 'zod';

export const TIPOS_EQUIPO = ['Minisplit', 'Ventana', 'Central', 'Portátil'];
export const REFRIGERANTES = ['R-410A', 'R-32', 'R-22', 'Otro'];

const opcional = (esquema) =>
  z.preprocess((v) => (v === '' || v === null ? undefined : v), esquema.optional());

export const esquemaNumeroSerie = z
  .string()
  .trim()
  .toUpperCase()
  .min(4, 'El número de serie debe tener al menos 4 caracteres')
  .max(60)
  .regex(/^[A-Z0-9][A-Z0-9-]*$/, 'Usa solo letras, números y guiones');

export const esquemaEquipo = z.object({
  numeroSerie: esquemaNumeroSerie,
  marca: z.string().trim().min(2, 'Escribe la marca').max(60),
  modelo: z.string().trim().min(1, 'Escribe el modelo').max(80),
  tipo: z.enum(TIPOS_EQUIPO).default('Minisplit'),
  capacidadBTU: opcional(z.coerce.number().int().min(5000, 'Capacidad inválida').max(60000, 'Capacidad inválida')),
  refrigerante: opcional(z.enum(REFRIGERANTES)),
  ubicacion: opcional(z.string().trim().max(80)),
  fechaInstalacion: opcional(
    z.iso
      .date('Fecha inválida (AAAA-MM-DD)')
      .refine((f) => new Date(`${f}T00:00:00Z`) <= new Date(), 'La fecha de instalación no puede ser futura'),
  ),
});

export const esquemaIdRuta = z.object({ id: z.coerce.number().int().positive() });

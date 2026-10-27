import { z } from 'zod';

const correo = z.email('Correo electrónico inválido').trim().toLowerCase().max(160);

export const esquemaRegistro = z.object({
  nombre: z.string().trim().min(3, 'Escribe tu nombre completo').max(120),
  correo,
  telefono: z
    .string()
    .trim()
    .regex(/^\+?[0-9 ]{10,15}$/, 'Teléfono inválido (10 dígitos)')
    .optional(),
  password: z.string().min(8, 'La contraseña debe tener al menos 8 caracteres').max(72),
});

export const esquemaLogin = z.object({
  correo,
  password: z.string().min(1, 'Escribe tu contraseña'),
});

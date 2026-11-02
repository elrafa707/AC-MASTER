import 'dotenv/config';
import { z } from 'zod';

const esquema = z.object({
  PORT: z.coerce.number().int().positive().default(3000),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  CORS_ORIGINS: z.string().default(''),

  DB_HOST: z.string().min(1),
  DB_PORT: z.coerce.number().int().positive().default(1433),
  DB_USER: z.string().min(1),
  DB_PASSWORD: z.string().min(1),
  DB_NAME: z.string().min(1).default('ACMaster'),
  DB_TRUST_CERT: z.stringbool().default(true),

  JWT_SECRET: z.string().min(32, 'JWT_SECRET debe tener al menos 32 caracteres'),
  JWT_EXPIRES_IN: z.string().default('7d'),

  UPLOADS_DIR: z.string().default('./uploads'),

  // Asistente de diagnóstico: "claude" usa la API de Anthropic; "simulado" usa reglas locales
  // (para desarrollar y probar sin clave). Si no se indica, se elige "claude" solo cuando hay clave.
  ASISTENTE_MODO: z.enum(['claude', 'simulado']).optional(),
  ANTHROPIC_API_KEY: z.string().optional(),
  ANTHROPIC_MODEL: z.string().default('claude-opus-5-5'),
});

const resultado = esquema.safeParse(process.env);

if (!resultado.success) {
  const detalle = resultado.error.issues.map((i) => `  - ${i.path.join('.')}: ${i.message}`).join('\n');
  console.error(`Configuración inválida. Revisa tu archivo .env:\n${detalle}`);
  process.exit(1);
}

const datos = resultado.data;
datos.ASISTENTE_MODO ??= datos.ANTHROPIC_API_KEY ? 'claude' : 'simulado';

if (datos.ASISTENTE_MODO === 'claude' && !datos.ANTHROPIC_API_KEY) {
  console.error('ASISTENTE_MODO=claude requiere ANTHROPIC_API_KEY en el archivo .env');
  process.exit(1);
}

export const env = datos;

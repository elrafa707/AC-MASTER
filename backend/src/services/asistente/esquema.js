import { z } from 'zod';

export const ESPECIALIDADES = ['REFRIGERACION', 'ELECTRICO', 'DRENAJE', 'MECANICO', 'MANTENIMIENTO'];
export const PRIORIDADES = ['BAJA', 'MEDIA', 'ALTA'];

/**
 * Forma exacta que debe devolver el asistente (RF-03). Se usa como salida estructurada de Claude
 * y también la cumple el asistente simulado. Los rangos numéricos se ajustan después en normalizar().
 */
export const esquemaResultado = z.object({
  falla: z.string().describe('Nombre corto de la falla más probable, para el cliente'),
  descripcion: z.string().describe('Explicación breve y clara de qué está pasando y por qué'),
  confianza: z.number().describe('Qué tan seguro estás de la falla principal, entre 0 y 1'),
  causas: z
    .array(z.object({ nombre: z.string(), probabilidad: z.number().describe('Entre 0 y 1') }))
    .describe('De 1 a 4 causas posibles, de la más a la menos probable'),
  requiereTecnico: z.boolean().describe('true si hace falta un técnico; false si el cliente puede resolverlo con los pasos'),
  pasosAutoayuda: z
    .array(z.object({ titulo: z.string(), detalle: z.string() }))
    .describe('Pasos seguros que el cliente puede hacer sin herramientas; vacío si no hay ninguno'),
  herramientas: z.array(z.string()).describe('Herramientas y refacciones que debe llevar el técnico'),
  especialidad: z.enum(ESPECIALIDADES).describe('Especialidad del técnico más adecuado'),
  prioridad: z.enum(PRIORIDADES),
  costoMin: z.number().describe('Costo mínimo estimado en pesos mexicanos'),
  costoMax: z.number().describe('Costo máximo estimado en pesos mexicanos'),
  advertencia: z.string().nullable().describe('Aviso de seguridad para el cliente, o null'),
  analisisFoto: z.string().nullable().describe('Qué se observa en las fotos que sea relevante, o null si no hay fotos'),
});

const recortar = (texto, max) => (texto && texto.length > max ? `${texto.slice(0, max - 1)}…` : texto);
const entre0y1 = (n) => Math.min(1, Math.max(0, Number.isFinite(n) ? n : 0));

/** Ajusta el resultado a los límites de la base de datos y a reglas de negocio mínimas. */
export function normalizar(r) {
  const pasos = r.pasosAutoayuda.slice(0, 8).map((p) => ({ titulo: recortar(p.titulo, 120), detalle: recortar(p.detalle, 400) }));
  const costoMin = Math.max(0, Math.round(r.costoMin));
  const costoMax = Math.max(costoMin, Math.round(r.costoMax));
  return {
    falla: recortar(r.falla.trim(), 160),
    descripcion: recortar(r.descripcion.trim(), 1000),
    confianza: entre0y1(r.confianza),
    causas: r.causas.slice(0, 4).map((c) => ({ nombre: recortar(c.nombre, 160), probabilidad: entre0y1(c.probabilidad) })),
    // Sin pasos seguros no hay autoayuda posible.
    requiereTecnico: r.requiereTecnico || pasos.length === 0,
    pasosAutoayuda: pasos,
    herramientas: r.herramientas.slice(0, 12).map((h) => recortar(h, 80)),
    especialidad: r.especialidad,
    prioridad: r.prioridad,
    costoMin,
    costoMax,
    advertencia: r.advertencia ? recortar(r.advertencia.trim(), 400) : null,
    analisisFoto: r.analisisFoto ? recortar(r.analisisFoto.trim(), 600) : null,
  };
}

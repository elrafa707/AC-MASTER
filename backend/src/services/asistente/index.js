import { env } from '../../config/env.js';
import { AsistenteClaude } from './claude.js';
import { AsistenteSimulado } from './simulado.js';

let asistente;

/**
 * Asistente activo según ASISTENTE_MODO. Ambos exponen
 * evaluar({ equipo, sintomas: [{ clave, etiqueta }], respuestas, descripcion, fotos }) → resultado normalizado + { modelo, respuestaCruda }.
 */
export function obtenerAsistente() {
  asistente ??=
    env.ASISTENTE_MODO === 'claude'
      ? new AsistenteClaude({ apiKey: env.ANTHROPIC_API_KEY, modelo: env.ANTHROPIC_MODEL })
      : new AsistenteSimulado();
  return asistente;
}

/** Solo para pruebas: reemplaza el asistente activo. */
export function establecerAsistente(nuevo) {
  asistente = nuevo;
}

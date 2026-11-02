// Cuestionario inteligente (RF-02): preguntas que dependen de los síntomas elegidos.
// Las respuestas viajan al asistente junto con las fotos para afinar el diagnóstico.

export const SINTOMAS = {
  NO_ENFRIA: { etiqueta: 'No enfría', detalle: 'El aire sale, pero no baja la temperatura' },
  NO_ENCIENDE: { etiqueta: 'No enciende', detalle: 'No responde al control ni al botón' },
  GOTEA: { etiqueta: 'Gotea agua', detalle: 'Hay humedad o agua debajo de la unidad' },
  RUIDO: { etiqueta: 'Hace ruido', detalle: 'Vibración o sonido fuera de lo habitual' },
  MAL_OLOR: { etiqueta: 'Huele raro', detalle: 'Olor a humedad o a quemado al encender' },
};

const NO_SE = 'No sé';

const GENERALES = [
  {
    id: 'ultima_limpieza_filtros',
    texto: '¿Cuándo se limpiaron los filtros por última vez?',
    opciones: ['Hace menos de 3 meses', 'Entre 3 y 6 meses', 'Hace más de 6 meses', NO_SE],
  },
  {
    id: 'desde_cuando',
    texto: '¿Desde cuándo notas la falla?',
    opciones: ['Hoy', 'Esta semana', 'Hace más de una semana'],
  },
];

const POR_SINTOMA = {
  NO_ENFRIA: [
    {
      id: 'modo_frio',
      texto: '¿El control está en modo frío (copo de nieve) y a menos de 24 °C?',
      opciones: ['Sí', 'No', NO_SE],
    },
    {
      id: 'sale_aire',
      texto: '¿Sale aire por la unidad interior?',
      opciones: ['Sí, con fuerza', 'Sí, pero muy débil', 'No sale aire'],
    },
    {
      id: 'ventilador_exterior',
      texto: '¿Gira el ventilador de la unidad exterior?',
      opciones: ['Sí', 'No', NO_SE],
      ayuda: 'La unidad exterior es la que está afuera; se ve un ventilador detrás de una rejilla.',
    },
    {
      id: 'hielo_tuberia',
      texto: '¿Ves hielo o escarcha en las tuberías o en la unidad interior?',
      opciones: ['Sí', 'No', NO_SE],
    },
  ],
  NO_ENCIENDE: [
    {
      id: 'luces_display',
      texto: '¿Se encienden las luces o la pantalla de la unidad interior?',
      opciones: ['Sí', 'No'],
    },
    {
      id: 'pilas_control',
      texto: '¿Ya probaste el control con pilas nuevas?',
      opciones: ['Sí, y sigue sin encender', 'No'],
    },
    {
      id: 'interruptor',
      texto: '¿Revisaste el interruptor (breaker) del clima en el centro de carga?',
      opciones: ['Sí, está arriba (encendido)', 'Estaba abajo o botado', 'No sé dónde está'],
    },
  ],
  GOTEA: [
    {
      id: 'donde_gotea',
      texto: '¿Dónde cae el agua?',
      opciones: ['Dentro de la casa, de la unidad interior', 'Afuera, de la unidad exterior'],
    },
    {
      id: 'manguera_drenaje',
      texto: '¿La manguera de drenaje está doblada, aplastada o tapada?',
      opciones: ['Sí', 'No', 'No la encuentro'],
    },
  ],
  RUIDO: [
    {
      id: 'unidad_ruido',
      texto: '¿De qué unidad viene el ruido?',
      opciones: ['Interior', 'Exterior', 'De las dos'],
    },
    {
      id: 'tipo_ruido',
      texto: '¿Cómo es el ruido?',
      opciones: [
        'Golpeteo o vibración',
        'Chillido o silbido',
        'Zumbido y no arranca',
        'Crujidos al encender o apagar',
      ],
    },
  ],
  MAL_OLOR: [
    {
      id: 'tipo_olor',
      texto: '¿A qué huele?',
      opciones: ['A humedad o moho', 'A quemado o plástico caliente', 'A otro olor'],
    },
  ],
};

/** Preguntas para los síntomas indicados: primero las de cada síntoma y al final las generales. */
export function preguntasPara(sintomas) {
  return [...sintomas.flatMap((s) => POR_SINTOMA[s] ?? []), ...GENERALES];
}

/** Devuelve el primer problema encontrado en las respuestas, o null si son válidas. */
export function validarRespuestas(sintomas, respuestas) {
  const preguntas = preguntasPara(sintomas);
  for (const p of preguntas) {
    const valor = respuestas[p.id];
    if (valor === undefined) return `Falta responder: "${p.texto}"`;
    if (!p.opciones.includes(valor)) return `Respuesta no válida para "${p.texto}"`;
  }
  const extra = Object.keys(respuestas).find((id) => !preguntas.some((p) => p.id === id));
  return extra ? `Pregunta desconocida: ${extra}` : null;
}

/** Une pregunta y respuesta en texto legible, para el asistente y para el historial. */
export function respuestasLegibles(sintomas, respuestas) {
  return preguntasPara(sintomas).map((p) => ({ id: p.id, pregunta: p.texto, respuesta: respuestas[p.id] }));
}

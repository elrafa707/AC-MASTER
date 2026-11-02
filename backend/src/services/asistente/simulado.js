import { normalizar } from './esquema.js';

/**
 * Asistente por reglas para desarrollar y probar sin clave de Anthropic (ASISTENTE_MODO=simulado).
 * No analiza las fotos: solo usa los síntomas y las respuestas del cuestionario.
 */
export class AsistenteSimulado {
  modelo = 'simulado-reglas';

  async evaluar({ sintomas, respuestas, fotos }) {
    const r = Object.fromEntries(respuestas.map((x) => [x.id, x.respuesta]));
    const candidatos = sintomas.map((s) => REGLAS[s.clave](r)).sort((a, b) => b.confianza - a.confianza);
    // Una señal de peligro manda aunque no sea el síntoma con más confianza.
    const principal = candidatos.find((c) => c.prioridad === 'ALTA' && c.advertencia) ?? candidatos[0];

    const resultado = normalizar({
      ...principal,
      causas: candidatos.slice(0, 4).map((c) => ({ nombre: c.falla, probabilidad: c.confianza })),
      herramientas: [...new Set(candidatos.flatMap((c) => c.herramientas))],
      advertencia: principal.advertencia ?? null,
      analisisFoto: fotos.length ? 'Modo simulado: las fotos se guardaron, pero no se analizaron.' : null,
    });
    return { ...resultado, modelo: this.modelo, respuestaCruda: null };
  }
}

const filtrosSucios = (r) => r.ultima_limpieza_filtros === 'Hace más de 6 meses' || r.ultima_limpieza_filtros === 'No sé';

const PASOS_FILTROS = [
  { titulo: 'Apaga y desconecta el equipo', detalle: 'Apágalo con el control y baja su interruptor en el centro de carga.' },
  { titulo: 'Retira los filtros', detalle: 'Levanta la tapa frontal de la unidad interior y desliza los filtros hacia abajo.' },
  { titulo: 'Lávalos con agua', detalle: 'Usa agua tibia y jabón neutro; no uses cepillos duros.' },
  { titulo: 'Déjalos secar y colócalos', detalle: 'Espera a que estén completamente secos antes de reinstalarlos.' },
  { titulo: 'Enciende y espera 20 minutos', detalle: 'Ponlo en modo frío a 22 °C y revisa si enfría mejor.' },
];

const base = (datos) => ({
  requiereTecnico: true,
  pasosAutoayuda: [],
  herramientas: [],
  prioridad: 'MEDIA',
  ...datos,
});

const REGLAS = {
  NO_ENFRIA(r) {
    if (r.modo_frio === 'No') {
      return base({
        falla: 'Configuración incorrecta del control',
        descripcion: 'El equipo no está en modo frío o la temperatura es muy alta.',
        confianza: 0.8,
        requiereTecnico: false,
        prioridad: 'BAJA',
        especialidad: 'MANTENIMIENTO',
        costoMin: 350,
        costoMax: 450,
        pasosAutoayuda: [
          { titulo: 'Elige el modo frío', detalle: 'Presiona MODE hasta ver el copo de nieve.' },
          { titulo: 'Baja la temperatura', detalle: 'Ponla entre 22 y 24 °C y espera 15 minutos.' },
        ],
      });
    }
    if (r.ventilador_exterior === 'No') {
      return base({
        falla: 'Falla en el capacitor o el motor del ventilador exterior',
        descripcion: 'La unidad exterior no saca el calor porque su ventilador no gira.',
        confianza: 0.75,
        especialidad: 'ELECTRICO',
        costoMin: 900,
        costoMax: 2400,
        herramientas: ['Multímetro', 'Capacitores de repuesto', 'Desarmadores'],
      });
    }
    if (filtrosSucios(r) || r.sale_aire === 'Sí, pero muy débil') {
      return base({
        falla: 'Filtros saturados de polvo',
        descripcion: 'Los filtros sucios no dejan pasar el aire y el equipo pierde capacidad de enfriar.',
        confianza: 0.7,
        requiereTecnico: false,
        prioridad: 'BAJA',
        especialidad: 'MANTENIMIENTO',
        costoMin: 450,
        costoMax: 900,
        pasosAutoayuda: PASOS_FILTROS,
        herramientas: ['Hidrolavadora', 'Químico desincrustante'],
      });
    }
    return base({
      falla: 'Posible fuga o baja carga de refrigerante',
      descripcion: 'El equipo funciona pero el circuito de refrigeración no está enfriando lo suficiente.',
      confianza: r.hielo_tuberia === 'Sí' ? 0.8 : 0.6,
      especialidad: 'REFRIGERACION',
      costoMin: 1200,
      costoMax: 2800,
      herramientas: ['Manómetros', 'Detector de fugas', 'Bomba de vacío', 'Refrigerante'],
    });
  },

  NO_ENCIENDE(r) {
    if (r.interruptor === 'Estaba abajo o botado') {
      return base({
        falla: 'Interruptor del clima apagado o botado',
        descripcion: 'El equipo no recibe energía porque su interruptor se botó.',
        confianza: 0.8,
        requiereTecnico: false,
        prioridad: 'BAJA',
        especialidad: 'ELECTRICO',
        costoMin: 350,
        costoMax: 450,
        advertencia: 'Si el interruptor se vuelve a botar, no lo subas otra vez y pide un técnico.',
        pasosAutoayuda: [
          { titulo: 'Sube el interruptor', detalle: 'En el centro de carga, súbelo hasta que quede firme.' },
          { titulo: 'Espera 3 minutos', detalle: 'Deja que el equipo se reinicie antes de encenderlo.' },
          { titulo: 'Enciéndelo con el control', detalle: 'Si enciende, el problema está resuelto.' },
        ],
      });
    }
    if (r.pilas_control === 'No') {
      return base({
        falla: 'Pilas del control agotadas',
        descripcion: 'El control no envía la señal al equipo.',
        confianza: 0.65,
        requiereTecnico: false,
        prioridad: 'BAJA',
        especialidad: 'ELECTRICO',
        costoMin: 350,
        costoMax: 450,
        pasosAutoayuda: [
          { titulo: 'Cambia las pilas', detalle: 'Usa dos pilas AAA nuevas.' },
          { titulo: 'Apunta a la unidad interior', detalle: 'Presiona ON/OFF a menos de 3 metros.' },
        ],
      });
    }
    return base({
      falla: 'Falla en la tarjeta electrónica o el capacitor',
      descripcion: 'El equipo tiene energía y el control funciona, pero no arranca.',
      confianza: 0.6,
      especialidad: 'ELECTRICO',
      costoMin: 900,
      costoMax: 3200,
      herramientas: ['Multímetro', 'Capacitores de repuesto', 'Tarjeta universal'],
    });
  },

  GOTEA(r) {
    if (r.donde_gotea === 'Afuera, de la unidad exterior') {
      return base({
        falla: 'Condensación normal de la unidad exterior',
        descripcion: 'Es normal que la unidad exterior gotee agua mientras enfría.',
        confianza: 0.7,
        requiereTecnico: false,
        prioridad: 'BAJA',
        especialidad: 'DRENAJE',
        costoMin: 350,
        costoMax: 450,
        pasosAutoayuda: [{ titulo: 'Observa durante un día', detalle: 'Si solo gotea mientras enfría, no hay falla.' }],
      });
    }
    if (r.manguera_drenaje === 'Sí') {
      return base({
        falla: 'Manguera de drenaje obstruida',
        descripcion: 'El agua de la condensación no sale y se desborda por la unidad interior.',
        confianza: 0.75,
        requiereTecnico: false,
        prioridad: 'BAJA',
        especialidad: 'DRENAJE',
        costoMin: 450,
        costoMax: 750,
        pasosAutoayuda: [
          { titulo: 'Apaga el equipo', detalle: 'Evita que siga acumulando agua.' },
          { titulo: 'Endereza la manguera', detalle: 'Quita dobleces y revisa que la punta no esté tapada.' },
          { titulo: 'Enciende y revisa', detalle: 'Después de 30 minutos debe salir agua por la manguera.' },
        ],
      });
    }
    return base({
      falla: 'Drenaje o charola obstruidos',
      descripcion: 'La charola interior o la línea de drenaje están tapadas por suciedad.',
      confianza: 0.65,
      especialidad: 'DRENAJE',
      costoMin: 650,
      costoMax: 1100,
      herramientas: ['Bomba de presión para drenaje', 'Aspiradora de agua'],
    });
  },

  RUIDO(r) {
    if (r.tipo_ruido === 'Crujidos al encender o apagar') {
      return base({
        falla: 'Dilatación normal de los plásticos',
        descripcion: 'Los plásticos se expanden y contraen con el cambio de temperatura; no es una falla.',
        confianza: 0.7,
        requiereTecnico: false,
        prioridad: 'BAJA',
        especialidad: 'MECANICO',
        costoMin: 350,
        costoMax: 450,
        pasosAutoayuda: [{ titulo: 'No requiere acción', detalle: 'Si el ruido cambia o aumenta, solicita una revisión.' }],
      });
    }
    if (r.tipo_ruido === 'Zumbido y no arranca') {
      return base({
        falla: 'Capacitor de arranque dañado',
        descripcion: 'El compresor o el ventilador intentan arrancar pero no tienen suficiente fuerza.',
        confianza: 0.75,
        especialidad: 'ELECTRICO',
        costoMin: 700,
        costoMax: 1500,
        herramientas: ['Multímetro', 'Capacitores de repuesto'],
      });
    }
    return base({
      falla: r.tipo_ruido === 'Chillido o silbido' ? 'Rodamientos del motor desgastados' : 'Tornillería floja o ventilador desbalanceado',
      descripcion: 'Una pieza móvil vibra o roza fuera de lo normal.',
      confianza: 0.6,
      especialidad: 'MECANICO',
      costoMin: 800,
      costoMax: 1900,
      herramientas: ['Juego de llaves', 'Lubricante', 'Gomas antivibración'],
    });
  },

  MAL_OLOR(r) {
    if (r.tipo_olor === 'A quemado o plástico caliente') {
      return base({
        falla: 'Posible falla eléctrica',
        descripcion: 'El olor a quemado puede indicar un cable o componente sobrecalentado.',
        confianza: 0.7,
        prioridad: 'ALTA',
        especialidad: 'ELECTRICO',
        costoMin: 900,
        costoMax: 3000,
        advertencia: 'Apaga el equipo y baja su interruptor de inmediato. No lo vuelvas a encender hasta que lo revise un técnico.',
        herramientas: ['Multímetro', 'Cable y terminales', 'Cámara termográfica'],
      });
    }
    return base({
      falla: 'Humedad y moho en la unidad interior',
      descripcion: 'La humedad acumulada en filtros y serpentín produce mal olor.',
      confianza: 0.65,
      requiereTecnico: false,
      prioridad: 'BAJA',
      especialidad: 'MANTENIMIENTO',
      costoMin: 600,
      costoMax: 1100,
      pasosAutoayuda: [
        ...PASOS_FILTROS.slice(0, 4),
        { titulo: 'Seca el equipo', detalle: 'Déjalo 30 minutos en modo ventilador antes de apagarlo.' },
      ],
      herramientas: ['Hidrolavadora', 'Bactericida para serpentín'],
    });
  },
};

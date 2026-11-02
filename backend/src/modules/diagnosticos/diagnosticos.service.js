import { enTransaccion } from '../../config/db.js';
import { obtenerAsistente } from '../../services/asistente/index.js';
import { eliminarArchivos, guardarImagen, tipoDeImagen } from '../../services/almacenamiento.js';
import { HttpError } from '../../utils/http-error.js';
import * as equipos from '../equipos/equipos.repository.js';
import { SINTOMAS, respuestasLegibles, validarRespuestas } from './cuestionario.js';
import * as diagnosticos from './diagnosticos.repository.js';

/** Crea un diagnóstico con el asistente (RF-02, RF-03) y lo registra en el historial del equipo. */
export async function diagnosticar({ usuarioId, equipoId, sintomas, respuestas, descripcion, archivos }) {
  const equipo = await equipos.buscarPorId(equipoId);
  if (!equipo || equipo.ClienteId !== usuarioId) {
    throw HttpError.notFound('No encontramos ese equipo', 'EQUIPO_NO_ENCONTRADO');
  }

  const problema = validarRespuestas(sintomas, respuestas);
  if (problema) throw HttpError.badRequest(problema, 'CUESTIONARIO_INCOMPLETO');

  // Se valida el contenido real de cada archivo antes de mandarlo al asistente o al disco.
  const fotos = archivos.map((a) => ({ buffer: a.buffer, mimeType: tipoDeImagen(a.buffer).mime }));
  const legibles = respuestasLegibles(sintomas, respuestas);
  const api = equipos.aEquipoApi(equipo);

  const resultado = await obtenerAsistente().evaluar({
    equipo: {
      ...api,
      aniosUso: api.fechaInstalacion
        ? Math.floor((Date.now() - new Date(api.fechaInstalacion).getTime()) / (365.25 * 24 * 3600 * 1000))
        : null,
    },
    sintomas: sintomas.map((clave) => ({ clave, etiqueta: SINTOMAS[clave].etiqueta })),
    respuestas: legibles,
    descripcion,
    fotos,
  });

  const rutas = [];
  try {
    for (const foto of fotos) rutas.push(await guardarImagen(foto.buffer, 'diagnosticos'));

    const id = await enTransaccion(async (q) => {
      const diagnosticoId = await diagnosticos.crear(q, {
        equipoId,
        clienteId: usuarioId,
        sintomas,
        respuestas: legibles.map(({ pregunta, respuesta }) => ({ pregunta, respuesta })),
        resultado,
      });
      for (const [i, ruta] of rutas.entries()) {
        await diagnosticos.agregarFoto(q, { diagnosticoId, ruta, mimeType: fotos[i].mimeType, usuarioId });
      }
      await equipos.insertarRegistro(q, {
        equipoId,
        tipo: 'PREDICCION',
        titulo: `Diagnóstico del asistente: ${resultado.falla}`,
        descripcion: `Síntomas: ${sintomas.map((s) => SINTOMAS[s].etiqueta).join(', ')}. Confianza: ${Math.round(resultado.confianza * 100)}%.`,
        diagnosticoId,
      });
      return diagnosticoId;
    });

    return obtener(id);
  } catch (err) {
    await eliminarArchivos(rutas);
    throw err;
  }
}

export async function obtener(id) {
  const encontrado = await diagnosticos.buscarPorId(id);
  if (!encontrado) throw HttpError.notFound('Diagnóstico no encontrado', 'DIAGNOSTICO_NO_ENCONTRADO');
  return diagnosticos.aDiagnosticoApi(encontrado.fila, encontrado.fotos);
}

export function verificarAcceso(diagnostico, usuario) {
  if (usuario.rol === 'cliente' && diagnostico.clienteId !== usuario.id) {
    throw HttpError.notFound('Diagnóstico no encontrado', 'DIAGNOSTICO_NO_ENCONTRADO');
  }
}

/** El cliente terminó la guía de autoayuda. Si se resolvió, queda en el historial del equipo. */
export async function registrarAutoayuda({ usuario, id, resuelto }) {
  const diagnostico = await obtener(id);
  verificarAcceso(diagnostico, usuario);
  if (diagnostico.resultado !== 'PENDIENTE') {
    throw HttpError.conflict('Este diagnóstico ya fue cerrado', 'DIAGNOSTICO_CERRADO');
  }
  if (!diagnostico.pasosAutoayuda.length) {
    throw HttpError.badRequest('Este diagnóstico no tiene guía de autoayuda', 'SIN_AUTOAYUDA');
  }

  // Si no se resolvió se queda PENDIENTE: el siguiente paso es solicitar un técnico (etapa 3).
  if (resuelto) {
    await enTransaccion(async (q) => {
      await diagnosticos.marcarResultado(q, id, 'RESUELTO_AUTOAYUDA');
      await equipos.insertarRegistro(q, {
        equipoId: diagnostico.equipoId,
        tipo: 'AUTOAYUDA',
        titulo: `Resuelto con el asistente: ${diagnostico.falla}`,
        descripcion: `El cliente siguió la guía de ${diagnostico.pasosAutoayuda.length} pasos y confirmó que el problema se resolvió.`,
        diagnosticoId: id,
      });
    });
  }
  return obtener(id);
}

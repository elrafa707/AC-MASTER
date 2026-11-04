import { enTransaccion, sql } from '../../config/db.js';
import { HttpError } from '../../utils/http-error.js';
import { buscarDireccion } from '../direcciones/direcciones.routes.js';
import * as diagnosticosRepo from '../diagnosticos/diagnosticos.repository.js';
import * as diagnosticos from '../diagnosticos/diagnosticos.service.js';
import { cambiarEstado, idsAdministradores, notificar, registrarEvento } from './flujo.js';
import * as repo from './solicitudes.repository.js';

export const COSTO_VISITA = 350;

const formatoVentana = new Intl.DateTimeFormat('es-MX', {
  timeZone: 'America/Monterrey',
  weekday: 'long',
  day: 'numeric',
  month: 'long',
  hour: '2-digit',
  minute: '2-digit',
});
const formatoHora = new Intl.DateTimeFormat('es-MX', { timeZone: 'America/Monterrey', hour: '2-digit', minute: '2-digit' });
const pesos = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN', maximumFractionDigits: 0 });

export const textoVentana = (inicio, fin) => `${formatoVentana.format(inicio)} a ${formatoHora.format(fin)}`;

/** Borrador que propone el sistema a partir del costo estimado por el asistente. El administrador lo valida. */
export function partidasAutomaticas(diagnostico) {
  const partidas = [{ concepto: 'Visita de diagnóstico a domicilio', cantidad: 1, precioUnitario: COSTO_VISITA }];
  const promedio = Math.round((diagnostico.costoMin + diagnostico.costoMax) / 2 / 10) * 10;
  if (promedio > COSTO_VISITA) {
    partidas.push({ concepto: `Reparación estimada: ${diagnostico.falla}`.slice(0, 160), cantidad: 1, precioUnitario: promedio - COSTO_VISITA });
  }
  return partidas;
}

function noEncontrada() {
  return HttpError.notFound('No encontramos esa solicitud', 'SOLICITUD_NO_ENCONTRADA');
}

/** Carga la solicitud y verifica que el usuario pueda verla. El técnico solo ve las órdenes que le asignaron. */
export async function cargar(usuario, id) {
  const fila = await repo.buscar(id);
  if (!fila) throw noEncontrada();
  const permitido =
    usuario.rol === 'administrador' ||
    (usuario.rol === 'cliente' && fila.ClienteId === usuario.id) ||
    (usuario.rol === 'tecnico' && fila.TecnicoId === usuario.id && ['EN_CAMINO', 'FINALIZADO'].includes(fila.Estado));
  if (!permitido) throw noEncontrada();
  return fila;
}

/** Detalle completo, recortado según lo que cada rol debe ver. */
export async function detalle(usuario, id) {
  const f = await cargar(usuario, id);
  const esCliente = usuario.rol === 'cliente';
  const [diagnostico, cotizacion, eventos] = await Promise.all([
    diagnosticos.obtener(f.DiagnosticoId),
    repo.cotizacion(f.SolicitudId),
    repo.eventos(f.SolicitudId),
  ]);

  // El cliente ve al técnico desde que recibe la cotización y su teléfono hasta que la aprueba.
  const mostrarTecnico = f.TecnicoId && (!esCliente || f.Estado !== 'EN_REVISION');
  const contactoTecnico = !esCliente || ['EN_CAMINO', 'FINALIZADO'].includes(f.Estado);
  // El borrador de la cotización solo lo ve el administrador.
  const mostrarCotizacion = cotizacion && (!esCliente || cotizacion.estado !== 'BORRADOR');

  return {
    ...repo.aResumenApi(f),
    descripcion: f.Descripcion,
    cliente: { id: f.ClienteId, nombre: f.ClienteNombre, telefono: f.ClienteTelefono, correo: f.ClienteCorreo },
    equipo: { id: f.EquipoId, nombre: `${f.Marca} ${f.Modelo}`, numeroSerie: f.NumeroSerie, tipo: f.EquipoTipo, ubicacion: f.EquipoUbicacion },
    direccion: { id: f.DireccionId, alias: f.Alias, calle: f.Calle, colonia: f.Colonia, ciudad: f.Ciudad, cp: f.CP, referencias: f.Referencias },
    diagnostico,
    tecnico: mostrarTecnico
      ? {
          id: f.TecnicoId,
          nombre: f.TecnicoNombre,
          calificacion: Number(f.TecnicoCalificacion),
          telefono: contactoTecnico ? f.TecnicoTelefono : null,
        }
      : null,
    cotizacion: mostrarCotizacion ? cotizacion : null,
    eventos,
    calificacion: f.Calificacion ?? null,
    comentarioCalificacion: f.ComentarioCalificacion ?? null,
  };
}

export async function crear({ usuario, diagnosticoId, direccionId, descripcion }) {
  const diagnostico = await diagnosticos.obtener(diagnosticoId).catch(() => null);
  if (!diagnostico || diagnostico.clienteId !== usuario.id) {
    throw HttpError.notFound('Diagnóstico no encontrado', 'DIAGNOSTICO_NO_ENCONTRADO');
  }
  if (diagnostico.resultado !== 'PENDIENTE') {
    throw HttpError.conflict(
      diagnostico.resultado === 'ESCALADO' ? 'Ya hay una solicitud para este diagnóstico' : 'Este diagnóstico ya se resolvió con la guía',
      'DIAGNOSTICO_CERRADO',
    );
  }
  const direccion = await buscarDireccion(direccionId);
  if (!direccion || direccion.UsuarioId !== usuario.id) {
    throw HttpError.badRequest('Elige una de tus direcciones', 'DIRECCION_INVALIDA');
  }

  const id = await enTransaccion(async (q) => {
    const { SolicitudId, Folio } = await repo.crear(q, {
      diagnostico,
      direccionId,
      descripcion,
      pedidaPorCliente: !diagnostico.requiereTecnico,
    });
    await diagnosticosRepo.marcarResultado(q, diagnostico.id, 'ESCALADO');
    await repo.guardarPartidas(q, SolicitudId, partidasAutomaticas(diagnostico), { generadaAuto: true });
    await registrarEvento(q, {
      solicitudId: SolicitudId,
      estado: 'EN_REVISION',
      titulo: 'Solicitud recibida',
      detalle: `Diagnóstico del asistente: ${diagnostico.falla}`,
      usuarioId: usuario.id,
    });
    await notificar(q, [usuario.id], {
      solicitudId: SolicitudId,
      titulo: `Recibimos tu solicitud ${Folio}`,
      cuerpo: 'Un administrador la revisará, asignará un técnico y te enviará la cotización.',
    });
    await notificar(q, await idsAdministradores(q), {
      solicitudId: SolicitudId,
      titulo: `Nueva solicitud ${Folio}`,
      cuerpo: `${diagnostico.falla} · prioridad ${diagnostico.prioridad}`,
    });
    return SolicitudId;
  });
  return detalle(usuario, id);
}

/** Técnicos ordenados por idoneidad para la falla predicha (RF-04). El administrador decide. */
export async function recomendados(id) {
  const f = await repo.buscar(id);
  if (!f) throw noEncontrada();
  const lista = await repo.candidatos(f.EspecialidadId);
  return lista
    .map((t) => {
      const calificacion = Number(t.Calificacion);
      const razones = [];
      if (t.TieneEspecialidad) razones.push('Tiene la especialidad de la falla');
      razones.push(t.Disponible ? 'Disponible' : 'Ocupado');
      razones.push(t.Activas ? `${t.Activas} servicio${t.Activas === 1 ? '' : 's'} activo${t.Activas === 1 ? '' : 's'}` : 'Sin servicios activos');
      return {
        id: t.UsuarioId,
        nombre: t.Nombre,
        especialidades: t.Especialidades ? t.Especialidades.split(', ') : [],
        disponible: t.Disponible,
        calificacion,
        serviciosActivos: t.Activas,
        tieneEspecialidad: Boolean(t.TieneEspecialidad),
        puntaje: (t.TieneEspecialidad ? 50 : 0) + (t.Disponible ? 30 : 0) - 10 * t.Activas + Math.round(calificacion * 4),
        asignado: t.UsuarioId === f.TecnicoId,
        razones,
      };
    })
    .sort((a, b) => b.puntaje - a.puntaje || a.nombre.localeCompare(b.nombre));
}

async function enRevision(id) {
  const f = await repo.buscar(id);
  if (!f) throw noEncontrada();
  if (f.Estado !== 'EN_REVISION') {
    throw HttpError.conflict('Solo se puede modificar una solicitud en revisión', 'SOLICITUD_NO_EDITABLE');
  }
  return f;
}

export async function asignar({ usuario, id, tecnicoId, ventanaInicio, ventanaFin }) {
  await enRevision(id);
  const tecnico = (await repo.candidatos(null)).find((t) => t.UsuarioId === tecnicoId);
  if (!tecnico) throw HttpError.badRequest('Elige un técnico activo', 'TECNICO_INVALIDO');

  await enTransaccion(async (q) => {
    await q(
      `UPDATE dbo.Solicitudes SET TecnicoId = @t, VentanaInicio = @i, VentanaFin = @f, FechaActualizacion = SYSUTCDATETIME()
       WHERE SolicitudId = @id AND Estado = 'EN_REVISION'`,
      { id: [sql.Int, id], t: [sql.Int, tecnicoId], i: [sql.DateTime2(0), ventanaInicio], f: [sql.DateTime2(0), ventanaFin] },
    );
    await registrarEvento(q, {
      solicitudId: id,
      estado: 'EN_REVISION',
      titulo: 'Técnico asignado',
      detalle: `${tecnico.Nombre} · ${textoVentana(ventanaInicio, ventanaFin)}`,
      usuarioId: usuario.id,
    });
  });
  return detalle(usuario, id);
}

export async function guardarCotizacion({ usuario, id, partidas }) {
  await enRevision(id);
  await enTransaccion((q) => repo.guardarPartidas(q, id, partidas, { generadaAuto: false }));
  return detalle(usuario, id);
}

export async function enviarCotizacion({ usuario, id }) {
  const f = await enRevision(id);
  if (!f.TecnicoId || !f.VentanaInicio) {
    throw HttpError.badRequest('Asigna un técnico y la ventana de visita antes de enviar la cotización', 'FALTA_TECNICO');
  }
  const cotizacion = await repo.cotizacion(id);
  if (!cotizacion?.partidas.length) throw HttpError.badRequest('La cotización no tiene partidas', 'COTIZACION_VACIA');

  await enTransaccion(async (q) => {
    await repo.actualizarCotizacion(q, id, { estado: 'ENVIADA', validadaPor: usuario.id });
    await cambiarEstado(q, {
      solicitudId: id,
      actual: 'EN_REVISION',
      nuevo: 'COTIZADO',
      usuarioId: usuario.id,
      titulo: 'Cotización enviada',
      detalle: `Total ${pesos.format(cotizacion.total)}`,
    });
    await notificar(q, [f.ClienteId], {
      solicitudId: id,
      titulo: `Tu cotización ${f.Folio} está lista`,
      cuerpo: `Total ${pesos.format(cotizacion.total)}. Revísala y apruébala para agendar la visita.`,
    });
  });
  return detalle(usuario, id);
}

export async function aprobar({ usuario, id }) {
  const f = await cargar(usuario, id);
  if (f.Estado !== 'COTIZADO') throw HttpError.conflict('No hay una cotización pendiente de aprobar', 'SIN_COTIZACION_PENDIENTE');

  await enTransaccion(async (q) => {
    await repo.actualizarCotizacion(q, id, { estado: 'APROBADA' });
    await cambiarEstado(q, {
      solicitudId: id,
      actual: 'COTIZADO',
      nuevo: 'EN_CAMINO',
      usuarioId: usuario.id,
      titulo: 'Cotización aprobada',
      detalle: `${f.TecnicoNombre} te visitará el ${textoVentana(f.VentanaInicio, f.VentanaFin)}`,
    });
    const { recordset } = await q(
      `INSERT INTO dbo.OrdenesTrabajo (SolicitudId, TecnicoId) OUTPUT INSERTED.Folio VALUES (@id, @t)`,
      { id: [sql.Int, id], t: [sql.Int, f.TecnicoId] },
    );
    await notificar(q, [f.TecnicoId], {
      solicitudId: id,
      titulo: `Nueva orden ${recordset[0].Folio}`,
      cuerpo: `${f.FallaPredicha} · ${f.Colonia} · ${textoVentana(f.VentanaInicio, f.VentanaFin)}`,
    });
    await notificar(q, await idsAdministradores(q), {
      solicitudId: id,
      titulo: `Cotización aprobada ${f.Folio}`,
      cuerpo: `${f.ClienteNombre} aprobó la cotización. Se generó la orden para ${f.TecnicoNombre}.`,
    });
  });
  return detalle(usuario, id);
}

/** Rechazo de la cotización o cancelación de la solicitud; ambos terminan en CANCELADA. */
export async function cancelar({ usuario, id, motivo, rechazo = false }) {
  const f = await cargar(usuario, id);
  if (rechazo && f.Estado !== 'COTIZADO') {
    throw HttpError.conflict('No hay una cotización pendiente de responder', 'SIN_COTIZACION_PENDIENTE');
  }
  const titulo = rechazo ? 'Cotización rechazada' : 'Solicitud cancelada';
  const quien = usuario.rol === 'cliente' ? 'por el cliente' : 'por el administrador';

  await enTransaccion(async (q) => {
    if (rechazo) await repo.actualizarCotizacion(q, id, { estado: 'RECHAZADA', comentario: motivo });
    await cambiarEstado(q, {
      solicitudId: id,
      actual: f.Estado,
      nuevo: 'CANCELADA',
      usuarioId: usuario.id,
      titulo,
      detalle: motivo ? `${quien[0].toUpperCase()}${quien.slice(1)}: ${motivo}` : `Cancelada ${quien}`,
    });
    const avisar = usuario.rol === 'cliente' ? await idsAdministradores(q) : [f.ClienteId];
    await notificar(q, avisar, { solicitudId: id, titulo: `${titulo} ${f.Folio}`, cuerpo: motivo || `La solicitud fue cancelada ${quien}.` });
  });
  return detalle(usuario, id);
}

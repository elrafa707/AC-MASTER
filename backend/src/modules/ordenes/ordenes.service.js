// Orden de trabajo del técnico (RF-06, RF-07): llegada, diagnóstico final, evidencias, piezas y cierre.
import { consulta, enTransaccion, sql } from '../../config/db.js';
import { eliminarArchivos, guardarImagen, tipoDeImagen } from '../../services/almacenamiento.js';
import { HttpError } from '../../utils/http-error.js';
import * as equipos from '../equipos/equipos.repository.js';
import { cambiarEstado, idsAdministradores, notificar, registrarEvento } from '../solicitudes/flujo.js';
import * as repo from '../solicitudes/solicitudes.repository.js';
import * as solicitudes from '../solicitudes/solicitudes.service.js';

export const MAX_EVIDENCIAS = 10;
const pesos = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN', maximumFractionDigits: 0 });

/** Orden del técnico que todavía puede modificarse (la solicitud sigue En camino). */
async function ordenAbierta(usuario, id) {
  const f = await solicitudes.cargar(usuario, id);
  if (!f.OrdenId) throw HttpError.notFound('No encontramos esa orden', 'ORDEN_NO_ENCONTRADA');
  if (f.Estado !== 'EN_CAMINO') throw HttpError.conflict('Esta orden ya fue cerrada', 'ORDEN_CERRADA');
  return f;
}

export async function cambiarDisponibilidad(usuario, disponible) {
  await consulta('UPDATE dbo.Tecnicos SET Disponible = @d WHERE TecnicoId = @t', { t: [sql.Int, usuario.id], d: [sql.Bit, disponible] });
  return { disponible };
}

export async function disponibilidad(usuario) {
  const { recordset } = await consulta('SELECT Disponible FROM dbo.Tecnicos WHERE TecnicoId = @t', { t: [sql.Int, usuario.id] });
  return { disponible: recordset[0]?.Disponible ?? false };
}

export async function registrarLlegada(usuario, id) {
  const f = await ordenAbierta(usuario, id);
  if (f.FechaLlegada) return solicitudes.detalle(usuario, id);
  await enTransaccion(async (q) => {
    await q('UPDATE dbo.OrdenesTrabajo SET FechaLlegada = SYSUTCDATETIME() WHERE OrdenId = @o', { o: [sql.Int, f.OrdenId] });
    await registrarEvento(q, { solicitudId: id, estado: 'EN_CAMINO', titulo: 'El técnico llegó', detalle: f.TecnicoNombre, usuarioId: usuario.id });
    await notificar(q, [f.ClienteId], {
      solicitudId: id,
      titulo: `${f.TecnicoNombre} llegó a tu domicilio`,
      cuerpo: `Comenzó el servicio ${f.Folio}.`,
    });
  });
  return solicitudes.detalle(usuario, id);
}

export async function guardarRegistro(usuario, id, { diagnosticoFinal, notas }) {
  const f = await ordenAbierta(usuario, id);
  await consulta(
    `UPDATE dbo.OrdenesTrabajo SET DiagnosticoFinal = COALESCE(@diag, DiagnosticoFinal), Notas = COALESCE(@notas, Notas)
     WHERE OrdenId = @o`,
    { o: [sql.Int, f.OrdenId], diag: [sql.NVarChar(2000), diagnosticoFinal ?? null], notas: [sql.NVarChar(2000), notas ?? null] },
  );
  return solicitudes.detalle(usuario, id);
}

export async function agregarEvidencias(usuario, id, archivos) {
  const f = await ordenAbierta(usuario, id);
  if (!archivos.length) throw HttpError.badRequest('Adjunta al menos una foto', 'SIN_FOTOS');
  const orden = await repo.orden(f);
  if (orden.evidencias.length + archivos.length > MAX_EVIDENCIAS) {
    throw HttpError.badRequest(`La orden admite hasta ${MAX_EVIDENCIAS} fotos de evidencia`, 'DEMASIADAS_FOTOS');
  }
  const fotos = archivos.map((a) => ({ buffer: a.buffer, mime: tipoDeImagen(a.buffer).mime }));
  const rutas = [];
  try {
    for (const foto of fotos) rutas.push(await guardarImagen(foto.buffer, 'evidencias'));
    await enTransaccion(async (q) => {
      for (const [i, ruta] of rutas.entries()) {
        await q(
          `INSERT INTO dbo.Fotos (Ruta, MimeType, Tipo, OrdenId, SubidaPor) VALUES (@ruta, @mime, 'EVIDENCIA', @o, @u)`,
          { ruta: [sql.NVarChar(260), ruta], mime: [sql.VarChar(30), fotos[i].mime], o: [sql.Int, f.OrdenId], u: [sql.Int, usuario.id] },
        );
      }
    });
  } catch (err) {
    await eliminarArchivos(rutas);
    throw err;
  }
  return solicitudes.detalle(usuario, id);
}

export async function eliminarEvidencia(usuario, id, fotoId) {
  const f = await ordenAbierta(usuario, id);
  const { recordset } = await consulta(
    `DELETE FROM dbo.Fotos OUTPUT DELETED.Ruta WHERE FotoId = @f AND OrdenId = @o AND Tipo = 'EVIDENCIA'`,
    { f: [sql.Int, fotoId], o: [sql.Int, f.OrdenId] },
  );
  if (!recordset.length) throw HttpError.notFound('Foto no encontrada', 'FOTO_NO_ENCONTRADA');
  await eliminarArchivos(recordset.map((r) => r.Ruta));
  return solicitudes.detalle(usuario, id);
}

/** Reemplaza las piezas usadas. Se guarda el precio vigente del catálogo en ese momento. */
export async function guardarPiezas(usuario, id, piezas) {
  const f = await ordenAbierta(usuario, id);
  const ids = [...new Set(piezas.map((p) => p.piezaId))];
  if (ids.length !== piezas.length) throw HttpError.badRequest('Cada pieza debe aparecer una sola vez', 'PIEZA_REPETIDA');

  await enTransaccion(async (q) => {
    await q('DELETE FROM dbo.OrdenPiezas WHERE OrdenId = @o', { o: [sql.Int, f.OrdenId] });
    for (const p of piezas) {
      const { rowsAffected } = await q(
        `INSERT INTO dbo.OrdenPiezas (OrdenId, PiezaId, Cantidad, PrecioUnitario)
         SELECT @o, PiezaId, @c, PrecioUnitario FROM dbo.Piezas WHERE PiezaId = @p AND Activo = 1`,
        { o: [sql.Int, f.OrdenId], p: [sql.Int, p.piezaId], c: [sql.Int, p.cantidad] },
      );
      if (rowsAffected[0] !== 1) throw HttpError.badRequest('Una de las piezas no está en el catálogo', 'PIEZA_INVALIDA');
    }
  });
  return solicitudes.detalle(usuario, id);
}

/** Cierra la orden: la solicitud pasa a Finalizado y el servicio queda en el historial del equipo. */
export async function cerrar(usuario, id) {
  const f = await ordenAbierta(usuario, id);
  const orden = await repo.orden(f);
  const faltantes = [];
  if (!orden.diagnosticoFinal || orden.diagnosticoFinal.trim().length < 10) faltantes.push('el diagnóstico final');
  if (!orden.evidencias.length) faltantes.push('al menos una foto de evidencia');
  if (faltantes.length) {
    throw HttpError.badRequest(`Antes de cerrar registra ${faltantes.join(' y ')}`, 'ORDEN_INCOMPLETA');
  }

  const piezas = orden.piezas.map((p) => `${p.nombre} × ${p.cantidad}`).join(', ');
  const esMantenimiento = /mantenimiento|limpieza/i.test(`${f.FallaPredicha} ${orden.diagnosticoFinal}`);

  await enTransaccion(async (q) => {
    await q('UPDATE dbo.OrdenesTrabajo SET FechaCierre = SYSUTCDATETIME() WHERE OrdenId = @o', { o: [sql.Int, f.OrdenId] });
    await cambiarEstado(q, {
      solicitudId: id,
      actual: 'EN_CAMINO',
      nuevo: 'FINALIZADO',
      usuarioId: usuario.id,
      titulo: 'Servicio finalizado',
      detalle: piezas ? `Piezas: ${piezas}` : 'Sin piezas reemplazadas',
    });
    await equipos.insertarRegistro(q, {
      equipoId: f.EquipoId,
      tipo: esMantenimiento ? 'MANTENIMIENTO' : 'REPARACION',
      titulo: `${esMantenimiento ? 'Mantenimiento' : 'Reparación'}: ${f.FallaPredicha}`.slice(0, 160),
      descripcion: [orden.diagnosticoFinal.trim(), piezas && `Piezas: ${piezas} (${pesos.format(orden.totalPiezas)}).`, `Orden ${orden.folio}.`]
        .filter(Boolean)
        .join('\n')
        .slice(0, 2000),
      solicitudId: id,
      tecnicoId: f.TecnicoId,
      diagnosticoId: f.DiagnosticoId,
    });
    await notificar(q, [f.ClienteId], {
      solicitudId: id,
      titulo: `Servicio ${f.Folio} finalizado`,
      cuerpo: `Consulta el resumen y califica a ${f.TecnicoNombre}.`,
    });
    await notificar(q, await idsAdministradores(q), {
      solicitudId: id,
      titulo: `Orden ${orden.folio} cerrada`,
      cuerpo: `${f.TecnicoNombre} terminó el servicio de ${f.ClienteNombre}.`,
    });
  });
  return solicitudes.detalle(usuario, id);
}

/** El cliente califica al técnico al terminar; la calificación del técnico es el promedio de sus servicios. */
export async function calificar(usuario, id, { calificacion, comentario }) {
  const f = await solicitudes.cargar(usuario, id);
  if (f.Estado !== 'FINALIZADO') throw HttpError.conflict('Solo se califica un servicio terminado', 'SERVICIO_NO_FINALIZADO');
  if (f.Calificacion) throw HttpError.conflict('Ya calificaste este servicio', 'YA_CALIFICADO');

  await enTransaccion(async (q) => {
    await q('UPDATE dbo.Solicitudes SET Calificacion = @c, ComentarioCalificacion = @t WHERE SolicitudId = @id', {
      id: [sql.Int, id],
      c: [sql.TinyInt, calificacion],
      t: [sql.NVarChar(400), comentario ?? null],
    });
    await q(
      `UPDATE dbo.Tecnicos SET Calificacion =
         (SELECT CAST(AVG(CAST(Calificacion AS DECIMAL(4,2))) AS DECIMAL(2,1))
          FROM dbo.Solicitudes WHERE TecnicoId = @t AND Calificacion IS NOT NULL)
       WHERE TecnicoId = @t`,
      { t: [sql.Int, f.TecnicoId] },
    );
    await notificar(q, [f.TecnicoId], {
      solicitudId: id,
      titulo: `Te calificaron con ${'★'.repeat(calificacion)}`,
      cuerpo: comentario || `Servicio ${f.Folio}`,
    });
  });
  return solicitudes.detalle(usuario, id);
}

import { consulta, sql } from '../../config/db.js';

export const ESTADOS_ACTIVOS = ['EN_REVISION', 'COTIZADO', 'EN_CAMINO'];
const PRIORIDAD_API = { BAJA: 'baja', MEDIA: 'media', ALTA: 'alta' };

const BASE = `
  SELECT s.*, d.FallaPredicha, d.EspecialidadId,
         c.Nombre AS ClienteNombre, c.Telefono AS ClienteTelefono, c.Correo AS ClienteCorreo,
         tu.Nombre AS TecnicoNombre, tu.Telefono AS TecnicoTelefono, tt.Calificacion AS TecnicoCalificacion,
         e.Marca, e.Modelo, e.NumeroSerie, e.Tipo AS EquipoTipo, e.Ubicacion AS EquipoUbicacion,
         dir.Alias, dir.Calle, dir.Colonia, dir.Ciudad, dir.CP, dir.Referencias,
         (SELECT SUM(p.Cantidad * p.PrecioUnitario) FROM dbo.Cotizaciones co
            JOIN dbo.CotizacionPartidas p ON p.CotizacionId = co.CotizacionId
          WHERE co.SolicitudId = s.SolicitudId) AS TotalCotizacion,
         (SELECT co.Estado FROM dbo.Cotizaciones co WHERE co.SolicitudId = s.SolicitudId) AS EstadoCotizacion
  FROM dbo.Solicitudes s
  JOIN dbo.Diagnosticos d ON d.DiagnosticoId = s.DiagnosticoId
  JOIN dbo.Usuarios c ON c.UsuarioId = s.ClienteId
  JOIN dbo.Equipos e ON e.EquipoId = s.EquipoId
  JOIN dbo.Direcciones dir ON dir.DireccionId = s.DireccionId
  LEFT JOIN dbo.Usuarios tu ON tu.UsuarioId = s.TecnicoId
  LEFT JOIN dbo.Tecnicos tt ON tt.TecnicoId = s.TecnicoId`;

export async function buscar(id) {
  const { recordset } = await consulta(`${BASE} WHERE s.SolicitudId = @id`, { id: [sql.Int, id] });
  return recordset[0] ?? null;
}

/** Resumen para listas (bandeja del administrador, "Mis servicios", órdenes del técnico). */
export function aResumenApi(f) {
  return {
    id: f.SolicitudId,
    folio: f.Folio,
    estado: f.Estado,
    prioridad: PRIORIDAD_API[f.Prioridad],
    falla: f.FallaPredicha,
    pedidaPorCliente: f.PedidaPorCliente,
    equipo: { id: f.EquipoId, nombre: `${f.Marca} ${f.Modelo}` },
    clienteNombre: f.ClienteNombre,
    colonia: f.Colonia,
    tecnicoNombre: f.TecnicoNombre,
    ventanaInicio: f.VentanaInicio,
    ventanaFin: f.VentanaFin,
    totalCotizacion: f.TotalCotizacion == null ? null : Number(f.TotalCotizacion),
    fechaCreacion: f.FechaCreacion,
    fechaActualizacion: f.FechaActualizacion,
  };
}

export async function listar({ clienteId, tecnicoId, estados, prioridad, texto } = {}) {
  const filtros = [];
  const p = {};
  if (clienteId) {
    filtros.push('s.ClienteId = @clienteId');
    p.clienteId = [sql.Int, clienteId];
  }
  if (tecnicoId) {
    filtros.push('s.TecnicoId = @tecnicoId');
    p.tecnicoId = [sql.Int, tecnicoId];
  }
  if (estados?.length) {
    filtros.push(`s.Estado IN (${estados.map((_, i) => `@estado${i}`).join(', ')})`);
    estados.forEach((e, i) => (p[`estado${i}`] = [sql.VarChar(12), e]));
  }
  if (prioridad) {
    filtros.push('s.Prioridad = @prioridad');
    p.prioridad = [sql.VarChar(5), prioridad];
  }
  if (texto) {
    filtros.push('(s.Folio LIKE @texto OR c.Nombre LIKE @texto OR e.NumeroSerie LIKE @texto)');
    p.texto = [sql.NVarChar(130), `%${texto}%`];
  }
  const where = filtros.length ? `WHERE ${filtros.join(' AND ')}` : '';
  // Primero lo urgente y lo que espera acción; dentro de cada grupo, lo más reciente.
  const { recordset } = await consulta(
    `${BASE} ${where}
     ORDER BY CASE s.Estado WHEN 'EN_REVISION' THEN 0 WHEN 'COTIZADO' THEN 1 WHEN 'EN_CAMINO' THEN 2 ELSE 3 END,
              CASE s.Prioridad WHEN 'ALTA' THEN 0 WHEN 'MEDIA' THEN 1 ELSE 2 END,
              s.FechaCreacion DESC`,
    p,
  );
  return recordset.map(aResumenApi);
}

export async function eventos(solicitudId) {
  const { recordset } = await consulta(
    `SELECT EventoId, Estado, Titulo, Detalle, Fecha FROM dbo.EventosSolicitud
     WHERE SolicitudId = @id ORDER BY Fecha, EventoId`,
    { id: [sql.Int, solicitudId] },
  );
  return recordset.map((f) => ({ id: f.EventoId, estado: f.Estado, titulo: f.Titulo, detalle: f.Detalle, fecha: f.Fecha }));
}

export async function cotizacion(solicitudId, q = consulta) {
  const { recordset } = await q('SELECT * FROM dbo.Cotizaciones WHERE SolicitudId = @id', { id: [sql.Int, solicitudId] });
  const c = recordset[0];
  if (!c) return null;
  const partidas = await q(
    'SELECT PartidaId, Concepto, Cantidad, PrecioUnitario FROM dbo.CotizacionPartidas WHERE CotizacionId = @id ORDER BY PartidaId',
    { id: [sql.Int, c.CotizacionId] },
  );
  const lista = partidas.recordset.map((p) => ({
    id: p.PartidaId,
    concepto: p.Concepto,
    cantidad: p.Cantidad,
    precioUnitario: Number(p.PrecioUnitario),
    importe: p.Cantidad * Number(p.PrecioUnitario),
  }));
  return {
    id: c.CotizacionId,
    estado: c.Estado,
    generadaAuto: c.GeneradaAuto,
    partidas: lista,
    total: lista.reduce((s, p) => s + p.importe, 0),
    fechaEnvio: c.FechaEnvio,
    fechaRespuesta: c.FechaRespuesta,
    comentarioCliente: c.ComentarioCliente,
  };
}

export async function crear(q, { diagnostico, direccionId, descripcion, pedidaPorCliente }) {
  const { recordset } = await q(
    `INSERT INTO dbo.Solicitudes (DiagnosticoId, ClienteId, EquipoId, DireccionId, Descripcion, Prioridad, PedidaPorCliente)
     OUTPUT INSERTED.SolicitudId, INSERTED.Folio
     VALUES (@diagnosticoId, @clienteId, @equipoId, @direccionId, @descripcion, @prioridad, @pedida)`,
    {
      diagnosticoId: [sql.Int, diagnostico.id],
      clienteId: [sql.Int, diagnostico.clienteId],
      equipoId: [sql.Int, diagnostico.equipoId],
      direccionId: [sql.Int, direccionId],
      descripcion: [sql.NVarChar(1000), descripcion ?? null],
      prioridad: [sql.VarChar(5), diagnostico.prioridad.toUpperCase()],
      pedida: [sql.Bit, pedidaPorCliente],
    },
  );
  return recordset[0];
}

/** Reemplaza las partidas de la cotización (la crea si no existe). */
export async function guardarPartidas(q, solicitudId, partidas, { generadaAuto }) {
  const { recordset } = await q(
    `MERGE dbo.Cotizaciones AS destino
     USING (SELECT @solicitudId AS SolicitudId) AS origen ON destino.SolicitudId = origen.SolicitudId
     WHEN MATCHED THEN UPDATE SET GeneradaAuto = @auto
     WHEN NOT MATCHED THEN INSERT (SolicitudId, GeneradaAuto) VALUES (@solicitudId, @auto)
     OUTPUT INSERTED.CotizacionId;`,
    { solicitudId: [sql.Int, solicitudId], auto: [sql.Bit, generadaAuto] },
  );
  const cotizacionId = recordset[0].CotizacionId;
  await q('DELETE FROM dbo.CotizacionPartidas WHERE CotizacionId = @id', { id: [sql.Int, cotizacionId] });
  for (const p of partidas) {
    await q(
      `INSERT INTO dbo.CotizacionPartidas (CotizacionId, Concepto, Cantidad, PrecioUnitario)
       VALUES (@id, @concepto, @cantidad, @precio)`,
      {
        id: [sql.Int, cotizacionId],
        concepto: [sql.NVarChar(160), p.concepto],
        cantidad: [sql.Int, p.cantidad],
        precio: [sql.Decimal(10, 2), p.precioUnitario],
      },
    );
  }
}

export async function actualizarCotizacion(q, solicitudId, { estado, validadaPor, comentario }) {
  await q(
    `UPDATE dbo.Cotizaciones SET
       Estado = @estado,
       ValidadaPor = COALESCE(@validadaPor, ValidadaPor),
       FechaEnvio = CASE WHEN @estado = 'ENVIADA' THEN SYSUTCDATETIME() ELSE FechaEnvio END,
       FechaRespuesta = CASE WHEN @estado IN ('APROBADA', 'RECHAZADA') THEN SYSUTCDATETIME() ELSE FechaRespuesta END,
       ComentarioCliente = COALESCE(@comentario, ComentarioCliente)
     WHERE SolicitudId = @id`,
    {
      id: [sql.Int, solicitudId],
      estado: [sql.VarChar(10), estado],
      validadaPor: [sql.Int, validadaPor ?? null],
      comentario: [sql.NVarChar(400), comentario ?? null],
    },
  );
}

/** Técnicos activos con los datos que usa el ranking de RF-04. */
export async function candidatos(especialidadId) {
  const { recordset } = await consulta(
    `SELECT u.UsuarioId, u.Nombre, t.Disponible, t.Calificacion,
            CASE WHEN EXISTS (SELECT 1 FROM dbo.TecnicoEspecialidades te
                              WHERE te.TecnicoId = t.TecnicoId AND te.EspecialidadId = @esp) THEN 1 ELSE 0 END AS TieneEspecialidad,
            (SELECT COUNT(*) FROM dbo.Solicitudes s
             WHERE s.TecnicoId = t.TecnicoId AND s.Estado IN ('EN_REVISION', 'COTIZADO', 'EN_CAMINO')) AS Activas,
            (SELECT STRING_AGG(es.Nombre, ', ') FROM dbo.TecnicoEspecialidades te
               JOIN dbo.Especialidades es ON es.EspecialidadId = te.EspecialidadId
             WHERE te.TecnicoId = t.TecnicoId) AS Especialidades
     FROM dbo.Tecnicos t JOIN dbo.Usuarios u ON u.UsuarioId = t.TecnicoId
     WHERE u.Activo = 1`,
    { esp: [sql.Int, especialidadId ?? null] },
  );
  return recordset;
}

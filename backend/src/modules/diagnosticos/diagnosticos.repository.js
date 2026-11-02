import { consulta, sql } from '../../config/db.js';

const PRIORIDAD_API = { BAJA: 'baja', MEDIA: 'media', ALTA: 'alta' };

export function aDiagnosticoApi(f, fotos = []) {
  return {
    id: f.DiagnosticoId,
    equipoId: f.EquipoId,
    clienteId: f.ClienteId,
    sintomas: JSON.parse(f.Sintomas),
    respuestas: JSON.parse(f.Respuestas),
    falla: f.FallaPredicha,
    descripcion: f.Descripcion,
    confianza: Number(f.Confianza),
    causas: JSON.parse(f.Causas),
    requiereTecnico: f.RequiereTecnico,
    pasosAutoayuda: JSON.parse(f.PasosAutoayuda),
    herramientas: JSON.parse(f.Herramientas),
    especialidad: f.EspecialidadClave ? { clave: f.EspecialidadClave, nombre: f.EspecialidadNombre } : null,
    prioridad: PRIORIDAD_API[f.Prioridad],
    costoMin: Number(f.CostoMin),
    costoMax: Number(f.CostoMax),
    advertencia: f.Advertencia,
    analisisFoto: f.AnalisisFoto,
    modelo: f.ModeloIA,
    resultado: f.Resultado,
    fechaCreacion: f.FechaCreacion,
    fotos: fotos.map((foto) => ({ id: foto.FotoId, url: `/api/v1/fotos/${foto.FotoId}` })),
  };
}

export async function buscarPorId(id) {
  const { recordset } = await consulta(
    `SELECT d.*, e.Clave AS EspecialidadClave, e.Nombre AS EspecialidadNombre
     FROM dbo.Diagnosticos d
     LEFT JOIN dbo.Especialidades e ON e.EspecialidadId = d.EspecialidadId
     WHERE d.DiagnosticoId = @id`,
    { id: [sql.Int, id] },
  );
  const fila = recordset[0];
  if (!fila) return null;
  const fotos = await consulta('SELECT FotoId FROM dbo.Fotos WHERE DiagnosticoId = @id ORDER BY FotoId', {
    id: [sql.Int, id],
  });
  return { fila, fotos: fotos.recordset };
}

export async function crear(q, { equipoId, clienteId, sintomas, respuestas, resultado }) {
  const { recordset } = await q(
    `INSERT INTO dbo.Diagnosticos
       (EquipoId, ClienteId, Sintomas, Respuestas, FallaPredicha, Descripcion, Confianza, Causas, RequiereTecnico,
        EspecialidadId, Prioridad, PasosAutoayuda, Herramientas, CostoMin, CostoMax, Advertencia, AnalisisFoto,
        ModeloIA, RespuestaIA)
     OUTPUT INSERTED.DiagnosticoId
     VALUES
       (@equipoId, @clienteId, @sintomas, @respuestas, @falla, @descripcion, @confianza, @causas, @requiere,
        (SELECT EspecialidadId FROM dbo.Especialidades WHERE Clave = @especialidad), @prioridad, @pasos,
        @herramientas, @costoMin, @costoMax, @advertencia, @analisisFoto, @modelo, @cruda)`,
    {
      equipoId: [sql.Int, equipoId],
      clienteId: [sql.Int, clienteId],
      sintomas: [sql.NVarChar(sql.MAX), JSON.stringify(sintomas)],
      respuestas: [sql.NVarChar(sql.MAX), JSON.stringify(respuestas)],
      falla: [sql.NVarChar(160), resultado.falla],
      descripcion: [sql.NVarChar(1000), resultado.descripcion],
      confianza: [sql.Decimal(4, 3), resultado.confianza],
      causas: [sql.NVarChar(sql.MAX), JSON.stringify(resultado.causas)],
      requiere: [sql.Bit, resultado.requiereTecnico],
      especialidad: [sql.VarChar(20), resultado.especialidad],
      prioridad: [sql.VarChar(5), resultado.prioridad],
      pasos: [sql.NVarChar(sql.MAX), JSON.stringify(resultado.pasosAutoayuda)],
      herramientas: [sql.NVarChar(sql.MAX), JSON.stringify(resultado.herramientas)],
      costoMin: [sql.Decimal(10, 2), resultado.costoMin],
      costoMax: [sql.Decimal(10, 2), resultado.costoMax],
      advertencia: [sql.NVarChar(400), resultado.advertencia],
      analisisFoto: [sql.NVarChar(600), resultado.analisisFoto],
      modelo: [sql.NVarChar(60), resultado.modelo],
      cruda: [sql.NVarChar(sql.MAX), resultado.respuestaCruda ? JSON.stringify(resultado.respuestaCruda) : null],
    },
  );
  return recordset[0].DiagnosticoId;
}

export async function agregarFoto(q, { diagnosticoId, ruta, mimeType, usuarioId }) {
  await q(
    `INSERT INTO dbo.Fotos (Ruta, MimeType, Tipo, DiagnosticoId, SubidaPor)
     VALUES (@ruta, @mime, 'DIAGNOSTICO', @diagnosticoId, @usuarioId)`,
    {
      ruta: [sql.NVarChar(260), ruta],
      mime: [sql.VarChar(30), mimeType],
      diagnosticoId: [sql.Int, diagnosticoId],
      usuarioId: [sql.Int, usuarioId],
    },
  );
}

export async function marcarResultado(q, id, resultado) {
  await q('UPDATE dbo.Diagnosticos SET Resultado = @resultado WHERE DiagnosticoId = @id', {
    id: [sql.Int, id],
    resultado: [sql.VarChar(20), resultado],
  });
}

/** Foto con el dueño del diagnóstico al que pertenece, para validar permisos antes de servirla. */
export async function buscarFoto(fotoId) {
  const { recordset } = await consulta(
    `SELECT f.FotoId, f.Ruta, f.MimeType, d.ClienteId
     FROM dbo.Fotos f LEFT JOIN dbo.Diagnosticos d ON d.DiagnosticoId = f.DiagnosticoId
     WHERE f.FotoId = @id`,
    { id: [sql.Int, fotoId] },
  );
  return recordset[0] ?? null;
}

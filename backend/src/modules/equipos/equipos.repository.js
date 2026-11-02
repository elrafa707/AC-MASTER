import { consulta, sql } from '../../config/db.js';

const COLUMNAS = `e.EquipoId, e.ClienteId, e.NumeroSerie, e.Marca, e.Modelo, e.Tipo, e.CapacidadBTU,
  e.Refrigerante, e.Ubicacion, e.FechaInstalacion, e.FechaRegistro, u.Nombre AS ClienteNombre`;

const fechaISO = (d) => (d ? d.toISOString().slice(0, 10) : null);

export function aEquipoApi(f) {
  return {
    id: f.EquipoId,
    clienteId: f.ClienteId,
    clienteNombre: f.ClienteNombre,
    numeroSerie: f.NumeroSerie,
    marca: f.Marca,
    modelo: f.Modelo,
    tipo: f.Tipo,
    capacidadBTU: f.CapacidadBTU,
    refrigerante: f.Refrigerante,
    ubicacion: f.Ubicacion,
    fechaInstalacion: fechaISO(f.FechaInstalacion),
    fechaRegistro: f.FechaRegistro,
  };
}

export function aRegistroApi(f) {
  return {
    id: f.RegistroId,
    tipo: f.Tipo,
    titulo: f.Titulo,
    descripcion: f.Descripcion,
    fecha: f.Fecha,
    diagnosticoId: f.DiagnosticoId,
    solicitudId: f.SolicitudId,
    tecnicoNombre: f.TecnicoNombre,
  };
}

export async function listarDeCliente(clienteId) {
  const { recordset } = await consulta(
    `SELECT ${COLUMNAS},
            (SELECT MAX(h.Fecha) FROM dbo.HistorialEquipo h WHERE h.EquipoId = e.EquipoId) AS UltimoRegistro
     FROM dbo.Equipos e JOIN dbo.Usuarios u ON u.UsuarioId = e.ClienteId
     WHERE e.ClienteId = @clienteId
     ORDER BY e.FechaRegistro DESC`,
    { clienteId: [sql.Int, clienteId] },
  );
  return recordset.map((f) => ({ ...aEquipoApi(f), ultimoRegistro: f.UltimoRegistro }));
}

export async function buscarPorId(id) {
  const { recordset } = await consulta(
    `SELECT ${COLUMNAS} FROM dbo.Equipos e JOIN dbo.Usuarios u ON u.UsuarioId = e.ClienteId WHERE e.EquipoId = @id`,
    { id: [sql.Int, id] },
  );
  return recordset[0] ?? null;
}

export async function buscarPorSerie(numeroSerie) {
  const { recordset } = await consulta(
    `SELECT ${COLUMNAS} FROM dbo.Equipos e JOIN dbo.Usuarios u ON u.UsuarioId = e.ClienteId WHERE e.NumeroSerie = @serie`,
    { serie: [sql.NVarChar(60), numeroSerie] },
  );
  return recordset[0] ?? null;
}

export async function historial(equipoId) {
  const { recordset } = await consulta(
    `SELECT h.RegistroId, h.Tipo, h.Titulo, h.Descripcion, h.Fecha, h.DiagnosticoId, h.SolicitudId,
            t.Nombre AS TecnicoNombre
     FROM dbo.HistorialEquipo h
     LEFT JOIN dbo.Usuarios t ON t.UsuarioId = h.TecnicoId
     WHERE h.EquipoId = @equipoId
     ORDER BY h.Fecha DESC, h.RegistroId DESC`,
    { equipoId: [sql.Int, equipoId] },
  );
  return recordset.map(aRegistroApi);
}

/** Inserta el equipo y, si trae fecha de instalación, su primer registro en el historial. */
export async function crear(q, clienteId, datos) {
  const { recordset } = await q(
    `INSERT INTO dbo.Equipos (ClienteId, NumeroSerie, Marca, Modelo, Tipo, CapacidadBTU, Refrigerante, Ubicacion, FechaInstalacion)
     OUTPUT INSERTED.EquipoId
     VALUES (@clienteId, @serie, @marca, @modelo, @tipo, @btu, @refrigerante, @ubicacion, @fecha)`,
    {
      clienteId: [sql.Int, clienteId],
      serie: [sql.NVarChar(60), datos.numeroSerie],
      marca: [sql.NVarChar(60), datos.marca],
      modelo: [sql.NVarChar(80), datos.modelo],
      tipo: [sql.NVarChar(40), datos.tipo],
      btu: [sql.Int, datos.capacidadBTU ?? null],
      refrigerante: [sql.NVarChar(20), datos.refrigerante ?? null],
      ubicacion: [sql.NVarChar(80), datos.ubicacion ?? null],
      fecha: [sql.Date, datos.fechaInstalacion ?? null],
    },
  );
  const equipoId = recordset[0].EquipoId;

  if (datos.fechaInstalacion) {
    await insertarRegistro(q, {
      equipoId,
      tipo: 'INSTALACION',
      titulo: 'Instalación del equipo',
      descripcion: 'Fecha de instalación indicada por el cliente al registrar el equipo.',
      fecha: new Date(`${datos.fechaInstalacion}T12:00:00Z`),
    });
  }
  return equipoId;
}

export async function insertarRegistro(q, { equipoId, tipo, titulo, descripcion, diagnosticoId, fecha }) {
  await q(
    `INSERT INTO dbo.HistorialEquipo (EquipoId, Tipo, Titulo, Descripcion, DiagnosticoId, Fecha)
     VALUES (@equipoId, @tipo, @titulo, @descripcion, @diagnosticoId, COALESCE(@fecha, SYSUTCDATETIME()))`,
    {
      equipoId: [sql.Int, equipoId],
      tipo: [sql.VarChar(15), tipo],
      titulo: [sql.NVarChar(160), titulo],
      descripcion: [sql.NVarChar(2000), descripcion ?? null],
      diagnosticoId: [sql.Int, diagnosticoId ?? null],
      fecha: [sql.DateTime2(0), fecha ?? null],
    },
  );
}

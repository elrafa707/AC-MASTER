import { Router } from 'express';
import { z } from 'zod';
import { consulta, enTransaccion, sql } from '../../config/db.js';
import { autenticar, permitir } from '../../middlewares/auth.js';
import { validar } from '../../middlewares/validate.js';
import { HttpError } from '../../utils/http-error.js';
import { hashPassword } from '../auth/auth.service.js';
import { esquemaRegistro } from '../auth/auth.schemas.js';
import { esquemaIdRuta } from '../equipos/equipos.schemas.js';
import { ESPECIALIDADES } from '../../services/asistente/esquema.js';
import { ESTADOS } from '../solicitudes/flujo.js';
import * as solicitudes from '../solicitudes/solicitudes.repository.js';
import * as servicio from '../solicitudes/solicitudes.service.js';

export const adminRouter = Router();
const soloAdmin = [autenticar, permitir('administrador')];

const VIOLACION_UNIQUE = new Set([2627, 2601]);
const HORA = 60 * 60 * 1000;

/* ───────────────────────────── Solicitudes (interfaz 5) ───────────────────────────── */

const esquemaFiltros = z.object({
  estado: z.enum(ESTADOS).optional(),
  prioridad: z.enum(['BAJA', 'MEDIA', 'ALTA']).optional(),
  q: z.string().trim().max(120).optional(),
});

const esquemaAsignacion = z
  .object({
    tecnicoId: z.number().int().positive('Elige un técnico'),
    ventanaInicio: z.coerce.date('Fecha de inicio inválida'),
    ventanaFin: z.coerce.date('Fecha de fin inválida'),
  })
  .refine((v) => v.ventanaInicio.getTime() > Date.now() - 10 * 60 * 1000, {
    message: 'La visita no puede empezar en el pasado',
    path: ['ventanaInicio'],
  })
  .refine((v) => v.ventanaFin > v.ventanaInicio && v.ventanaFin - v.ventanaInicio <= 8 * HORA, {
    message: 'La ventana debe durar entre unos minutos y 8 horas',
    path: ['ventanaFin'],
  });

const esquemaPartidas = z.object({
  partidas: z
    .array(
      z.object({
        concepto: z.string().trim().min(3, 'Describe la partida').max(160),
        cantidad: z.number().int().min(1).max(99),
        precioUnitario: z.number().min(0).max(200000),
      }),
    )
    .min(1, 'Agrega al menos una partida')
    .max(20),
});

adminRouter.get('/admin/resumen', ...soloAdmin, async (_req, res) => {
  const { recordset } = await consulta(
    `SELECT
       (SELECT COUNT(*) FROM dbo.Solicitudes WHERE Estado = 'EN_REVISION') AS enRevision,
       (SELECT COUNT(*) FROM dbo.Solicitudes WHERE Estado = 'COTIZADO') AS cotizadas,
       (SELECT COUNT(*) FROM dbo.Solicitudes WHERE Estado = 'EN_CAMINO') AS enCamino,
       (SELECT COUNT(*) FROM dbo.Solicitudes WHERE Estado = 'FINALIZADO') AS finalizadas,
       (SELECT COUNT(*) FROM dbo.Solicitudes WHERE Estado = 'EN_REVISION' AND Prioridad = 'ALTA') AS urgentes,
       (SELECT COUNT(*) FROM dbo.Tecnicos t JOIN dbo.Usuarios u ON u.UsuarioId = t.TecnicoId
         WHERE u.Activo = 1 AND t.Disponible = 1) AS tecnicosDisponibles,
       (SELECT COUNT(*) FROM dbo.Tecnicos t JOIN dbo.Usuarios u ON u.UsuarioId = t.TecnicoId
         WHERE u.Activo = 1) AS tecnicosActivos`,
  );
  res.json(recordset[0]);
});

adminRouter.get('/admin/solicitudes', ...soloAdmin, validar(esquemaFiltros, 'query'), async (req, res) => {
  const { estado, prioridad, q } = req.consulta;
  res.json(await solicitudes.listar({ estados: estado ? [estado] : null, prioridad, texto: q }));
});

adminRouter.get('/admin/solicitudes/:id/tecnicos-recomendados', ...soloAdmin, validar(esquemaIdRuta, 'params'), async (req, res) => {
  res.json(await servicio.recomendados(req.params.id));
});

adminRouter.post(
  '/admin/solicitudes/:id/asignar',
  ...soloAdmin,
  validar(esquemaIdRuta, 'params'),
  validar(esquemaAsignacion),
  async (req, res) => {
    res.json(await servicio.asignar({ usuario: req.usuario, id: req.params.id, ...req.body }));
  },
);

adminRouter.put(
  '/admin/solicitudes/:id/cotizacion',
  ...soloAdmin,
  validar(esquemaIdRuta, 'params'),
  validar(esquemaPartidas),
  async (req, res) => {
    res.json(await servicio.guardarCotizacion({ usuario: req.usuario, id: req.params.id, partidas: req.body.partidas }));
  },
);

adminRouter.post('/admin/solicitudes/:id/cotizacion/enviar', ...soloAdmin, validar(esquemaIdRuta, 'params'), async (req, res) => {
  res.json(await servicio.enviarCotizacion({ usuario: req.usuario, id: req.params.id }));
});

/* ───────────────────────────── Técnicos ───────────────────────────── */

const listaEspecialidades = z.array(z.enum(ESPECIALIDADES)).min(1, 'Elige al menos una especialidad').max(ESPECIALIDADES.length);

const esquemaNuevoTecnico = esquemaRegistro.extend({ especialidades: listaEspecialidades });
const esquemaEdicionTecnico = z
  .object({ especialidades: listaEspecialidades.optional(), activo: z.boolean().optional() })
  .refine((v) => v.especialidades || v.activo !== undefined, 'No hay cambios');

async function listarTecnicos(id) {
  const { recordset } = await consulta(
    `SELECT u.UsuarioId, u.Nombre, u.Correo, u.Telefono, u.Activo, t.Disponible, t.Calificacion,
            (SELECT STRING_AGG(es.Clave, ',') FROM dbo.TecnicoEspecialidades te
               JOIN dbo.Especialidades es ON es.EspecialidadId = te.EspecialidadId WHERE te.TecnicoId = t.TecnicoId) AS Claves,
            (SELECT COUNT(*) FROM dbo.Solicitudes s WHERE s.TecnicoId = t.TecnicoId
               AND s.Estado IN ('EN_REVISION', 'COTIZADO', 'EN_CAMINO')) AS Activas,
            (SELECT COUNT(*) FROM dbo.Solicitudes s WHERE s.TecnicoId = t.TecnicoId AND s.Estado = 'FINALIZADO') AS Finalizadas
     FROM dbo.Tecnicos t JOIN dbo.Usuarios u ON u.UsuarioId = t.TecnicoId
     ${id ? 'WHERE u.UsuarioId = @id' : ''}
     ORDER BY u.Activo DESC, u.Nombre`,
    { id: [sql.Int, id ?? null] },
  );
  return recordset.map((f) => ({
    id: f.UsuarioId,
    nombre: f.Nombre,
    correo: f.Correo,
    telefono: f.Telefono,
    activo: f.Activo,
    disponible: f.Disponible,
    calificacion: Number(f.Calificacion),
    especialidades: f.Claves ? f.Claves.split(',') : [],
    serviciosActivos: f.Activas,
    serviciosFinalizados: f.Finalizadas,
  }));
}

async function reemplazarEspecialidades(q, tecnicoId, claves) {
  await q('DELETE FROM dbo.TecnicoEspecialidades WHERE TecnicoId = @t', { t: [sql.Int, tecnicoId] });
  for (const clave of claves) {
    await q(
      `INSERT INTO dbo.TecnicoEspecialidades (TecnicoId, EspecialidadId)
       SELECT @t, EspecialidadId FROM dbo.Especialidades WHERE Clave = @clave`,
      { t: [sql.Int, tecnicoId], clave: [sql.VarChar(20), clave] },
    );
  }
}

adminRouter.get('/especialidades', autenticar, async (_req, res) => {
  const { recordset } = await consulta('SELECT Clave, Nombre FROM dbo.Especialidades ORDER BY Nombre');
  res.json(recordset.map((f) => ({ clave: f.Clave, nombre: f.Nombre })));
});

adminRouter.get('/admin/tecnicos', ...soloAdmin, async (_req, res) => {
  res.json(await listarTecnicos());
});

adminRouter.post('/admin/tecnicos', ...soloAdmin, validar(esquemaNuevoTecnico), async (req, res) => {
  const { nombre, correo, telefono, password, especialidades } = req.body;
  const passwordHash = await hashPassword(password);
  try {
    const id = await enTransaccion(async (q) => {
      const { recordset } = await q(
        `INSERT INTO dbo.Usuarios (Nombre, Correo, Telefono, PasswordHash, Rol)
         OUTPUT INSERTED.UsuarioId VALUES (@nombre, @correo, @telefono, @hash, 'TECNICO')`,
        {
          nombre: [sql.NVarChar(120), nombre],
          correo: [sql.NVarChar(160), correo],
          telefono: [sql.NVarChar(20), telefono ?? null],
          hash: [sql.NVarChar(100), passwordHash],
        },
      );
      const tecnicoId = recordset[0].UsuarioId;
      await q('INSERT INTO dbo.Tecnicos (TecnicoId) VALUES (@t)', { t: [sql.Int, tecnicoId] });
      await reemplazarEspecialidades(q, tecnicoId, especialidades);
      return tecnicoId;
    });
    res.status(201).json((await listarTecnicos(id))[0]);
  } catch (err) {
    if (VIOLACION_UNIQUE.has(err.number)) throw HttpError.conflict('Ya existe una cuenta con ese correo', 'CORREO_REGISTRADO');
    throw err;
  }
});

adminRouter.patch(
  '/admin/tecnicos/:id',
  ...soloAdmin,
  validar(esquemaIdRuta, 'params'),
  validar(esquemaEdicionTecnico),
  async (req, res) => {
    const [actual] = await listarTecnicos(req.params.id);
    if (!actual) throw HttpError.notFound('Técnico no encontrado', 'TECNICO_NO_ENCONTRADO');
    if (req.body.activo === false && actual.serviciosActivos > 0) {
      throw HttpError.conflict('El técnico tiene servicios activos. Reasígnalos o termínalos antes de desactivarlo.', 'TECNICO_CON_SERVICIOS');
    }
    await enTransaccion(async (q) => {
      if (req.body.especialidades) await reemplazarEspecialidades(q, req.params.id, req.body.especialidades);
      if (req.body.activo !== undefined) {
        await q('UPDATE dbo.Usuarios SET Activo = @a WHERE UsuarioId = @id', { id: [sql.Int, req.params.id], a: [sql.Bit, req.body.activo] });
      }
    });
    res.json((await listarTecnicos(req.params.id))[0]);
  },
);

/* ───────────────────────────── Clientes ───────────────────────────── */

adminRouter.get('/admin/clientes', ...soloAdmin, validar(z.object({ q: z.string().trim().max(120).optional() }), 'query'), async (req, res) => {
  const { recordset } = await consulta(
    `SELECT u.UsuarioId, u.Nombre, u.Correo, u.Telefono, u.Activo, u.FechaRegistro,
            (SELECT COUNT(*) FROM dbo.Equipos e WHERE e.ClienteId = u.UsuarioId) AS Equipos,
            (SELECT COUNT(*) FROM dbo.Solicitudes s WHERE s.ClienteId = u.UsuarioId) AS Solicitudes
     FROM dbo.Usuarios u
     WHERE u.Rol = 'CLIENTE' AND (@q IS NULL OR u.Nombre LIKE @patron OR u.Correo LIKE @patron)
     ORDER BY u.Nombre`,
    { q: [sql.NVarChar(120), req.consulta.q || null], patron: [sql.NVarChar(130), `%${req.consulta.q ?? ''}%`] },
  );
  res.json(
    recordset.map((f) => ({
      id: f.UsuarioId,
      nombre: f.Nombre,
      correo: f.Correo,
      telefono: f.Telefono,
      activo: f.Activo,
      fechaRegistro: f.FechaRegistro,
      equipos: f.Equipos,
      solicitudes: f.Solicitudes,
    })),
  );
});

adminRouter.patch(
  '/admin/clientes/:id',
  ...soloAdmin,
  validar(esquemaIdRuta, 'params'),
  validar(z.object({ activo: z.boolean() })),
  async (req, res) => {
    const { rowsAffected } = await consulta(`UPDATE dbo.Usuarios SET Activo = @a WHERE UsuarioId = @id AND Rol = 'CLIENTE'`, {
      id: [sql.Int, req.params.id],
      a: [sql.Bit, req.body.activo],
    });
    if (rowsAffected[0] !== 1) throw HttpError.notFound('Cliente no encontrado', 'CLIENTE_NO_ENCONTRADO');
    res.json({ id: req.params.id, activo: req.body.activo });
  },
);

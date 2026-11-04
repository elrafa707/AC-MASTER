import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { consulta, sql } from '../../config/db.js';
import { autenticar, permitir } from '../../middlewares/auth.js';
import { validar } from '../../middlewares/validate.js';
import { HttpError } from '../../utils/http-error.js';
import { esquemaIdRuta } from '../equipos/equipos.schemas.js';
import * as solicitudesRepo from '../solicitudes/solicitudes.repository.js';
import * as solicitudes from '../solicitudes/solicitudes.service.js';
import * as servicio from './ordenes.service.js';

export const ordenesRouter = Router();
const soloTecnico = [autenticar, permitir('tecnico')];
const soloAdmin = [autenticar, permitir('administrador')];

const texto = (max) => z.preprocess((v) => (v === '' ? undefined : v), z.string().trim().max(max).optional());

const esquemaRegistro = z
  .object({ diagnosticoFinal: texto(2000), notas: texto(2000) })
  .refine((v) => v.diagnosticoFinal !== undefined || v.notas !== undefined, 'No hay cambios');

const esquemaPiezas = z.object({
  piezas: z.array(z.object({ piezaId: z.number().int().positive(), cantidad: z.number().int().min(1).max(50) })).max(30),
});

const esquemaRutaFoto = z.object({ id: z.coerce.number().int().positive(), fotoId: z.coerce.number().int().positive() });

const subida = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 4 * 1024 * 1024, files: 3 },
  fileFilter: (_req, archivo, cb) =>
    ['image/jpeg', 'image/png', 'image/webp'].includes(archivo.mimetype)
      ? cb(null, true)
      : cb(HttpError.badRequest('Solo se aceptan fotos JPG, PNG o WebP', 'ARCHIVO_INVALIDO')),
});

function recibirEvidencias(req, res, next) {
  subida.array('fotos', 3)(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      return next(HttpError.badRequest(err.code === 'LIMIT_FILE_SIZE' ? 'Cada foto debe pesar menos de 4 MB' : 'Puedes subir hasta 3 fotos a la vez', 'ARCHIVO_INVALIDO'));
    }
    next(err);
  });
}

/* ───────────────────────────── Técnico (interfaz 6) ───────────────────────────── */

ordenesRouter.get('/tecnico/ordenes', ...soloTecnico, validar(z.object({ vista: z.enum(['activas', 'finalizadas']).default('activas') }), 'query'), async (req, res) => {
  const estados = req.consulta.vista === 'activas' ? ['EN_CAMINO'] : ['FINALIZADO'];
  const lista = await solicitudesRepo.listar({ tecnicoId: req.usuario.id, estados });
  // Las activas, de la visita más próxima a la más lejana.
  if (req.consulta.vista === 'activas') lista.sort((a, b) => new Date(a.ventanaInicio) - new Date(b.ventanaInicio));
  res.json(lista);
});

ordenesRouter.get('/tecnico/disponibilidad', ...soloTecnico, async (req, res) => {
  res.json(await servicio.disponibilidad(req.usuario));
});

ordenesRouter.put('/tecnico/disponibilidad', ...soloTecnico, validar(z.object({ disponible: z.boolean() })), async (req, res) => {
  res.json(await servicio.cambiarDisponibilidad(req.usuario, req.body.disponible));
});

ordenesRouter.post('/tecnico/ordenes/:id/llegada', ...soloTecnico, validar(esquemaIdRuta, 'params'), async (req, res) => {
  res.json(await servicio.registrarLlegada(req.usuario, req.params.id));
});

ordenesRouter.patch('/tecnico/ordenes/:id', ...soloTecnico, validar(esquemaIdRuta, 'params'), validar(esquemaRegistro), async (req, res) => {
  res.json(await servicio.guardarRegistro(req.usuario, req.params.id, req.body));
});

ordenesRouter.post('/tecnico/ordenes/:id/evidencias', ...soloTecnico, validar(esquemaIdRuta, 'params'), recibirEvidencias, async (req, res) => {
  res.status(201).json(await servicio.agregarEvidencias(req.usuario, req.params.id, req.files ?? []));
});

ordenesRouter.delete('/tecnico/ordenes/:id/evidencias/:fotoId', ...soloTecnico, validar(esquemaRutaFoto, 'params'), async (req, res) => {
  res.json(await servicio.eliminarEvidencia(req.usuario, req.params.id, req.params.fotoId));
});

ordenesRouter.put('/tecnico/ordenes/:id/piezas', ...soloTecnico, validar(esquemaIdRuta, 'params'), validar(esquemaPiezas), async (req, res) => {
  res.json(await servicio.guardarPiezas(req.usuario, req.params.id, req.body.piezas));
});

ordenesRouter.post('/tecnico/ordenes/:id/cerrar', ...soloTecnico, validar(esquemaIdRuta, 'params'), async (req, res) => {
  res.json(await servicio.cerrar(req.usuario, req.params.id));
});

/* ───────────────────────────── Cliente ───────────────────────────── */

ordenesRouter.post(
  '/solicitudes/:id/calificar',
  autenticar,
  permitir('cliente'),
  validar(esquemaIdRuta, 'params'),
  validar(z.object({ calificacion: z.number().int().min(1, 'Elige de 1 a 5 estrellas').max(5), comentario: texto(400) })),
  async (req, res) => {
    res.json(await servicio.calificar(req.usuario, req.params.id, req.body));
  },
);

/* ───────────────────────────── Catálogo de piezas ───────────────────────────── */

function aPiezaApi(f) {
  return { id: f.PiezaId, codigo: f.Codigo, nombre: f.Nombre, precioUnitario: Number(f.PrecioUnitario), activo: f.Activo };
}

ordenesRouter.get('/piezas', autenticar, permitir('tecnico', 'administrador'), async (_req, res) => {
  const { recordset } = await consulta('SELECT * FROM dbo.Piezas WHERE Activo = 1 ORDER BY Nombre');
  res.json(recordset.map(aPiezaApi));
});

ordenesRouter.get('/admin/piezas', ...soloAdmin, async (_req, res) => {
  const { recordset } = await consulta('SELECT * FROM dbo.Piezas ORDER BY Activo DESC, Nombre');
  res.json(recordset.map(aPiezaApi));
});

const esquemaPieza = z.object({
  codigo: z.string().trim().toUpperCase().regex(/^[A-Z0-9-]{3,30}$/, 'Usa de 3 a 30 letras, números o guiones'),
  nombre: z.string().trim().min(3, 'Escribe el nombre').max(120),
  precioUnitario: z.number().min(0).max(200000),
});

ordenesRouter.post('/admin/piezas', ...soloAdmin, validar(esquemaPieza), async (req, res) => {
  try {
    const { recordset } = await consulta(
      `INSERT INTO dbo.Piezas (Codigo, Nombre, PrecioUnitario) OUTPUT INSERTED.* VALUES (@c, @n, @p)`,
      { c: [sql.VarChar(30), req.body.codigo], n: [sql.NVarChar(120), req.body.nombre], p: [sql.Decimal(10, 2), req.body.precioUnitario] },
    );
    res.status(201).json(aPiezaApi(recordset[0]));
  } catch (err) {
    if ([2627, 2601].includes(err.number)) throw HttpError.conflict('Ya existe una pieza con ese código', 'CODIGO_REGISTRADO');
    throw err;
  }
});

ordenesRouter.patch(
  '/admin/piezas/:id',
  ...soloAdmin,
  validar(esquemaIdRuta, 'params'),
  validar(esquemaPieza.omit({ codigo: true }).partial().extend({ activo: z.boolean().optional() })),
  async (req, res) => {
    const { nombre, precioUnitario, activo } = req.body;
    const { recordset } = await consulta(
      `UPDATE dbo.Piezas SET Nombre = COALESCE(@n, Nombre), PrecioUnitario = COALESCE(@p, PrecioUnitario), Activo = COALESCE(@a, Activo)
       OUTPUT INSERTED.* WHERE PiezaId = @id`,
      {
        id: [sql.Int, req.params.id],
        n: [sql.NVarChar(120), nombre ?? null],
        p: [sql.Decimal(10, 2), precioUnitario ?? null],
        a: [sql.Bit, activo ?? null],
      },
    );
    if (!recordset.length) throw HttpError.notFound('Pieza no encontrada', 'PIEZA_NO_ENCONTRADA');
    res.json(aPiezaApi(recordset[0]));
  },
);

// El detalle de la orden es el detalle de la solicitud: el técnico asignado ya tiene acceso.
ordenesRouter.get('/tecnico/ordenes/:id', ...soloTecnico, validar(esquemaIdRuta, 'params'), async (req, res) => {
  res.json(await solicitudes.detalle(req.usuario, req.params.id));
});

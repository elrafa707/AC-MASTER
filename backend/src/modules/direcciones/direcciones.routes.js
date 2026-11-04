import { Router } from 'express';
import { z } from 'zod';
import { consulta, enTransaccion, sql } from '../../config/db.js';
import { autenticar, permitir } from '../../middlewares/auth.js';
import { validar } from '../../middlewares/validate.js';

export const direccionesRouter = Router();

const opcional = (esquema) => z.preprocess((v) => (v === '' || v === null ? undefined : v), esquema.optional());

const esquemaDireccion = z.object({
  alias: z.string().trim().min(2, 'Ponle un nombre, como Casa u Oficina').max(40),
  calle: z.string().trim().min(3, 'Escribe la calle y el número').max(160),
  colonia: z.string().trim().min(2, 'Escribe la colonia').max(120),
  ciudad: z.string().trim().min(2, 'Escribe la ciudad').max(80),
  cp: opcional(z.string().trim().regex(/^\d{5}$/, 'El código postal tiene 5 dígitos')),
  referencias: opcional(z.string().trim().max(200)),
  principal: z.boolean().default(false),
});

export function aDireccionApi(f) {
  return {
    id: f.DireccionId,
    alias: f.Alias,
    calle: f.Calle,
    colonia: f.Colonia,
    ciudad: f.Ciudad,
    cp: f.CP,
    referencias: f.Referencias,
    principal: f.EsPrincipal,
  };
}

export async function buscarDireccion(id) {
  const { recordset } = await consulta('SELECT * FROM dbo.Direcciones WHERE DireccionId = @id', { id: [sql.Int, id] });
  return recordset[0] ?? null;
}

async function listar(usuarioId) {
  const { recordset } = await consulta(
    'SELECT * FROM dbo.Direcciones WHERE UsuarioId = @id ORDER BY EsPrincipal DESC, DireccionId',
    { id: [sql.Int, usuarioId] },
  );
  return recordset.map(aDireccionApi);
}

direccionesRouter.get('/me/direcciones', autenticar, permitir('cliente'), async (req, res) => {
  res.json(await listar(req.usuario.id));
});

direccionesRouter.post('/me/direcciones', autenticar, permitir('cliente'), validar(esquemaDireccion), async (req, res) => {
  const d = req.body;
  const id = await enTransaccion(async (q) => {
    const { recordset: existentes } = await q('SELECT COUNT(*) AS n FROM dbo.Direcciones WHERE UsuarioId = @u', {
      u: [sql.Int, req.usuario.id],
    });
    // La primera dirección siempre queda como principal; si la nueva es principal, las demás dejan de serlo.
    const principal = d.principal || existentes[0].n === 0;
    if (principal) {
      await q('UPDATE dbo.Direcciones SET EsPrincipal = 0 WHERE UsuarioId = @u', { u: [sql.Int, req.usuario.id] });
    }
    const { recordset } = await q(
      `INSERT INTO dbo.Direcciones (UsuarioId, Alias, Calle, Colonia, Ciudad, CP, Referencias, EsPrincipal)
       OUTPUT INSERTED.DireccionId
       VALUES (@u, @alias, @calle, @colonia, @ciudad, @cp, @referencias, @principal)`,
      {
        u: [sql.Int, req.usuario.id],
        alias: [sql.NVarChar(40), d.alias],
        calle: [sql.NVarChar(160), d.calle],
        colonia: [sql.NVarChar(120), d.colonia],
        ciudad: [sql.NVarChar(80), d.ciudad],
        cp: [sql.VarChar(5), d.cp ?? null],
        referencias: [sql.NVarChar(200), d.referencias ?? null],
        principal: [sql.Bit, principal],
      },
    );
    return recordset[0].DireccionId;
  });
  res.status(201).json(aDireccionApi(await buscarDireccion(id)));
});

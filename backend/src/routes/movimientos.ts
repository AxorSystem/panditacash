import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireAdmin } from '../lib/auth.js';

const router = Router();
router.use(requireAuth);
router.use(requireAdmin);

/** GET /api/movimientos  — historial cronológico global de cobros
 *  Query params: desde, hasta, cliente_id, metodo, limit
 */
router.get('/', async (req, res) => {
  const desde = String(req.query.desde ?? '').trim();
  const hasta = String(req.query.hasta ?? '').trim();
  const cliente_id = req.query.cliente_id ? Number(req.query.cliente_id) : null;
  const metodo = String(req.query.metodo ?? '').trim();
  const limit = Math.min(500, Number(req.query.limit) || 100);

  const where: string[] = [];
  const params: any = { limit };
  if (desde) { where.push('m.fecha_pago >= @desde'); params.desde = desde; }
  if (hasta) { where.push('m.fecha_pago < DATEADD(day, 1, @hasta)'); params.hasta = hasta; }
  if (cliente_id) { where.push('m.usuario_id = @cid'); params.cid = cliente_id; }
  if (metodo) { where.push('m.metodo = @metodo'); params.metodo = metodo; }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const r = await query(
    `SELECT TOP (@limit)
            m.id, m.pago_id, m.prestamo_id, m.usuario_id,
            m.monto_capital, m.monto_mora, m.mora_perdonada,
            m.metodo, m.notas, m.fecha_pago,
            u.nombre AS cliente_nombre, u.telefono AS cliente_tel,
            reg.nombre AS registrado_por_nombre,
            pg.numero_pago,
            p.principal, p.plazo_meses
       FROM dbo.movimientos m
       JOIN dbo.usuarios u ON u.id = m.usuario_id
       JOIN dbo.usuarios reg ON reg.id = m.registrado_por
       JOIN dbo.pagos pg ON pg.id = m.pago_id
       JOIN dbo.prestamos p ON p.id = m.prestamo_id
       ${whereSql}
      ORDER BY m.fecha_pago DESC`,
    params,
  );

  const stats = await query(
    `SELECT
        COUNT(*) AS n_movimientos,
        ISNULL(SUM(m.monto_capital), 0) AS total_capital,
        ISNULL(SUM(m.monto_mora), 0) AS total_mora,
        ISNULL(SUM(m.mora_perdonada), 0) AS total_perdonado
       FROM dbo.movimientos m
       ${whereSql}`,
    params,
  );

  res.json({
    stats: stats.recordset[0],
    movimientos: r.recordset,
  });
});

/** DELETE /api/movimientos/:id — anula un cobro (revierte pago aplicado) */
router.delete('/:id', async (req, res) => {
  const id = Number(req.params.id);
  const r = await query(
    `SELECT pago_id, monto_capital, monto_mora FROM dbo.movimientos WHERE id=@id`,
    { id },
  );
  const mov = r.recordset[0];
  if (!mov) return res.status(404).json({ error: 'No existe' });

  await query(
    `UPDATE dbo.pagos
        SET monto_pagado_capital = ISNULL(monto_pagado_capital, 0) - @mc,
            monto_pagado_mora    = ISNULL(monto_pagado_mora, 0) - @mm,
            estado = 'pendiente'
      WHERE id = @pid`,
    { pid: mov.pago_id, mc: mov.monto_capital, mm: mov.monto_mora },
  );
  await query(`DELETE FROM dbo.movimientos WHERE id=@id`, { id });
  res.json({ ok: true });
});

/** PATCH /api/movimientos/:id — edita monto o notas */
router.patch('/:id', async (req, res) => {
  const id = Number(req.params.id);
  const { monto_capital, monto_mora, notas, metodo } = req.body ?? {};

  const cur = await query(
    `SELECT pago_id, monto_capital AS mc0, monto_mora AS mm0 FROM dbo.movimientos WHERE id=@id`,
    { id },
  );
  const m = cur.recordset[0];
  if (!m) return res.status(404).json({ error: 'No existe' });

  const nuevoMC = monto_capital != null ? Number(monto_capital) : m.mc0;
  const nuevoMM = monto_mora != null ? Number(monto_mora) : m.mm0;
  const dMC = nuevoMC - m.mc0;
  const dMM = nuevoMM - m.mm0;

  await query(
    `UPDATE dbo.movimientos
        SET monto_capital = @mc, monto_mora = @mm,
            notas = COALESCE(@n, notas), metodo = COALESCE(@met, metodo)
      WHERE id=@id`,
    { id, mc: nuevoMC, mm: nuevoMM, n: notas ?? null, met: metodo ?? null },
  );
  if (dMC !== 0 || dMM !== 0) {
    await query(
      `UPDATE dbo.pagos
          SET monto_pagado_capital = ISNULL(monto_pagado_capital, 0) + @dmc,
              monto_pagado_mora    = ISNULL(monto_pagado_mora, 0) + @dmm
        WHERE id=@pid`,
      { pid: m.pago_id, dmc: dMC, dmm: dMM },
    );
  }
  res.json({ ok: true });
});

export default router;

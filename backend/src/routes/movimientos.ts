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

export default router;

import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireAdmin } from '../lib/auth.js';

const router = Router();
router.use(requireAuth);
router.use(requireAdmin);

/** GET /api/analytics  — métricas para mamá */
router.get('/', async (req, res) => {
  // Totales generales
  const tot = await query(`
    SELECT
      COUNT(*) AS prestamos_totales,
      SUM(CASE WHEN estado = 'activo' THEN 1 ELSE 0 END) AS prestamos_activos,
      SUM(CASE WHEN estado = 'liquidado' THEN 1 ELSE 0 END) AS prestamos_liquidados,
      ISNULL(SUM(principal), 0) AS total_prestado_historico,
      ISNULL(SUM(CASE WHEN estado = 'activo' THEN principal ELSE 0 END), 0) AS total_prestado_activo
    FROM dbo.prestamos`);

  const mov = await query(`
    SELECT
      ISNULL(SUM(monto_capital), 0) AS total_cobrado_capital,
      ISNULL(SUM(monto_mora), 0) AS total_cobrado_mora,
      ISNULL(SUM(mora_perdonada), 0) AS total_mora_perdonada,
      COUNT(*) AS n_movimientos
    FROM dbo.movimientos`);

  const clientes = await query(`
    SELECT COUNT(DISTINCT usuario_id) AS clientes_totales
    FROM dbo.prestamos`);

  // Ganancia mes a mes (últimos 12 meses)
  const porMes = await query(`
    SELECT
      YEAR(m.fecha_pago) AS anio,
      MONTH(m.fecha_pago) AS mes,
      SUM(m.monto_capital) AS capital,
      SUM(m.monto_mora) AS mora,
      COUNT(*) AS movimientos
    FROM dbo.movimientos m
    WHERE m.fecha_pago >= DATEADD(month, -12, GETUTCDATE())
    GROUP BY YEAR(m.fecha_pago), MONTH(m.fecha_pago)
    ORDER BY anio, mes`);

  // Top 5 clientes por deuda activa
  const topDeuda = await query(`
    SELECT TOP 5
      u.id, u.nombre,
      SUM(p.principal) AS deuda_original,
      SUM(p.principal - ISNULL((SELECT SUM(monto_capital) FROM dbo.movimientos WHERE prestamo_id = p.id), 0)) AS saldo_estimado
    FROM dbo.prestamos p
    JOIN dbo.usuarios u ON u.id = p.usuario_id
    WHERE p.estado = 'activo'
    GROUP BY u.id, u.nombre
    ORDER BY saldo_estimado DESC`);

  // Clientes con pagos atrasados actuales
  const enAtraso = await query(`
    SELECT COUNT(DISTINCT p.usuario_id) AS n
      FROM dbo.pagos pg
      JOIN dbo.prestamos p ON p.id = pg.prestamo_id
     WHERE pg.estado IN ('pendiente','parcial')
       AND pg.fecha_programada < CAST(GETUTCDATE() AS DATE)`);

  // Ganancia teórica pendiente (intereses futuros de préstamos activos)
  const ganPend = await query(`
    SELECT ISNULL(SUM((p.interes_mensual * (p.plazo_meses - 1)) - m.pagado), 0) AS ganancia_pendiente
    FROM dbo.prestamos p
    OUTER APPLY (
      SELECT ISNULL(SUM(monto_capital), 0) - p.principal AS pagado
      FROM dbo.movimientos WHERE prestamo_id = p.id
    ) m
    WHERE p.estado = 'activo'`);

  res.json({
    totales: {
      ...tot.recordset[0],
      ...mov.recordset[0],
      clientes_totales: clientes.recordset[0].clientes_totales,
      en_atraso: enAtraso.recordset[0].n,
      ganancia_neta: Number(mov.recordset[0].total_cobrado_capital) + Number(mov.recordset[0].total_cobrado_mora) - Number(tot.recordset[0].total_prestado_historico),
      ganancia_pendiente: ganPend.recordset[0].ganancia_pendiente,
    },
    por_mes: porMes.recordset,
    top_deuda: topDeuda.recordset,
  });
});

export default router;

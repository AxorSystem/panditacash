import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireAdmin } from '../lib/auth.js';

const router = Router();
router.use(requireAuth);
router.use(requireAdmin);

/** GET /api/analytics  — métricas para mamá */
router.get('/', async (req, res) => {
  // Rango opcional (desde, hasta) — solo filtra movimientos y ganancias.
  const desde = String(req.query.desde ?? '').trim();
  const hasta = String(req.query.hasta ?? '').trim();
  const movWhere: string[] = [];
  const movParams: any = {};
  if (desde) { movWhere.push('fecha_pago >= @desde'); movParams.desde = desde; }
  if (hasta) { movWhere.push('fecha_pago < DATEADD(day, 1, @hasta)'); movParams.hasta = hasta; }
  const movWhereSql = movWhere.length ? `WHERE ${movWhere.join(' AND ')}` : '';

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
    FROM dbo.movimientos ${movWhereSql}`, movParams);

  const clientes = await query(`
    SELECT COUNT(DISTINCT usuario_id) AS clientes_totales
    FROM dbo.prestamos`);

  // Ganancia mes a mes: usa el rango si viene, sino últimos 12 meses.
  const porMesWhere = movWhere.length
    ? `WHERE ${movWhere.join(' AND ')}`
    : `WHERE fecha_pago >= DATEADD(month, -12, GETUTCDATE())`;
  const porMes = await query(`
    SELECT
      YEAR(fecha_pago) AS anio,
      MONTH(fecha_pago) AS mes,
      SUM(monto_capital) AS capital,
      SUM(monto_mora) AS mora,
      COUNT(*) AS movimientos
    FROM dbo.movimientos
    ${porMesWhere}
    GROUP BY YEAR(fecha_pago), MONTH(fecha_pago)
    ORDER BY anio, mes`, movParams);

  // Top 5 clientes por deuda activa
  const topDeuda = await query(`
    WITH pagos_por_prestamo AS (
      SELECT p.id AS pid, p.usuario_id, p.principal,
             ISNULL((SELECT SUM(monto_capital) FROM dbo.movimientos WHERE prestamo_id = p.id), 0) AS pagado
        FROM dbo.prestamos p WHERE p.estado = 'activo'
    )
    SELECT TOP 5 u.id, u.nombre,
           SUM(pp.principal) AS deuda_original,
           SUM(pp.principal - pp.pagado) AS saldo_estimado
      FROM pagos_por_prestamo pp
      JOIN dbo.usuarios u ON u.id = pp.usuario_id
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
    SELECT ISNULL(SUM(p.interes_mensual * (p.plazo_meses - 1)) - SUM(m.pagado_capital), 0) AS ganancia_pendiente
    FROM dbo.prestamos p
    OUTER APPLY (
      SELECT ISNULL(SUM(monto_capital), 0) AS pagado_capital
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

/** GET /api/analytics/actividad — feed unificado de eventos recientes */
router.get('/actividad', async (_req, res) => {
  const limit = 40;
  const eventos = await query(`
    SELECT TOP (@limit) * FROM (
      SELECT 'prestamo' AS tipo, p.id AS ref_id, p.fecha_inicio AS fecha,
             u.nombre AS cliente_nombre, p.principal AS monto,
             p.estado AS estado, NULL AS metodo, NULL AS notas
        FROM dbo.prestamos p
        JOIN dbo.usuarios u ON u.id = p.usuario_id
      UNION ALL
      SELECT 'cobro' AS tipo, m.id AS ref_id, m.fecha_pago AS fecha,
             u.nombre AS cliente_nombre, (m.monto_capital + m.monto_mora) AS monto,
             NULL AS estado, m.metodo, m.notas
        FROM dbo.movimientos m
        JOIN dbo.usuarios u ON u.id = m.usuario_id
      UNION ALL
      SELECT 'solicitud' AS tipo, s.id AS ref_id, s.created_at AS fecha,
             u.nombre AS cliente_nombre, s.monto_solicitado AS monto,
             s.estado AS estado, NULL AS metodo, s.motivo AS notas
        FROM dbo.solicitudes s
        JOIN dbo.usuarios u ON u.id = s.usuario_id
    ) x
    ORDER BY fecha DESC
  `, { limit });
  res.json(eventos.recordset);
});

export default router;

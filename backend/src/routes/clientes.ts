import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireAdmin } from '../lib/auth.js';
import { saldoPago } from '../lib/finanzas.js';
import { calcularScore } from '../lib/score.js';

const router = Router();
router.use(requireAuth);
router.use(requireAdmin);

/** GET /api/clientes  — lista todos los clientes con resumen */
router.get('/', async (req, res) => {
  const buscar = String(req.query.buscar ?? '').trim();

  const r = await query(
    `SELECT u.id, u.nombre, u.telefono, u.notas, u.created_at,
            (SELECT COUNT(*) FROM dbo.prestamos WHERE usuario_id = u.id) AS n_prestamos,
            (SELECT COUNT(*) FROM dbo.prestamos WHERE usuario_id = u.id AND estado = 'activo') AS activos,
            (SELECT ISNULL(SUM(principal), 0) FROM dbo.prestamos WHERE usuario_id = u.id AND estado = 'activo') AS deuda_original,
            (SELECT ISNULL(SUM(monto_capital), 0) FROM dbo.movimientos WHERE usuario_id = u.id) AS total_pagado_capital
       FROM dbo.usuarios u
      WHERE u.es_admin = 0 AND u.activo = 1
        AND (@buscar = '' OR u.nombre LIKE '%' + @buscar + '%' OR u.telefono LIKE '%' + @buscar + '%')
      ORDER BY activos DESC, u.nombre ASC`,
    { buscar },
  );

  const clientes = await Promise.all(
    r.recordset.map(async (c: any) => {
      // Cuenta cuántos pagos han estado atrasados (histórico)
      const atrasos = await query(
        `SELECT COUNT(*) AS n
           FROM dbo.pagos pg
           JOIN dbo.prestamos p ON p.id = pg.prestamo_id
          WHERE p.usuario_id = @u AND pg.estado = 'pagado'
            AND pg.fecha_pagada > DATEADD(day, 1, pg.fecha_programada)`,
        { u: c.id },
      );
      // Saldo real: sumar saldos de pagos pendientes/parciales de todos sus préstamos activos
      const pendR = await query(
        `SELECT pg.monto_esperado, pg.fecha_programada, pg.monto_pagado_capital,
                pg.monto_pagado_mora, pg.mora_perdonada_total, p.mora_diaria
           FROM dbo.pagos pg
           JOIN dbo.prestamos p ON p.id = pg.prestamo_id
          WHERE p.usuario_id = @u AND p.estado = 'activo'
            AND pg.estado IN ('pendiente','parcial')`,
        { u: c.id },
      );
      const hoy = new Date();
      let saldo_real = 0;
      let vencidos = 0;
      for (const pg of pendR.recordset) {
        const s = saldoPago(pg, hoy);
        saldo_real += s.total_pendiente;
        if (s.dias_retraso > 0) vencidos++;
      }
      return {
        ...c,
        atrasos_historicos: atrasos.recordset[0].n,
        saldo_real,
        vencidos,
      };
    }),
  );

  res.json(clientes);
});

/** GET /api/clientes/:id  — detalle del cliente con sus préstamos + historial */
router.get('/:id', async (req, res) => {
  const id = Number(req.params.id);
  const uR = await query(
    `SELECT id, nombre, telefono, notas, created_at, last_login
       FROM dbo.usuarios WHERE id = @id AND es_admin = 0`,
    { id },
  );
  const cliente = uR.recordset[0];
  if (!cliente) return res.status(404).json({ error: 'No existe' });

  const prR = await query(
    `SELECT p.id, p.principal, p.tasa_mensual, p.plazo_meses, p.monto_entregado,
            p.interes_mensual, p.mora_diaria, p.fecha_inicio, p.fecha_liquidacion,
            p.estado, p.notas, p.aprobado_at,
            (SELECT ISNULL(SUM(monto_capital), 0) FROM dbo.movimientos WHERE prestamo_id = p.id) AS pagado_capital,
            (SELECT ISNULL(SUM(monto_mora), 0) FROM dbo.movimientos WHERE prestamo_id = p.id) AS pagado_mora
       FROM dbo.prestamos p
      WHERE p.usuario_id = @id
      ORDER BY p.fecha_inicio DESC`,
    { id },
  );

  const movR = await query(
    `SELECT m.id, m.pago_id, m.prestamo_id, m.monto_capital, m.monto_mora,
            m.mora_perdonada, m.metodo, m.notas, m.fecha_pago,
            u.nombre AS registrado_por_nombre
       FROM dbo.movimientos m
       JOIN dbo.usuarios u ON u.id = m.registrado_por
      WHERE m.usuario_id = @id
      ORDER BY m.fecha_pago DESC`,
    { id },
  );

  const score = await calcularScore(id);
  res.json({ cliente, prestamos: prR.recordset, movimientos: movR.recordset, score });
});

/** GET /api/clientes/:id/score — solo el score */
router.get('/:id/score', async (req, res) => {
  const score = await calcularScore(Number(req.params.id));
  res.json(score);
});

/** PATCH /api/clientes/:id — mamá edita notas o nombre */
router.patch('/:id', async (req: any, res) => {
  const id = Number(req.params.id);
  const { nombre, notas, telefono } = req.body ?? {};
  const parts: string[] = [];
  const params: any = { id };
  if (nombre !== undefined) { parts.push('nombre = @nombre'); params.nombre = nombre; }
  if (notas !== undefined) { parts.push('notas = @notas'); params.notas = notas; }
  if (telefono !== undefined) { parts.push('telefono = @tel'); params.tel = telefono; }
  if (!parts.length) return res.json({ ok: true });
  await query(`UPDATE dbo.usuarios SET ${parts.join(', ')} WHERE id = @id AND es_admin = 0`, params);
  res.json({ ok: true });
});

export default router;

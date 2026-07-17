import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../lib/auth.js';
import { moraAcumulada, diasRetraso } from '../lib/finanzas.js';

const router = Router();
router.use(requireAuth);

/** GET /api/mi/resumen  cliente ve su resumen personal */
router.get('/resumen', async (req: any, res) => {
  const uid = req.user.id;

  // Préstamo activo actual (más reciente si hay varios)
  const pR = await query(
    `SELECT TOP 1 p.id, p.principal, p.tasa_mensual, p.plazo_meses, p.monto_entregado,
            p.interes_mensual, p.mora_diaria, p.fecha_inicio, p.estado
       FROM dbo.prestamos p
      WHERE p.usuario_id = @u AND p.estado = 'activo'
      ORDER BY p.fecha_inicio DESC`,
    { u: uid },
  );
  const prestamo = pR.recordset[0];

  let proximo: any = null;
  let total_pendiente = 0;
  let total_pagado = 0;

  if (prestamo) {
    const pagosR = await query(
      `SELECT id, numero_pago, monto_esperado, fecha_programada, monto_pagado, estado, fecha_pagada
         FROM dbo.pagos WHERE prestamo_id = @id ORDER BY numero_pago`,
      { id: prestamo.id },
    );
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);

    for (const pg of pagosR.recordset) {
      if (pg.estado === 'pagado' || pg.estado === 'pagado_anticipado') {
        total_pagado += Number(pg.monto_pagado || 0);
      } else if (pg.estado === 'pendiente') {
        const mora = moraAcumulada(pg.fecha_programada, Number(prestamo.mora_diaria), hoy);
        total_pendiente += Number(pg.monto_esperado) + mora;
        if (!proximo) {
          proximo = {
            id: pg.id,
            numero_pago: pg.numero_pago,
            monto: Number(pg.monto_esperado),
            mora,
            total: Number(pg.monto_esperado) + mora,
            fecha_programada: pg.fecha_programada,
            dias_retraso: diasRetraso(pg.fecha_programada, hoy),
          };
        }
      }
    }
  }

  const historicos = await query(
    `SELECT id, principal, plazo_meses, fecha_inicio, fecha_liquidacion, estado
       FROM dbo.prestamos WHERE usuario_id = @u AND estado <> 'activo' ORDER BY fecha_inicio DESC`,
    { u: uid },
  );

  const solicitudPendiente = await query(
    `SELECT id, monto_solicitado, plazo_meses, created_at FROM dbo.solicitudes
      WHERE usuario_id = @u AND estado = 'pendiente' ORDER BY created_at DESC`,
    { u: uid },
  );

  res.json({
    prestamo_activo: prestamo,
    proximo_pago: proximo,
    total_pendiente,
    total_pagado,
    historicos: historicos.recordset,
    solicitud_pendiente: solicitudPendiente.recordset[0] ?? null,
  });
});

/** POST /api/mi/avisar-pago   cliente avisa que ya pagó (marca al pago con nota)
 *  body: { pago_id, monto?, notas? }
 *  NO cambia estado — mamá confirma cuando registra en su vista.
 */
router.post('/avisar-pago', async (req: any, res) => {
  const { pago_id, monto, notas } = req.body ?? {};
  if (!pago_id) return res.status(400).json({ error: 'Falta pago_id' });

  const r = await query(
    `SELECT pg.id, pg.prestamo_id, p.usuario_id, u.nombre AS cliente_nombre, m.telefono AS mama_tel
       FROM dbo.pagos pg
       JOIN dbo.prestamos p ON p.id = pg.prestamo_id
       JOIN dbo.usuarios u ON u.id = p.usuario_id
       LEFT JOIN dbo.usuarios m ON m.es_admin = 1 AND m.activo = 1
      WHERE pg.id = @id`,
    { id: pago_id },
  );
  const pg = r.recordset[0];
  if (!pg || pg.usuario_id !== req.user.id) return res.status(403).json({ error: 'No autorizado' });

  const notaExistente = notas ? `[Cliente avisa] ${notas}${monto ? ` — $${Number(monto).toLocaleString('es-MX')}` : ''}` : `[Cliente avisa]${monto ? ` $${Number(monto).toLocaleString('es-MX')}` : ''}`;
  await query(
    `UPDATE dbo.pagos SET notas = CASE WHEN notas IS NULL THEN @n ELSE notas + CHAR(10) + @n END WHERE id = @id`,
    { n: notaExistente, id: pago_id },
  );

  // Avisa a mamá por WA
  const { enviarWA } = await import('../lib/wa.js');
  const msg = `🐼 PanditaCash\n\n💬 ${pg.cliente_nombre} avisa que pagó${monto ? ` $${Number(monto).toLocaleString('es-MX')}` : ''}.${notas ? `\n\n"${notas}"` : ''}\n\nConfírmalo en la app.`;
  if (pg.mama_tel) await enviarWA({ telefono: pg.mama_tel, mensaje: msg, tipo: 'aviso_pago_cliente', ref_pago: pago_id, ref_prestamo: pg.prestamo_id }).catch(() => {});

  res.json({ ok: true });
});

export default router;

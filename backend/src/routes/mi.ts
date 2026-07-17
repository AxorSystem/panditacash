import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../lib/auth.js';
import { saldoPago } from '../lib/finanzas.js';

const router = Router();
router.use(requireAuth);

/** GET /api/mi/resumen — cliente ve solo lectura de su préstamo activo */
router.get('/resumen', async (req: any, res) => {
  const uid = req.user.id;

  const pR = await query(
    `SELECT TOP 1 p.id, p.principal, p.tasa_mensual, p.plazo_meses, p.monto_entregado,
            p.interes_mensual, p.mora_diaria, p.fecha_inicio, p.estado, p.notas
       FROM dbo.prestamos p
      WHERE p.usuario_id = @u AND p.estado = 'activo'
      ORDER BY p.fecha_inicio DESC`,
    { u: uid },
  );
  const prestamo = pR.recordset[0];

  let proximo: any = null;
  let total_pendiente = 0;
  let total_pagado = 0;
  let pagos: any[] = [];
  let movimientos: any[] = [];

  if (prestamo) {
    const pagosR = await query(
      `SELECT id, numero_pago, monto_esperado, fecha_programada,
              monto_pagado_capital, monto_pagado_mora, mora_perdonada_total,
              estado, fecha_pagada
         FROM dbo.pagos WHERE prestamo_id = @id ORDER BY numero_pago`,
      { id: prestamo.id },
    );
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);
    pagos = pagosR.recordset.map((pg: any) => {
      const s = saldoPago({ ...pg, mora_diaria: prestamo.mora_diaria }, hoy);
      return { ...pg, ...s };
    });

    for (const pg of pagos) {
      total_pagado += Number(pg.monto_pagado_capital) + Number(pg.monto_pagado_mora);
      if (pg.estado === 'pendiente' || pg.estado === 'parcial') {
        total_pendiente += pg.total_pendiente;
        if (!proximo) proximo = pg;
      }
    }

    const movR = await query(
      `SELECT id, monto_capital, monto_mora, metodo, fecha_pago
         FROM dbo.movimientos WHERE prestamo_id = @id ORDER BY fecha_pago DESC`,
      { id: prestamo.id },
    );
    movimientos = movR.recordset;
  }

  const solicitudPendiente = await query(
    `SELECT id, monto_solicitado, plazo_meses, created_at FROM dbo.solicitudes
      WHERE usuario_id = @u AND estado = 'pendiente' ORDER BY created_at DESC`,
    { u: uid },
  );

  const historicos = await query(
    `SELECT id, principal, plazo_meses, fecha_inicio, fecha_liquidacion, estado
       FROM dbo.prestamos WHERE usuario_id = @u AND estado <> 'activo' ORDER BY fecha_inicio DESC`,
    { u: uid },
  );

  res.json({
    prestamo_activo: prestamo,
    proximo_pago: proximo,
    pagos,
    movimientos,
    total_pendiente,
    total_pagado,
    historicos: historicos.recordset,
    solicitud_pendiente: solicitudPendiente.recordset[0] ?? null,
  });
});

export default router;

import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireAdmin } from '../lib/auth.js';
import { calcularPrestamo, generarPagosProgramados } from '../lib/finanzas.js';
import { enviarWA } from '../lib/wa.js';

const router = Router();
router.use(requireAuth);

/** POST /api/solicitudes  cliente pide un préstamo */
router.post('/', async (req: any, res) => {
  const { monto_solicitado, plazo_meses, motivo } = req.body ?? {};
  if (!monto_solicitado || !plazo_meses) return res.status(400).json({ error: 'Faltan datos' });
  if (req.user.es_admin) return res.status(400).json({ error: 'Mamá crea préstamos, no solicita' });

  const insR = await query(
    `INSERT INTO dbo.solicitudes (usuario_id, monto_solicitado, plazo_meses, motivo)
     OUTPUT INSERTED.id
     VALUES (@u, @m, @p, @mo)`,
    { u: req.user.id, m: Number(monto_solicitado), p: Number(plazo_meses), mo: motivo ?? null },
  );

  // Notifica a todas las mamás activas
  const mamas = await query(`SELECT telefono, nombre FROM dbo.usuarios WHERE es_admin = 1 AND activo = 1`);
  for (const m of mamas.recordset) {
    const msg = `🐼 PanditaCash\n\n📩 Nueva solicitud\n\n👤 ${req.user.nombre}\n💰 $${Number(monto_solicitado).toLocaleString('es-MX')}\n📅 ${plazo_meses} meses\n${motivo ? `📝 ${motivo}` : ''}\n\nRevísala en la app.`;
    await enviarWA({ telefono: m.telefono, mensaje: msg, tipo: 'solicitud_recibida' }).catch(() => {});
  }

  res.json({ id: insR.recordset[0].id, estado: 'pendiente' });
});

/** GET /api/solicitudes/mias   cliente ve sus solicitudes */
router.get('/mias', async (req: any, res) => {
  const r = await query(
    `SELECT id, monto_solicitado, plazo_meses, motivo, estado, respuesta_notas,
            respondido_at, created_at, prestamo_id
       FROM dbo.solicitudes WHERE usuario_id = @u ORDER BY created_at DESC`,
    { u: req.user.id },
  );
  res.json(r.recordset);
});

/** POST /api/solicitudes/:id/responder   mamá aprueba/rechaza
 *  body: { accion: 'aprobar' | 'rechazar', tasa_mensual?, mora_diaria?, notas? }
 *  Si aprueba, crea el préstamo con los términos que mamá especifica.
 */
router.post('/:id/responder', requireAdmin, async (req: any, res) => {
  const id = Number(req.params.id);
  const { accion, tasa_mensual, mora_diaria, notas } = req.body ?? {};

  const sR = await query(
    `SELECT s.*, u.telefono, u.nombre FROM dbo.solicitudes s
       JOIN dbo.usuarios u ON u.id = s.usuario_id
      WHERE s.id = @id AND s.estado = 'pendiente'`,
    { id },
  );
  const s = sR.recordset[0];
  if (!s) return res.status(404).json({ error: 'Solicitud no encontrada o ya respondida' });

  if (accion === 'rechazar') {
    await query(
      `UPDATE dbo.solicitudes SET estado = 'rechazada', respondido_por = @u, respondido_at = SYSUTCDATETIME(), respuesta_notas = @n WHERE id = @id`,
      { u: req.user.id, n: notas ?? null, id },
    );
    const msg = `🐼 PanditaCash\n\n❌ Tu solicitud de $${Number(s.monto_solicitado).toLocaleString('es-MX')} fue rechazada.${notas ? `\n\n${notas}` : ''}`;
    await enviarWA({ telefono: s.telefono, mensaje: msg, tipo: 'solicitud_rechazada' }).catch(() => {});
    return res.json({ ok: true, estado: 'rechazada' });
  }

  if (accion !== 'aprobar') return res.status(400).json({ error: 'Acción inválida' });
  if (!tasa_mensual) return res.status(400).json({ error: 'Falta tasa_mensual para aprobar' });
  const { frecuencia } = req.body ?? {};
  const frec: 'mensual' | 'quincenal' = frecuencia === 'quincenal' ? 'quincenal' : 'mensual';

  const p = {
    principal: Number(s.monto_solicitado),
    tasa_mensual: Number(tasa_mensual),
    plazo_meses: Number(s.plazo_meses),
    mora_diaria: Number(mora_diaria) || 0,
    fecha_inicio: new Date().toISOString().slice(0, 10),
    frecuencia: frec,
  };
  const calc = calcularPrestamo(p);

  const insP = await query(
    `INSERT INTO dbo.prestamos
       (usuario_id, principal, tasa_mensual, plazo_meses, interes_mensual,
        monto_entregado, mora_diaria, fecha_inicio, aprobado_por, notas, frecuencia)
     OUTPUT INSERTED.id
     VALUES (@u, @pr, @t, @pm, @im, @me, @md, @fi, @ap, @no, @fr)`,
    {
      u: s.usuario_id, pr: p.principal, t: p.tasa_mensual, pm: p.plazo_meses,
      im: calc.interes_mensual, me: calc.monto_entregado, md: p.mora_diaria,
      fi: p.fecha_inicio, ap: req.user.id, no: notas ?? null, fr: p.frecuencia,
    },
  );
  const prestamo_id = insP.recordset[0].id;

  const pagos = generarPagosProgramados(p);
  for (const pg of pagos) {
    await query(
      `INSERT INTO dbo.pagos (prestamo_id, numero_pago, monto_esperado, fecha_programada, estado, monto_pagado, fecha_pagada)
       VALUES (@p, @n, @m, @f, @e, @mp, @fp)`,
      {
        p: prestamo_id, n: pg.numero_pago, m: pg.monto_esperado, f: pg.fecha_programada,
        e: pg.estado_inicial,
        mp: pg.estado_inicial === 'pagado_anticipado' ? pg.monto_esperado : null,
        fp: pg.estado_inicial === 'pagado_anticipado' ? new Date() : null,
      },
    );
  }

  await query(
    `UPDATE dbo.solicitudes SET estado = 'aprobada', respondido_por = @u, respondido_at = SYSUTCDATETIME(), respuesta_notas = @n, prestamo_id = @pid WHERE id = @id`,
    { u: req.user.id, n: notas ?? null, pid: prestamo_id, id },
  );

  const msg = `🐼 PanditaCash\n\n✅ ¡Aprobado! $${calc.monto_entregado.toLocaleString('es-MX')} listo para recoger.\n\n💰 Prestamos: $${p.principal.toLocaleString('es-MX')}\n📅 Plazo: ${p.plazo_meses} meses\n\nVe tu préstamo en la app.`;
  await enviarWA({ telefono: s.telefono, mensaje: msg, tipo: 'solicitud_aprobada', ref_prestamo: prestamo_id }).catch(() => {});

  res.json({ ok: true, estado: 'aprobada', prestamo_id, ...calc });
});

export default router;

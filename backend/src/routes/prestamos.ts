import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireAdmin } from '../lib/auth.js';
import { calcularPrestamo, generarPagosProgramados, moraAcumulada, diasRetraso } from '../lib/finanzas.js';
import { enviarWA, normalizarTel } from '../lib/wa.js';

const router = Router();
router.use(requireAuth);

/**
 * GET /api/prestamos/dashboard   — admin ve estado global
 */
router.get('/dashboard', requireAdmin, async (req, res) => {
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  const en7 = new Date(hoy);
  en7.setDate(en7.getDate() + 7);

  const activos = await query(`
    SELECT p.id, p.principal, p.tasa_mensual, p.plazo_meses, p.mora_diaria,
           p.fecha_inicio, u.nombre, u.telefono
      FROM dbo.prestamos p
      JOIN dbo.usuarios u ON u.id = p.usuario_id
     WHERE p.estado = 'activo'
     ORDER BY p.fecha_inicio DESC`);

  const pagosPend = await query(`
    SELECT pg.id, pg.prestamo_id, pg.numero_pago, pg.monto_esperado, pg.fecha_programada,
           p.mora_diaria, u.nombre AS cliente_nombre, u.telefono AS cliente_tel,
           p.principal, p.tasa_mensual, p.plazo_meses
      FROM dbo.pagos pg
      JOIN dbo.prestamos p ON p.id = pg.prestamo_id
      JOIN dbo.usuarios u ON u.id = p.usuario_id
     WHERE pg.estado = 'pendiente' AND p.estado = 'activo'
     ORDER BY pg.fecha_programada ASC`);

  const solicitudes = await query(`
    SELECT s.id, s.monto_solicitado, s.plazo_meses, s.motivo, s.created_at,
           u.nombre, u.telefono
      FROM dbo.solicitudes s
      JOIN dbo.usuarios u ON u.id = s.usuario_id
     WHERE s.estado = 'pendiente'
     ORDER BY s.created_at ASC`);

  // Enriquece pagos con mora acumulada + estado urgencia
  const pagosEnriquecidos = pagosPend.recordset.map((p: any) => {
    const dias = diasRetraso(p.fecha_programada, hoy);
    const mora = moraAcumulada(p.fecha_programada, Number(p.mora_diaria), hoy);
    const total = Number(p.monto_esperado) + mora;
    let urgencia: 'vencido' | 'hoy' | 'pronto' | 'futuro';
    const f = new Date(p.fecha_programada);
    f.setHours(0, 0, 0, 0);
    if (dias > 0) urgencia = 'vencido';
    else if (f.getTime() === hoy.getTime()) urgencia = 'hoy';
    else if (f.getTime() < en7.getTime()) urgencia = 'pronto';
    else urgencia = 'futuro';
    return { ...p, dias_retraso: dias, mora_acumulada: mora, total_a_cobrar: total, urgencia };
  });

  const stats = {
    prestado_activo: activos.recordset.reduce((s: number, p: any) => s + Number(p.principal), 0),
    por_cobrar_hoy: pagosEnriquecidos.filter((p) => p.urgencia === 'hoy').reduce((s, p) => s + p.total_a_cobrar, 0),
    por_cobrar_hoy_n: pagosEnriquecidos.filter((p) => p.urgencia === 'hoy').length,
    vencidos: pagosEnriquecidos.filter((p) => p.urgencia === 'vencido').reduce((s, p) => s + p.total_a_cobrar, 0),
    vencidos_n: pagosEnriquecidos.filter((p) => p.urgencia === 'vencido').length,
    proximos_7d: pagosEnriquecidos.filter((p) => p.urgencia === 'pronto').reduce((s, p) => s + p.total_a_cobrar, 0),
    proximos_7d_n: pagosEnriquecidos.filter((p) => p.urgencia === 'pronto').length,
    solicitudes_pendientes: solicitudes.recordset.length,
  };

  res.json({ stats, pagos_pendientes: pagosEnriquecidos, solicitudes_pendientes: solicitudes.recordset });
});

/**
 * POST /api/prestamos   admin crea préstamo directo
 * body: { telefono, nombre?, principal, tasa_mensual, plazo_meses, mora_diaria?, fecha_inicio?, notas? }
 */
router.post('/', requireAdmin, async (req: any, res) => {
  const { telefono, nombre, principal, tasa_mensual, plazo_meses, mora_diaria, fecha_inicio, notas } = req.body ?? {};
  if (!telefono || !principal || !tasa_mensual || !plazo_meses)
    return res.status(400).json({ error: 'Faltan datos' });

  const tel = normalizarTel(telefono);

  // Buscar/crear usuario
  let uR = await query('SELECT id, nombre FROM dbo.usuarios WHERE telefono = @t', { t: tel });
  let usuario_id: number;
  if (!uR.recordset[0]) {
    if (!nombre) return res.status(400).json({ error: 'Cliente nuevo requiere nombre' });
    const ins = await query(
      `INSERT INTO dbo.usuarios (telefono, nombre, es_admin) OUTPUT INSERTED.id VALUES (@t, @n, 0)`,
      { t: tel, n: nombre },
    );
    usuario_id = ins.recordset[0].id;
  } else {
    usuario_id = uR.recordset[0].id;
  }

  const p = {
    principal: Number(principal),
    tasa_mensual: Number(tasa_mensual),
    plazo_meses: Number(plazo_meses),
    mora_diaria: Number(mora_diaria) || 0,
    fecha_inicio: fecha_inicio || new Date().toISOString().slice(0, 10),
  };
  const calc = calcularPrestamo(p);

  const insP = await query(
    `INSERT INTO dbo.prestamos
       (usuario_id, principal, tasa_mensual, plazo_meses, interes_mensual,
        monto_entregado, mora_diaria, fecha_inicio, aprobado_por, notas)
     OUTPUT INSERTED.id
     VALUES (@u, @pr, @t, @pm, @im, @me, @md, @fi, @ap, @no)`,
    {
      u: usuario_id, pr: p.principal, t: p.tasa_mensual, pm: p.plazo_meses,
      im: calc.interes_mensual, me: calc.monto_entregado, md: p.mora_diaria,
      fi: p.fecha_inicio, ap: req.user.id, no: notas ?? null,
    },
  );
  const prestamo_id = insP.recordset[0].id;

  // Genera pagos programados
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

  // WA al cliente
  const msg = `🐼 PanditaCash\n\n¡Hola${nombre ? ` ${nombre}` : ''}! Tu préstamo fue aprobado.\n\n💰 Recibes: $${calc.monto_entregado.toLocaleString('es-MX')}\n📅 Plazo: ${p.plazo_meses} meses\n\nVe tu préstamo en:\nhttps://panditacash.5-78-222-255.sslip.io/mi-prestamo`;
  await enviarWA({ telefono: tel, mensaje: msg, tipo: 'nuevo_prestamo', ref_prestamo: prestamo_id }).catch(() => {});

  res.json({ id: prestamo_id, ...calc, pagos: pagos.length });
});

/** GET /api/prestamos/mios   cliente ve sus préstamos */
router.get('/mios', async (req: any, res) => {
  const r = await query(
    `SELECT p.id, p.principal, p.tasa_mensual, p.plazo_meses, p.interes_mensual,
            p.monto_entregado, p.mora_diaria, p.fecha_inicio, p.estado, p.notas
       FROM dbo.prestamos p
      WHERE p.usuario_id = @u
      ORDER BY p.fecha_inicio DESC`,
    { u: req.user.id },
  );
  res.json(r.recordset);
});

/** GET /api/prestamos/:id   detalle con pagos + urgencias */
router.get('/:id', async (req: any, res) => {
  const id = Number(req.params.id);
  const pR = await query(
    `SELECT p.*, u.id AS uid, u.nombre AS cliente_nombre, u.telefono AS cliente_tel
       FROM dbo.prestamos p
       JOIN dbo.usuarios u ON u.id = p.usuario_id
      WHERE p.id = @id`,
    { id },
  );
  const p = pR.recordset[0];
  if (!p) return res.status(404).json({ error: 'No existe' });

  // Solo el dueño del préstamo o mamá pueden ver
  if (!req.user.es_admin && p.uid !== req.user.id)
    return res.status(403).json({ error: 'No autorizado' });

  const pagosR = await query(
    `SELECT id, numero_pago, monto_esperado, fecha_programada, monto_pagado,
            mora_calculada, mora_perdonada, fecha_pagada, estado, notas, comprobante_url
       FROM dbo.pagos WHERE prestamo_id = @id ORDER BY numero_pago`,
    { id },
  );

  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  const pagos = pagosR.recordset.map((pg: any) => {
    const mora = pg.estado === 'pendiente'
      ? moraAcumulada(pg.fecha_programada, Number(p.mora_diaria), hoy)
      : 0;
    const dias = pg.estado === 'pendiente'
      ? diasRetraso(pg.fecha_programada, hoy)
      : 0;
    return {
      ...pg,
      mora_acumulada_hoy: mora,
      dias_retraso: dias,
      total_a_cobrar_hoy: Number(pg.monto_esperado) + mora,
    };
  });

  const totalPagado = pagos
    .filter((p) => p.estado === 'pagado' || p.estado === 'pagado_anticipado')
    .reduce((s, p) => s + Number(p.monto_pagado ?? 0), 0);
  const totalPendiente = pagos
    .filter((p) => p.estado === 'pendiente')
    .reduce((s, p) => s + p.total_a_cobrar_hoy, 0);

  const proximo = pagos.find((p) => p.estado === 'pendiente');

  res.json({ ...p, pagos, total_pagado: totalPagado, total_pendiente: totalPendiente, proximo });
});

/**
 * POST /api/prestamos/:id/pagar   admin registra un pago
 * body: { pago_id, monto_pagado, mora_perdonada?, comprobante_url?, notas? }
 */
router.post('/:id/pagar', requireAdmin, async (req: any, res) => {
  const prestamo_id = Number(req.params.id);
  const { pago_id, monto_pagado, mora_perdonada, comprobante_url, notas } = req.body ?? {};
  if (!pago_id || monto_pagado == null) return res.status(400).json({ error: 'Faltan datos' });

  const pR = await query(
    `SELECT pg.*, p.mora_diaria, p.principal, p.plazo_meses, u.telefono, u.nombre
       FROM dbo.pagos pg
       JOIN dbo.prestamos p ON p.id = pg.prestamo_id
       JOIN dbo.usuarios u ON u.id = p.usuario_id
      WHERE pg.id = @pid AND pg.prestamo_id = @rid`,
    { pid: pago_id, rid: prestamo_id },
  );
  const pg = pR.recordset[0];
  if (!pg) return res.status(404).json({ error: 'Pago no encontrado' });
  if (pg.estado !== 'pendiente') return res.status(400).json({ error: `El pago ya está en estado "${pg.estado}"` });

  const mora = moraAcumulada(pg.fecha_programada, Number(pg.mora_diaria), new Date());
  const perdonada = Number(mora_perdonada) || 0;

  await query(
    `UPDATE dbo.pagos SET
       monto_pagado = @m,
       mora_calculada = @mc,
       mora_perdonada = @mp,
       fecha_pagada = SYSUTCDATETIME(),
       comprobante_url = @cu,
       registrado_por = @rp,
       notas = @no,
       estado = 'pagado',
       updated_at = SYSUTCDATETIME()
     WHERE id = @id`,
    {
      m: Number(monto_pagado),
      mc: mora, mp: perdonada,
      cu: comprobante_url ?? null, rp: req.user.id, no: notas ?? null, id: pago_id,
    },
  );

  // Si es el último pago, liquida el préstamo
  const pend = await query(
    `SELECT COUNT(*) AS n FROM dbo.pagos WHERE prestamo_id = @r AND estado = 'pendiente'`,
    { r: prestamo_id },
  );
  if (pend.recordset[0].n === 0) {
    await query(
      `UPDATE dbo.prestamos SET estado = 'liquidado', fecha_liquidacion = CAST(SYSUTCDATETIME() AS DATE) WHERE id = @id`,
      { id: prestamo_id },
    );
  }

  // Notifica al cliente
  const msg = `🐼 PanditaCash\n\n✅ Registrado tu pago de $${Number(monto_pagado).toLocaleString('es-MX')}.\n\nGracias, ${pg.nombre}.`;
  await enviarWA({ telefono: pg.telefono, mensaje: msg, tipo: 'pago_registrado', ref_prestamo: prestamo_id, ref_pago: pago_id }).catch(() => {});

  res.json({ ok: true, liquidado: pend.recordset[0].n === 0 });
});

/**
 * POST /api/prestamos/simular
 * body: { principal, tasa_mensual, plazo_meses }
 * Cálculo previo antes de aprobar
 */
router.post('/simular', async (req, res) => {
  const { principal, tasa_mensual, plazo_meses } = req.body ?? {};
  if (!principal || !tasa_mensual || !plazo_meses) return res.status(400).json({ error: 'Faltan datos' });
  const calc = calcularPrestamo({
    principal: Number(principal),
    tasa_mensual: Number(tasa_mensual),
    plazo_meses: Number(plazo_meses),
  });
  const pagos = generarPagosProgramados({
    principal: Number(principal),
    tasa_mensual: Number(tasa_mensual),
    plazo_meses: Number(plazo_meses),
    mora_diaria: 0,
    fecha_inicio: new Date().toISOString().slice(0, 10),
  });
  res.json({ ...calc, pagos });
});

export default router;

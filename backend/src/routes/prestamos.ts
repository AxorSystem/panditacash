import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireAdmin } from '../lib/auth.js';
import { calcularPrestamo, generarPagosProgramados, saldoPago } from '../lib/finanzas.js';
import { notificar, normalizarTel } from '../lib/wa.js';
import { calcularScore } from '../lib/score.js';

const router = Router();
router.use(requireAuth);

/** GET /api/prestamos/dashboard   — admin ve estado global */
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
     WHERE p.estado = 'activo'`);

  const pagosPend = await query(`
    SELECT pg.id, pg.prestamo_id, pg.numero_pago, pg.monto_esperado, pg.fecha_programada,
           pg.monto_pagado_capital, pg.monto_pagado_mora, pg.mora_perdonada_total,
           p.mora_diaria, u.id AS usuario_id, u.nombre AS cliente_nombre, u.telefono AS cliente_tel
      FROM dbo.pagos pg
      JOIN dbo.prestamos p ON p.id = pg.prestamo_id
      JOIN dbo.usuarios u ON u.id = p.usuario_id
     WHERE pg.estado IN ('pendiente', 'parcial') AND p.estado = 'activo'
     ORDER BY pg.fecha_programada ASC`);

  const solicitudes = await query(`
    SELECT s.id, s.monto_solicitado, s.plazo_meses, s.motivo, s.created_at,
           u.nombre, u.telefono
      FROM dbo.solicitudes s
      JOIN dbo.usuarios u ON u.id = s.usuario_id
     WHERE s.estado = 'pendiente'
     ORDER BY s.created_at ASC`);

  const pagosEnriquecidos = pagosPend.recordset.map((p: any) => {
    const s = saldoPago(p, hoy);
    const f = new Date(p.fecha_programada);
    f.setHours(0, 0, 0, 0);
    let urgencia: 'vencido' | 'hoy' | 'pronto' | 'futuro';
    if (s.dias_retraso > 0) urgencia = 'vencido';
    else if (f.getTime() === hoy.getTime()) urgencia = 'hoy';
    else if (f.getTime() < en7.getTime()) urgencia = 'pronto';
    else urgencia = 'futuro';
    return { ...p, ...s, urgencia };
  });

  const stats = {
    prestado_activo: activos.recordset.reduce((s: number, p: any) => s + Number(p.principal), 0),
    por_cobrar_hoy: pagosEnriquecidos.filter((p) => p.urgencia === 'hoy').reduce((s, p) => s + p.total_pendiente, 0),
    por_cobrar_hoy_n: pagosEnriquecidos.filter((p) => p.urgencia === 'hoy').length,
    vencidos: pagosEnriquecidos.filter((p) => p.urgencia === 'vencido').reduce((s, p) => s + p.total_pendiente, 0),
    vencidos_n: pagosEnriquecidos.filter((p) => p.urgencia === 'vencido').length,
    proximos_7d: pagosEnriquecidos.filter((p) => p.urgencia === 'pronto').reduce((s, p) => s + p.total_pendiente, 0),
    proximos_7d_n: pagosEnriquecidos.filter((p) => p.urgencia === 'pronto').length,
    total_pendiente: pagosEnriquecidos.reduce((s, p) => s + p.total_pendiente, 0),
    solicitudes_pendientes: solicitudes.recordset.length,
    prestamos_activos_n: activos.recordset.length,
    clientes_activos_n: new Set(pagosEnriquecidos.map(p => p.usuario_id)).size,
  };

  res.json({ stats, pagos_pendientes: pagosEnriquecidos, solicitudes_pendientes: solicitudes.recordset });
});

/** POST /api/prestamos — admin crea préstamo directo
 *  Si el cliente está en score 'bloqueado' o excede su monto/activos máximos,
 *  responde 409 con detalle. Si viene `override: true` en el body, ignora el score.
 */
router.post('/', requireAdmin, async (req: any, res) => {
  const { telefono, nombre, principal, tasa_mensual, plazo_meses, mora_diaria, fecha_inicio, frecuencia, notas, override } = req.body ?? {};
  if (!telefono || !principal || !tasa_mensual || !plazo_meses)
    return res.status(400).json({ error: 'Faltan datos' });
  const frec = (frecuencia === 'quincenal') ? 'quincenal' : 'mensual';

  const tel = normalizarTel(telefono);

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
    // Si el admin proporcionó un nombre distinto al registrado, actualízalo.
    const nombreExistente = String(uR.recordset[0].nombre || '').trim();
    const nombreNuevo = String(nombre || '').trim();
    if (nombreNuevo && nombreNuevo.toLowerCase() !== nombreExistente.toLowerCase()) {
      await query(`UPDATE dbo.usuarios SET nombre = @n WHERE id = @id`,
        { n: nombreNuevo, id: usuario_id });
    }
  }

  // Chequeo de score — bloquea automáticamente salvo override
  if (!override) {
    const score = await calcularScore(usuario_id);
    if (score.nivel === 'bloqueado') {
      return res.status(409).json({
        error: 'Cliente bloqueado',
        score,
        motivo: score.razones.join('. '),
        hint: 'Usa override:true si aún así quieres aprobar (bajo tu criterio)',
      });
    }
    if (Number(principal) > score.monto_maximo_sugerido) {
      return res.status(409).json({
        error: `Excede el monto máximo sugerido para nivel ${score.nivel} (${score.emoji})`,
        score,
        monto_maximo: score.monto_maximo_sugerido,
        hint: 'Reduce el monto o usa override:true',
      });
    }
    if (score.prestamos_activos >= score.activos_maximos) {
      return res.status(409).json({
        error: `Cliente ya tiene ${score.prestamos_activos} préstamo(s) activo(s) — máximo para nivel ${score.nivel} es ${score.activos_maximos}`,
        score,
        hint: 'Espera a que liquide alguno o usa override:true',
      });
    }
  }

  const p = {
    principal: Number(principal),
    tasa_mensual: Number(tasa_mensual),
    plazo_meses: Number(plazo_meses),
    mora_diaria: Number(mora_diaria) || 0,
    fecha_inicio: fecha_inicio || new Date().toISOString().slice(0, 10),
    frecuencia: frec as 'mensual' | 'quincenal',
  };
  const calc = calcularPrestamo(p);

  const insP = await query(
    `INSERT INTO dbo.prestamos
       (usuario_id, principal, tasa_mensual, plazo_meses, interes_mensual,
        monto_entregado, mora_diaria, fecha_inicio, aprobado_por, notas, frecuencia)
     OUTPUT INSERTED.id
     VALUES (@u, @pr, @t, @pm, @im, @me, @md, @fi, @ap, @no, @fr)`,
    {
      u: usuario_id, pr: p.principal, t: p.tasa_mensual, pm: p.plazo_meses,
      im: calc.interes_mensual, me: calc.monto_entregado, md: p.mora_diaria,
      fi: p.fecha_inicio, ap: req.user.id, no: notas ?? null, fr: p.frecuencia,
    },
  );
  const prestamo_id = insP.recordset[0].id;

  const pagos = generarPagosProgramados(p);
  for (const pg of pagos) {
    const insPg = await query(
      `INSERT INTO dbo.pagos (prestamo_id, numero_pago, monto_esperado, fecha_programada, estado, monto_pagado_capital, fecha_pagada)
       OUTPUT INSERTED.id
       VALUES (@p, @n, @m, @f, @e, @mp, @fp)`,
      {
        p: prestamo_id, n: pg.numero_pago, m: pg.monto_esperado, f: pg.fecha_programada,
        e: pg.estado_inicial,
        mp: pg.estado_inicial === 'pagado_anticipado' ? pg.monto_esperado : 0,
        fp: pg.estado_inicial === 'pagado_anticipado' ? new Date() : null,
      },
    );
    // Si es pagado_anticipado, crea el movimiento correspondiente
    if (pg.estado_inicial === 'pagado_anticipado') {
      await query(
        `INSERT INTO dbo.movimientos (pago_id, prestamo_id, usuario_id, monto_capital, metodo, notas, registrado_por)
         VALUES (@pg, @pr, @u, @m, 'retencion', @no, @rp)`,
        {
          pg: insPg.recordset[0].id, pr: prestamo_id, u: usuario_id,
          m: pg.monto_esperado, no: 'Retenido al entregar el préstamo (interés mes 1)',
          rp: req.user.id,
        },
      );
    }
  }

  await notificar({
    telefono: tel,
    tipo: 'nuevo_prestamo',
    data: { nombre: nombre || 'Cliente' },
    ref_prestamo: prestamo_id,
  }).catch(() => {});

  res.json({ id: prestamo_id, ...calc, pagos: pagos.length });
});

/** GET /api/prestamos/lookup?telefono=... — busca cliente por teléfono y devuelve su score.
 *  IMPORTANTE: debe ir ANTES del /:id para no matchear como id="lookup". */
router.get('/lookup', requireAdmin, async (req, res) => {
  const tel = normalizarTel(String(req.query.telefono ?? ''));
  if (!tel) return res.status(400).json({ error: 'Teléfono requerido' });
  const uR = await query('SELECT id, nombre, telefono FROM dbo.usuarios WHERE telefono = @t', { t: tel });
  const u = uR.recordset[0];
  if (!u) return res.json({ encontrado: false });
  const score = await calcularScore(u.id);
  res.json({ encontrado: true, cliente: u, score });
});

/** GET /api/prestamos/:id — detalle con pagos + movimientos */
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
  if (!req.user.es_admin && p.uid !== req.user.id)
    return res.status(403).json({ error: 'No autorizado' });

  const pagosR = await query(
    `SELECT id, numero_pago, monto_esperado, fecha_programada,
            monto_pagado_capital, monto_pagado_mora, mora_perdonada_total,
            fecha_pagada, estado, notas
       FROM dbo.pagos WHERE prestamo_id = @id ORDER BY numero_pago`,
    { id },
  );

  const movR = await query(
    `SELECT m.id, m.pago_id, m.monto_capital, m.monto_mora, m.mora_perdonada,
            m.metodo, m.notas, m.fecha_pago, u.nombre AS registrado_por_nombre
       FROM dbo.movimientos m
       JOIN dbo.usuarios u ON u.id = m.registrado_por
      WHERE m.prestamo_id = @id
      ORDER BY m.fecha_pago DESC`,
    { id },
  );

  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  const pagos = pagosR.recordset.map((pg: any) => ({
    ...pg,
    ...saldoPago({ ...pg, mora_diaria: p.mora_diaria }, hoy),
  }));

  const total_pagado_capital = pagos.reduce((s: number, pg: any) => s + Number(pg.monto_pagado_capital), 0);
  const total_pagado_mora = pagos.reduce((s: number, pg: any) => s + Number(pg.monto_pagado_mora), 0);
  const total_pendiente = pagos
    .filter((pg: any) => pg.estado === 'pendiente' || pg.estado === 'parcial')
    .reduce((s: number, pg: any) => s + pg.total_pendiente, 0);

  const proximo = pagos.find((pg: any) => pg.estado === 'pendiente' || pg.estado === 'parcial');

  res.json({
    ...p,
    pagos,
    movimientos: movR.recordset,
    total_pagado_capital,
    total_pagado_mora,
    total_pendiente,
    proximo,
  });
});

/**
 * POST /api/prestamos/:id/cobrar — mamá registra un cobro
 * body: { pago_id, monto, mora_perdonada?, metodo?, notas? }
 *
 * El sistema aplica el monto primero a MORA pendiente, luego a CAPITAL del pago.
 * Si sobra, sugiere aplicar al siguiente pago (o queda como sobrante).
 */
router.post('/:id/cobrar', requireAdmin, async (req: any, res) => {
  const prestamo_id = Number(req.params.id);
  const { pago_id, monto, mora_perdonada, metodo, notas } = req.body ?? {};
  if (!pago_id || monto == null) return res.status(400).json({ error: 'Faltan datos' });

  const pR = await query(
    `SELECT pg.*, p.mora_diaria, p.usuario_id, u.telefono, u.nombre
       FROM dbo.pagos pg
       JOIN dbo.prestamos p ON p.id = pg.prestamo_id
       JOIN dbo.usuarios u ON u.id = p.usuario_id
      WHERE pg.id = @pid AND pg.prestamo_id = @rid`,
    { pid: pago_id, rid: prestamo_id },
  );
  const pg = pR.recordset[0];
  if (!pg) return res.status(404).json({ error: 'Pago no encontrado' });
  if (pg.estado === 'pagado' || pg.estado === 'pagado_anticipado')
    return res.status(400).json({ error: 'Ese pago ya está saldado' });

  const saldo = saldoPago({ ...pg, mora_diaria: pg.mora_diaria }, new Date());
  const perdonada = Math.min(Number(mora_perdonada) || 0, saldo.mora_pendiente);
  const mora_effective = saldo.mora_pendiente - perdonada;

  const totalRecibido = Number(monto);
  // Aplicar primero a mora, luego a capital
  const aplicadoMora = Math.min(mora_effective, totalRecibido);
  const aplicadoCapital = Math.min(saldo.capital_pendiente, totalRecibido - aplicadoMora);
  const sobrante = totalRecibido - aplicadoMora - aplicadoCapital;

  // Insert movimiento
  await query(
    `INSERT INTO dbo.movimientos
       (pago_id, prestamo_id, usuario_id, monto_capital, monto_mora, mora_perdonada, metodo, notas, registrado_por)
     VALUES (@pg, @pr, @u, @mc, @mm, @mp, @met, @no, @rp)`,
    {
      pg: pago_id, pr: prestamo_id, u: pg.usuario_id,
      mc: aplicadoCapital, mm: aplicadoMora, mp: perdonada,
      met: metodo || 'efectivo', no: notas ?? null, rp: req.user.id,
    },
  );

  // Actualiza acumulados en pagos
  const nuevoCapital = Number(pg.monto_pagado_capital) + aplicadoCapital;
  const nuevoMora = Number(pg.monto_pagado_mora) + aplicadoMora;
  const nuevoPerdon = Number(pg.mora_perdonada_total) + perdonada;
  const nuevoEstado =
    nuevoCapital >= Number(pg.monto_esperado) ? 'pagado' : 'parcial';

  await query(
    `UPDATE dbo.pagos SET
       monto_pagado_capital = @mc,
       monto_pagado_mora = @mm,
       mora_perdonada_total = @mp,
       fecha_pagada = CASE WHEN @e = 'pagado' THEN SYSUTCDATETIME() ELSE fecha_pagada END,
       estado = @e,
       updated_at = SYSUTCDATETIME()
     WHERE id = @id`,
    { mc: nuevoCapital, mm: nuevoMora, mp: nuevoPerdon, e: nuevoEstado, id: pago_id },
  );

  // Si todos los pagos están saldados, liquida el préstamo
  const pend = await query(
    `SELECT COUNT(*) AS n FROM dbo.pagos
      WHERE prestamo_id = @r AND estado IN ('pendiente', 'parcial')`,
    { r: prestamo_id },
  );
  const liquidado = pend.recordset[0].n === 0;
  if (liquidado) {
    await query(
      `UPDATE dbo.prestamos SET estado = 'liquidado', fecha_liquidacion = CAST(SYSUTCDATETIME() AS DATE) WHERE id = @id`,
      { id: prestamo_id },
    );
  }

  await notificar({
    telefono: pg.telefono,
    tipo: 'pago_registrado',
    data: {
      nombre: pg.nombre,
      monto: Number(monto),
      folio: `PANDITA-${String(prestamo_id).padStart(3, '0')}`,
    },
    ref_prestamo: prestamo_id,
    ref_pago: pago_id,
  }).catch(() => {});

  res.json({ ok: true, liquidado, aplicadoCapital, aplicadoMora, sobrante, perdonada });
});

/** POST /api/prestamos/simular — cálculo previo */
router.post('/simular', async (req, res) => {
  const { principal, tasa_mensual, plazo_meses, frecuencia } = req.body ?? {};
  if (!principal || !tasa_mensual || !plazo_meses) return res.status(400).json({ error: 'Faltan datos' });
  const frec = (frecuencia === 'quincenal') ? 'quincenal' : 'mensual';
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
    frecuencia: frec,
  });
  res.json({ ...calc, pagos, frecuencia: frec });
});

/** GET /api/prestamos/mios — cliente ve sus préstamos */
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

export default router;

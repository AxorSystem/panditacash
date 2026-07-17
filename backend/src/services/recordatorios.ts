/**
 * Servicio de recordatorios automáticos por WhatsApp.
 * Corre 1 vez al día (a las 9am hora CDMX) y envía:
 *   - 3 días antes del vencimiento → WA al cliente
 *   - Día del vencimiento          → WA al cliente
 *   - 1 día después si no pagó     → WA a mamá con alerta
 *
 * Usa dbo.notificaciones para no duplicar recordatorios el mismo día.
 */
import { query } from '../db.js';
import { enviarWA, notificar } from '../lib/wa.js';
import { moraAcumuladaBruta, diasRetraso } from '../lib/finanzas.js';

const HORA_ENVIO = 9;  // 9am hora local

function fmt(n: number): string {
  return '$' + Math.round(Number(n)).toLocaleString('es-MX');
}
function fmtDia(d: Date | string): string {
  return new Date(d).toLocaleDateString('es-MX', { day: '2-digit', month: 'long' });
}

/** Ya se envió hoy un recordatorio de este tipo para este pago? */
async function yaEnviadoHoy(tipo: string, ref_pago: number): Promise<boolean> {
  const r = await query(
    `SELECT TOP 1 id FROM dbo.notificaciones
      WHERE tipo = @t AND ref_pago = @p
        AND CAST(enviado_at AS DATE) = CAST(SYSUTCDATETIME() AS DATE)`,
    { t: tipo, p: ref_pago },
  );
  return r.recordset.length > 0;
}

export async function ejecutarRecordatorios() {
  console.log('[recordatorios] Ejecutando barrido...');
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);

  // Trae todos los pagos pendientes/parciales de préstamos activos
  const r = await query(
    `SELECT pg.id AS pago_id, pg.prestamo_id, pg.numero_pago, pg.monto_esperado,
            pg.fecha_programada, pg.monto_pagado_capital, pg.monto_pagado_mora,
            pg.mora_perdonada_total,
            p.mora_diaria, p.frecuencia,
            u.id AS cliente_id, u.nombre AS cliente_nombre, u.telefono AS cliente_tel
       FROM dbo.pagos pg
       JOIN dbo.prestamos p ON p.id = pg.prestamo_id
       JOIN dbo.usuarios u ON u.id = p.usuario_id
      WHERE pg.estado IN ('pendiente', 'parcial') AND p.estado = 'activo'`,
  );

  const mamas = await query(
    `SELECT id, telefono, nombre FROM dbo.usuarios WHERE es_admin = 1 AND activo = 1`,
  );

  let enviados = 0;
  let saltados = 0;

  for (const pg of r.recordset) {
    const fp = new Date(pg.fecha_programada);
    fp.setHours(0, 0, 0, 0);
    const diffDias = Math.round((fp.getTime() - hoy.getTime()) / 86400000);
    const capital_pend = Math.max(0, Number(pg.monto_esperado) - Number(pg.monto_pagado_capital));
    const mora = moraAcumuladaBruta(pg.fecha_programada, Number(pg.mora_diaria), new Date())
                 - Number(pg.monto_pagado_mora) - Number(pg.mora_perdonada_total);
    const total = capital_pend + Math.max(0, mora);
    if (total <= 0) continue;

    const folio = `PANDITA-${String(pg.prestamo_id).padStart(3, '0')}`;

    // Caso 1: faltan 3 días → template
    if (diffDias === 3) {
      if (await yaEnviadoHoy('vence_pronto', pg.pago_id)) { saltados++; continue; }
      const ok = await notificar({
        telefono: pg.cliente_tel,
        tipo: 'vence_pronto',
        data: { nombre: pg.cliente_nombre, monto: total, fecha_str: fmtDia(pg.fecha_programada), folio },
        ref_pago: pg.pago_id, ref_prestamo: pg.prestamo_id,
      });
      if (ok.ok) enviados++;
    }

    // Caso 2: vence hoy → template
    else if (diffDias === 0) {
      if (await yaEnviadoHoy('vence_hoy', pg.pago_id)) { saltados++; continue; }
      const ok = await notificar({
        telefono: pg.cliente_tel,
        tipo: 'vence_hoy',
        data: { nombre: pg.cliente_nombre, monto: total, fecha_str: 'hoy mismo', folio },
        ref_pago: pg.pago_id, ref_prestamo: pg.prestamo_id,
      });
      if (ok.ok) enviados++;
    }

    // Caso 3: 1 día después → alerta a mamá (freeform, mamá está en ventana)
    else if (diffDias === -1) {
      if (await yaEnviadoHoy('vencido_alerta_mama', pg.pago_id)) { saltados++; continue; }
      for (const m of mamas.recordset) {
        const msg = `🐼 PanditaCash\n\n🚨 ${pg.cliente_nombre} no pagó ayer.\n\nDebe: ${fmt(total)}\nMora sumando: ${fmt(pg.mora_diaria)}/día\n\nCóbrale.`;
        const ok = await enviarWA({ telefono: m.telefono, mensaje: msg, tipo: 'vencido_alerta_mama', ref_pago: pg.pago_id, ref_prestamo: pg.prestamo_id });
        if (ok.ok) enviados++;
      }
    }

    // Caso 4: cada 7 días de atraso → template al cliente
    else if (diffDias < -1 && Math.abs(diffDias) % 7 === 0) {
      if (await yaEnviadoHoy('vencido_semanal', pg.pago_id)) { saltados++; continue; }
      const dias = diasRetraso(pg.fecha_programada, new Date());
      const ok = await notificar({
        telefono: pg.cliente_tel,
        tipo: 'vencido_semanal',
        data: { nombre: pg.cliente_nombre, monto: total, fecha_str: `vencido hace ${dias} días`, folio },
        ref_pago: pg.pago_id, ref_prestamo: pg.prestamo_id,
      });
      if (ok.ok) enviados++;
    }
  }

  console.log(`[recordatorios] Enviados: ${enviados}, saltados (ya enviado hoy): ${saltados}`);
  return { enviados, saltados };
}

let lastRunDay: string | null = null;

/**
 * Programa el barrido: revisa cada 30 min si ya son las 9am y aún no se ha
 * corrido HOY. Si sí, ejecuta. Simple y sin dependencias externas.
 */
export function iniciarScheduler() {
  const check = async () => {
    try {
      const ahora = new Date();
      // Convierte a hora CDMX (UTC-6, o UTC-5 en horario de verano). Usamos UTC-6 fijo.
      const hCdmx = new Date(ahora.getTime() - 6 * 3600 * 1000);
      const hoy = hCdmx.toISOString().slice(0, 10);
      if (hCdmx.getUTCHours() >= HORA_ENVIO && lastRunDay !== hoy) {
        lastRunDay = hoy;
        await ejecutarRecordatorios();
      }
    } catch (e: any) {
      console.error('[recordatorios] error:', e.message);
    }
  };
  // Chequea cada 30 minutos
  setInterval(check, 30 * 60 * 1000);
  // Primer chequeo inmediato al arrancar
  setTimeout(check, 5000);
  console.log(`[recordatorios] Scheduler iniciado (envío diario a las ${HORA_ENVIO}am CDMX)`);
}

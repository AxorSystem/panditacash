/**
 * Score interno de cliente: reglas de negocio basadas EXCLUSIVAMENTE en
 * el historial dentro de PanditaCash. Sin buró externo.
 */
import { query } from '../db.js';

export type NivelScore = 'nuevo' | 'bronce' | 'plata' | 'oro' | 'bloqueado';

export interface ScoreCliente {
  usuario_id: number;
  nivel: NivelScore;
  emoji: string;
  puntualidad_pct: number;         // 0-100
  prestamos_liquidados: number;
  prestamos_activos: number;
  atrasos_totales: number;         // # de pagos históricos pagados con retraso
  atrasos_serios: number;          // # de pagos históricos con >7 días retraso
  atraso_max_actual: number;       // días del pago activo más atrasado
  monto_maximo_sugerido: number;
  activos_maximos: number;
  tasa_sugerida_pct: number;
  razones: string[];               // flags que explican el nivel
  puede_prestamo_nuevo: boolean;
}

const REGLAS = {
  nuevo:      { monto: 2000,  activos: 1, tasa: 20, emoji: '🆕' },
  bronce:     { monto: 5000,  activos: 1, tasa: 18, emoji: '🥉' },
  plata:      { monto: 10000, activos: 2, tasa: 15, emoji: '🥈' },
  oro:        { monto: 25000, activos: 3, tasa: 12, emoji: '🥇' },
  bloqueado:  { monto: 0,     activos: 0, tasa: 0,  emoji: '🚫' },
};

export async function calcularScore(usuario_id: number): Promise<ScoreCliente> {
  // Historial completo del cliente
  const prR = await query(
    `SELECT id, estado, principal FROM dbo.prestamos WHERE usuario_id = @u`,
    { u: usuario_id },
  );
  const prestamos = prR.recordset;
  const activos = prestamos.filter((p: any) => p.estado === 'activo').length;
  const liquidados = prestamos.filter((p: any) => p.estado === 'liquidado').length;

  // Todos los pagos NO-anticipados (que efectivamente el cliente tuvo que pagar)
  const pagosR = await query(
    `SELECT pg.id, pg.estado, pg.fecha_programada, pg.fecha_pagada,
            pg.monto_pagado_capital, pg.monto_esperado,
            p.mora_diaria
       FROM dbo.pagos pg
       JOIN dbo.prestamos p ON p.id = pg.prestamo_id
      WHERE p.usuario_id = @u AND pg.estado <> 'pagado_anticipado'`,
    { u: usuario_id },
  );

  const hoy = new Date(); hoy.setHours(0, 0, 0, 0);
  let cumplidos = 0, atrasos_totales = 0, atrasos_serios = 0, atraso_max_actual = 0;

  for (const pg of pagosR.recordset) {
    const fp = new Date(pg.fecha_programada); fp.setHours(0, 0, 0, 0);
    if (pg.estado === 'pagado' && pg.fecha_pagada) {
      const fpag = new Date(pg.fecha_pagada); fpag.setHours(0, 0, 0, 0);
      const dias = Math.floor((fpag.getTime() - fp.getTime()) / 86400000);
      if (dias <= 0) cumplidos++;
      else {
        atrasos_totales++;
        if (dias > 7) atrasos_serios++;
      }
    } else if (pg.estado === 'pendiente' || pg.estado === 'parcial') {
      const dias = Math.floor((hoy.getTime() - fp.getTime()) / 86400000);
      if (dias > atraso_max_actual) atraso_max_actual = Math.max(0, dias);
    }
  }

  const total_evaluables = cumplidos + atrasos_totales;
  const puntualidad_pct = total_evaluables === 0 ? 100 : Math.round((cumplidos / total_evaluables) * 100);

  const razones: string[] = [];
  let nivel: NivelScore;

  // Reglas de bloqueo (más estrictas primero)
  if (atraso_max_actual > 30) {
    nivel = 'bloqueado';
    razones.push(`Tiene ${atraso_max_actual} días de atraso en pago actual`);
  } else if (atrasos_serios >= 3) {
    nivel = 'bloqueado';
    razones.push(`${atrasos_serios} atrasos históricos mayores a 7 días`);
  }
  // Reglas de nivel
  else if (liquidados === 0 && activos === 0) {
    nivel = 'nuevo';
    razones.push('Cliente nuevo — sin historial previo');
  } else if (liquidados >= 3 && puntualidad_pct === 100) {
    nivel = 'oro';
    razones.push(`${liquidados} préstamos liquidados con 100% puntualidad`);
  } else if (liquidados >= 2 && puntualidad_pct >= 80) {
    nivel = 'plata';
    razones.push(`${liquidados} préstamos liquidados con ${puntualidad_pct}% puntualidad`);
  } else if (liquidados >= 1 && atrasos_serios === 0) {
    nivel = 'bronce';
    razones.push(`${liquidados} préstamo liquidado sin atrasos serios`);
  } else if (liquidados === 0 && activos >= 1) {
    // Cliente con préstamo activo pero sin liquidar aún
    nivel = 'nuevo';
    razones.push('Sin préstamos liquidados aún');
  } else {
    nivel = 'bronce';
    razones.push('Historial mixto');
  }

  // Info adicional útil
  if (atrasos_totales > 0 && nivel !== 'bloqueado') {
    razones.push(`${atrasos_totales} pagos históricos con atraso (${atrasos_serios} graves)`);
  }
  if (atraso_max_actual > 0 && atraso_max_actual <= 30 && nivel !== 'bloqueado') {
    razones.push(`⚠️ Actualmente tiene un pago atrasado ${atraso_max_actual} días`);
  }
  if (activos > 0 && nivel !== 'bloqueado') {
    razones.push(`Tiene ${activos} préstamo${activos === 1 ? '' : 's'} activo${activos === 1 ? '' : 's'}`);
  }

  const r = REGLAS[nivel];
  const puede_prestamo_nuevo = nivel !== 'bloqueado' && activos < r.activos;

  return {
    usuario_id,
    nivel,
    emoji: r.emoji,
    puntualidad_pct,
    prestamos_liquidados: liquidados,
    prestamos_activos: activos,
    atrasos_totales,
    atrasos_serios,
    atraso_max_actual,
    monto_maximo_sugerido: r.monto,
    activos_maximos: r.activos,
    tasa_sugerida_pct: r.tasa,
    razones,
    puede_prestamo_nuevo,
  };
}

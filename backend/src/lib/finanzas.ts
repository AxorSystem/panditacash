/**
 * Cálculos del negocio PanditaCash.
 * Reglas:
 * - Se cobra el interés del primer mes por adelantado (retención al entregar)
 * - Meses intermedios: solo interés
 * - Último mes: principal completo (sin interés adicional)
 * - Mora diaria por cada día de retraso, mamá puede perdonar total o parcial
 */

export interface Prestamo {
  principal: number;
  tasa_mensual: number;
  plazo_meses: number;
  mora_diaria: number;
  fecha_inicio: string | Date;
}

export interface CalculoPrestamo {
  interes_mensual: number;
  monto_entregado: number;
  total_a_pagar: number;
  ganancia_total: number;
}

export function calcularPrestamo(p: {
  principal: number;
  tasa_mensual: number;
  plazo_meses: number;
}): CalculoPrestamo {
  const interes_mensual = p.principal * p.tasa_mensual;
  const monto_entregado = p.principal - interes_mensual;
  const total_meses_interes = Math.max(0, p.plazo_meses - 2);
  const total_a_pagar = interes_mensual * total_meses_interes + p.principal;
  const ganancia_total = interes_mensual * (p.plazo_meses - 1);
  return { interes_mensual, monto_entregado, total_a_pagar, ganancia_total };
}

export interface PagoProgramado {
  numero_pago: number;
  monto_esperado: number;
  fecha_programada: Date;
  tipo: 'interes' | 'principal' | 'interes+principal';
  estado_inicial: 'pagado_anticipado' | 'pendiente';
}

export function generarPagosProgramados(p: Prestamo): PagoProgramado[] {
  const { interes_mensual } = calcularPrestamo(p);
  const fechaInicio = new Date(p.fecha_inicio);
  const pagos: PagoProgramado[] = [];

  pagos.push({
    numero_pago: 1,
    monto_esperado: interes_mensual,
    fecha_programada: fechaInicio,
    tipo: 'interes',
    estado_inicial: 'pagado_anticipado',
  });

  for (let i = 2; i < p.plazo_meses; i++) {
    const fecha = new Date(fechaInicio);
    fecha.setMonth(fecha.getMonth() + i - 1);
    pagos.push({
      numero_pago: i,
      monto_esperado: interes_mensual,
      fecha_programada: fecha,
      tipo: 'interes',
      estado_inicial: 'pendiente',
    });
  }

  const ultimaFecha = new Date(fechaInicio);
  ultimaFecha.setMonth(ultimaFecha.getMonth() + p.plazo_meses - 1);
  pagos.push({
    numero_pago: p.plazo_meses,
    monto_esperado: p.principal,
    fecha_programada: ultimaFecha,
    tipo: 'principal',
    estado_inicial: 'pendiente',
  });

  return pagos;
}

export function diasRetraso(fecha_programada: Date | string, hoy: Date = new Date()): number {
  const f = new Date(fecha_programada);
  f.setHours(0, 0, 0, 0);
  const h = new Date(hoy);
  h.setHours(0, 0, 0, 0);
  const diff = Math.floor((h.getTime() - f.getTime()) / (24 * 3600 * 1000));
  return Math.max(0, diff);
}

/** Mora acumulada bruta (sin perdones) al día de hoy. */
export function moraAcumuladaBruta(fecha_programada: Date | string, mora_diaria: number, hoy: Date = new Date()): number {
  return diasRetraso(fecha_programada, hoy) * mora_diaria;
}

/**
 * Saldo pendiente de un pago considerando lo ya cobrado.
 * Retorna cuánto FALTA por cobrar dividido en capital + mora.
 */
export function saldoPago(pg: {
  monto_esperado: number;
  monto_pagado_capital: number;
  monto_pagado_mora: number;
  mora_perdonada_total: number;
  fecha_programada: Date | string;
  mora_diaria: number;
}, hoy: Date = new Date()) {
  const capital_pendiente = Math.max(0, Number(pg.monto_esperado) - Number(pg.monto_pagado_capital));
  const mora_bruta = moraAcumuladaBruta(pg.fecha_programada, Number(pg.mora_diaria), hoy);
  const mora_pendiente = Math.max(0, mora_bruta - Number(pg.monto_pagado_mora) - Number(pg.mora_perdonada_total));
  return {
    capital_pendiente,
    mora_pendiente,
    mora_bruta,
    total_pendiente: capital_pendiente + mora_pendiente,
    dias_retraso: diasRetraso(pg.fecha_programada, hoy),
  };
}

/**
 * Cálculos del negocio PanditaCash.
 *
 * Modelo: se cobra el interés del primer mes por adelantado (retención al entregar).
 * Meses intermedios: solo interés. Último mes: principal completo (sin interés adicional).
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
  total_a_pagar: number;      // suma de todos los pagos futuros
  ganancia_total: number;     // ganancia neta de mamá al liquidar
}

export function calcularPrestamo(p: {
  principal: number;
  tasa_mensual: number;
  plazo_meses: number;
}): CalculoPrestamo {
  const interes_mensual = p.principal * p.tasa_mensual;
  const monto_entregado = p.principal - interes_mensual;
  // meses intermedios pagan interés, último paga principal
  const total_meses_interes = Math.max(0, p.plazo_meses - 2);   // -1 mes ya cobrado, -1 último es principal
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

/**
 * Genera los pagos programados de un préstamo:
 * - Pago 1 = pagado_anticipado (mamá lo retuvo al entregar)
 * - Pagos 2..N-1 = interés
 * - Pago N = principal (sin interés)
 *
 * Si plazo = 1: pago 1 pagado_anticipado (interés) + pago 2 = principal
 * Si plazo = 2: pago 1 pagado_anticipado (interés) + pago 2 = principal
 * Si plazo = 3: pago 1 pagado_anticipado + pago 2 interés + pago 3 principal
 */
export function generarPagosProgramados(p: Prestamo): PagoProgramado[] {
  const { interes_mensual } = calcularPrestamo(p);
  const fechaInicio = new Date(p.fecha_inicio);
  const pagos: PagoProgramado[] = [];

  // Pago 1: retención al entregar (ya pagado)
  pagos.push({
    numero_pago: 1,
    monto_esperado: interes_mensual,
    fecha_programada: fechaInicio,
    tipo: 'interes',
    estado_inicial: 'pagado_anticipado',
  });

  // Pagos 2..N-1: solo interés
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

  // Pago N: principal
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

/** Días de retraso vs hoy. 0 si aún no vence. */
export function diasRetraso(fecha_programada: Date | string, hoy: Date = new Date()): number {
  const f = new Date(fecha_programada);
  f.setHours(0, 0, 0, 0);
  const h = new Date(hoy);
  h.setHours(0, 0, 0, 0);
  const diff = Math.floor((h.getTime() - f.getTime()) / (24 * 3600 * 1000));
  return Math.max(0, diff);
}

/** Mora acumulada al día de hoy. */
export function moraAcumulada(fecha_programada: Date | string, mora_diaria: number, hoy: Date = new Date()): number {
  return diasRetraso(fecha_programada, hoy) * mora_diaria;
}

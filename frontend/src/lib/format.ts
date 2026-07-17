export function fmt(n: number | string | null | undefined): string {
  const v = Number(n) || 0;
  return '$' + Math.round(v).toLocaleString('es-MX');
}

export function fmtDia(d: string | Date | null | undefined): string {
  if (!d) return '';
  return new Date(d).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' });
}

export function fmtDiaCorto(d: string | Date | null | undefined): string {
  if (!d) return '';
  return new Date(d).toLocaleDateString('es-MX', { day: '2-digit', month: 'short' });
}

export function fmtHora(d: string | Date | null | undefined): string {
  if (!d) return '';
  return new Date(d).toLocaleString('es-MX', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
}

export function diasHasta(d: string | Date): number {
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0);
  const f = new Date(d); f.setHours(0, 0, 0, 0);
  return Math.round((f.getTime() - hoy.getTime()) / 86400000);
}

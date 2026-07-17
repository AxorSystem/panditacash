import { config } from '../config.js';
import { query } from '../db.js';

/**
 * Notificaciones WhatsApp de PanditaCash.
 *
 * Dos vías de envío:
 *   1) Template APPROVED de Meta → llega SIEMPRE (fuera de ventana 24h).
 *   2) Texto libre (freeform) → solo llega si el destinatario escribió al bot
 *      en las últimas 24h. Se usa cuando mamá es la destinataria (siempre
 *      está en ventana) o como fallback.
 *
 * Loguea a dbo.notificaciones cada intento.
 */

export type TipoNotif =
  | 'otp'
  | 'nuevo_prestamo'
  | 'solicitud_aprobada'
  | 'solicitud_rechazada'
  | 'pago_registrado'
  | 'vence_pronto'
  | 'vence_hoy'
  | 'vencido_semanal'
  | 'vencido_alerta_mama'
  | 'solicitud_recibida'
  | 'aviso_pago_cliente';

interface EnvioParams {
  telefono: string;
  tipo: TipoNotif;
  // Para templates
  template?: string;
  parameters?: string[];
  language?: string;
  // Para freeform / fallback
  mensaje?: string;
  ref_prestamo?: number | null;
  ref_pago?: number | null;
}

async function enviar(
  endpoint: 'whatsapp' | 'whatsapp-template',
  body: Record<string, any>,
  opts: EnvioParams,
): Promise<{ ok: boolean; error?: string }> {
  const tel = normalizarTel(opts.telefono);
  let ok = false;
  let error: string | undefined;
  try {
    const r = await fetch(`${config.notif.url}/api/send/${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-otp-secret': config.notif.otpSecret,
      },
      body: JSON.stringify({ ...body, to: tel, app: 'panditacash' }),
    });
    if (r.ok) {
      ok = true;
    } else {
      const j = await r.json().catch(() => ({}));
      error = j.error || `HTTP ${r.status}`;
    }
  } catch (e: any) {
    error = e.message;
  }
  await query(
    `INSERT INTO dbo.notificaciones (telefono, tipo, canal, mensaje, ref_prestamo, ref_pago, exito, error_msg)
     VALUES (@tel, @tipo, 'whatsapp', @msg, @rp, @rpg, @ok, @err)`,
    {
      tel,
      tipo: opts.tipo,
      msg: opts.template ? `[tpl:${opts.template}] ${(opts.parameters || []).join(' | ')}` : opts.mensaje ?? '',
      rp: opts.ref_prestamo ?? null,
      rpg: opts.ref_pago ?? null,
      ok: ok ? 1 : 0,
      err: error ?? null,
    },
  ).catch(() => {});
  return { ok, error };
}

/**
 * Envía usando template APPROVED. Es la vía preferida para clientes
 * (garantiza entrega fuera de la ventana de 24h).
 */
export async function enviarTemplate(opts: {
  telefono: string;
  tipo: TipoNotif;
  template: string;
  parameters: string[];
  language?: string;
  ref_prestamo?: number | null;
  ref_pago?: number | null;
}) {
  return enviar('whatsapp-template', {
    template: opts.template,
    language: opts.language || 'es_MX',
    parameters: opts.parameters,
  }, opts);
}

/**
 * Envía texto libre. Solo llega si el destinatario está dentro de la ventana
 * de 24h. Útil para: mamá (siempre en ventana) y clientes que acaban de
 * escribir al bot.
 */
export async function enviarWA(opts: {
  telefono: string;
  mensaje: string;
  tipo: TipoNotif;
  ref_prestamo?: number | null;
  ref_pago?: number | null;
}) {
  return enviar('whatsapp', { message: opts.mensaje }, opts);
}

function fmtMoney(n: number): string {
  return '$' + Math.round(Number(n)).toLocaleString('es-MX');
}
function fmtFecha(d: Date | string): string {
  return new Date(d).toLocaleDateString('es-MX', { day: '2-digit', month: 'long' });
}

/**
 * Fachada de alto nivel: dispara la mejor variante según el tipo.
 *   - Notificaciones a CLIENTE con evento programable → template APPROVED.
 *   - Notificaciones a MAMÁ o triviales conversacionales → freeform.
 */
export async function notificar(opts: {
  telefono: string;
  tipo: TipoNotif;
  data: Record<string, any>;
  ref_prestamo?: number | null;
  ref_pago?: number | null;
}) {
  const { telefono, tipo, data, ref_prestamo, ref_pago } = opts;
  const primerNombre = String(data.nombre ?? '').split(' ')[0] || 'Cliente';
  const folio = String(data.folio ?? `PANDITA-${ref_prestamo ?? '000'}`);

  switch (tipo) {
    case 'nuevo_prestamo':
    case 'solicitud_aprobada':
      // Template: común_bienvenida ({{1}}=nombre, {{2}}=servicio)
      return enviarTemplate({
        telefono, tipo, ref_prestamo, ref_pago,
        template: 'common_bienvenida',
        parameters: [primerNombre, 'PanditaCash'],
      });

    case 'pago_registrado':
      // Template: common_pago_confirmado ({{1}}=nombre, {{2}}=monto, {{3}}=servicio, {{4}}=folio)
      return enviarTemplate({
        telefono, tipo, ref_prestamo, ref_pago,
        template: 'common_pago_confirmado',
        parameters: [primerNombre, fmtMoney(data.monto ?? 0), 'PanditaCash', folio],
      });

    case 'vence_pronto':
    case 'vence_hoy':
    case 'vencido_semanal':
      // Template: axor_recordatorio_pago ({{1}}=nombre, {{2}}=monto, {{3}}=fecha, {{4}}=folio)
      return enviarTemplate({
        telefono, tipo, ref_prestamo, ref_pago,
        template: 'axor_recordatorio_pago',
        parameters: [
          primerNombre,
          fmtMoney(data.monto ?? 0),
          data.fecha_str || (data.fecha_programada ? fmtFecha(data.fecha_programada) : 'próximamente'),
          folio,
        ],
      });

    // Mamá o dentro-de-ventana → freeform con el mensaje literal
    default:
      return enviarWA({
        telefono, tipo, ref_prestamo, ref_pago,
        mensaje: data.mensaje || '',
      });
  }
}

/** Normaliza a 12 dígitos: 52 + 10 (compatible con Meta y WhatsApp Business). */
export function normalizarTel(t: string): string {
  const digits = String(t).replace(/\D/g, '');
  if (digits.length === 10) return `52${digits}`;
  if (digits.length === 12 && digits.startsWith('52')) return digits;
  if (digits.length === 13 && digits.startsWith('521')) return `52${digits.slice(3)}`;
  return digits;
}

export function generarOTP(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}

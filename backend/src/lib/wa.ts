import { config } from '../config.js';
import { query } from '../db.js';

/**
 * Envía WhatsApp usando el notifications-backend compartido de AxorCloud.
 * Loguea a dbo.notificaciones sea o no exitoso.
 */
export async function enviarWA(opts: {
  telefono: string;                   // 10 dígitos MX o con lada
  mensaje: string;
  tipo: string;                       // vence_pronto | vence_hoy | vencido | nuevo_prestamo | pago_registrado | solicitud_recibida
  ref_prestamo?: number | null;
  ref_pago?: number | null;
}): Promise<{ ok: boolean; error?: string }> {
  const tel = normalizarTel(opts.telefono);
  let ok = false;
  let error: string | undefined;
  try {
    const r = await fetch(`${config.notif.url}/api/send/whatsapp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-otp-secret': config.notif.otpSecret,
      },
      body: JSON.stringify({ to: tel, message: opts.mensaje, app: 'panditacash' }),
    });
    if (r.ok) {
      ok = true;
    } else {
      error = `HTTP ${r.status}`;
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
      msg: opts.mensaje,
      rp: opts.ref_prestamo ?? null,
      rpg: opts.ref_pago ?? null,
      ok: ok ? 1 : 0,
      err: error ?? null,
    },
  ).catch(() => {});
  return { ok, error };
}

/** Normaliza a 10 dígitos + código país 52 si viene sin él. */
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

import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { query } from '../db.js';
import { signToken } from '../lib/auth.js';
import { enviarWA, generarOTP, normalizarTel } from '../lib/wa.js';

const router = Router();

/** POST /api/auth/mama/login  { telefono, pin }   — solo admin */
router.post('/mama/login', async (req, res) => {
  const { telefono, pin } = req.body ?? {};
  if (!telefono || !pin) return res.status(400).json({ error: 'Faltan datos' });

  const tel = normalizarTel(telefono);
  const r = await query(
    `SELECT id, telefono, nombre, es_admin, pin_hash FROM dbo.usuarios
      WHERE telefono = @t AND es_admin = 1 AND activo = 1`,
    { t: tel },
  );
  const user = r.recordset[0];
  if (!user) return res.status(401).json({ error: 'Datos incorrectos' });

  const ok = await bcrypt.compare(String(pin), user.pin_hash);
  if (!ok) return res.status(401).json({ error: 'PIN incorrecto' });

  await query('UPDATE dbo.usuarios SET last_login = SYSUTCDATETIME() WHERE id = @id', { id: user.id });
  const token = signToken({
    id: user.id, telefono: user.telefono, nombre: user.nombre, es_admin: true,
  });
  res.json({ token, user: { id: user.id, nombre: user.nombre, es_admin: true } });
});

/** POST /api/auth/mama/change-pin   auth requerida */
router.post('/mama/change-pin', async (req: any, res) => {
  // Simplificado: requiere el token normal, no re-auth
  const { pin_actual, pin_nuevo } = req.body ?? {};
  if (!pin_nuevo || String(pin_nuevo).length < 4)
    return res.status(400).json({ error: 'PIN nuevo requerido (mín 4 dígitos)' });

  const auth = req.headers.authorization?.replace('Bearer ', '') ?? '';
  const jwt = await import('jsonwebtoken');
  let payload: any;
  try { payload = jwt.default.verify(auth, process.env.JWT_SECRET || 'dev-secret-change-me'); }
  catch { return res.status(401).json({ error: 'No autenticado' }); }

  const r = await query('SELECT pin_hash FROM dbo.usuarios WHERE id = @id', { id: payload.id });
  const ok = await bcrypt.compare(String(pin_actual), r.recordset[0].pin_hash);
  if (!ok) return res.status(401).json({ error: 'PIN actual incorrecto' });

  const nuevo = await bcrypt.hash(String(pin_nuevo), 12);
  await query('UPDATE dbo.usuarios SET pin_hash = @p WHERE id = @id', { p: nuevo, id: payload.id });
  res.json({ ok: true });
});

/** POST /api/auth/cliente/request-otp  { telefono, nombre? } */
router.post('/cliente/request-otp', async (req, res) => {
  const { telefono, nombre } = req.body ?? {};
  if (!telefono) return res.status(400).json({ error: 'Teléfono requerido' });
  const tel = normalizarTel(telefono);

  // Si es nuevo, se registra al vuelo
  const existe = await query('SELECT id FROM dbo.usuarios WHERE telefono = @t', { t: tel });
  if (!existe.recordset[0]) {
    if (!nombre || String(nombre).trim().length < 3)
      return res.status(400).json({ error: 'Este número no está registrado. Escribe tu nombre completo para crearlo.' });
    await query(
      `INSERT INTO dbo.usuarios (telefono, nombre, es_admin) VALUES (@t, @n, 0)`,
      { t: tel, n: String(nombre).trim() },
    );
  }

  // Genera OTP válido 5 min
  const codigo = generarOTP();
  const expires = new Date(Date.now() + 5 * 60 * 1000);
  await query(
    `INSERT INTO dbo.otps (telefono, codigo, expires_at) VALUES (@t, @c, @e)`,
    { t: tel, c: codigo, e: expires },
  );

  // Envía por WA
  const msg = `🐼 PanditaCash\n\nTu código: ${codigo}\n\nVence en 5 minutos. No lo compartas.`;
  const wa = await enviarWA({ telefono: tel, mensaje: msg, tipo: 'otp' });

  res.json({ ok: true, sent_via: wa.ok ? 'whatsapp' : 'error', debug_code: wa.ok ? undefined : codigo });
});

/** POST /api/auth/cliente/verify-otp  { telefono, codigo } */
router.post('/cliente/verify-otp', async (req, res) => {
  const { telefono, codigo } = req.body ?? {};
  if (!telefono || !codigo) return res.status(400).json({ error: 'Faltan datos' });
  const tel = normalizarTel(telefono);

  const r = await query(
    `SELECT TOP 1 id, expires_at, usado FROM dbo.otps
      WHERE telefono = @t AND codigo = @c
      ORDER BY id DESC`,
    { t: tel, c: String(codigo) },
  );
  const otp = r.recordset[0];
  if (!otp) return res.status(401).json({ error: 'Código incorrecto' });
  if (otp.usado) return res.status(401).json({ error: 'Ese código ya fue usado' });
  if (new Date(otp.expires_at) < new Date()) return res.status(401).json({ error: 'El código expiró' });

  await query('UPDATE dbo.otps SET usado = 1 WHERE id = @id', { id: otp.id });

  const u = await query(
    `SELECT id, telefono, nombre, es_admin FROM dbo.usuarios WHERE telefono = @t`,
    { t: tel },
  );
  const user = u.recordset[0];
  await query('UPDATE dbo.usuarios SET last_login = SYSUTCDATETIME() WHERE id = @id', { id: user.id });

  const token = signToken({
    id: user.id, telefono: user.telefono, nombre: user.nombre, es_admin: !!user.es_admin,
  });
  res.json({ token, user: { id: user.id, nombre: user.nombre, es_admin: !!user.es_admin } });
});

/** GET /api/auth/me   auth requerida */
router.get('/me', async (req: any, res) => {
  const auth = req.headers.authorization?.replace('Bearer ', '') ?? '';
  const jwt = await import('jsonwebtoken');
  try {
    const payload = jwt.default.verify(auth, process.env.JWT_SECRET || 'dev-secret-change-me') as any;
    res.json({ user: payload });
  } catch {
    res.status(401).json({ error: 'No autenticado' });
  }
});

export default router;

import { Router } from 'express';
import multer from 'multer';
import fs from 'node:fs/promises';
import path from 'node:path';
import { query } from '../db.js';
import { requireAuth } from '../lib/auth.js';

const router = Router();
router.use(requireAuth);

// Storage local para documentos KYC (volumen /data/kyc dentro del container)
const KYC_DIR = process.env.KYC_STORAGE_DIR || '/data/kyc';

async function ensureDir() {
  await fs.mkdir(KYC_DIR, { recursive: true });
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 6 * 1024 * 1024 }, // 6 MB max
  fileFilter: (_req, file, cb) => {
    if (!/^image\/(jpeg|png|heic|webp)$/.test(file.mimetype)) {
      return cb(new Error('Solo se permiten imágenes JPG/PNG/HEIC/WEBP'));
    }
    cb(null, true);
  },
});

// POST /api/kyc/upload  { tipo }  (multipart file)
router.post('/upload', upload.single('imagen'), async (req: any, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Falta archivo' });
    const tipo = String(req.body?.tipo ?? '');
    const tipos = ['ine_frente', 'ine_reverso', 'selfie', 'comprobante_dom'];
    if (!tipos.includes(tipo)) return res.status(400).json({ error: 'Tipo inválido' });

    await ensureDir();
    const ext = req.file.mimetype.split('/')[1] || 'jpg';
    const filename = `u${req.user.id}_${tipo}_${Date.now()}.${ext}`;
    const abs = path.join(KYC_DIR, filename);
    await fs.writeFile(abs, req.file.buffer);

    // Reemplaza si ya existía uno del mismo tipo
    const existing = await query(
      `SELECT id, ruta FROM dbo.documentos_kyc WHERE usuario_id=@u AND tipo=@t`,
      { u: req.user.id, t: tipo },
    );
    if (existing.recordset[0]) {
      const oldPath = existing.recordset[0].ruta;
      await fs.unlink(oldPath).catch(() => {});
      await query(
        `UPDATE dbo.documentos_kyc SET ruta=@r, mime_type=@m, bytes=@b, validado=0, notas=NULL, created_at=SYSUTCDATETIME()
          WHERE id=@id`,
        { r: abs, m: req.file.mimetype, b: req.file.buffer.length, id: existing.recordset[0].id },
      );
    } else {
      await query(
        `INSERT INTO dbo.documentos_kyc (usuario_id, tipo, ruta, mime_type, bytes)
         VALUES (@u, @t, @r, @m, @b)`,
        { u: req.user.id, t: tipo, r: abs, m: req.file.mimetype, b: req.file.buffer.length },
      );
    }

    await refreshKycCompleto(req.user.id);
    res.json({ ok: true, tipo });
  } catch (e: any) {
    res.status(500).json({ error: e.message ?? 'Error subiendo archivo' });
  }
});

// GET /api/kyc/status
router.get('/status', async (req: any, res) => {
  const docs = await query(
    `SELECT tipo, validado, created_at FROM dbo.documentos_kyc WHERE usuario_id=@u`,
    { u: req.user.id },
  );
  const avales = await query(
    `SELECT COUNT(*) AS n FROM dbo.avales WHERE usuario_id=@u AND verificado_wa=1`,
    { u: req.user.id },
  );
  const tarjetas = await query(
    `SELECT COUNT(*) AS n FROM dbo.tarjetas_tokens WHERE usuario_id=@u AND activa=1`,
    { u: req.user.id },
  );
  const u = await query(
    `SELECT kyc_completo, kyc_completed_at FROM dbo.usuarios WHERE id=@u`,
    { u: req.user.id },
  );

  const tiposCompletos = new Set(docs.recordset.map((d: any) => d.tipo));
  res.json({
    kyc_completo: !!u.recordset[0]?.kyc_completo,
    documentos: docs.recordset,
    tiene_ine: tiposCompletos.has('ine_frente') && tiposCompletos.has('ine_reverso'),
    tiene_selfie: tiposCompletos.has('selfie'),
    avales_verificados: avales.recordset[0].n,
    tarjetas_activas: tarjetas.recordset[0].n,
    nivel_garantia: nivelGarantia({
      ine: tiposCompletos.has('ine_frente') && tiposCompletos.has('ine_reverso'),
      selfie: tiposCompletos.has('selfie'),
      aval: avales.recordset[0].n > 0,
      tarjeta: tarjetas.recordset[0].n > 0,
    }),
  });
});

// POST /api/kyc/aval  { nombre, telefono, relacion }
router.post('/aval', async (req: any, res) => {
  const { nombre, telefono, relacion } = req.body ?? {};
  if (!nombre || !telefono) return res.status(400).json({ error: 'Faltan datos del aval' });

  const insR = await query(
    `INSERT INTO dbo.avales (usuario_id, nombre, telefono, relacion)
     OUTPUT INSERTED.id VALUES (@u, @n, @t, @r)`,
    { u: req.user.id, n: nombre, t: telefono, r: relacion ?? null },
  );

  // TODO Fase 2: contactar al aval por WhatsApp y esperar OK
  res.json({ ok: true, aval_id: insR.recordset[0].id });
});

// TODO: endpoints tarjeta (Mercado Pago) — placeholders
router.post('/tarjeta/token', async (_req, res) => {
  res.status(501).json({ error: 'Integración Mercado Pago pendiente de credentials' });
});

// Refresca campo usuarios.kyc_completo (INE + selfie + al menos 1 aval verificado)
async function refreshKycCompleto(userId: number) {
  const chk = await query(
    `SELECT
      (SELECT COUNT(DISTINCT tipo) FROM dbo.documentos_kyc WHERE usuario_id=@u AND tipo IN ('ine_frente','ine_reverso','selfie')) AS docs_n,
      (SELECT COUNT(*) FROM dbo.avales WHERE usuario_id=@u AND verificado_wa=1) AS avales_n`,
    { u: userId },
  );
  const c = chk.recordset[0];
  const completo = c.docs_n >= 3 && c.avales_n >= 1;
  await query(
    `UPDATE dbo.usuarios SET kyc_completo=@c, kyc_completed_at=CASE WHEN @c=1 THEN SYSUTCDATETIME() ELSE NULL END WHERE id=@u`,
    { c: completo ? 1 : 0, u: userId },
  );
}

// Determina el nivel de garantía (afecta ceiling)
export function nivelGarantia(flags: { ine: boolean; selfie: boolean; aval: boolean; tarjeta: boolean }): {
  nivel: 'bronce' | 'plata' | 'oro' | 'inicial';
  monto_max: number;
} {
  if (flags.ine && flags.selfie && flags.aval && flags.tarjeta) return { nivel: 'oro', monto_max: 20000 };
  if (flags.ine && flags.selfie && flags.aval) return { nivel: 'plata', monto_max: 5000 };
  if (flags.ine && flags.selfie) return { nivel: 'bronce', monto_max: 2500 };
  return { nivel: 'inicial', monto_max: 500 };
}

export default router;

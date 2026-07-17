import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import { getPool, query } from './db.js';
import auth from './routes/auth.js';
import prestamos from './routes/prestamos.js';
import solicitudes from './routes/solicitudes.js';
import mi from './routes/mi.js';

const app = express();
app.disable('x-powered-by');

app.use(cors({ origin: config.cors.origins, credentials: true }));
app.use(express.json({ limit: '2mb' }));

app.get('/api/health', (req, res) => {
  res.json({ ok: true, service: 'panditacash-backend', ts: new Date().toISOString() });
});

app.get('/api/health/db', async (req, res) => {
  try {
    await query('SELECT 1 AS ok');
    res.json({ ok: true, ts: new Date().toISOString() });
  } catch (e: any) {
    res.status(503).json({ ok: false, error: e.message });
  }
});

app.use('/api/auth', auth);
app.use('/api/prestamos', prestamos);
app.use('/api/solicitudes', solicitudes);
app.use('/api/mi', mi);

app.use((req, res) => res.status(404).json({ error: 'ruta no encontrada' }));
app.use((err: any, req: any, res: any, _next: any) => {
  console.error('[error]', err);
  res.status(err.status || 500).json({ error: err.message || 'error interno' });
});

try {
  await getPool();
  app.listen(config.port, () => {
    console.log(`🐼 PanditaCash backend en :${config.port}`);
  });
} catch (e: any) {
  console.error('✗ No se pudo conectar a SQL Server:', e.message);
  process.exit(1);
}

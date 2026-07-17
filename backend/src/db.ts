import sql from 'mssql';
import { config } from './config.js';

const pool = new sql.ConnectionPool({
  server: config.db.server,
  port: config.db.port,
  user: config.db.user,
  password: config.db.password,
  database: config.db.database,
  options: {
    encrypt: config.db.encrypt,
    trustServerCertificate: config.db.trustServerCertificate,
  },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
  connectionTimeout: 15000,
});

let connecting: Promise<sql.ConnectionPool> | null = null;

export async function getPool(): Promise<sql.ConnectionPool> {
  if (!connecting) {
    connecting = pool.connect();
    connecting.catch(() => { connecting = null; });
  }
  await connecting;
  return pool;
}
pool.on('error', () => { connecting = null; });

export async function query<T = any>(
  text: string,
  params: Record<string, any> = {},
): Promise<{ recordset: T[]; rowsAffected: number[] }> {
  const p = await getPool();
  const req = p.request();
  for (const [key, value] of Object.entries(params)) req.input(key, value);
  return req.query(text) as any;
}

export { sql };

import 'dotenv/config';

export const config = {
  port: Number(process.env.PORT) || 4600,
  jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me',
  db: {
    server: process.env.SQL_HOST || 'axor-db',
    port: Number(process.env.SQL_PORT) || 1433,
    user: process.env.SQL_USER || 'sa',
    password: process.env.SQL_PASSWORD || '',
    database: process.env.SQL_DB || 'panditacash',
    encrypt: (process.env.SQL_ENCRYPT || 'false') === 'true',
    trustServerCertificate: (process.env.SQL_TRUST_CERT || 'true') === 'true',
  },
  cors: {
    origins: (process.env.CORS_ORIGINS || 'http://localhost:5173,https://panditacash.5-78-222-255.sslip.io').split(','),
  },
  notif: {
    url: process.env.NOTIF_URL || 'https://pjn97vt5z1cb70nke95gs0bg.5.78.222.255.sslip.io',
    otpSecret: process.env.OTP_SHARED_SECRET || '',
  },
};

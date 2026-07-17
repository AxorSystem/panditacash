-- ============================================================
-- PanditaCash — schema inicial
-- ============================================================
IF DB_ID('panditacash') IS NULL CREATE DATABASE panditacash;
GO
USE panditacash;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── USUARIOS ────────────────────────────────────────────────
IF OBJECT_ID('dbo.usuarios', 'U') IS NULL
CREATE TABLE dbo.usuarios (
  id             INT IDENTITY(1,1) PRIMARY KEY,
  telefono       NVARCHAR(20) NOT NULL UNIQUE,     -- 10 dígitos MX
  nombre         NVARCHAR(200) NOT NULL,
  es_admin       BIT NOT NULL DEFAULT 0,
  pin_hash       NVARCHAR(200) NULL,               -- bcrypt PIN (solo admin)
  activo         BIT NOT NULL DEFAULT 1,
  notas          NVARCHAR(1000) NULL,              -- notas privadas de mamá sobre el cliente
  created_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  last_login     DATETIME2 NULL
);

-- ── OTPs (para login clientes) ──────────────────────────────
IF OBJECT_ID('dbo.otps', 'U') IS NULL
CREATE TABLE dbo.otps (
  id             INT IDENTITY(1,1) PRIMARY KEY,
  telefono       NVARCHAR(20) NOT NULL,
  codigo         NVARCHAR(10) NOT NULL,
  expires_at     DATETIME2 NOT NULL,
  usado          BIT NOT NULL DEFAULT 0,
  created_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ── PRÉSTAMOS ───────────────────────────────────────────────
IF OBJECT_ID('dbo.prestamos', 'U') IS NULL
CREATE TABLE dbo.prestamos (
  id                    INT IDENTITY(1,1) PRIMARY KEY,
  usuario_id            INT NOT NULL REFERENCES dbo.usuarios(id),
  principal             DECIMAL(12,2) NOT NULL,        -- monto solicitado ej: 10000
  tasa_mensual          DECIMAL(5,4) NOT NULL,         -- 0.15 = 15%
  plazo_meses           INT NOT NULL,                  -- ej: 3
  interes_mensual       DECIMAL(12,2) NOT NULL,        -- principal * tasa (ej: 1500)
  monto_entregado       DECIMAL(12,2) NOT NULL,        -- principal - interes_mes1 (ej: 8500)
  mora_diaria           DECIMAL(10,2) NOT NULL DEFAULT 0,  -- MXN por día de retraso (0 = sin mora)
  fecha_inicio          DATE NOT NULL,
  fecha_liquidacion     DATE NULL,
  estado                NVARCHAR(20) NOT NULL DEFAULT 'activo',
    -- activo | liquidado | cancelado
  aprobado_por          INT NULL REFERENCES dbo.usuarios(id),
  aprobado_at           DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  notas                 NVARCHAR(1000) NULL,
  created_at            DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at            DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_prestamos_estado')
  CREATE INDEX ix_prestamos_estado ON dbo.prestamos (estado, fecha_inicio DESC);

-- ── PAGOS PROGRAMADOS + REGISTRADOS ─────────────────────────
-- Cuando se crea un préstamo, se generan N pagos programados.
-- El "mes 1" queda como "pagado_anticipado" porque se cobró con la retención.
IF OBJECT_ID('dbo.pagos', 'U') IS NULL
CREATE TABLE dbo.pagos (
  id                    INT IDENTITY(1,1) PRIMARY KEY,
  prestamo_id           INT NOT NULL REFERENCES dbo.prestamos(id),
  numero_pago           INT NOT NULL,                  -- 1..plazo_meses
  monto_esperado        DECIMAL(12,2) NOT NULL,        -- lo que debía pagar (interés o principal+interés)
  fecha_programada      DATE NOT NULL,                 -- fecha vencimiento
  monto_pagado          DECIMAL(12,2) NULL,            -- lo que efectivamente pagó
  mora_calculada        DECIMAL(12,2) NULL,            -- calculada al momento del pago
  mora_perdonada        DECIMAL(12,2) NULL,            -- mamá pudo perdonar parte
  fecha_pagada          DATETIME2 NULL,
  comprobante_url       NVARCHAR(500) NULL,
  registrado_por        INT NULL REFERENCES dbo.usuarios(id),
  notas                 NVARCHAR(1000) NULL,
  estado                NVARCHAR(20) NOT NULL DEFAULT 'pendiente',
    -- pendiente | pagado | pagado_anticipado | vencido | perdonado
  created_at            DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at            DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_pagos_prestamo')
  CREATE INDEX ix_pagos_prestamo ON dbo.pagos (prestamo_id, numero_pago);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_pagos_pendientes')
  CREATE INDEX ix_pagos_pendientes ON dbo.pagos (estado, fecha_programada) WHERE estado = 'pendiente';

-- ── SOLICITUDES DE PRÉSTAMO ─────────────────────────────────
IF OBJECT_ID('dbo.solicitudes', 'U') IS NULL
CREATE TABLE dbo.solicitudes (
  id                    INT IDENTITY(1,1) PRIMARY KEY,
  usuario_id            INT NOT NULL REFERENCES dbo.usuarios(id),
  monto_solicitado      DECIMAL(12,2) NOT NULL,
  plazo_meses           INT NOT NULL,
  motivo                NVARCHAR(500) NULL,
  estado                NVARCHAR(20) NOT NULL DEFAULT 'pendiente',
    -- pendiente | aprobada | rechazada
  respuesta_notas       NVARCHAR(500) NULL,
  respondido_por        INT NULL REFERENCES dbo.usuarios(id),
  respondido_at         DATETIME2 NULL,
  prestamo_id           INT NULL REFERENCES dbo.prestamos(id),  -- si se aprobó
  created_at            DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ── LOG DE NOTIFICACIONES ───────────────────────────────────
IF OBJECT_ID('dbo.notificaciones', 'U') IS NULL
CREATE TABLE dbo.notificaciones (
  id             INT IDENTITY(1,1) PRIMARY KEY,
  telefono       NVARCHAR(20) NOT NULL,
  tipo           NVARCHAR(50) NOT NULL,    -- vence_pronto | vence_hoy | vencido | nuevo_prestamo | pago_registrado | solicitud_recibida
  canal          NVARCHAR(20) NOT NULL DEFAULT 'whatsapp',
  mensaje        NVARCHAR(2000) NOT NULL,
  ref_prestamo   INT NULL,
  ref_pago       INT NULL,
  enviado_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  exito          BIT NOT NULL DEFAULT 1,
  error_msg      NVARCHAR(500) NULL
);

-- ── SEED: crea a mamá (admin) ───────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.usuarios WHERE es_admin = 1)
BEGIN
  -- PIN por defecto: 1234 (bcrypt hash generado antes)
  -- Mamá lo cambia al primer login
  INSERT INTO dbo.usuarios (telefono, nombre, es_admin, pin_hash)
  VALUES ('5215500000000', 'Mamá Panda', 1, '$2b$12$KIXQL5o.5vN0P4WDf.qWFuP7cPRt7X4wq5FgO5FZYnAcyRr6lhkxu');
  PRINT 'Admin creado. PIN inicial: 1234 (cámbialo).';
END;

PRINT 'PanditaCash schema aplicado.';
GO

-- schema v4: KYC + tarjetas + avales para modelo híbrido de garantías
-- Aplica DESPUÉS de schema-v3.sql

-- Documentos de identidad del cliente (INE frente, INE reverso, selfie, comprobante domicilio)
IF OBJECT_ID('dbo.documentos_kyc', 'U') IS NULL
CREATE TABLE dbo.documentos_kyc (
    id            INT IDENTITY PRIMARY KEY,
    usuario_id    INT NOT NULL FOREIGN KEY REFERENCES dbo.usuarios(id),
    tipo          VARCHAR(30) NOT NULL, -- 'ine_frente','ine_reverso','selfie','comprobante_dom'
    ruta          NVARCHAR(500) NOT NULL, -- path relativo en el volumen (o URL Storage Box)
    mime_type     VARCHAR(50) NOT NULL DEFAULT 'image/jpeg',
    bytes         INT,
    validado      BIT NOT NULL DEFAULT 0, -- 1 = pasó validación (manual o AI)
    validado_por  INT,   -- id de admin que aprobó
    validado_at   DATETIME2,
    notas         NVARCHAR(500),
    created_at    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_documentos_kyc_usuario_tipo UNIQUE (usuario_id, tipo)
);

-- Avales (contacto de referencia obligatorio para garantía)
IF OBJECT_ID('dbo.avales', 'U') IS NULL
CREATE TABLE dbo.avales (
    id            INT IDENTITY PRIMARY KEY,
    usuario_id    INT NOT NULL FOREIGN KEY REFERENCES dbo.usuarios(id),
    nombre        NVARCHAR(150) NOT NULL,
    telefono      NVARCHAR(20) NOT NULL,
    relacion      NVARCHAR(50), -- 'familiar','amigo','pareja','trabajo'
    verificado_wa BIT NOT NULL DEFAULT 0,  -- 1 = contactado por WhatsApp y aceptó ser aval
    contactado_at DATETIME2,
    created_at    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Tokens de tarjetas (Mercado Pago) — NUNCA guardamos el PAN
IF OBJECT_ID('dbo.tarjetas_tokens', 'U') IS NULL
CREATE TABLE dbo.tarjetas_tokens (
    id                INT IDENTITY PRIMARY KEY,
    usuario_id        INT NOT NULL FOREIGN KEY REFERENCES dbo.usuarios(id),
    proveedor         VARCHAR(20) NOT NULL DEFAULT 'mercadopago', -- 'mercadopago','openpay','stripe'
    customer_id       NVARCHAR(100), -- MP customer id
    card_id           NVARCHAR(100) NOT NULL, -- MP card id / token permanente
    ultimos_4         VARCHAR(4) NOT NULL,
    marca             VARCHAR(20), -- visa, mastercard, amex
    tipo              VARCHAR(10) NOT NULL DEFAULT 'debito', -- 'debito','credito'
    exp_mes           INT,
    exp_anio          INT,
    holder_name       NVARCHAR(100),
    activa            BIT NOT NULL DEFAULT 1,
    primaria          BIT NOT NULL DEFAULT 0, -- 1 = tarjeta por default para cobros
    created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Autorizaciones recurrentes (preapprovals de MP)
IF OBJECT_ID('dbo.autorizaciones_recurrentes', 'U') IS NULL
CREATE TABLE dbo.autorizaciones_recurrentes (
    id                  INT IDENTITY PRIMARY KEY,
    prestamo_id         INT NOT NULL FOREIGN KEY REFERENCES dbo.prestamos(id),
    tarjeta_token_id    INT NOT NULL FOREIGN KEY REFERENCES dbo.tarjetas_tokens(id),
    preapproval_id      NVARCHAR(100), -- MP preapproval id
    monto_por_pago      DECIMAL(10,2) NOT NULL,
    frecuencia          VARCHAR(20) NOT NULL, -- 'mensual','quincenal'
    estado              VARCHAR(20) NOT NULL DEFAULT 'activa', -- 'activa','pausada','cancelada'
    created_at          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Intentos de cargo automático (histórico)
IF OBJECT_ID('dbo.cargos_automaticos', 'U') IS NULL
CREATE TABLE dbo.cargos_automaticos (
    id                  INT IDENTITY PRIMARY KEY,
    pago_id             INT NOT NULL FOREIGN KEY REFERENCES dbo.pagos(id),
    autorizacion_id     INT FOREIGN KEY REFERENCES dbo.autorizaciones_recurrentes(id),
    tarjeta_token_id    INT NOT NULL FOREIGN KEY REFERENCES dbo.tarjetas_tokens(id),
    monto_intentado     DECIMAL(10,2) NOT NULL,
    payment_id          NVARCHAR(100), -- MP payment id
    estado              VARCHAR(20) NOT NULL, -- 'approved','rejected','pending','refunded'
    codigo_rechazo      NVARCHAR(50), -- MP status_detail
    intento_num         INT NOT NULL DEFAULT 1, -- 1er, 2do, 3er intento
    created_at          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Score público del cliente (para ceiling en solicitudes)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.usuarios') AND name = 'kyc_completo')
ALTER TABLE dbo.usuarios ADD kyc_completo BIT NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.usuarios') AND name = 'kyc_completed_at')
ALTER TABLE dbo.usuarios ADD kyc_completed_at DATETIME2;
GO

-- Ceiling de préstamo según nivel de garantías
-- (usado por lib/score.ts en el backend)
-- Sin nada:              $500 max
-- Solo INE + selfie:      $2,500
-- + Aval verificado:      $5,000
-- + Tarjeta activa:       $20,000

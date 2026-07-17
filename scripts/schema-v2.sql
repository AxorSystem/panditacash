-- ============================================================
-- PanditaCash — schema v2: movimientos + pagos parciales + estados sólidos
-- ============================================================
USE panditacash;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── MOVIMIENTOS DE PAGO (nuevo, permite pagos parciales) ────
IF OBJECT_ID('dbo.movimientos', 'U') IS NULL
CREATE TABLE dbo.movimientos (
  id                INT IDENTITY(1,1) PRIMARY KEY,
  pago_id           INT NOT NULL REFERENCES dbo.pagos(id),
  prestamo_id       INT NOT NULL REFERENCES dbo.prestamos(id),
  usuario_id        INT NOT NULL REFERENCES dbo.usuarios(id),  -- cliente que pagó
  monto_capital     DECIMAL(12,2) NOT NULL DEFAULT 0,          -- lo que va a interés/principal
  monto_mora        DECIMAL(12,2) NOT NULL DEFAULT 0,          -- lo que va a mora
  mora_perdonada    DECIMAL(12,2) NOT NULL DEFAULT 0,          -- mamá perdonó parte de la mora
  metodo            NVARCHAR(20)  NOT NULL DEFAULT 'efectivo',
    -- efectivo | transferencia | deposito | otro
  comprobante_url   NVARCHAR(500) NULL,
  notas             NVARCHAR(500) NULL,
  registrado_por    INT NOT NULL REFERENCES dbo.usuarios(id),  -- siempre mamá
  fecha_pago        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  created_at        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_mov_prestamo')
  CREATE INDEX ix_mov_prestamo ON dbo.movimientos (prestamo_id, fecha_pago DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_mov_pago')
  CREATE INDEX ix_mov_pago ON dbo.movimientos (pago_id, fecha_pago DESC);

-- ── PAGOS: refactor de estados y campos ───────────────────
-- monto_pagado ahora es el acumulado (SUM movimientos.monto_capital)
-- estado nuevo: pendiente | parcial | pagado | pagado_anticipado
IF COL_LENGTH('dbo.pagos', 'monto_pagado_capital') IS NULL
  ALTER TABLE dbo.pagos ADD monto_pagado_capital DECIMAL(12,2) NOT NULL DEFAULT 0;
GO
IF COL_LENGTH('dbo.pagos', 'monto_pagado_mora') IS NULL
  ALTER TABLE dbo.pagos ADD monto_pagado_mora DECIMAL(12,2) NOT NULL DEFAULT 0;
GO
IF COL_LENGTH('dbo.pagos', 'mora_perdonada_total') IS NULL
  ALTER TABLE dbo.pagos ADD mora_perdonada_total DECIMAL(12,2) NOT NULL DEFAULT 0;
GO

-- Migrar datos viejos (si había pagos con monto_pagado)
UPDATE dbo.pagos SET monto_pagado_capital = ISNULL(monto_pagado, 0), monto_pagado_mora = 0
 WHERE monto_pagado IS NOT NULL AND monto_pagado_capital = 0;
GO

-- ── VISTA para resumen de cliente ──────────────────────────
IF OBJECT_ID('dbo.vw_cliente_resumen', 'V') IS NOT NULL DROP VIEW dbo.vw_cliente_resumen;
GO
CREATE VIEW dbo.vw_cliente_resumen AS
SELECT
  u.id AS usuario_id,
  u.nombre,
  u.telefono,
  COUNT(DISTINCT CASE WHEN p.estado = 'activo' THEN p.id END) AS prestamos_activos,
  COUNT(DISTINCT p.id) AS prestamos_totales,
  ISNULL(SUM(CASE WHEN p.estado = 'activo' THEN p.principal ELSE 0 END), 0) AS deuda_original_activa,
  ISNULL(SUM(CASE WHEN p.estado = 'activo' THEN p.principal - p.monto_pagado_capital_prestamo ELSE 0 END), 0) AS saldo_pendiente_estimado
FROM dbo.usuarios u
LEFT JOIN (
  SELECT p.*, ISNULL(SUM(pg.monto_pagado_capital), 0) AS monto_pagado_capital_prestamo
  FROM dbo.prestamos p
  LEFT JOIN dbo.pagos pg ON pg.prestamo_id = p.id
  GROUP BY p.id, p.principal, p.tasa_mensual, p.plazo_meses, p.interes_mensual, p.monto_entregado,
           p.mora_diaria, p.fecha_inicio, p.fecha_liquidacion, p.estado, p.aprobado_por,
           p.aprobado_at, p.notas, p.created_at, p.updated_at, p.usuario_id
) p ON p.usuario_id = u.id
WHERE u.es_admin = 0
GROUP BY u.id, u.nombre, u.telefono;
GO

PRINT 'PanditaCash schema v2 aplicado.';
GO

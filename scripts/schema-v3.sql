-- ============================================================
-- PanditaCash — schema v3: frecuencia quincenal/mensual
-- ============================================================
USE panditacash;
GO
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.prestamos', 'frecuencia') IS NULL
  ALTER TABLE dbo.prestamos ADD frecuencia NVARCHAR(20) NOT NULL DEFAULT 'mensual';
GO
-- CHECK constraint: solo 'mensual' o 'quincenal'
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'ck_prestamos_frecuencia')
  ALTER TABLE dbo.prestamos ADD CONSTRAINT ck_prestamos_frecuencia CHECK (frecuencia IN ('mensual', 'quincenal'));
GO

PRINT 'PanditaCash schema v3 (frecuencia) aplicado.';
GO

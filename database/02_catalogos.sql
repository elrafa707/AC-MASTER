-- AC-Master · Catálogos base (especialidades técnicas y piezas)

USE ACMaster;
GO

MERGE dbo.Especialidades AS destino
USING (VALUES
    ('REFRIGERACION', N'Refrigeración'),
    ('ELECTRICO',     N'Eléctrico'),
    ('DRENAJE',       N'Drenajes'),
    ('MECANICO',      N'Mecánico'),
    ('MANTENIMIENTO', N'Mantenimiento')
) AS origen (Clave, Nombre)
ON destino.Clave = origen.Clave
WHEN MATCHED THEN UPDATE SET Nombre = origen.Nombre
WHEN NOT MATCHED THEN INSERT (Clave, Nombre) VALUES (origen.Clave, origen.Nombre);
GO

MERGE dbo.Piezas AS destino
USING (VALUES
    ('REP-CAP-35',    N'Capacitor de marcha 35 µF',          420.00),
    ('REP-CAP-45',    N'Capacitor de marcha 45 µF',          480.00),
    ('REP-CAP-FAN',   N'Capacitor de ventilador 2.5 µF',     180.00),
    ('REP-FLT-24',    N'Filtro lavable 24"',                 250.00),
    ('INS-R410A-1K',  N'Refrigerante R-410A (1 kg)',         650.00),
    ('INS-R32-1K',    N'Refrigerante R-32 (1 kg)',           700.00),
    ('INS-R22-1K',    N'Refrigerante R-22 (1 kg)',           950.00),
    ('REP-SENS-TEMP', N'Sensor de temperatura (termistor)',  320.00),
    ('REP-MOT-FAN',   N'Motor ventilador condensador',      1850.00),
    ('REP-TARJ-UNI',  N'Tarjeta electrónica universal',     2200.00),
    ('INS-DREN-MAN',  N'Manguera de drenaje (1 m)',           60.00),
    ('INS-AISL-TER',  N'Aislante térmico (1 m)',              45.00),
    ('INS-CINTA',     N'Cinta para tubería',                  35.00),
    ('REP-CONT-24V',  N'Contactor 24 V',                     390.00)
) AS origen (Codigo, Nombre, PrecioUnitario)
ON destino.Codigo = origen.Codigo
WHEN MATCHED THEN UPDATE SET Nombre = origen.Nombre, PrecioUnitario = origen.PrecioUnitario
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, PrecioUnitario) VALUES (origen.Codigo, origen.Nombre, origen.PrecioUnitario);
GO

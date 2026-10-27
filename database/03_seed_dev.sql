-- AC-Master · Datos de prueba SOLO PARA DESARROLLO. No ejecutar en producción.
-- Las tres cuentas usan la contraseña: AcMaster2026!
--   admin@acmaster.mx    (Administrador)
--   tecnico@acmaster.mx  (Técnico)
--   cliente@acmaster.mx  (Cliente)

USE ACMaster;
GO

DECLARE @hash NVARCHAR(100) = N'$2b$10$nGNvjFi4nTGGi5nAGwkXk.ZLnvpa5sQE7dMF9ZsNPNa2g5G2xvdGC';

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'admin@acmaster.mx')
    INSERT INTO dbo.Usuarios (Nombre, Correo, Telefono, PasswordHash, Rol)
    VALUES (N'Administrador AC-Master', N'admin@acmaster.mx', N'8110000001', @hash, 'ADMIN');

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'tecnico@acmaster.mx')
BEGIN
    INSERT INTO dbo.Usuarios (Nombre, Correo, Telefono, PasswordHash, Rol)
    VALUES (N'Mariela Ríos', N'tecnico@acmaster.mx', N'8110000002', @hash, 'TECNICO');

    DECLARE @tecnicoId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Tecnicos (TecnicoId, Disponible, Calificacion) VALUES (@tecnicoId, 1, 4.9);
    INSERT INTO dbo.TecnicoEspecialidades (TecnicoId, EspecialidadId)
    SELECT @tecnicoId, EspecialidadId FROM dbo.Especialidades WHERE Clave IN ('REFRIGERACION', 'MANTENIMIENTO');
END

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'cliente@acmaster.mx')
BEGIN
    INSERT INTO dbo.Usuarios (Nombre, Correo, Telefono, PasswordHash, Rol)
    VALUES (N'Rafael Báez', N'cliente@acmaster.mx', N'8110000003', @hash, 'CLIENTE');

    INSERT INTO dbo.Direcciones (UsuarioId, Alias, Calle, Colonia, Ciudad, CP, EsPrincipal)
    VALUES (SCOPE_IDENTITY(), N'Casa', N'Av. Universidad 1500', N'Ciudad Universitaria', N'San Nicolás de los Garza', '66455', 1);
END
GO

-- AC-Master · Esquema de base de datos (SQL Server 2022)
-- Crea la base y todas las tablas del modelo de datos de la arquitectura (Fase 3).

IF DB_ID(N'ACMaster') IS NULL
    CREATE DATABASE ACMaster COLLATE Modern_Spanish_CI_AS;
GO

USE ACMaster;
GO

-- Necesario para columnas calculadas con índice (Folio). sqlcmd lo trae apagado por defecto.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

/* ───────────────────────────── Usuarios y perfiles ───────────────────────────── */

IF OBJECT_ID(N'dbo.Usuarios') IS NULL
CREATE TABLE dbo.Usuarios (
    UsuarioId      INT IDENTITY(1,1) CONSTRAINT PK_Usuarios PRIMARY KEY,
    Nombre         NVARCHAR(120) NOT NULL,
    Correo         NVARCHAR(160) NOT NULL CONSTRAINT UQ_Usuarios_Correo UNIQUE,
    Telefono       NVARCHAR(20)  NULL,
    PasswordHash   NVARCHAR(100) NOT NULL,
    Rol            VARCHAR(10)   NOT NULL CONSTRAINT CK_Usuarios_Rol CHECK (Rol IN ('CLIENTE', 'TECNICO', 'ADMIN')),
    Activo         BIT           NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
    FechaRegistro  DATETIME2(0)  NOT NULL CONSTRAINT DF_Usuarios_FechaRegistro DEFAULT (SYSUTCDATETIME())
);
GO

IF OBJECT_ID(N'dbo.Direcciones') IS NULL
CREATE TABLE dbo.Direcciones (
    DireccionId  INT IDENTITY(1,1) CONSTRAINT PK_Direcciones PRIMARY KEY,
    UsuarioId    INT           NOT NULL CONSTRAINT FK_Direcciones_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    Alias        NVARCHAR(40)  NOT NULL,
    Calle        NVARCHAR(160) NOT NULL,
    Colonia      NVARCHAR(120) NOT NULL,
    Ciudad       NVARCHAR(80)  NOT NULL,
    CP           VARCHAR(5)    NULL,
    Referencias  NVARCHAR(200) NULL,
    EsPrincipal  BIT           NOT NULL CONSTRAINT DF_Direcciones_EsPrincipal DEFAULT (0)
);
GO

IF OBJECT_ID(N'dbo.Tecnicos') IS NULL
CREATE TABLE dbo.Tecnicos (
    TecnicoId     INT          CONSTRAINT PK_Tecnicos PRIMARY KEY
                               CONSTRAINT FK_Tecnicos_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    Disponible    BIT          NOT NULL CONSTRAINT DF_Tecnicos_Disponible DEFAULT (1),
    Calificacion  DECIMAL(2,1) NOT NULL CONSTRAINT DF_Tecnicos_Calificacion DEFAULT (5.0)
                               CONSTRAINT CK_Tecnicos_Calificacion CHECK (Calificacion BETWEEN 0 AND 5)
);
GO

IF OBJECT_ID(N'dbo.Especialidades') IS NULL
CREATE TABLE dbo.Especialidades (
    EspecialidadId  INT IDENTITY(1,1) CONSTRAINT PK_Especialidades PRIMARY KEY,
    Clave           VARCHAR(20)  NOT NULL CONSTRAINT UQ_Especialidades_Clave UNIQUE,
    Nombre          NVARCHAR(60) NOT NULL
);
GO

IF OBJECT_ID(N'dbo.TecnicoEspecialidades') IS NULL
CREATE TABLE dbo.TecnicoEspecialidades (
    TecnicoId       INT NOT NULL CONSTRAINT FK_TecEsp_Tecnicos REFERENCES dbo.Tecnicos(TecnicoId),
    EspecialidadId  INT NOT NULL CONSTRAINT FK_TecEsp_Especialidades REFERENCES dbo.Especialidades(EspecialidadId),
    CONSTRAINT PK_TecnicoEspecialidades PRIMARY KEY (TecnicoId, EspecialidadId)
);
GO

/* ───────────────────────────── Equipos y diagnósticos ───────────────────────────── */

IF OBJECT_ID(N'dbo.Equipos') IS NULL
CREATE TABLE dbo.Equipos (
    EquipoId          INT IDENTITY(1,1) CONSTRAINT PK_Equipos PRIMARY KEY,
    ClienteId         INT           NOT NULL CONSTRAINT FK_Equipos_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    DireccionId       INT           NULL     CONSTRAINT FK_Equipos_Direcciones REFERENCES dbo.Direcciones(DireccionId),
    NumeroSerie       NVARCHAR(60)  NOT NULL CONSTRAINT UQ_Equipos_NumeroSerie UNIQUE,
    Marca             NVARCHAR(60)  NOT NULL,
    Modelo            NVARCHAR(80)  NOT NULL,
    Tipo              NVARCHAR(40)  NOT NULL CONSTRAINT DF_Equipos_Tipo DEFAULT (N'Minisplit'),
    CapacidadBTU      INT           NULL,
    Refrigerante      NVARCHAR(20)  NULL,
    Ubicacion         NVARCHAR(80)  NULL,
    FechaInstalacion  DATE          NULL,
    FechaRegistro     DATETIME2(0)  NOT NULL CONSTRAINT DF_Equipos_FechaRegistro DEFAULT (SYSUTCDATETIME())
);
GO

IF OBJECT_ID(N'dbo.Diagnosticos') IS NULL
CREATE TABLE dbo.Diagnosticos (
    DiagnosticoId    INT IDENTITY(1,1) CONSTRAINT PK_Diagnosticos PRIMARY KEY,
    EquipoId         INT            NOT NULL CONSTRAINT FK_Diagnosticos_Equipos REFERENCES dbo.Equipos(EquipoId),
    ClienteId        INT            NOT NULL CONSTRAINT FK_Diagnosticos_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    Sintomas         NVARCHAR(MAX)  NOT NULL CONSTRAINT CK_Diagnosticos_Sintomas CHECK (ISJSON(Sintomas) = 1),
    Respuestas       NVARCHAR(MAX)  NOT NULL CONSTRAINT CK_Diagnosticos_Respuestas CHECK (ISJSON(Respuestas) = 1),
    FallaPredicha    NVARCHAR(160)  NOT NULL,
    Descripcion      NVARCHAR(1000) NOT NULL,
    Confianza        DECIMAL(4,3)   NOT NULL CONSTRAINT CK_Diagnosticos_Confianza CHECK (Confianza BETWEEN 0 AND 1),
    Causas           NVARCHAR(MAX)  NOT NULL CONSTRAINT CK_Diagnosticos_Causas CHECK (ISJSON(Causas) = 1),
    RequiereTecnico  BIT            NOT NULL,
    EspecialidadId   INT            NULL CONSTRAINT FK_Diagnosticos_Especialidades REFERENCES dbo.Especialidades(EspecialidadId),
    Prioridad        VARCHAR(5)     NOT NULL CONSTRAINT CK_Diagnosticos_Prioridad CHECK (Prioridad IN ('BAJA', 'MEDIA', 'ALTA')),
    PasosAutoayuda   NVARCHAR(MAX)  NOT NULL CONSTRAINT CK_Diagnosticos_Pasos CHECK (ISJSON(PasosAutoayuda) = 1),
    Herramientas     NVARCHAR(MAX)  NOT NULL CONSTRAINT CK_Diagnosticos_Herramientas CHECK (ISJSON(Herramientas) = 1),
    CostoMin         DECIMAL(10,2)  NOT NULL,
    CostoMax         DECIMAL(10,2)  NOT NULL,
    Advertencia      NVARCHAR(400)  NULL,
    ModeloIA         NVARCHAR(60)   NOT NULL,
    RespuestaIA      NVARCHAR(MAX)  NULL CONSTRAINT CK_Diagnosticos_RespuestaIA CHECK (RespuestaIA IS NULL OR ISJSON(RespuestaIA) = 1),
    Resultado        VARCHAR(20)    NOT NULL CONSTRAINT DF_Diagnosticos_Resultado DEFAULT ('PENDIENTE')
                                    CONSTRAINT CK_Diagnosticos_Resultado CHECK (Resultado IN ('PENDIENTE', 'RESUELTO_AUTOAYUDA', 'ESCALADO')),
    FechaCreacion    DATETIME2(0)   NOT NULL CONSTRAINT DF_Diagnosticos_FechaCreacion DEFAULT (SYSUTCDATETIME())
);
GO

/* ───────────────────────────── Solicitudes y cotizaciones ───────────────────────────── */

IF OBJECT_ID(N'dbo.Solicitudes') IS NULL
CREATE TABLE dbo.Solicitudes (
    SolicitudId         INT IDENTITY(1,1) CONSTRAINT PK_Solicitudes PRIMARY KEY,
    Folio               AS ('AC-' + RIGHT('000000' + CAST(SolicitudId AS VARCHAR(10)), 6)) PERSISTED,
    DiagnosticoId       INT            NOT NULL CONSTRAINT FK_Solicitudes_Diagnosticos REFERENCES dbo.Diagnosticos(DiagnosticoId)
                                       CONSTRAINT UQ_Solicitudes_Diagnostico UNIQUE,
    ClienteId           INT            NOT NULL CONSTRAINT FK_Solicitudes_Clientes REFERENCES dbo.Usuarios(UsuarioId),
    EquipoId            INT            NOT NULL CONSTRAINT FK_Solicitudes_Equipos REFERENCES dbo.Equipos(EquipoId),
    DireccionId         INT            NOT NULL CONSTRAINT FK_Solicitudes_Direcciones REFERENCES dbo.Direcciones(DireccionId),
    Descripcion         NVARCHAR(1000) NULL,
    Estado              VARCHAR(12)    NOT NULL CONSTRAINT DF_Solicitudes_Estado DEFAULT ('EN_REVISION')
                                       CONSTRAINT CK_Solicitudes_Estado CHECK (Estado IN ('EN_REVISION', 'COTIZADO', 'EN_CAMINO', 'FINALIZADO', 'CANCELADA')),
    Prioridad           VARCHAR(5)     NOT NULL CONSTRAINT CK_Solicitudes_Prioridad CHECK (Prioridad IN ('BAJA', 'MEDIA', 'ALTA')),
    TecnicoId           INT            NULL CONSTRAINT FK_Solicitudes_Tecnicos REFERENCES dbo.Tecnicos(TecnicoId),
    PedidaPorCliente    BIT            NOT NULL CONSTRAINT DF_Solicitudes_PedidaPorCliente DEFAULT (0),
    VentanaInicio       DATETIME2(0)   NULL,
    VentanaFin          DATETIME2(0)   NULL,
    FechaCreacion       DATETIME2(0)   NOT NULL CONSTRAINT DF_Solicitudes_FechaCreacion DEFAULT (SYSUTCDATETIME()),
    FechaActualizacion  DATETIME2(0)   NOT NULL CONSTRAINT DF_Solicitudes_FechaActualizacion DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Solicitudes_Folio UNIQUE (Folio),
    CONSTRAINT CK_Solicitudes_Ventana CHECK (VentanaFin IS NULL OR VentanaInicio IS NULL OR VentanaFin > VentanaInicio)
);
GO

IF OBJECT_ID(N'dbo.Cotizaciones') IS NULL
CREATE TABLE dbo.Cotizaciones (
    CotizacionId    INT IDENTITY(1,1) CONSTRAINT PK_Cotizaciones PRIMARY KEY,
    SolicitudId     INT           NOT NULL CONSTRAINT FK_Cotizaciones_Solicitudes REFERENCES dbo.Solicitudes(SolicitudId)
                                  CONSTRAINT UQ_Cotizaciones_Solicitud UNIQUE,
    Estado          VARCHAR(10)   NOT NULL CONSTRAINT DF_Cotizaciones_Estado DEFAULT ('BORRADOR')
                                  CONSTRAINT CK_Cotizaciones_Estado CHECK (Estado IN ('BORRADOR', 'ENVIADA', 'APROBADA', 'RECHAZADA')),
    GeneradaAuto    BIT           NOT NULL CONSTRAINT DF_Cotizaciones_GeneradaAuto DEFAULT (1),
    ValidadaPor     INT           NULL CONSTRAINT FK_Cotizaciones_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    FechaEnvio      DATETIME2(0)  NULL,
    FechaRespuesta  DATETIME2(0)  NULL
);
GO

IF OBJECT_ID(N'dbo.CotizacionPartidas') IS NULL
CREATE TABLE dbo.CotizacionPartidas (
    PartidaId       INT IDENTITY(1,1) CONSTRAINT PK_CotizacionPartidas PRIMARY KEY,
    CotizacionId    INT           NOT NULL CONSTRAINT FK_Partidas_Cotizaciones REFERENCES dbo.Cotizaciones(CotizacionId) ON DELETE CASCADE,
    Concepto        NVARCHAR(160) NOT NULL,
    Cantidad        INT           NOT NULL CONSTRAINT CK_Partidas_Cantidad CHECK (Cantidad > 0),
    PrecioUnitario  DECIMAL(10,2) NOT NULL CONSTRAINT CK_Partidas_Precio CHECK (PrecioUnitario >= 0)
);
GO

/* ───────────────────────────── Órdenes de trabajo ───────────────────────────── */

IF OBJECT_ID(N'dbo.OrdenesTrabajo') IS NULL
CREATE TABLE dbo.OrdenesTrabajo (
    OrdenId           INT IDENTITY(1,1) CONSTRAINT PK_OrdenesTrabajo PRIMARY KEY,
    Folio             AS ('ORD-' + RIGHT('000000' + CAST(OrdenId AS VARCHAR(10)), 6)) PERSISTED,
    SolicitudId       INT            NOT NULL CONSTRAINT FK_Ordenes_Solicitudes REFERENCES dbo.Solicitudes(SolicitudId)
                                     CONSTRAINT UQ_Ordenes_Solicitud UNIQUE,
    TecnicoId         INT            NOT NULL CONSTRAINT FK_Ordenes_Tecnicos REFERENCES dbo.Tecnicos(TecnicoId),
    DiagnosticoFinal  NVARCHAR(2000) NULL,
    Notas             NVARCHAR(2000) NULL,
    FechaLlegada      DATETIME2(0)   NULL,
    FechaCierre       DATETIME2(0)   NULL,
    CONSTRAINT UQ_Ordenes_Folio UNIQUE (Folio)
);
GO

IF OBJECT_ID(N'dbo.Piezas') IS NULL
CREATE TABLE dbo.Piezas (
    PiezaId         INT IDENTITY(1,1) CONSTRAINT PK_Piezas PRIMARY KEY,
    Codigo          VARCHAR(30)   NOT NULL CONSTRAINT UQ_Piezas_Codigo UNIQUE,
    Nombre          NVARCHAR(120) NOT NULL,
    PrecioUnitario  DECIMAL(10,2) NOT NULL CONSTRAINT CK_Piezas_Precio CHECK (PrecioUnitario >= 0),
    Activo          BIT           NOT NULL CONSTRAINT DF_Piezas_Activo DEFAULT (1)
);
GO

IF OBJECT_ID(N'dbo.OrdenPiezas') IS NULL
CREATE TABLE dbo.OrdenPiezas (
    OrdenId         INT           NOT NULL CONSTRAINT FK_OrdenPiezas_Ordenes REFERENCES dbo.OrdenesTrabajo(OrdenId),
    PiezaId         INT           NOT NULL CONSTRAINT FK_OrdenPiezas_Piezas REFERENCES dbo.Piezas(PiezaId),
    Cantidad        INT           NOT NULL CONSTRAINT CK_OrdenPiezas_Cantidad CHECK (Cantidad > 0),
    PrecioUnitario  DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_OrdenPiezas PRIMARY KEY (OrdenId, PiezaId)
);
GO

/* ───────────────────────────── Fotos ───────────────────────────── */

IF OBJECT_ID(N'dbo.Fotos') IS NULL
CREATE TABLE dbo.Fotos (
    FotoId         INT IDENTITY(1,1) CONSTRAINT PK_Fotos PRIMARY KEY,
    Ruta           NVARCHAR(260) NOT NULL,
    MimeType       VARCHAR(30)   NOT NULL,
    Tipo           VARCHAR(12)   NOT NULL CONSTRAINT CK_Fotos_Tipo CHECK (Tipo IN ('DIAGNOSTICO', 'EVIDENCIA')),
    DiagnosticoId  INT           NULL CONSTRAINT FK_Fotos_Diagnosticos REFERENCES dbo.Diagnosticos(DiagnosticoId),
    OrdenId        INT           NULL CONSTRAINT FK_Fotos_Ordenes REFERENCES dbo.OrdenesTrabajo(OrdenId),
    SubidaPor      INT           NOT NULL CONSTRAINT FK_Fotos_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    Fecha          DATETIME2(0)  NOT NULL CONSTRAINT DF_Fotos_Fecha DEFAULT (SYSUTCDATETIME()),
    -- Cada foto pertenece exactamente a un diagnóstico (cliente) o a una orden (evidencia del técnico).
    CONSTRAINT CK_Fotos_Duenio CHECK (
        (Tipo = 'DIAGNOSTICO' AND DiagnosticoId IS NOT NULL AND OrdenId IS NULL) OR
        (Tipo = 'EVIDENCIA'   AND OrdenId IS NOT NULL AND DiagnosticoId IS NULL)
    )
);
GO

/* ───────────────────────────── Línea de tiempo e historial ───────────────────────────── */

IF OBJECT_ID(N'dbo.EventosSolicitud') IS NULL
CREATE TABLE dbo.EventosSolicitud (
    EventoId     INT IDENTITY(1,1) CONSTRAINT PK_EventosSolicitud PRIMARY KEY,
    SolicitudId  INT           NOT NULL CONSTRAINT FK_Eventos_Solicitudes REFERENCES dbo.Solicitudes(SolicitudId),
    Estado       VARCHAR(12)   NOT NULL,
    Titulo       NVARCHAR(120) NOT NULL,
    Detalle      NVARCHAR(400) NULL,
    UsuarioId    INT           NULL CONSTRAINT FK_Eventos_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    Fecha        DATETIME2(0)  NOT NULL CONSTRAINT DF_Eventos_Fecha DEFAULT (SYSUTCDATETIME())
);
GO

IF OBJECT_ID(N'dbo.HistorialEquipo') IS NULL
CREATE TABLE dbo.HistorialEquipo (
    RegistroId     INT IDENTITY(1,1) CONSTRAINT PK_HistorialEquipo PRIMARY KEY,
    EquipoId       INT            NOT NULL CONSTRAINT FK_Historial_Equipos REFERENCES dbo.Equipos(EquipoId),
    Tipo           VARCHAR(15)    NOT NULL CONSTRAINT CK_Historial_Tipo
                                  CHECK (Tipo IN ('INSTALACION', 'MANTENIMIENTO', 'REPARACION', 'AUTOAYUDA', 'PREDICCION')),
    Titulo         NVARCHAR(160)  NOT NULL,
    Descripcion    NVARCHAR(2000) NULL,
    SolicitudId    INT            NULL CONSTRAINT FK_Historial_Solicitudes REFERENCES dbo.Solicitudes(SolicitudId),
    DiagnosticoId  INT            NULL CONSTRAINT FK_Historial_Diagnosticos REFERENCES dbo.Diagnosticos(DiagnosticoId),
    TecnicoId      INT            NULL CONSTRAINT FK_Historial_Tecnicos REFERENCES dbo.Tecnicos(TecnicoId),
    Fecha          DATETIME2(0)   NOT NULL CONSTRAINT DF_Historial_Fecha DEFAULT (SYSUTCDATETIME())
);
GO

/* ───────────────────────────── Notificaciones ───────────────────────────── */

IF OBJECT_ID(N'dbo.DispositivosPush') IS NULL
CREATE TABLE dbo.DispositivosPush (
    DispositivoId  INT IDENTITY(1,1) CONSTRAINT PK_DispositivosPush PRIMARY KEY,
    UsuarioId      INT           NOT NULL CONSTRAINT FK_Dispositivos_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    TokenFCM       NVARCHAR(400) NOT NULL,
    Plataforma     VARCHAR(10)   NOT NULL CONSTRAINT DF_Dispositivos_Plataforma DEFAULT ('android'),
    Actualizado    DATETIME2(0)  NOT NULL CONSTRAINT DF_Dispositivos_Actualizado DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Dispositivos_Token UNIQUE (TokenFCM)
);
GO

IF OBJECT_ID(N'dbo.Notificaciones') IS NULL
CREATE TABLE dbo.Notificaciones (
    NotificacionId  INT IDENTITY(1,1) CONSTRAINT PK_Notificaciones PRIMARY KEY,
    UsuarioId       INT           NOT NULL CONSTRAINT FK_Notificaciones_Usuarios REFERENCES dbo.Usuarios(UsuarioId),
    SolicitudId     INT           NULL CONSTRAINT FK_Notificaciones_Solicitudes REFERENCES dbo.Solicitudes(SolicitudId),
    Titulo          NVARCHAR(120) NOT NULL,
    Cuerpo          NVARCHAR(400) NOT NULL,
    Leida           BIT           NOT NULL CONSTRAINT DF_Notificaciones_Leida DEFAULT (0),
    Fecha           DATETIME2(0)  NOT NULL CONSTRAINT DF_Notificaciones_Fecha DEFAULT (SYSUTCDATETIME())
);
GO

/* ───────────────────────────── Índices de consulta ───────────────────────────── */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Equipos_Cliente')
    CREATE INDEX IX_Equipos_Cliente ON dbo.Equipos (ClienteId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Diagnosticos_Equipo')
    CREATE INDEX IX_Diagnosticos_Equipo ON dbo.Diagnosticos (EquipoId, FechaCreacion DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Solicitudes_Cliente')
    CREATE INDEX IX_Solicitudes_Cliente ON dbo.Solicitudes (ClienteId, FechaCreacion DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Solicitudes_Estado')
    CREATE INDEX IX_Solicitudes_Estado ON dbo.Solicitudes (Estado, FechaCreacion DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Solicitudes_Tecnico')
    CREATE INDEX IX_Solicitudes_Tecnico ON dbo.Solicitudes (TecnicoId, Estado);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Eventos_Solicitud')
    CREATE INDEX IX_Eventos_Solicitud ON dbo.EventosSolicitud (SolicitudId, Fecha);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Historial_Equipo')
    CREATE INDEX IX_Historial_Equipo ON dbo.HistorialEquipo (EquipoId, Fecha DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Notificaciones_Usuario')
    CREATE INDEX IX_Notificaciones_Usuario ON dbo.Notificaciones (UsuarioId, Leida, Fecha DESC);
GO

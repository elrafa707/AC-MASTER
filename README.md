# AC-MASTER
Aplicacion de soporte tecnico para climas apoyado de asistente inteligente.

App móvil para gestionar la instalación, el mantenimiento y la reparación de aire acondicionado y minisplits.
Conecta a clientes, técnicos y administradores, y un asistente con IA ayuda a diagnosticar las fallas.

| Carpeta | Contenido |
|---|---|
| `mobile/` | App móvil en Flutter (APK para Android) |
| `backend/` | API REST en Node.js + Express |
| `database/` | Scripts de SQL Server: esquema, catálogos y datos de prueba |
| `docker-compose.yml` | SQL Server 2022 local |

## Requisitos
- Docker Desktop
- Node.js 20 o superior
- Flutter 3.47 o superior y Android Studio (con un emulador o un teléfono con depuración USB)
- Una clave de la API de Anthropic para el asistente de diagnóstico (opcional; sin ella funciona en modo simulado)

## Cómo levantar el proyecto

### 1. Base de datos
```bash
docker compose up -d
```
Levanta SQL Server en `localhost:1433` y aplica los scripts de `database/` en orden. Para revisar el resultado:
`docker compose logs db-init` debe terminar con "Base de datos lista".

### 2. Backend
```bash
cd backend
cp .env.example .env      # en Windows: copy .env.example .env
npm install
npm run dev               # http://localhost:3000/api/v1
```
Para comprobar que responde: `http://localhost:3000/health` debe regresar `{"estado":"ok","baseDeDatos":"ok"}`.

Si quieres crear un administrador real en lugar de la cuenta de prueba: `npm run crear-admin`.

#### Asistente de diagnóstico (Claude)
El asistente analiza los síntomas, el cuestionario y las fotos del compresor con Claude (`claude-opus-5-5`).
1. Crea una clave en https://console.anthropic.com (cada integrante usa la suya).
2. Pégala en `backend/.env` → `ANTHROPIC_API_KEY=sk-ant-...`. **Nunca la subas al repositorio** (`.env` ya está en `.gitignore`).
3. Reinicia el backend. Al arrancar debe decir `Asistente de diagnóstico: Claude (claude-opus-5-5)`.

Sin clave, el backend arranca en **modo simulado**: usa reglas locales, no analiza las fotos y la app muestra la etiqueta "Modo simulado" en el resultado. Sirve para desarrollar y probar sin gastar.

### 3. App móvil
```bash
cd mobile
flutter pub get
flutter run                                                         # emulador de Android
flutter run --dart-define=API_URL=http://192.168.1.50:3000/api/v1   # teléfono físico (usa la IP de tu PC)
```

## Cuentas de prueba (solo desarrollo)
Las tres usan la contraseña `AcMaster2026!`.

| Rol | Correo |
|---|---|
| Administrador | admin@acmaster.mx |
| Técnico | tecnico@acmaster.mx |
| Cliente | cliente@acmaster.mx |

## Qué incluye cada etapa
| Etapa | Contenido |
|---|---|
| 1. Infraestructura | SQL Server en Docker, esquema completo, inicio de sesión y registro (RF-01) |
| 2. Diagnóstico con IA | Registro de equipos, cuestionario inteligente, fotos, diagnóstico con Claude, guía de autoayuda e historial por número de serie (RF-02, RF-03, RF-08) |
| 3. Solicitudes y cotizaciones | Solicitar técnico, seguimiento con línea de tiempo, cotización automática que valida el administrador, ranking y asignación de técnicos, gestión de técnicos y clientes, avisos en la app (RF-04, RF-05) |
| 4. Orden de trabajo | Órdenes del técnico con kit sugerido, llegada, diagnóstico final, evidencias, piezas del catálogo, cierre en el historial del equipo y calificación del técnico (RF-06, RF-07) |

## Probar el flujo completo
1. **Cliente** (`cliente@acmaster.mx`): registra un equipo, haz un diagnóstico y toca **Solicitar técnico**.
2. **Administrador** (`admin@acmaster.mx`): abre la solicitud en la bandeja, elige un técnico del ranking, ajusta la cotización y **envíala**.
3. **Cliente**: en *Servicios en curso*, **aprueba** la cotización.
4. **Técnico** (`tecnico@acmaster.mx`): abre la orden, marca **Llegué**, escribe el diagnóstico final, sube una foto de evidencia, agrega piezas y **cierra la orden**.
5. **Cliente**: revisa el resumen del servicio y **califica** al técnico. La reparación aparece en el historial del equipo.

## Pruebas
```bash
cd backend && npm test        # integración; requiere la base de datos corriendo. Usa el asistente simulado (no gasta)
cd mobile && flutter test
```
Si cambias la forma de alguna respuesta del API, regenera los JSON que usan las pruebas de la app con
`cd backend && node scripts/generar-fixtures-app.mjs` (requiere la base de datos corriendo).

## Flujo de trabajo con Git
- `main`: versiones entregables.
- `develop`: integración.
- `feature/*`: una rama por funcionalidad, que entra a `develop` con pull request.

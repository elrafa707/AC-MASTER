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
- Flutter 3.38 o superior y Android Studio (con un emulador o un teléfono con depuración USB)

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

## Pruebas
```bash
cd backend && npm test        # integración; requiere la base de datos corriendo
cd mobile && flutter test
```

## Flujo de trabajo con Git
- `main`: versiones entregables.
- `develop`: integración.
- `feature/*`: una rama por funcionalidad, que entra a `develop` con pull request.

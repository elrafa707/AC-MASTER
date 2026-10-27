/// Configuración inyectada al compilar:
///   flutter run --dart-define=API_URL=http://192.168.1.50:3000/api/v1
/// Por defecto apunta al backend local visto desde el emulador de Android (10.0.2.2 = localhost del equipo).
abstract final class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');
}

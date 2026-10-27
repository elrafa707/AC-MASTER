enum Rol {
  cliente('Cliente'),
  tecnico('Técnico'),
  administrador('Administrador');

  const Rol(this.etiqueta);
  final String etiqueta;

  static Rol desdeApi(String valor) =>
      Rol.values.firstWhere((r) => r.name == valor, orElse: () => throw FormatException('Rol desconocido: $valor'));
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.telefono,
  });

  final int id;
  final String nombre;
  final String correo;
  final String? telefono;
  final Rol rol;

  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        correo: json['correo'] as String,
        telefono: json['telefono'] as String?,
        rol: Rol.desdeApi(json['rol'] as String),
      );
}

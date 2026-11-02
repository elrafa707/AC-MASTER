import 'package:intl/intl.dart';

import 'config.dart';

final _fecha = DateFormat("d 'de' MMMM 'de' y", 'es_MX');
final _fechaCorta = DateFormat('d MMM y', 'es_MX');
final _hora = DateFormat('HH:mm', 'es_MX');
final _pesos = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 0);

String fechaLarga(DateTime d) => _fecha.format(d);
String fechaCorta(DateTime d) => _fechaCorta.format(d);
String fechaHora(DateTime d) => '${_fechaCorta.format(d)} · ${_hora.format(d)}';
String pesos(num valor) => '${_pesos.format(valor)} MXN';

/// URL absoluta de un recurso del backend que viene como ruta (/api/v1/fotos/3).
String urlDelServidor(String ruta) => Uri.parse(AppConfig.apiUrl).replace(path: ruta).toString();

/// Textos del núcleo de GRAVITY: saludo según la hora y resumen del día.
/// Tono cercano y sin culpa (sección 1).
library;

import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import 'resumen_gravity.dart';

/// Nombre visible de cada módulo: el del espejo de permisos (uno solo en la app).
export '../../../nucleo/permisos/permisos.dart' show nombreModulo;

/// "Buenos días" de 05:00 a 11:59, "Buenas tardes" de 12:00 a 18:59 y
/// "Buenas noches" el resto.
String saludoSegunHora(DateTime momento) {
  final h = momento.hour;
  if (h >= 5 && h < 12) return 'Buenos días';
  if (h >= 12 && h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

/// "Buenas noches. Te faltan 2 hábitos de hoy y a las 20:00 hay un
/// medicamento en el turno."
///
/// Solo habla de lo que trae [resumen], que ya viene filtrado por el rol
/// (`ResumenGravity.paraRol`): si el rol no ve cuidados ni dinero, no los
/// menciona. Con [privado], no menciona nada de cuidados.
String mensajeDelNucleo(
  DateTime momento,
  ResumenGravity resumen, {
  bool privado = false,
}) {
  final partes = <String>[];
  if (resumen.habitosTotal > 0) {
    final faltan = resumen.habitosTotal - resumen.habitosHechos;
    partes.add(
      faltan <= 0
          ? 'Vas al día con tus hábitos'
          : 'Te ${faltan == 1 ? 'falta 1 hábito' : 'faltan $faltan hábitos'} de hoy',
    );
  }
  final aviso = resumen.cuidados?.avisoNucleo;
  if (!privado && aviso != null) partes.add(aviso);
  final saludo = '${saludoSegunHora(momento)}.';
  if (partes.isEmpty) return saludo;
  return '$saludo ${_conMayusculaInicial(partes.join(' y '))}.';
}

String _conMayusculaInicial(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// Ruta de primer nivel de cada módulo.
String rutaModulo(Modulo modulo) => switch (modulo) {
  Modulo.gravity => Rutas.inicio,
  Modulo.finanzas => Rutas.finanzas,
  Modulo.habitos => Rutas.habitos,
  Modulo.cuidados => Rutas.cuidados,
  Modulo.alimentacion => Rutas.alimentacion,
  Modulo.casa => Rutas.casa,
  Modulo.ajustes => Rutas.ajustes,
};

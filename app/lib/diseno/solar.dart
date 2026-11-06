/// Amanecer y atardecer reales del lugar, calculados sin red (DISENO_UX_UI,
/// sección 4, capa 4; respuesta P8 del dueño: claro y oscuro según el sol).
///
/// Es la ecuación del amanecer (valores astronómicos de NOAA): con solo la
/// fecha, la latitud y la longitud da la hora del amanecer y del atardecer con
/// un error de unos minutos, que basta para cambiar entre claro y oscuro. No
/// pide permiso de ubicación: el lugar se elige en Configuración de una lista.
///
/// Todo es puro: la hora entra como parámetro. La hora de pared de [ahora] se
/// toma como la **del lugar** (el teléfono de la persona está en su zona).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Un lugar de la tabla solar. Las zonas de México no tienen horario de
/// verano desde 2022, así que el corrimiento respecto a UTC es fijo.
@immutable
class LugarSolar {
  const LugarSolar({
    required this.id,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.utcHoras,
  });

  /// Identificador estable para guardar la preferencia.
  final String id;
  final String nombre;

  /// Grados; norte positivo.
  final double latitud;

  /// Grados; este positivo (México es negativo).
  final double longitud;

  /// Corrimiento de la zona respecto a UTC, en horas (México central: -6).
  final double utcHoras;

  @override
  bool operator ==(Object other) => other is LugarSolar && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Tabla de lugares disponibles (sin red).
const List<LugarSolar> lugaresSolares = [
  LugarSolar(
    id: 'cdmx',
    nombre: 'Ciudad de México',
    latitud: 19.4326,
    longitud: -99.1332,
    utcHoras: -6,
  ),
  LugarSolar(
    id: 'guadalajara',
    nombre: 'Guadalajara',
    latitud: 20.6597,
    longitud: -103.3496,
    utcHoras: -6,
  ),
  LugarSolar(
    id: 'monterrey',
    nombre: 'Monterrey',
    latitud: 25.6866,
    longitud: -100.3161,
    utcHoras: -6,
  ),
  LugarSolar(
    id: 'merida',
    nombre: 'Mérida',
    latitud: 20.9674,
    longitud: -89.5926,
    utcHoras: -6,
  ),
  LugarSolar(
    id: 'cancun',
    nombre: 'Cancún',
    latitud: 21.1619,
    longitud: -86.8515,
    utcHoras: -5,
  ),
  LugarSolar(
    id: 'hermosillo',
    nombre: 'Hermosillo',
    latitud: 29.0729,
    longitud: -110.9559,
    utcHoras: -7,
  ),
  LugarSolar(
    id: 'la_paz',
    nombre: 'La Paz',
    latitud: 24.1426,
    longitud: -110.3128,
    utcHoras: -7,
  ),
];

/// El lugar por omisión (el mismo de los bocetos).
const LugarSolar lugarSolarPorDefecto = LugarSolar(
  id: 'cdmx',
  nombre: 'Ciudad de México',
  latitud: 19.4326,
  longitud: -99.1332,
  utcHoras: -6,
);

/// Busca un lugar por su id; si no existe, regresa el de por omisión.
LugarSolar lugarSolarPorId(String? id) {
  for (final lugar in lugaresSolares) {
    if (lugar.id == id) return lugar;
  }
  return lugarSolarPorDefecto;
}

/// Amanecer y atardecer de un día, en minutos desde la medianoche **del lugar**.
@immutable
class SolDelDia {
  const SolDelDia(this.amanecerMin, this.atardecerMin);

  /// Sol de todo el día (no ocurre en México).
  static const dia24 = SolDelDia(0, 1440);

  /// Noche de todo el día (no ocurre en México).
  static const noche24 = SolDelDia(0, 0);

  final int amanecerMin;
  final int atardecerMin;

  /// Si ese minuto del día es de día: del amanecer (incluido) al atardecer.
  bool contiene(int minutoDelDia) =>
      minutoDelDia >= amanecerMin && minutoDelDia < atardecerMin;

  static String _hhmm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  String get textoAmanecer => _hhmm(amanecerMin);
  String get textoAtardecer => _hhmm(atardecerMin);

  @override
  String toString() => 'SolDelDia($textoAmanecer–$textoAtardecer)';
}

double _rad(double grados) => grados * math.pi / 180;

double _grados(double rad) => rad * 180 / math.pi;

/// Amanecer y atardecer del día de [fecha] (año, mes y día locales del lugar).
SolDelDia solDelDia(DateTime fecha, LugarSolar lugar) {
  // Días enteros desde el mediodía del 1 de enero de 2000 (J2000).
  final n = DateTime.utc(
    fecha.year,
    fecha.month,
    fecha.day,
    12,
  ).difference(DateTime.utc(2000, 1, 1, 12)).inDays;
  final jEstrella = n + lugar.longitud / 360;
  final anomalia = (357.5291 + 0.98560028 * jEstrella) % 360;
  final m = _rad(anomalia);
  final centro =
      1.9148 * math.sin(m) + 0.02 * math.sin(2 * m) + 0.0003 * math.sin(3 * m);
  final lambda = _rad((anomalia + centro + 180 + 102.9372) % 360);
  final transito =
      jEstrella + 0.0053 * math.sin(m) - 0.0069 * math.sin(2 * lambda);
  final senoDeclinacion = math.sin(lambda) * math.sin(_rad(23.4397));
  final cosDeclinacion = math.cos(math.asin(senoDeclinacion));
  final phi = _rad(lugar.latitud);
  final cosOmega =
      (math.sin(_rad(-0.833)) - math.sin(phi) * senoDeclinacion) /
      (math.cos(phi) * cosDeclinacion);
  if (cosOmega >= 1) return SolDelDia.noche24;
  if (cosOmega <= -1) return SolDelDia.dia24;
  final omega = _grados(math.acos(cosOmega));

  int aMinutoLocal(double diasDesdeJ2000) {
    final fraccion = (diasDesdeJ2000 % 1 + 0.5) % 1; // fracción del día UT
    final minutoUtc = fraccion * 1440;
    final local = (minutoUtc + lugar.utcHoras * 60) % 1440;
    return local.round() % 1440;
  }

  return SolDelDia(
    aMinutoLocal(transito - omega / 360),
    aMinutoLocal(transito + omega / 360),
  );
}

/// Si en ese momento (hora de pared del lugar) es de día.
bool esDeDiaSolar(DateTime ahora, LugarSolar lugar) =>
    solDelDia(ahora, lugar).contiene(ahora.hour * 60 + ahora.minute);

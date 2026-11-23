/// UUID v5 (RFC 4122, sección 4.3): SHA-1 del espacio de nombres y del nombre.
///
/// Sirve para los ids que no deben duplicarse al reintentar: la sesión de un
/// día y una plantilla y cada serie (spec de «Mi gimnasio», 2 y 4.2). Dos
/// equipos que registran lo mismo calculan **el mismo id** y el servidor
/// converge (`ON CONFLICT (id)`).
///
/// Sin dependencias nuevas: usa `crypto`, que la app ya trae. Se prueba con los
/// vectores publicados de la RFC y contra el paquete `uuid` (que usa el resto de
/// la app).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Espacios de nombres de la RFC 4122, apéndice C.
abstract final class EspacioUuid {
  static const dns = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
  static const url = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';
}

/// Los 16 bytes de un UUID escrito como texto. Lanza [FormatException] si no
/// lo es.
List<int> bytesDeUuid(String uuid) {
  final limpio = uuid.replaceAll('-', '');
  if (limpio.length != 32 || !RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(limpio)) {
    throw FormatException('No es un UUID válido.', uuid);
  }
  return [
    for (var i = 0; i < 32; i += 2) int.parse(limpio.substring(i, i + 2), radix: 16),
  ];
}

String _comoTexto(List<int> b) {
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// UUID v5 de [nombre] (texto UTF-8) dentro del espacio [espacio].
String uuidV5(String espacio, String nombre) {
  final hash = sha1.convert([...bytesDeUuid(espacio), ...utf8.encode(nombre)]);
  final b = hash.bytes.take(16).toList();
  b[6] = (b[6] & 0x0f) | 0x50; // versión 5
  b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122
  return _comoTexto(b);
}

/// `true` si [texto] es un UUID de la [version] dada (4 o 5) en minúsculas.
bool esUuidDeVersion(String texto, int version) => RegExp(
  '^[0-9a-f]{8}-[0-9a-f]{4}-$version[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\$',
).hasMatch(texto);

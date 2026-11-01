/// Frase de recuperación de 12 palabras (D21). 132 bits = 128 de azar + 4 de
/// verificación (primeros bits de SHA-256 del azar), como BIP-39.
///
/// **La lista de 2048 palabras es propia y se genera** (no se usó la de BIP-39
/// para no depender de una licencia): `consonante · a/e/i/o · consonante ·
/// a/o` = 16 × 4 × 16 × 2 = 2048 palabras pronunciables, únicas, de 4 letras
/// (las 4 letras bastan para distinguirlas).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

const _consonantes = 'bdfgjklmnprstvzh';
const _vocales1 = 'aeio';
const _vocales2 = 'ao';

/// Las 2048 palabras, en orden fijo.
final List<String> listaDePalabras = List.unmodifiable([
  for (final c1 in _consonantes.split(''))
    for (final v1 in _vocales1.split(''))
      for (final c2 in _consonantes.split(''))
        for (final v2 in _vocales2.split('')) '$c1$v1$c2$v2'
]);

final Map<String, int> _indice = {
  for (var i = 0; i < listaDePalabras.length; i++) listaDePalabras[i]: i
};

/// Palabras para 16 bytes de azar ([entropia]).
List<String> frasePara(List<int> entropia) {
  if (entropia.length != 16) throw ArgumentError('Se necesitan 16 bytes.');
  final cs = sha256.convert(entropia).bytes.first >> 4;
  var bits = BigInt.zero;
  for (final b in entropia) {
    bits = (bits << 8) | BigInt.from(b);
  }
  bits = (bits << 4) | BigInt.from(cs);
  return [
    for (var i = 11; i >= 0; i--)
      listaDePalabras[((bits >> (11 * i)) & BigInt.from(2047)).toInt()]
  ];
}

/// Genera una frase nueva con azar del sistema.
List<String> generarFrase([Random? azar]) {
  final r = azar ?? Random.secure();
  return frasePara(List<int>.generate(16, (_) => r.nextInt(256)));
}

/// Verifica el formato y los 4 bits de verificación.
bool fraseValida(List<String> palabras) {
  if (palabras.length != 12) return false;
  var bits = BigInt.zero;
  for (final p in palabras) {
    final i = _indice[p.trim().toLowerCase()];
    if (i == null) return false;
    bits = (bits << 11) | BigInt.from(i);
  }
  final cs = (bits & BigInt.from(15)).toInt();
  final azar = bits >> 4;
  final bytes = Uint8List(16);
  var t = azar;
  for (var i = 15; i >= 0; i--) {
    bytes[i] = (t & BigInt.from(255)).toInt();
    t >>= 8;
  }
  return sha256.convert(bytes).bytes.first >> 4 == cs;
}

/// Texto canónico de la frase para derivar la llave.
String normalizarFrase(List<String> palabras) =>
    palabras.map((p) => p.trim().toLowerCase()).join(' ');

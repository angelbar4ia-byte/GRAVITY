/// PIN de 4 a 6 dígitos. Nunca se guarda el PIN: solo su hash con sal
/// (PBKDF2 con HMAC-SHA256), dentro del almacenamiento seguro.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final _formatoPin = RegExp(r'^\d{4,6}$');

/// `true` si [pin] tiene de 4 a 6 dígitos.
bool pinValido(String pin) => _formatoPin.hasMatch(pin);

abstract final class HashPin {
  static const version = 'pbkdf2-sha256';
  static const iteracionesPorDefecto = 10000;
  static const _bytesSal = 16;

  /// Hash con sal aleatoria: `pbkdf2-sha256$iteraciones$sal$hash` (base64).
  static String crear(
    String pin, {
    int iteraciones = iteracionesPorDefecto,
    List<int>? sal,
  }) {
    if (!pinValido(pin)) {
      throw ArgumentError.value(pin, 'pin', 'Debe tener de 4 a 6 dígitos');
    }
    final salUsada = sal ?? _salAleatoria();
    final hash = _pbkdf2(utf8.encode(pin), salUsada, iteraciones);
    return [
      version,
      '$iteraciones',
      base64Encode(salUsada),
      base64Encode(hash),
    ].join(r'$');
  }

  /// Compara [pin] con un hash guardado, en tiempo constante.
  static bool verificar(String pin, String guardado) {
    final partes = guardado.split(r'$');
    if (partes.length != 4 || partes[0] != version) return false;
    final iteraciones = int.tryParse(partes[1]);
    if (iteraciones == null || iteraciones < 1) return false;
    final List<int> sal;
    final List<int> esperado;
    try {
      sal = base64Decode(partes[2]);
      esperado = base64Decode(partes[3]);
    } on FormatException {
      return false;
    }
    final calculado = _pbkdf2(utf8.encode(pin), sal, iteraciones);
    if (calculado.length != esperado.length) return false;
    var diferencia = 0;
    for (var i = 0; i < calculado.length; i++) {
      diferencia |= calculado[i] ^ esperado[i];
    }
    return diferencia == 0;
  }

  /// Llave de 32 bytes derivada del PIN (PBKDF2-HMAC-SHA256), p. ej. para
  /// cifrar la credencial de una persona en la tablet (`cifrado.dart`). Usa
  /// una sal distinta de la del hash.
  static List<int> derivarLlave(
    String pin,
    List<int> sal, {
    int iteraciones = iteracionesPorDefecto,
  }) => _pbkdf2(utf8.encode(pin), sal, iteraciones);

  /// Sal aleatoria de 16 bytes.
  static List<int> salAleatoria() => _salAleatoria();

  static List<int> _salAleatoria() {
    final azar = Random.secure();
    return List<int>.generate(_bytesSal, (_) => azar.nextInt(256));
  }

  /// PBKDF2-HMAC-SHA256 con un solo bloque de 32 bytes (RFC 8018).
  static List<int> _pbkdf2(List<int> clave, List<int> sal, int iteraciones) {
    final hmac = Hmac(sha256, clave);
    final bloque = Uint8List.fromList([...sal, 0, 0, 0, 1]);
    var u = hmac.convert(bloque).bytes;
    final resultado = Uint8List.fromList(u);
    for (var i = 1; i < iteraciones; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < resultado.length; j++) {
        resultado[j] ^= u[j];
      }
    }
    return resultado;
  }
}

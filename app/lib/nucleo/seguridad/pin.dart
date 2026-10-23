/// PIN de 4 a 6 dígitos, no trivial al elegirlo ([motivoPinDebil]). Nunca se
/// guarda el PIN: solo su hash con sal
/// (PBKDF2 con HMAC-SHA256), dentro del almacenamiento seguro.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final _formatoPin = RegExp(r'^\d{4,6}$');

/// `true` si [pin] tiene de 4 a 6 dígitos.
bool pinValido(String pin) => _formatoPin.hasMatch(pin);

/// Por qué [pin] (de 4 a 6 dígitos) es **trivial** y no se acepta como PIN
/// nuevo (M9, revisión de la Fase 1), o `null` si no lo es. Cuenta como
/// trivial:
///
/// - el mismo dígito repetido (`0000`, `1111`, `999999`);
/// - una secuencia seguida, de subida o de bajada, que da la vuelta del 9 al 0
///   (`1234`, `4321`, `0123`, `7890`, `123456`, `654321`);
/// - un bloque que se repite (`1212`, `4545`, `123123`, `686868`).
///
/// No cambia el largo del PIN (4 a 6): eso lo decide el dueño. Un PIN que no
/// pasa [pinValido] no se juzga aquí.
String? motivoPinDebil(String pin) {
  if (!pinValido(pin)) return null;
  final digitos = [for (final c in pin.split('')) int.parse(c)];
  if (digitos.every((d) => d == digitos.first)) {
    return 'Ese PIN repite el mismo número. Elige uno menos fácil de adivinar.';
  }
  bool conPaso(int paso) {
    for (var i = 1; i < digitos.length; i++) {
      if ((digitos[i] - digitos[i - 1]) % 10 != paso % 10) return false;
    }
    return true;
  }

  if (conPaso(1) || conPaso(-1)) {
    return 'Ese PIN es una secuencia (como 1234). Elige uno menos fácil de '
        'adivinar.';
  }
  for (var periodo = 2; periodo <= digitos.length ~/ 2; periodo++) {
    if (digitos.length % periodo != 0) continue;
    var seRepite = true;
    for (var i = periodo; i < digitos.length; i++) {
      if (digitos[i] != digitos[i - periodo]) {
        seRepite = false;
        break;
      }
    }
    if (seRepite) {
      return 'Ese PIN repite un mismo bloque (como 1212). Elige uno menos '
          'fácil de adivinar.';
    }
  }
  return null;
}

/// `true` si [pin] es trivial (ver [motivoPinDebil]).
bool pinEsDebil(String pin) => motivoPinDebil(pin) != null;

/// Mensaje para un PIN nuevo que no se puede aceptar (formato o trivial), o
/// `null` si sirve. Es lo que muestran los formularios.
String? errorDePinNuevo(String pin) =>
    pinValido(pin) ? motivoPinDebil(pin) : 'De 4 a 6 dígitos.';

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

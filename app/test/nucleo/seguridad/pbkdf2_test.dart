// PBKDF2-HMAC-SHA256 propio (M9' de la revisión de la Fase 1b): debe dar
// exactamente lo mismo que la implementación de referencia y ser bastante más
// rápido, para poder subir las vueltas del PIN de 10 000 a 100 000.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/seguridad/pbkdf2.dart';
import 'package:gravity/nucleo/seguridad/pin.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Referencia: PBKDF2 con el HMAC de `package:crypto` (una función por bloque).
List<int> _referencia(List<int> clave, List<int> sal, int vueltas, int largo) {
  final hmac = Hmac(sha256, clave);
  final salida = <int>[];
  for (var bloque = 1; salida.length < largo; bloque++) {
    var u = hmac.convert([
      ...sal,
      bloque >>> 24,
      (bloque >>> 16) & 0xFF,
      (bloque >>> 8) & 0xFF,
      bloque & 0xFF,
    ]).bytes;
    final t = List<int>.of(u);
    for (var i = 1; i < vueltas; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    salida.addAll(t);
  }
  return salida.sublist(0, largo);
}

void main() {
  group('vectores conocidos', () {
    test('"password" / "salt", 1 vuelta', () {
      expect(
        _hex(pbkdf2HmacSha256(utf8.encode('password'), utf8.encode('salt'), 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('"password" / "salt", 2 vueltas', () {
      expect(
        _hex(pbkdf2HmacSha256(utf8.encode('password'), utf8.encode('salt'), 2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('"password" / "salt", 4096 vueltas', () {
      expect(
        _hex(pbkdf2HmacSha256(utf8.encode('password'), utf8.encode('salt'), 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('RFC 7914: "passwd" / "salt", 1 vuelta, 64 bytes (dos bloques)', () {
      expect(
        _hex(pbkdf2HmacSha256(utf8.encode('passwd'), utf8.encode('salt'), 1, largo: 64)),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });
  });

  group('coincide con la implementación de referencia', () {
    test('entradas al azar: largos de llave y de sal en los bordes del relleno', () {
      final azar = Random(20261030);
      Uint8List bytes(int n) =>
          Uint8List.fromList(List<int>.generate(n, (_) => azar.nextInt(256)));
      // Largos que cruzan los bordes del relleno de SHA-256 (55, 56, 63, 64) y
      // el de la llave del HMAC (64, 65).
      final largos = [0, 1, 6, 16, 52, 55, 56, 57, 59, 60, 63, 64, 65, 100, 130];
      for (final largoClave in largos) {
        for (final largoSal in largos) {
          final clave = bytes(largoClave);
          final sal = bytes(largoSal);
          final vueltas = 1 + azar.nextInt(4);
          final largo = 1 + azar.nextInt(70);
          expect(
            _hex(pbkdf2HmacSha256(clave, sal, vueltas, largo: largo)),
            _hex(_referencia(clave, sal, vueltas, largo)),
            reason: 'clave $largoClave, sal $largoSal, $vueltas vueltas, $largo bytes',
          );
        }
      }
    });

    test('un PIN real con 10 000 y 100 000 vueltas', () {
      final sal = List<int>.generate(16, (i) => 3 * i + 1);
      for (final vueltas in [10000, 100000]) {
        expect(
          _hex(pbkdf2HmacSha256(utf8.encode('738291'), sal, vueltas)),
          _hex(_referencia(utf8.encode('738291'), sal, vueltas, 32)),
          reason: '$vueltas vueltas',
        );
      }
    });

    test('es determinista y la sal y la clave cambian el resultado', () {
      final a = pbkdf2HmacSha256(utf8.encode('738291'), [1, 2, 3], 100);
      expect(pbkdf2HmacSha256(utf8.encode('738291'), [1, 2, 3], 100), a);
      expect(pbkdf2HmacSha256(utf8.encode('738292'), [1, 2, 3], 100), isNot(a));
      expect(pbkdf2HmacSha256(utf8.encode('738291'), [1, 2, 4], 100), isNot(a));
      expect(pbkdf2HmacSha256(utf8.encode('738291'), [1, 2, 3], 101), isNot(a));
    });
  });

  test('parámetros inválidos', () {
    expect(() => pbkdf2HmacSha256([1], [1], 0), throwsArgumentError);
    expect(() => pbkdf2HmacSha256([1], [1], 1, largo: 0), throwsArgumentError);
  });

  group('costo del PIN (M9\')', () {
    test('las vueltas de hoy son 100 000 y las de antes 10 000', () {
      expect(HashPin.iteracionesActuales, 100000);
      expect(HashPin.iteracionesAnteriores, 10000);
      expect(HashPin.iteracionesActuales, greaterThan(HashPin.iteracionesAnteriores));
    });

    test('con las vueltas de verdad, crear y verificar un PIN es razonable', () {
      final antes = HashPin.iteracionesPorDefecto;
      addTearDown(() => HashPin.iteracionesPorDefecto = antes);
      HashPin.iteracionesPorDefecto = HashPin.iteracionesActuales;
      final reloj = Stopwatch()..start();
      final hash = HashPin.crear('738291');
      final crear = reloj.elapsedMilliseconds;
      reloj
        ..reset()
        ..start();
      expect(HashPin.verificar('738291', hash), isTrue);
      expect(HashPin.verificar('738290', hash), isFalse);
      final verificar = reloj.elapsedMilliseconds ~/ 2;
      expect(hash, contains(r'$100000$'));
      // Medido ~0.3 s en una computadora; el tope es generoso para no depender
      // de la máquina que corra la prueba. En un teléfono medio se estiman ~1 s.
      expect(crear, lessThan(8000), reason: 'crear: $crear ms');
      expect(verificar, lessThan(8000), reason: 'verificar: $verificar ms');
    });
  });
}

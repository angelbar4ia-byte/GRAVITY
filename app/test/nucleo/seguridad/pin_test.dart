import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/pin.dart';

void main() {
  test('pinValido: de 4 a 6 dígitos', () {
    for (final pin in ['1234', '12345', '123456', '0000']) {
      expect(pinValido(pin), isTrue, reason: pin);
    }
    for (final pin in ['', '123', '1234567', '12a4', ' 1234', '12 34']) {
      expect(pinValido(pin), isFalse, reason: pin);
    }
  });

  test('el hash no contiene el PIN y se verifica', () {
    final hash = HashPin.crear('482915');
    expect(hash, isNot(contains('482915')));
    expect(hash, startsWith('pbkdf2-sha256\$10000\$'));
    expect(HashPin.verificar('482915', hash), isTrue);
    expect(HashPin.verificar('482914', hash), isFalse);
    expect(HashPin.verificar('', hash), isFalse);
  });

  test('cada hash lleva sal distinta', () {
    final a = HashPin.crear('1234', iteraciones: 10);
    final b = HashPin.crear('1234', iteraciones: 10);
    expect(a, isNot(b));
    expect(HashPin.verificar('1234', a), isTrue);
    expect(HashPin.verificar('1234', b), isTrue);
  });

  test('coincide con PBKDF2-HMAC-SHA256 de referencia (hashlib de Python)', () {
    final sal = utf8.encode('salt');
    expect(
      HashPin.crear('1234', iteraciones: 1, sal: sal),
      r'pbkdf2-sha256$1$c2FsdA==$0Lw6Xl+wbzy4ksdB/r9Yt9QNIueeYBJeKbwOTzVLqEI=',
    );
    expect(
      HashPin.crear('1234', iteraciones: 1000, sal: sal),
      r'pbkdf2-sha256$1000$c2FsdA==$/vKS0jH25vXnh7ItsSiw5Q0uddDD1/KYnnf3ICZGcXs=',
    );
  });

  test('hash dañado o de otro formato no se acepta', () {
    final hash = HashPin.crear('1234', iteraciones: 10);
    expect(HashPin.verificar('1234', 'texto'), isFalse);
    expect(HashPin.verificar('1234', hash.replaceFirst('pbkdf2', 'md5')), isFalse);
    expect(HashPin.verificar('1234', '${hash}x'), isFalse);
    expect(
      HashPin.verificar('1234', r'pbkdf2-sha256$0$AAAA$AAAA'),
      isFalse,
    );
  });

  test('crear rechaza un PIN inválido', () {
    expect(() => HashPin.crear('12'), throwsArgumentError);
  });

  test('AlmacenSeguroEnMemoria lee, escribe y borra', () async {
    final almacen = AlmacenSeguroEnMemoria();
    expect(await almacen.leer('a'), isNull);
    await almacen.escribir('a', '1');
    expect(await almacen.leer('a'), '1');
    await almacen.borrar('a');
    expect(await almacen.leer('a'), isNull);
  });

  test('BiometriaFalsa y BiometriaNoDisponible', () async {
    expect(await const BiometriaNoDisponible().disponible(), isFalse);
    final falsa = BiometriaFalsa(acepta: false);
    expect(await falsa.disponible(), isTrue);
    expect(await falsa.autenticar('x'), isFalse);
    expect(falsa.intentos, 1);
  });
}

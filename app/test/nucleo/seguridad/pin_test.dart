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

  group('M9: PIN triviales', () {
    test('se rechazan los repetidos', () {
      for (final pin in ['0000', '1111', '9999', '00000', '777777']) {
        expect(pinEsDebil(pin), isTrue, reason: pin);
        expect(motivoPinDebil(pin), contains('repite el mismo número'));
      }
    });

    test('se rechazan las secuencias, de subida y de bajada', () {
      for (final pin in [
        '1234', '2345', '6789', '4321', '9876', '3210', '0123', '12345',
        '54321', '123456', '654321', '234567', '987654',
        // Dan la vuelta del 9 al 0.
        '7890', '8901', '9012', '0987', '1098', '890123',
      ]) {
        expect(pinEsDebil(pin), isTrue, reason: pin);
        expect(motivoPinDebil(pin), contains('secuencia'), reason: pin);
      }
    });

    test('se rechaza un bloque que se repite', () {
      for (final pin in ['1212', '4545', '6969', '123123', '686868', '121212']) {
        expect(pinEsDebil(pin), isTrue, reason: pin);
        expect(motivoPinDebil(pin), contains('bloque'), reason: pin);
      }
    });

    test('un PIN que no es trivial pasa, del largo que sea', () {
      for (final pin in [
        '2846', '7391', '1357', '2580', '1223', '5019', '28461', '73915',
        '482915', '135792', '120934',
      ]) {
        expect(pinEsDebil(pin), isFalse, reason: pin);
        expect(motivoPinDebil(pin), isNull, reason: pin);
      }
    });

    test('no cambia el largo del PIN: 4, 5 y 6 dígitos siguen valiendo', () {
      expect(errorDePinNuevo('2846'), isNull);
      expect(errorDePinNuevo('28461'), isNull);
      expect(errorDePinNuevo('284615'), isNull);
      expect(errorDePinNuevo('284'), 'De 4 a 6 dígitos.');
      expect(errorDePinNuevo('2846153'), 'De 4 a 6 dígitos.');
      expect(errorDePinNuevo('28a6'), 'De 4 a 6 dígitos.');
    });

    test('lo que no es un PIN válido no se juzga como débil', () {
      expect(motivoPinDebil('12'), isNull);
      expect(motivoPinDebil(''), isNull);
    });

    test('verificar un PIN ya guardado no exige que no sea trivial', () {
      // Quien ya tiene un PIN así (de antes) sigue pudiendo entrar; solo se
      // exige al elegirlo.
      final hash = HashPin.crear('1234', iteraciones: 10);
      expect(HashPin.verificar('1234', hash), isTrue);
    });
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

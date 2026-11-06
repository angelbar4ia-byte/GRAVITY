// Primitivas de los datos sensibles de Hábitos con vectores conocidos
// (NIST/McGrew para AES-GCM, RFC 5869 para HKDF) y propiedades de seguridad.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/sensibles/cripto.dart';

Uint8List hex(String h) => Uint8List.fromList([
  for (var i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

String aHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('AES-256-GCM', () {
    test(
      'vectores del documento original de GCM (casos 13 y 14, llave de ceros)',
      () {
        final llave = Uint8List(32);
        final nonce = Uint8List(12);
        // Caso 13: texto vacío → solo la etiqueta.
        final vacio = SobreAes.cifrarBytes(llave, const [], nonce: nonce);
        expect(aHex(vacio.sublist(13)), '530f8afbc74536b9a963b4f1c4cb738b');
        // Caso 14: 16 bytes de ceros.
        final uno = SobreAes.cifrarBytes(llave, Uint8List(16), nonce: nonce);
        expect(aHex(uno.sublist(13, 29)), 'cea7403d4d606b6e074ec5d3baf39d18');
        expect(aHex(uno.sublist(29)), 'd0d1c8a799996bf0265b98b5d48ab919');
      },
    );

    test('ida y vuelta, con un nonce distinto cada vez', () {
      final llave = bytesAleatorios(32);
      final claro = utf8.encode('{"cigarrillos": 3}');
      final a = SobreAes.cifrar(llave, claro);
      final b = SobreAes.cifrar(llave, claro);
      expect(a, isNot(b));
      expect(SobreAes.descifrar(llave, a), claro);
      expect(a, isNot(contains('cigarrillos')));
      // base64url sin relleno.
      expect(a, isNot(contains('=')));
      expect(a, isNot(contains('+')));
      expect(a, isNot(contains('/')));
    });

    test('los datos asociados atan el sobre a su lugar', () {
      final llave = bytesAleatorios(32);
      final aad = datosAsociadosDeSobre(
        persona: 'p',
        tipo: 'diario_oracion',
        id: 'i',
        revision: 3,
      );
      final s = SobreAes.cifrar(llave, [1, 2, 3], datosAsociados: aad);
      expect(SobreAes.descifrar(llave, s, datosAsociados: aad), [1, 2, 3]);
      for (final otro in [
        datosAsociadosDeSobre(
          persona: 'q',
          tipo: 'diario_oracion',
          id: 'i',
          revision: 3,
        ),
        datosAsociadosDeSobre(
          persona: 'p',
          tipo: 'habitos_sensibles',
          id: 'i',
          revision: 3,
        ),
        datosAsociadosDeSobre(
          persona: 'p',
          tipo: 'diario_oracion',
          id: 'j',
          revision: 3,
        ),
        datosAsociadosDeSobre(
          persona: 'p',
          tipo: 'diario_oracion',
          id: 'i',
          revision: 2,
        ),
      ]) {
        expect(SobreAes.descifrar(llave, s, datosAsociados: otro), isNull);
      }
    });

    test('llave equivocada, sobre alterado o dañado: null, nunca lanza', () {
      final llave = bytesAleatorios(32);
      final s = SobreAes.cifrar(llave, utf8.encode('secreto'));
      expect(SobreAes.descifrar(bytesAleatorios(32), s), isNull);
      final bytes = desdeBase64Url(s);
      for (final i in [0, 1, 13, bytes.length - 1]) {
        final malo = Uint8List.fromList(bytes)..[i] ^= 1;
        expect(
          SobreAes.descifrar(llave, aBase64Url(malo)),
          isNull,
          reason: 'byte $i',
        );
      }
      for (final raro in [
        '',
        'x',
        '%%%',
        aBase64Url([1, 2, 3]),
      ]) {
        expect(SobreAes.descifrar(llave, raro), isNull, reason: raro);
      }
      expect(SobreAes.descifrar(Uint8List(5), s), isNull);
      expect(() => SobreAes.cifrar(Uint8List(5), [1]), throwsArgumentError);
    });
  });

  group('HKDF-SHA256 (RFC 5869)', () {
    test('caso de prueba 3 (sin sal ni info)', () {
      final salida = hkdfSha256(
        hex('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b'),
        info: '',
        largo: 42,
      );
      expect(
        aHex(salida),
        '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d'
        '9d201395faa4b61a96c8',
      );
    });

    test('la llave de cada tipo y la de ids son distintas y repetibles', () {
      final base = bytesAleatorios(32);
      final a = hkdfSha256(base, info: 'gravity-hab/v1/habitos_sensibles');
      final b = hkdfSha256(base, info: 'gravity-hab/v1/diario_oracion');
      final ids = hkdfSha256(base, info: 'gravity-hab/v1/ids');
      expect({aHex(a), aHex(b), aHex(ids)}, hasLength(3));
      expect(hkdfSha256(base, info: 'gravity-hab/v1/ids'), ids);
    });
  });

  test('PBKDF2 en un hilo aparte da lo mismo que el directo', () async {
    final a = await pbkdf2EnAislado(
      utf8.encode('password'),
      utf8.encode('salt'),
      4096,
    );
    expect(
      aHex(a),
      'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
    );
  });

  test('600 000 vueltas en un hilo aparte: mide y cuida el tiempo', () async {
    final reloj = Stopwatch()..start();
    await pbkdf2EnAislado(
      utf8.encode('frase de prueba'),
      bytesAleatorios(16),
      600000,
    );
    // ~1.8 s en una computadora; el tope es generoso para no depender de la
    // máquina. El Galaxy A52 se mide aparte (ver el reporte de la Fase 3).
    expect(reloj.elapsedMilliseconds, lessThan(20000));
  });
}

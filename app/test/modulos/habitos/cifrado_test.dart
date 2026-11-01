import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/cifrado/cifrador_real.dart';
import 'package:gravity/modulos/habitos/cifrado/frase.dart';
import 'package:gravity/modulos/habitos/cifrado/llaves.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

List<int> hex(String s) => [
      for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)
    ];
String aHex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final c = CifradorReal(azar: Random(1));

  test('HKDF-SHA256, vector 1 de RFC 5869', () {
    final okm = c.hkdf(hex('0b' * 22), hex('000102030405060708090a0b0c'),
        hex('f0f1f2f3f4f5f6f7f8f9'), 42);
    expect(aHex(okm),
        '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865');
  });

  test('HMAC-SHA256, caso 1 de RFC 4231', () {
    expect(aHex(c.hmac(hex('0b' * 20), utf8.encode('Hi There'))),
        'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');
  });

  test('AES-256-GCM, vector de caso 14 de la especificación de GCM', () {
    // Llave de ceros, nonce de ceros, texto de 16 bytes de ceros, sin AAD.
    // Texto cifrado y etiqueta conocidos (McGrew y Viega, caso 14).
    final r = CifradorReal(azar: _Ceros());
    final salida = r.cifrar(llave: List.filled(32, 0), datos: List.filled(16, 0), aad: []);
    expect(aHex(salida.sublist(0, 12)), '000000000000000000000000');
    expect(aHex(salida.sublist(12)),
        'cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919');
  });

  test('ida y vuelta; AAD y llave equivocadas fallan; nonce distinto', () {
    final llave = List<int>.generate(32, (i) => i);
    final a = c.cifrar(llave: llave, datos: utf8.encode('hola'), aad: [1]);
    final b = c.cifrar(llave: llave, datos: utf8.encode('hola'), aad: [1]);
    expect(a, isNot(b));
    expect(utf8.decode(c.descifrar(llave: llave, sobre: a, aad: [1])), 'hola');
    expect(() => c.descifrar(llave: llave, sobre: a, aad: [2]), throwsFormatException);
    expect(() => c.descifrar(llave: List.filled(32, 9), sobre: a, aad: [1]),
        throwsFormatException);
    final roto = [...a]..[14] ^= 1;
    expect(() => c.descifrar(llave: llave, sobre: roto, aad: [1]), throwsFormatException);
  });

  test('sobres del dominio con el cifrador real', () {
    final llave = llaveDelTipo(c, List.filled(32, 7), 'diario_oracion');
    final s = sellarSobre(c, llaveDelTipo: llave, persona: 'p', tipo: 't', id: 'i',
        revision: 1, documento: {'v': 1, 'elementos': {}});
    expect(abrirSobre(c, s, llaveDelTipo: llave, persona: 'p', tipo: 't', id: 'i',
        revision: 1)['v'], 1);
    expect(() => abrirSobre(c, s, llaveDelTipo: llave, persona: 'p', tipo: 't',
        id: 'i', revision: 2), throwsFormatException);
  });

  test('lista de palabras: 2048 únicas; frase de 12 con verificación', () {
    expect(listaDePalabras.length, 2048);
    expect(listaDePalabras.toSet().length, 2048);
    expect(listaDePalabras.map((p) => p.substring(0, 4)).toSet().length, 2048);
    final f = generarFrase(Random(3));
    expect(f.length, 12);
    expect(fraseValida(f), isTrue);
    final mala = [...f]..[4] = f[4] == listaDePalabras[0] ? listaDePalabras[1] : listaDePalabras[0];
    expect(fraseValida(mala), isFalse);
    expect(fraseValida(f.sublist(1)), isFalse);
    expect(fraseValida(frasePara(List.filled(16, 0))), isTrue);
  });

  test('llave maestra envuelta con la frase', () {
    final frase = generarFrase(Random(5));
    final maestra = List<int>.generate(32, (i) => i * 3 & 255);
    final env = envolverLlave(c, persona: 'p', frase: frase, llaveMaestra: maestra,
        vueltas: 1000, azar: Random(2));
    expect(env.aParametros()['p_kdf'], 'pbkdf2-hmac-sha256');
    expect(desenvolverLlave(c, persona: 'p', frase: frase, envuelta: env), maestra);
    final otra = generarFrase(Random(6));
    expect(() => desenvolverLlave(c, persona: 'p', frase: otra, envuelta: env),
        throwsFormatException);
    expect(() => desenvolverLlave(c, persona: 'q', frase: frase, envuelta: env),
        throwsFormatException);
  });
}

class _Ceros implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

// Sobre sellado (ECIES): quien tiene la llave pública sella; solo la privada
// abre. Lo usa la bandeja de salida de la tablet (D14, 23/oct/2026).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/seguridad/sobre_sellado.dart';

void main() {
  test('sellar y abrir devuelve el mismo texto', () {
    final par = SobreSellado.generar();
    const texto = '{"access_token":"a","refresh_token":"r","ñ":"áéí"}';
    final sobre = SobreSellado.sellar(par.publica, texto);
    expect(SobreSellado.abrir(par.privada, sobre), texto);
  });

  test('las llaves tienen el tamaño esperado y son nuevas cada vez', () {
    final a = SobreSellado.generar();
    final b = SobreSellado.generar();
    expect(base64Decode(a.publica), hasLength(65));
    expect(base64Decode(a.publica).first, 4, reason: 'punto sin comprimir');
    expect(a.privada, hasLength(32));
    expect(a.publica, isNot(b.publica));
    expect(a.privada, isNot(b.privada));
  });

  test('el sobre no contiene el texto', () {
    final par = SobreSellado.generar();
    final sobre = SobreSellado.sellar(par.publica, 'refresh_token_secreto');
    expect(sobre, isNot(contains('refresh_token_secreto')));
    expect(
      utf8.decode(base64Decode(jsonDecode(sobre)['datos'] as String), allowMalformed: true),
      isNot(contains('secreto')),
    );
  });

  test('cada sellado es distinto (llave efímera y nonce nuevos)', () {
    final par = SobreSellado.generar();
    final a = SobreSellado.sellar(par.publica, 'igual');
    final b = SobreSellado.sellar(par.publica, 'igual');
    expect(a, isNot(b));
    expect(SobreSellado.abrir(par.privada, a), 'igual');
    expect(SobreSellado.abrir(par.privada, b), 'igual');
  });

  test('otra llave privada no lo abre', () {
    final par = SobreSellado.generar();
    final otra = SobreSellado.generar();
    final sobre = SobreSellado.sellar(par.publica, 'secreto');
    expect(SobreSellado.abrir(otra.privada, sobre), isNull);
  });

  test('un sobre alterado no se abre', () {
    final par = SobreSellado.generar();
    final json = jsonDecode(SobreSellado.sellar(par.publica, 'secreto')) as Map<String, dynamic>;
    final datos = base64Decode(json['datos'] as String);
    datos[0] ^= 1;
    expect(
      SobreSellado.abrir(par.privada, jsonEncode({...json, 'datos': base64Encode(datos)})),
      isNull,
    );
    // Ni cambiando la llave efímera.
    final otra = SobreSellado.generar();
    expect(
      SobreSellado.abrir(par.privada, jsonEncode({...json, 'e': otra.publica})),
      isNull,
    );
  });

  test('basura, versión desconocida o llave dañada: null, sin lanzar', () {
    final par = SobreSellado.generar();
    expect(SobreSellado.abrir(par.privada, 'no es json'), isNull);
    expect(SobreSellado.abrir(par.privada, '{}'), isNull);
    expect(SobreSellado.abrir(par.privada, '{"v":2}'), isNull);
    expect(SobreSellado.abrir(Uint8List(0), SobreSellado.sellar(par.publica, 'x')), isNull);
  });

  test('sellar con una llave pública mal formada lanza', () {
    expect(() => SobreSellado.sellar('AAAA', 'x'), throwsA(anything));
    expect(() => SobreSellado.sellar('no-base64!', 'x'), throwsA(anything));
  });
}

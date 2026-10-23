// Revisión de calidad de la Fase 1b: el sobre sellado de la bandeja de salida
// (ECIES: ECDH P-256 + HKDF-SHA256 + AES-256-GCM) y el cifrado con el PIN, puestos
// a prueba como lo haría un adversario que puede leer y escribir el almacén.
// Todas pasan hoy: son guardias.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
import 'package:gravity/nucleo/seguridad/sobre_sellado.dart';

Map<String, Object?> _partes(String sobre) =>
    (jsonDecode(sobre) as Map).cast<String, Object?>();

String _con(String sobre, String campo, List<int> bytes) =>
    jsonEncode({..._partes(sobre), campo: base64Encode(bytes)});

void main() {
  final par = SobreSellado.generar();
  final otra = SobreSellado.generar();
  // Una sesión de Supabase pesa un par de KB (JWT + refresh token + usuario).
  final texto = jsonEncode({
    'access_token': 'a' * 900,
    'refresh_token': 'r-0123456789',
    'user': {'id': 'u', 'email': 'dueno@ejemplo.test'},
  });

  test('cada sellado usa una llave efímera y un nonce nuevos (300 sellados del mismo texto)', () {
    final efimeras = <String>{};
    final nonces = <String>{};
    final datos = <String>{};
    for (var i = 0; i < 300; i++) {
      final p = _partes(SobreSellado.sellar(par.publica, texto));
      efimeras.add(p['e']! as String);
      nonces.add(p['nonce']! as String);
      datos.add(p['datos']! as String);
    }
    expect(efimeras, hasLength(300));
    expect(nonces, hasLength(300));
    expect(datos, hasLength(300), reason: 'el mismo texto nunca da el mismo sobre');
  });

  test('ida y vuelta de un texto del tamaño de una sesión', () {
    final sobre = SobreSellado.sellar(par.publica, texto);
    expect(SobreSellado.abrir(par.privada, sobre), texto);
    expect(sobre, isNot(contains('refresh_token')));
    expect(sobre, isNot(contains('dueno@ejemplo.test')));
  });

  test('alterar cualquier parte del sobre lo vuelve inservible, sin lanzar', () {
    final sobre = SobreSellado.sellar(par.publica, texto);
    final p = _partes(sobre);
    final datos = base64Decode(p['datos']! as String);
    final nonce = base64Decode(p['nonce']! as String);
    final efimera = base64Decode(p['e']! as String);

    Uint8List voltear(List<int> bytes, int i) {
      final copia = Uint8List.fromList(bytes);
      copia[i] ^= 0x01;
      return copia;
    }

    for (final i in [0, 1, datos.length ~/ 2, datos.length - 17, datos.length - 1]) {
      expect(
        SobreSellado.abrir(par.privada, _con(sobre, 'datos', voltear(datos, i))),
        isNull,
        reason: 'byte $i de los datos (el último bloque es la etiqueta de GCM)',
      );
    }
    for (var i = 0; i < nonce.length; i++) {
      expect(
        SobreSellado.abrir(par.privada, _con(sobre, 'nonce', voltear(nonce, i))),
        isNull,
        reason: 'byte $i del nonce',
      );
    }
    for (final i in [1, 2, 33, 64]) {
      expect(
        SobreSellado.abrir(par.privada, _con(sobre, 'e', voltear(efimera, i))),
        isNull,
        reason: 'byte $i de la llave efímera',
      );
    }
    // Recortar la etiqueta.
    expect(
      SobreSellado.abrir(par.privada, _con(sobre, 'datos', datos.sublist(0, datos.length - 1))),
      isNull,
    );
    expect(SobreSellado.abrir(par.privada, _con(sobre, 'datos', const [])), isNull);
    // Otra versión.
    expect(
      SobreSellado.abrir(par.privada, jsonEncode({...p, 'v': 2})),
      isNull,
    );
  });

  test('ni la llave pública, ni otra privada, ni una privada vacía lo abren', () {
    final sobre = SobreSellado.sellar(par.publica, texto);
    expect(SobreSellado.abrir(otra.privada, sobre), isNull);
    expect(SobreSellado.abrir(Uint8List.fromList(base64Decode(par.publica)), sobre), isNull);
    expect(SobreSellado.abrir(Uint8List(32), sobre), isNull);
    expect(SobreSellado.abrir(Uint8List(0), sobre), isNull);
  });

  test('una llave efímera hostil (punto fuera de la curva o infinito) no abre ni lanza', () {
    final sobre = SobreSellado.sellar(par.publica, texto);
    final fuera = Uint8List(65)..[0] = 0x04; // x = y = 0: no está en P-256
    expect(SobreSellado.abrir(par.privada, _con(sobre, 'e', fuera)), isNull);
    expect(SobreSellado.abrir(par.privada, _con(sobre, 'e', const [0])), isNull);
    expect(SobreSellado.abrir(par.privada, _con(sobre, 'e', const [])), isNull);
  });

  // Defensa en profundidad (menor): pointycastle decodifica un punto sin
  // comprobar que está en la curva y `sellar` cifra para él. No es explotable
  // hoy (la llave pública la genera la propia app y vive en el mismo almacén que
  // la credencial en claro), pero validar el punto cuesta una línea.
  test('sellar con una llave pública fuera de la curva lanza, no cifra a ciegas', () {
    final fuera = Uint8List(65)..[0] = 0x04;
    expect(
      () => SobreSellado.sellar(base64Encode(fuera), texto),
      throwsA(anything),
      reason: 'un punto fuera de la curva no debe servir como destino',
    );
  }, tags: ['hallazgo']);

  test('el cifrado con el PIN: 2,000 mensajes con la misma llave, nonces distintos', () {
    final llave = LlavePin.derivar('284651', iteraciones: 10);
    final nonces = <String>{};
    for (var i = 0; i < 2000; i++) {
      nonces.add(_partes(CifradoPin.cifrar(llave, 'x'))['nonce']! as String);
    }
    expect(nonces, hasLength(2000));
  });

  test('el cifrado con el PIN: un PIN distinto no abre, uno cercano tampoco', () {
    final sobre = CifradoPin.cifrar(LlavePin.derivar('284651', iteraciones: 10), texto);
    expect(CifradoPin.descifrar('284651', sobre)?.$2, texto);
    for (final malo in ['284650', '284652', '28465', '2846510', '']) {
      expect(CifradoPin.descifrar(malo, sobre), isNull, reason: 'PIN "$malo"');
    }
  });
}

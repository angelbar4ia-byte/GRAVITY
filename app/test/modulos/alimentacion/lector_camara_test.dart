import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/alimentacion/datos/lector_codigo.dart';
import 'package:gravity/modulos/alimentacion/datos/lector_codigo_camara.dart';
import 'package:gravity/modulos/alimentacion/estado/proveedores.dart';

LectorCodigo _con(TargetPlatform p) {
  final c = ProviderContainer(
    overrides: [plataformaLectorProvider.overrideWithValue(p)],
  );
  addTearDown(c.dispose);
  return c.read(lectorCodigoProvider);
}

void main() {
  test('Android usa la cámara; Windows no', () {
    expect(_con(TargetPlatform.android), isA<LectorCodigoCamara>());
    expect(_con(TargetPlatform.windows), isA<LectorCodigoSinCamara>());
  });

  test('la cámara sin contexto devuelve null y no abre nada', () async {
    expect(await LectorCodigoCamara(() => null).leer(), isNull);
  });

  test('el lector falso devuelve el código', () async {
    final f = LectorCodigoFalso('7501');
    expect(await f.leer(), '7501');
    expect(f.lecturas, 1);
    expect(await const LectorCodigoSinCamara().leer(), isNull);
  });
}

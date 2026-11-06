import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/firebase/firebase.dart';

void main() {
  test('fuera de Android no se inicializa', () async {
    var llamadas = 0;
    for (final plataforma in [TargetPlatform.windows, TargetPlatform.linux]) {
      final estado = await prepararFirebase(
        plataforma: plataforma,
        inicializar: () async => llamadas++,
      );
      expect(estado, EstadoFirebase.noAplica);
    }
    expect(llamadas, 0);
  });

  test('en Android con configuración queda activo', () async {
    final estado = await prepararFirebase(
      plataforma: TargetPlatform.android,
      inicializar: () async {},
    );
    expect(estado, EstadoFirebase.activo);
  });

  test('en Android sin google-services.json no falla', () async {
    final estado = await prepararFirebase(
      plataforma: TargetPlatform.android,
      inicializar: () async =>
          throw Exception('Failed to load FirebaseOptions from resource'),
    );
    expect(estado, EstadoFirebase.sinConfiguracion);
  });
}

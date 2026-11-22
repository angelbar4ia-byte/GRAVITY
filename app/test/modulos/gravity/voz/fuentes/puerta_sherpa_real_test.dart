// Prueba con la biblioteca nativa REAL de `sherpa_onnx` (puerta de la fuente B).
//
// No corre sola: necesita un modelo de verdad (63 MB) que no está en el
// repositorio. Para correrla (en una carpeta con los archivos descargados):
//
//   LD_LIBRARY_PATH=~/.pub-cache/hosted/pub.dev/sherpa_onnx_linux-2.0.1/linux/x64 \
//   GRAVITY_VOZ_MODELO_DIR=/ruta/a/vits-piper-en_US-kristin-medium \
//   GRAVITY_VOZ_LEXICON=/ruta/a/lexicon-en-us.txt \
//   flutter test test/modulos/gravity/voz/fuentes/puerta_sherpa_real_test.dart
//
// (`flutter test` no resuelve la biblioteca nativa por su cuenta: en Linux hay
// que darle `LD_LIBRARY_PATH`; en Windows, la carpeta de la DLL en el `PATH`.
// Dentro de la app compilada la empaqueta el propio plugin.)
//
// La carpeta del modelo trae `en_US-kristin-medium.onnx` y `tokens.txt`.
// Solo comprueba lo que se puede comprobar en la laptop de desarrollo (Linux o
// Windows): que el `Isolate` arranca, que carga el modelo sin `espeak-ng`
// (spec 4.2.5), que sintetiza audio de verdad y que los fallos dicen códigos
// y no rutas ni texto (R6). NO prueba Android.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/modelo/puerta_sherpa.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/modelo/puerta_sintesis.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';

void main() {
  final carpeta = Platform.environment['GRAVITY_VOZ_MODELO_DIR'];
  final lexicon = Platform.environment['GRAVITY_VOZ_LEXICON'];
  final hay = carpeta != null && lexicon != null;
  final razon = hay
      ? null
      : 'Define GRAVITY_VOZ_MODELO_DIR y GRAVITY_VOZ_LEXICON para correrla '
            '(ver el encabezado del archivo)';

  test(
    'carga el modelo, sintetiza y descarga, en un Isolate',
    () async {
      final puerta = PuertaSintesisSherpa();
      addTearDown(puerta.cerrar);
      final carga = CargaDeModelo(
        idModelo: 'kristin',
        rutaModelo: '$carpeta/en_US-kristin-medium.onnx',
        rutaTokens: '$carpeta/tokens.txt',
        rutaLexicon: lexicon!,
      );
      await puerta.cargar(carga);
      final audio = await puerta.sintetizar(
        idModelo: 'kristin',
        sid: 0,
        texto: 'Hello, this is a test.',
        velocidad: 1.0,
      );
      expect(audio.vacio, isFalse);
      expect(audio.frecuencia, 22050);
      final lento = await puerta.sintetizar(
        idModelo: 'kristin',
        sid: 0,
        texto: 'Hello, this is a test.',
        velocidad: 0.8,
      );
      // A 0.8 el audio dura más.
      expect(lento.muestras.length, greaterThan(audio.muestras.length));
      await puerta.descargar('kristin');
      await expectLater(
        puerta.sintetizar(
          idModelo: 'kristin',
          sid: 0,
          texto: 'x',
          velocidad: 1.0,
        ),
        throwsA(
          isA<FalloDeSintesis>().having(
            (e) => e.codigo,
            'código',
            'modelo_no_cargado',
          ),
        ),
      );
    },
    skip: razon,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'un modelo que no existe falla con un código, sin rutas ni mensajes',
    () async {
      final puerta = PuertaSintesisSherpa();
      addTearDown(puerta.cerrar);
      try {
        await puerta.cargar(
          const CargaDeModelo(
            idModelo: 'no-existe',
            rutaModelo: '/ruta/secreta/no-existe.onnx',
            rutaTokens: '/ruta/secreta/tokens.txt',
            rutaLexicon: '/ruta/secreta/lexicon.txt',
          ),
        );
        fail('debía fallar');
      } on FalloDeSintesis catch (e) {
        expect(e.toString(), isNot(contains('secreta')));
        expect(e.codigo, anyOf('carga_fallida', 'biblioteca_no_disponible'));
      }
    },
    skip: razon,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

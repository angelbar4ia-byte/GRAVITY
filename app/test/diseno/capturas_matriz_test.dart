// Genera capturas PNG de las pantallas con el estilo Bento (y el Futurista de
// referencia) para que el dueño las revise. No compara nada: solo escribe los
// archivos y solo cuando se pide con la variable CAPTURAS_DIR.
//
//   CAPTURAS_DIR=/ruta flutter test test/diseno/capturas_matriz_test.dart
//
// Usa solo los datos de ejemplo de los bocetos; nada real.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/modulos/gravity/pantalla/hoy_telefono.dart';
import 'package:gravity/modulos/gravity/pantalla/pantalla_principal.dart';

import 'ayuda_estilos.dart';
import 'ayuda_pruebas.dart';

/// Carga las fuentes del proyecto para que las capturas muestren letras de
/// verdad (en las pruebas, Flutter dibuja bloques si no se cargan).
Future<void> _cargarFuentes() async {
  const familias = {
    'Inter': ['Regular', 'SemiBold', 'Bold'],
    'ChakraPetch': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'IBMPlexSans': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'IBMPlexMono': ['Regular', 'Medium', 'SemiBold', 'Bold'],
  };
  final iconos = File(
    '/home/user/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconos.existsSync()) {
    final cargador = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconos.readAsBytesSync())));
    await cargador.load();
  }
  for (final MapEntry(key: familia, value: pesos) in familias.entries) {
    final cargador = FontLoader(familia);
    for (final peso in pesos) {
      final bytes = File('assets/fonts/$familia/$familia-$peso.ttf')
          .readAsBytesSync();
      cargador.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await cargador.load();
  }
}

void main() {
  final carpeta = Platform.environment['CAPTURAS_DIR'];

  final pantallas = <(String, Size, double, Widget Function())>[
    (
      'hoy-telefono-360',
      const Size(360, 800),
      1,
      () => const PantallaHoyTelefono(),
    ),
    (
      'hoy-tablet-800',
      const Size(800, 1000),
      1,
      () => const PantallaHoyTelefono(),
    ),
    (
      'hoy-telefono-360-letra2',
      const Size(360, 1400),
      2,
      () => const PantallaHoyTelefono(),
    ),
    (
      'principal-laptop-1280',
      const Size(1280, 800),
      1,
      () => const PantallaPrincipalGravity(),
    ),
    (
      'apariencia-1000',
      const Size(1000, 1500),
      1,
      () => const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: SeccionApariencia(),
        ),
      ),
    ),
    (
      'gadgets-412',
      const Size(412, 3600),
      1,
      () => Scaffold(body: muestraDeGadgets()),
    ),
  ];

  setUpAll(() async {
    if (carpeta != null) await _cargarFuentes();
  });

  for (final (estilo, brillo) in [
    (estiloBento, Brightness.light),
    (estiloBento, Brightness.dark),
    (estiloFuturista, Brightness.dark),
  ]) {
    for (final (nombre, tamano, letra, crear) in pantallas) {
      if (estilo == estiloFuturista && !nombre.startsWith('hoy-telefono-360')) {
        continue;
      }
      testWidgets(
        'captura $nombre ${estilo.id} ${brillo.name}',
        skip: carpeta == null,
        (tester) async {
          fijarVentana(tester, tamano);
          if (letra != 1) fijarEscalaDeLetra(tester, letra);
          final clave = GlobalKey();
          await montarConEstilo(
            tester,
            RepaintBoundary(key: clave, child: crear()),
            estilo: estilo,
            brillo: brillo,
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.runAsync(() async {
            final caja =
                clave.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final imagen = await caja.toImage();
            final datos = await imagen.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final archivo = File(
              '$carpeta/${estilo.id}-${brillo.name}-$nombre.png',
            );
            archivo.parent.createSync(recursive: true);
            archivo.writeAsBytesSync(datos!.buffer.asUint8List());
          });
        },
      );
    }
  }
}

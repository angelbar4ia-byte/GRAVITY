// Genera capturas PNG de las maquetas B1 a B11 de «Bicicleta» para revisarlas
// a ojo. No compara nada: solo escribe archivos y solo cuando se pide con la
// variable CAPTURAS_DIR.
//
//   CAPTURAS_DIR=/ruta flutter test test/diseno/bici/capturas_bici_test.dart
//
// Usa solo los datos de ejemplo de las maquetas; nada real.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_estilos.dart';
import '../ayuda_pruebas.dart';
import 'ayuda_bici.dart';

Future<void> _cargarFuentes() async {
  const familias = {
    'ChakraPetch': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'IBMPlexSans': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'IBMPlexMono': ['Regular', 'Medium', 'SemiBold', 'Bold'],
  };
  final raiz = Platform.environment['FLUTTER_ROOT'];
  final iconos = File(
    '$raiz/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (raiz != null && iconos.existsSync()) {
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

  setUpAll(() async {
    if (carpeta != null) await _cargarFuentes();
  });

  final casos = <(String, Estilo, Brightness, double, Size)>[
    for (final p in PantallaMaquetaBici.values)
      (p.name, estiloFuturista, Brightness.dark, 1, const Size(360, 2600)),
    ('b1Hoy', estiloFuturista, Brightness.light, 1, const Size(360, 2600)),
    ('b2Planear', estiloGlass, Brightness.light, 1, const Size(420, 2600)),
    ('b7MiBici', estiloBento, Brightness.dark, 1, const Size(420, 2000)),
    (
      'b1Hoy-letra2',
      estiloFuturista,
      Brightness.dark,
      2,
      const Size(360, 4200),
    ),
    (
      'b4Registro-letra2',
      estiloFuturista,
      Brightness.dark,
      2,
      const Size(360, 5200),
    ),
    (
      'b5Historial-laptop',
      estiloFuturista,
      Brightness.dark,
      1,
      const Size(900, 1500),
    ),
  ];

  for (final (nombre, estilo, brillo, letra, tamano) in casos) {
    testWidgets(
      'captura $nombre ${estilo.id} ${brillo.name}',
      skip: carpeta == null,
      (tester) async {
        fijarVentana(tester, tamano);
        if (letra != 1) fijarEscalaDeLetra(tester, letra);
        final pantalla = PantallaMaquetaBici.values.firstWhere(
          (p) => nombre.startsWith(p.name),
        );
        final reloj = RelojBici();
        final clave = GlobalKey();
        await montarConEstilo(
          tester,
          RepaintBoundary(
            key: clave,
            child: Scaffold(
              body: MaquetaBici(pantalla: pantalla, ahora: reloj.ahora),
            ),
          ),
          estilo: estilo,
          brillo: brillo,
          densidad: tamano.width >= 800 ? Densidad.compacta : Densidad.comoda,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(() async {
          final caja =
              clave.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final imagen = await caja.toImage();
          final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
          final archivo = File(
            '$carpeta/$nombre-${estilo.id}-${brillo.name}.png',
          );
          archivo.parent.createSync(recursive: true);
          archivo.writeAsBytesSync(datos!.buffer.asUint8List());
        });
        await desmontar(tester);
      },
    );
  }
}

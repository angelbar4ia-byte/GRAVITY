import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_estilos.dart';
import 'ayuda_pruebas.dart';

/// Matriz de la Fase 4 (criterios 24, 42 y 43): cada estilo incluido, de día y
/// de noche, sin desbordes con letra al doble a 360 dp y a 900 dp, y con las
/// guías de accesibilidad de Flutter (zona táctil de 48 dp, etiquetas y
/// contraste del texto).
void main() {
  final pantallas = <(String, Widget Function())>[
    ('gadgets', () => Scaffold(body: muestraDeGadgets())),
    (
      'apariencia',
      () => const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: SeccionApariencia(),
        ),
      ),
    ),
  ];

  for (final estilo in estilosIncluidos) {
    for (final brillo in Brightness.values) {
      final nombre = '${estilo.id} ${brillo.name}';
      for (final (tamano, etiqueta) in const [
        (Size(360, 800), '360 dp'),
        (Size(900, 900), '900 dp'),
      ]) {
        for (final (pantalla, crear) in pantallas) {
          testWidgets('$nombre · $pantalla · letra 2.0 en $etiqueta sin '
              'desbordes', (tester) async {
            fijarVentana(tester, tamano);
            fijarEscalaDeLetra(tester, 2.0);
            final desbordes = await recolectarDesbordes(() async {
              await montarConEstilo(
                tester,
                crear(),
                estilo: estilo,
                brillo: brillo,
              );
              await tester.pump(const Duration(milliseconds: 300));
            });
            expect(desbordes, isEmpty);
            expect(tester.takeException(), isNull);
          });
        }
      }

      for (final (pantalla, crear) in pantallas) {
        testWidgets('$nombre · $pantalla · guías de accesibilidad', (
          tester,
        ) async {
          fijarVentana(tester, const Size(412, 3200));
          final handle = tester.ensureSemantics();
          await montarConEstilo(
            tester,
            crear(),
            estilo: estilo,
            brillo: brillo,
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }

      testWidgets('$nombre · alto contraste global sin desbordes y legible', (
        tester,
      ) async {
        fijarVentana(tester, const Size(412, 3200));
        fijarEscalaDeLetra(tester, 1.5);
        final handle = tester.ensureSemantics();
        await montarConEstilo(
          tester,
          Scaffold(body: muestraDeGadgets()),
          estilo: estilo,
          brillo: brillo,
          altoContraste: true,
        );
        final v = ValoresDiseno.de(tester.element(find.byType(TarjetaModulo).first));
        expect(v.altoContraste, isTrue);
        expect(razonContraste(v.texto, v.panel), greaterThanOrEqualTo(7));
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }
}

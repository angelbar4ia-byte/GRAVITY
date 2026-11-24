// Matriz de «Bicicleta» (CA-B-30): las once maquetas B1 a B11 en cada estilo
// del sistema (Futurista, Glass y Bento en pausa), de día y de noche, sin
// desbordes con letra al doble en 360 dp (teléfono) y en 900 dp (laptop), y
// con las guías de accesibilidad de Flutter: zona táctil de 48 dp, etiquetas
// y contraste del texto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_estilos.dart';
import '../ayuda_pruebas.dart';
import 'ayuda_bici.dart';

Future<void> _montarMaqueta(
  WidgetTester tester,
  PantallaMaquetaBici pantalla, {
  required Estilo estilo,
  required Brightness brillo,
  bool altoContraste = false,
  Densidad? densidad,
  RelojBici? reloj,
}) async {
  final r = reloj ?? RelojBici();
  await montarConEstilo(
    tester,
    Scaffold(
      body: MaquetaBici(pantalla: pantalla, ahora: r.ahora),
    ),
    estilo: estilo,
    brillo: brillo,
    altoContraste: altoContraste,
    densidad: densidad,
  );
}

void main() {
  test('hay una maqueta por cada pantalla B1 a B11', () {
    expect(PantallaMaquetaBici.values, hasLength(11));
    expect(PantallaMaquetaBici.values.map((p) => p.titulo.split(' ').first), [
      'B1',
      'B2',
      'B3',
      'B4',
      'B5',
      'B6',
      'B7',
      'B8',
      'B9',
      'B10',
      'B11',
    ]);
    // Solo la tarjeta de Hoy, el cronómetro y el visor van en Sport (6).
    expect(PantallaMaquetaBici.values.where((p) => p.sport), [
      PantallaMaquetaBici.b1Hoy,
      PantallaMaquetaBici.b4Registro,
      PantallaMaquetaBici.b10EnVivo,
    ]);
    // B10 y B11 son V2 y las demás no.
    expect(PantallaMaquetaBici.values.where((p) => p.v2), [
      PantallaMaquetaBici.b10EnVivo,
      PantallaMaquetaBici.b11Resumen,
    ]);
  });

  test('hay tres estilos del catálogo real: Futurista, Glass y Bento', () {
    expect(todosLosEstilos.map((e) => e.id).toSet(), hasLength(3));
  });

  for (final estilo in todosLosEstilos) {
    for (final brillo in Brightness.values) {
      for (final pantalla in PantallaMaquetaBici.values) {
        final nombre = '${estilo.id} ${brillo.name} · ${pantalla.titulo}';
        for (final (tamano, etiqueta) in const [
          (Size(360, 800), '360 dp'),
          (Size(900, 900), '900 dp'),
        ]) {
          testWidgets('$nombre · letra 2.0 en $etiqueta sin desbordes', (
            tester,
          ) async {
            fijarVentana(tester, tamano);
            fijarEscalaDeLetra(tester, 2.0);
            final desbordes = await recolectarDesbordes(() async {
              await _montarMaqueta(
                tester,
                pantalla,
                estilo: estilo,
                brillo: brillo,
                densidad: tamano.width >= 900
                    ? Densidad.compacta
                    : Densidad.comoda,
              );
              await tester.pump(const Duration(milliseconds: 300));
            });
            expect(desbordes, isEmpty);
            expect(tester.takeException(), isNull);
            await desmontar(tester);
          });
        }

        testWidgets('$nombre · guías de accesibilidad', (tester) async {
          fijarVentana(tester, const Size(412, 6000));
          final handle = tester.ensureSemantics();
          await _montarMaqueta(
            tester,
            pantalla,
            estilo: estilo,
            brillo: brillo,
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
          await desmontar(tester);
        });
      }

      testWidgets('${estilo.id} ${brillo.name} · alto contraste global, letra '
          '1.5, sin desbordes y legible', (tester) async {
        fijarVentana(tester, const Size(412, 6000));
        fijarEscalaDeLetra(tester, 1.5);
        final handle = tester.ensureSemantics();
        final desbordes = await recolectarDesbordes(() async {
          await _montarMaqueta(
            tester,
            PantallaMaquetaBici.b7MiBici,
            estilo: estilo,
            brillo: brillo,
            altoContraste: true,
          );
        });
        expect(desbordes, isEmpty);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
        await desmontar(tester);
      });
    }
  }
}

// Matriz de «Mi gimnasio» (CA-G-41): las diez maquetas E1 a E10 en cada estilo
// del sistema, de día y de noche, sin desbordes con letra al doble en 360 dp
// (teléfono) y en 900 dp (laptop), y con las guías de accesibilidad de
// Flutter: zona táctil de 48 dp, etiquetas y contraste del texto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_estilos.dart';
import '../ayuda_pruebas.dart';
import 'ayuda_gimnasio.dart';

Future<void> _montarMaqueta(
  WidgetTester tester,
  PantallaMaqueta pantalla, {
  required Estilo estilo,
  required Brightness brillo,
  bool altoContraste = false,
  Densidad? densidad,
  RelojGimnasio? reloj,
}) async {
  final r = reloj ?? RelojGimnasio();
  await montarConEstilo(
    tester,
    Scaffold(
      body: MaquetaGimnasio(pantalla: pantalla, ahora: r.ahora),
    ),
    estilo: estilo,
    brillo: brillo,
    altoContraste: altoContraste,
    densidad: densidad,
  );
}

void main() {
  test('hay una maqueta por cada pantalla E1 a E10', () {
    expect(PantallaMaqueta.values, hasLength(10));
    expect(PantallaMaqueta.values.map((p) => p.titulo.split(' ').first), [
      'E1',
      'E2',
      'E3',
      'E4',
      'E5',
      'E6',
      'E7',
      'E8',
      'E9',
      'E10',
    ]);
    // Solo la sesión en curso y el registro rápido van en Sport (7).
    expect(PantallaMaqueta.values.where((p) => p.sport), [
      PantallaMaqueta.e5SesionEnCurso,
      PantallaMaqueta.e6RegistroRapido,
    ]);
  });

  for (final estilo in todosLosEstilos) {
    for (final brillo in Brightness.values) {
      for (final pantalla in PantallaMaqueta.values) {
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
          fijarVentana(tester, const Size(412, 3600));
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
        fijarVentana(tester, const Size(412, 3600));
        fijarEscalaDeLetra(tester, 1.5);
        final handle = tester.ensureSemantics();
        final desbordes = await recolectarDesbordes(() async {
          await _montarMaqueta(
            tester,
            PantallaMaqueta.e2Inventario,
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

// M8 y "tamaño mínimo sin cortes" (revisión de la Fase 1): "Hoy" del teléfono
// con la letra al 200 % en 360 dp y la pantalla principal desde 900 dp, con
// datos de ejemplo y sin datos, de día y de noche, sin un solo desborde.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/pantalla/hoy_telefono.dart';
import 'package:gravity/modulos/gravity/pantalla/pantalla_principal.dart';
import 'package:gravity/modulos/gravity/pantalla/resumen_gravity.dart';

import '../../../diseno/ayuda_pruebas.dart';

void main() {
  group('"Hoy" del teléfono (360 dp)', () {
    for (final escala in [1.0, 1.3, 1.5, 2.0]) {
      for (final (nombre, datos) in [
        ('con datos de ejemplo', ResumenGravity.ejemplo),
        ('sin datos', ResumenGravity.sinDatosTodavia),
      ]) {
        for (final (momento, hora) in [
          (momentoNoche, 'de noche'),
          (momentoDia, 'de día'),
        ]) {
          testWidgets('letra x$escala $nombre $hora', (tester) async {
            // Pantalla alta: la lista construye todas las tarjetas.
            fijarVentana(tester, const Size(360, 3000));
            fijarEscalaDeLetra(tester, escala);
            final desbordes = await recolectarDesbordes(() async {
              await montar(
                tester,
                const PantallaHoyTelefono(),
                datos: datos,
                momento: momento,
              );
              await tester.pump(const Duration(seconds: 1));
            });
            expect(desbordes, isEmpty);
          });
        }
      }
    }

    testWidgets('un hábito de nombre larguísimo se recorta, no desborda', (
      tester,
    ) async {
      fijarVentana(tester, const Size(360, 3000));
      fijarEscalaDeLetra(tester, 2);
      final desbordes = await recolectarDesbordes(() async {
        await montar(
          tester,
          const PantallaHoyTelefono(),
          datos: const ResumenGravity(
            habitos: [
              HabitoDeHoy(
                'Leer un capítulo completo del libro del mes con notas',
                hecho: true,
              ),
              HabitoDeHoy('Caminar'),
            ],
          ),
        );
        await tester.pump(const Duration(seconds: 1));
      });
      expect(desbordes, isEmpty);
    });
  });

  group('pantalla principal (laptop)', () {
    for (final ancho in [900.0, 1000.0, 1100.0, 1440.0]) {
      for (final escala in [1.0, 1.5, 2.0]) {
        for (final (nombre, datos) in [
          ('con datos de ejemplo', ResumenGravity.ejemplo),
          ('sin datos', ResumenGravity.sinDatosTodavia),
        ]) {
          testWidgets('$ancho dp, letra x$escala $nombre', (tester) async {
            fijarVentana(tester, Size(ancho, 800));
            fijarEscalaDeLetra(tester, escala);
            final desbordes = await recolectarDesbordes(() async {
              await montar(
                tester,
                const PantallaPrincipalGravity(),
                datos: datos,
              );
              await tester.pump(const Duration(seconds: 1));
            });
            expect(desbordes, isEmpty, reason: desbordes.join('\n'));
          });
        }
      }
    }
  });
}

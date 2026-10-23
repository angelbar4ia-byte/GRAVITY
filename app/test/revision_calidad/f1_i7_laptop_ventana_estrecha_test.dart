// I7 y M7 (revisión de calidad, Fase 1): pantallas de Finanzas de la laptop que
// se desbordan.
//
// - I7: el asistente de arranque (Resumen: remanente · techo) se desborda en
//   ventanas de hasta unos 1100 dp con la letra normal: una laptop de 1366 px
//   con la pantalla al 125 % (muy común) mide 1093 dp.
// - M7: con la letra al 150 % varias secciones (Semana, Ingresos, Categorías,
//   Compromisos, Ajustes y el propio asistente) se desbordan.
//
// Estado: I7 y M7 resueltos (sin etiqueta). Las secciones de Finanzas caben a
// 1100 dp con letra 1.5 (finanzas) y la pantalla principal de GRAVITY que la
// prueba arma antes de ir a Finanzas apila sus paneles cuando la letra es
// grande (diseno, pantalla_principal.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';

import 'ayuda_calidad.dart';

Future<Map<String, List<String>>> _desbordesPorSeccion(
  WidgetTester tester,
) async {
  final resultado = <String, List<String>>{};
  for (final seccion in SeccionFinanzas.values) {
    final errores = await recolectar(() => irA(tester, seccion.ruta));
    if (errores.desbordes.isNotEmpty) {
      resultado[seccion.ruta] = errores.desbordes;
    }
  }
  return resultado;
}

void main() {
  testWidgets('control: 1440 dp y letra normal, todas las secciones caben', (
    tester,
  ) async {
    await montarFinanzasConTamano(
      tester,
      dispositivo: TipoDispositivo.laptop,
      tamano: const Size(1440, 900),
    );
    expect(await _desbordesPorSeccion(tester), isEmpty);
  });

  testWidgets(
    'I7: el asistente de arranque cabe en una ventana de 1100 dp (letra normal)',
    (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1100, 900),
      );
      final errores = await recolectar(
        () => irA(tester, SeccionFinanzas.arranque.ruta),
      );
      expect(
        errores.desbordes,
        isEmpty,
        reason:
            'La línea "Remanente 20.58 % (meta 20 %) · techo \$…" es un Row '
            'sin Flexible (laptop/arranque.dart, Resumen)',
      );
    },
  );

  testWidgets(
    'M7: con la letra al 150 % ninguna sección de la laptop se desborda '
    '(1100 dp)',
    (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1100, 900),
        escalaDeLetra: 1.5,
      );
      expect(
        await _desbordesPorSeccion(tester),
        isEmpty,
        reason:
            'Secciones con desborde: Semana (laptop/semana.dart, _Dato), '
            'Ingresos (ingresos.dart), encabezado de Categorías, Compromisos, '
            'Asistente y Ajustes (marco_laptop.dart)',
      );
    },
  );
}

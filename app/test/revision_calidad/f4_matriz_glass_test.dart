// REVISIÓN DE CALIDAD · FASE 4 (docs/revisiones/fase-4.md) · accesibilidad con
// Glass en las pantallas REALES.
//
// La matriz de `test/diseno/matriz_estilos_test.dart` monta la muestra de
// gadgets y la sección Apariencia, no las pantallas de la sección 6 de la spec
// (criterios 24, 42 y 43). Esta prueba monta la app completa con el estilo Glass
// (noche y día) y recorre Hoy, Finanzas, Hábitos, Alimentación y Ajustes con
// letra al doble a 360 dp (teléfono) y a 900 dp (laptop): sin desbordes.
//
// Rutas de pantalla completa. No usa datos reales: hogar de ejemplo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';

import 'ayuda_calidad.dart';

const _rutas = <String>[
  '/',
  '/finanzas',
  '/finanzas/semana',
  '/habitos',
  '/habitos/objetivos',
  '/alimentacion',
  '/alimentacion/compras',
  '/ajustes',
  '/ajustes/apariencia',
  '/ajustes/personas',
  '/ajustes/notificaciones',
];

/// F4-X1: con letra 2.0 a 360 dp, Ajustes › Privacidad desborda (ver abajo).
const _rutaConHallazgo = '/ajustes/privacidad';

Future<List<String>> _desbordesDe(WidgetTester tester, String ruta) async {
  final r = await recolectar(() async {
    await irA(tester, ruta);
    await avanzar(tester);
  });
  return r.desbordes;
}

void main() {
  for (final (estilo, brillo) in [
    (estiloGlass, Brightness.dark),
    (estiloGlass, Brightness.light),
    (estiloFuturista, Brightness.dark),
  ]) {
    // F4-X1 (MENOR): Ajustes › Privacidad, "Ocultar los montos tras": el
    // `DropdownButton` va como `trailing` de un `ListTile` y con letra al doble
    // a 360 dp ocupa todo el ancho (pantalla_privacidad.dart, _MontosOcultos).
    // Pasa igual con el Futurista: no depende de Glass.
    testWidgets(
      'F4-X1: ${estilo.id} ${brillo.name} · Privacidad con letra 2.0 a 360 dp',
      (tester) async {
        await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.telefono,
          tamano: const Size(360, 800),
          escalaDeLetra: 2.0,
        );
        final c = ProviderScope.containerOf(
          tester.element(find.byType(AppGravity)),
        );
        c.read(estiloProvider.notifier).elegir(estilo);
        c
            .read(preferenciaClaroOscuroProvider.notifier)
            .cambiarModo(
              brillo == Brightness.dark
                  ? ModoClaroOscuro.oscuro
                  : ModoClaroOscuro.claro,
            );
        await avanzar(tester);
        expect(await _desbordesDe(tester, _rutaConHallazgo), isEmpty);
      },
    );
  }

  for (final (dispositivo, tamano, etiqueta) in const [
    (TipoDispositivo.telefono, Size(360, 800), '360 dp'),
    (TipoDispositivo.laptop, Size(900, 900), '900 dp'),
  ]) {
    for (final brillo in Brightness.values) {
      testWidgets(
        'Glass ${brillo.name} · letra 2.0 en $etiqueta · pantallas reales sin '
        'desbordes',
        (tester) async {
          await montarFinanzasConTamano(
            tester,
            dispositivo: dispositivo,
            tamano: tamano,
            escalaDeLetra: 2.0,
          );
          final c = ProviderScope.containerOf(
            tester.element(find.byType(AppGravity)),
          );
          c.read(estiloProvider.notifier).elegir(estiloGlass);
          c
              .read(preferenciaClaroOscuroProvider.notifier)
              .cambiarModo(
                brillo == Brightness.dark
                    ? ModoClaroOscuro.oscuro
                    : ModoClaroOscuro.claro,
              );
          await avanzar(tester);

          final desbordesPorRuta = <String, List<String>>{};
          for (final ruta in _rutas) {
            final recolector = await recolectar(() async {
              await irA(tester, ruta);
              await avanzar(tester);
            });
            if (recolector.desbordes.isNotEmpty) {
              desbordesPorRuta[ruta] = recolector.desbordes;
            }
          }
          expect(desbordesPorRuta, isEmpty);
        },
      );
    }
  }

  // Guías de accesibilidad de Flutter con Glass en las pantallas reales
  // (teléfono): zona táctil de 48 dp, etiquetas y contraste del texto.
  for (final brillo in Brightness.values) {
    for (final guia in const ['tap', 'etiqueta', 'contraste']) {
      testWidgets('Glass ${brillo.name} · guía $guia en pantallas reales', (
        tester,
      ) async {
        await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.telefono,
          tamano: const Size(412, 900),
        );
        final handle = tester.ensureSemantics();
        final c = ProviderScope.containerOf(
          tester.element(find.byType(AppGravity)),
        );
        c.read(estiloProvider.notifier).elegir(estiloGlass);
        c
            .read(preferenciaClaroOscuroProvider.notifier)
            .cambiarModo(
              brillo == Brightness.dark
                  ? ModoClaroOscuro.oscuro
                  : ModoClaroOscuro.claro,
            );
        await avanzar(tester);
        final fallas = <String>[];
        for (final ruta in _rutas) {
          await irA(tester, ruta);
          final guiaFlutter = switch (guia) {
            'tap' => androidTapTargetGuideline,
            'etiqueta' => labeledTapTargetGuideline,
            _ => textContrastGuideline,
          };
          final r = await guiaFlutter.evaluate(tester);
          if (!r.passed) fallas.add('$ruta: ${r.reason}');
        }
        handle.dispose();
        expect(fallas, isEmpty);
      });
    }
  }
}

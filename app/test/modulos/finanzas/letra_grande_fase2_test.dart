// Letra 2.0 en 360 dp (teléfono) y letra 1.5 en 900 dp (laptop) para la
// proyección, la tarjeta "¿y si abono más?" y las vistas y formularios de la
// Fase 2 de Finanzas (Fase 4, F4-3.6). Se parece a
// `f1_i6_letra_grande_telefono_test.dart`: cero desbordes y los botones de
// acción a la vista.
import 'package:finanzas_dominio/finanzas_dominio.dart' show Semana;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart' show formatearCentavos, montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_fase2.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';

import '../../revision_calidad/ayuda_calidad.dart';

void main() {
  const telefono = Size(360, 800);
  const laptop = Size(900, 800);

  final pantallas = {
    'Deudas': SeccionFinanzas.deudas,
    'Ahorro y fondo': SeccionFinanzas.ahorro,
    'Vencimientos': SeccionFinanzas.vencimientos,
  };

  for (final e in pantallas.entries) {
    testWidgets('${e.key}: teléfono 360 dp con letra 2.0 sin desbordes', (
      tester,
    ) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: telefono,
        escalaDeLetra: 2.0,
      );
      final errores = await recolectar(() => irA(tester, e.value.ruta));
      expect(errores.desbordes, isEmpty, reason: errores.desbordes.join('\n'));
    });

    testWidgets('${e.key}: laptop 900 dp con letra 1.5 sin desbordes', (
      tester,
    ) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: laptop,
        escalaDeLetra: 1.5,
      );
      final errores = await recolectar(() => irA(tester, e.value.ruta));
      expect(errores.desbordes, isEmpty, reason: errores.desbordes.join('\n'));
    });
  }

  group('la tarjeta "¿y si abono más cada semana?" y su proyección', () {
    testWidgets('360 dp, letra 2.0: se lee, se usa y no se desborda', (
      tester,
    ) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: telefono,
        escalaDeLetra: 2.0,
      );
      final errores = await recolectar(() async {
        await irA(tester, SeccionFinanzas.deudas.ruta);
        final campo = find.byKey(const ValueKey('abono-extra-monto'));
        await tester.scrollUntilVisible(
          campo,
          200,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('deudas-lista')),
            matching: find.byType(Scrollable),
          ),
        );
        // Con el teclado del sistema abierto el campo sigue a la vista.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(campo, '500');
        await avanzar(tester);
      });
      expect(errores.desbordes, isEmpty, reason: errores.desbordes.join('\n'));
      expect(
        find.byKey(const ValueKey('abono-extra-semanas')),
        findsOneWidget,
        reason: 'la proyección aparece al escribir el extra',
      );
      expect(
        find.byKey(const ValueKey('abono-extra-monto')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('con los montos ocultos no hay cifras de dinero en la '
        'tarjeta, ni en el texto ni en la semántica', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: telefono,
        escalaDeLetra: 2.0,
      );
      await irA(tester, SeccionFinanzas.deudas.ruta);
      final tarjeta = find.byKey(const ValueKey('deudas-abono-extra'));
      await tester.scrollUntilVisible(
        tarjeta,
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('deudas-lista')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('abono-extra-monto')),
        '500',
      );
      await avanzar(tester);
      final dinero = RegExp(r'\$\s*\d');
      final textos = find.descendant(of: tarjeta, matching: find.byType(Text));
      for (final t in tester.widgetList<Text>(textos)) {
        expect(dinero.hasMatch(t.data ?? ''), isFalse, reason: t.data);
      }
      final semantica = tester.getSemantics(tarjeta);
      expect(dinero.hasMatch(semantica.label), isFalse);
    });

    testWidgets('el resultado coincide al centavo con el cálculo del dominio', (
      tester,
    ) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: laptop,
        escalaDeLetra: 1.5,
      );
      await irA(tester, SeccionFinanzas.deudas.ruta);
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byType(AppGravity)),
      );
      contenedor.read(montosVisiblesProvider.notifier).fijar(true);
      final tarjeta = find.byKey(const ValueKey('deudas-abono-extra'));
      await tester.ensureVisible(tarjeta);
      await tester.enterText(
        find.byKey(const ValueKey('abono-extra-monto')),
        '500',
      );
      await avanzar(tester);
      final c = contenedor.read(contextoFinanzasProvider).value!;
      final esperado = contenedor
          .read(servicioFase2Provider)
          .abonoExtra(c.libroId, Semana.de(c.hoy), 50000)!;
      expect(
        find.descendant(
          of: tarjeta,
          matching: find.text(formatearCentavos(esperado.interesesAhorrados)),
        ),
        findsOneWidget,
      );
    });
  });
}

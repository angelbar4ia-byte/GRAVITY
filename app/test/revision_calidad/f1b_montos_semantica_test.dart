// Revisión de calidad de la Fase 1b: con los montos ocultos (como se abre la app
// y como quedan tras unos minutos sin uso) ninguna pantalla de Finanzas ni el
// "Hoy" deja ver una cifra de dinero, ni en el texto que se dibuja ni en lo que
// lee un lector de pantalla (etiquetas, valores, pistas y descripciones).
//
// Una cifra de dinero siempre sale con `formatearCentavos` ("$1,234.50"), así
// que se busca el signo de pesos pegado a un número.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/proveedores.dart'
    show RelojFijo, montosOcultosProvider, montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

import 'ayuda_calidad.dart';

final _cifra = RegExp(r'\$\s?\d');

/// Todo lo que un lector de pantalla puede decir de lo que hay en pantalla.
List<String> _lecturas(WidgetTester tester) {
  final salida = <String>[];
  void visitar(SemanticsNode nodo) {
    final d = nodo.getSemanticsData();
    for (final texto in [d.label, d.value, d.hint, d.tooltip]) {
      if (texto.isNotEmpty) salida.add(texto);
    }
    nodo.visitChildren((hijo) {
      visitar(hijo);
      return true;
    });
  }

  final raiz =
      tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (raiz != null) visitar(raiz);
  return salida;
}

/// Todo el texto que se dibuja.
List<String> _dibujado(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.byType(Text, skipOffstage: false),
  ))
    if (t.data != null)
      t.data!
    else if (t.textSpan != null)
      t.textSpan!.toPlainText(),
  for (final r in tester.widgetList<RichText>(
    find.byType(RichText, skipOffstage: false),
  ))
    r.text.toPlainText(),
];

void _sinCifras(WidgetTester tester, String donde) {
  expect(
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
        .read(montosOcultosProvider),
    isTrue,
    reason: '$donde: la prueba parte de los montos ocultos',
  );
  final dibujado = _dibujado(tester).where(_cifra.hasMatch).toSet();
  final leido = _lecturas(tester).where(_cifra.hasMatch).toSet();
  expect(
    dibujado,
    isEmpty,
    reason: '$donde: cifras dibujadas con los montos ocultos',
  );
  expect(
    leido,
    isEmpty,
    reason: '$donde: cifras que lee el lector de pantalla',
  );
}

void main() {
  for (final (dispositivo, tamano) in [
    (TipoDispositivo.laptop, const Size(1440, 900)),
    (TipoDispositivo.telefono, const Size(412, 840)),
  ]) {
    testWidgets(
      'con los montos ocultos, ninguna pantalla de Finanzas muestra ni dice una cifra ($dispositivo)',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await montarFinanzasConTamano(
          tester,
          dispositivo: dispositivo,
          tamano: tamano,
          reloj: RelojFijo(DateTime(2026, 10, 20, 10)),
        );
        final rutas = dispositivo == TipoDispositivo.laptop
            ? [Rutas.inicio, for (final s in SeccionFinanzas.values) s.ruta]
            : [Rutas.inicio, Rutas.finanzas, SeccionFinanzas.movimientos.ruta];
        for (final ruta in rutas) {
          await irA(tester, ruta);
          _sinCifras(tester, ruta);
        }
        semantica.dispose();
      },
    );
  }

  testWidgets(
    'control: con los montos a la vista sí hay cifras (la prueba no pasa en vacío)',
    (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1440, 900),
        reloj: RelojFijo(DateTime(2026, 10, 20, 10)),
      );
      await irA(tester, SeccionFinanzas.semana.ruta);
      expect(_dibujado(tester).where(_cifra.hasMatch), isEmpty);
      // Se piden a la vista como lo hace "Mostrar" (sin PIN en la prueba).
      ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
          .read(montosVisiblesProvider.notifier)
          .fijar(true);
      await avanzar(tester);
      expect(
        _dibujado(tester).where(_cifra.hasMatch),
        isNotEmpty,
        reason: 'con los montos visibles la Semana dibuja cifras: si no, la búsqueda no sirve',
      );
    },
  );
}

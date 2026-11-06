import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import '../../revision_calidad/ayuda_calidad.dart';

void main() {
  testWidgets('dbg', (tester) async {
    await montarFinanzasConTamano(tester, dispositivo: TipoDispositivo.laptop, tamano: const Size(900, 800), escalaDeLetra: 1.5);
    await irA(tester, SeccionFinanzas.deudas.ruta);
    for (final e in find.byType(Scrollable).evaluate()) {
      final w = e.widget as Scrollable;
      // ignore: avoid_print
      print('${e.size} ${w.axisDirection} ${w.physics}');
    }
    for (final e in find.byType(Text).evaluate().take(30)) {
      // ignore: avoid_print
      print((e.widget as Text).data);
    }
  });
}

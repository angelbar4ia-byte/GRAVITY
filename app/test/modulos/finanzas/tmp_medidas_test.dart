import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import '../../revision_calidad/ayuda_calidad.dart';

void main() {
  for (final (tam, esc) in [
    (const Size(360, 800), 1.0),
    (const Size(411, 850), 1.0),
    (const Size(360, 800), 1.5),
  ]) {
    testWidgets('medidas $tam $esc', (tester) async {
      await montarFinanzasConTamano(tester, dispositivo: TipoDispositivo.telefono, tamano: tam, escalaDeLetra: esc);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      Rect r(Finder f) => tester.getRect(f.first);
      final guardar = find.byKey(const ValueKey('gasto-guardar'));
      final cat = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('gasto-categoria-'));
      final cuenta = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('gasto-cuenta-'));
      debugPrint('== $tam x$esc cat=${cat.evaluate().isEmpty ? null : r(cat)} cuenta=${cuenta.evaluate().isEmpty ? null : r(cuenta)} guardar=${r(guardar)}');
    });
  }
}

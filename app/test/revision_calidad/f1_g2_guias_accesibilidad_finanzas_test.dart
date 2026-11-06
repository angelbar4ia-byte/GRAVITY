// Guardia de la revisión de calidad de la Fase 1: las guías de accesibilidad
// de Flutter (zona táctil de 48 dp, botones con etiqueta para el lector de
// pantalla y contraste del texto) sobre todas las pantallas de Finanzas, en el
// teléfono y la laptop, de día y de noche, y sobre las dos hojas del (+).
// Hoy PASAN; no cubren la letra grande (ver f1_i6 y f1_i7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo;
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

import 'ayuda_calidad.dart';

Future<void> _guias(WidgetTester tester, String donde) async {
  for (final (nombre, guia) in [
    ('zona táctil de 48 dp', androidTapTargetGuideline),
    ('botones con etiqueta', labeledTapTargetGuideline),
    ('contraste del texto', textContrastGuideline),
  ]) {
    await expectLater(tester, meetsGuideline(guia), reason: '$donde: $nombre');
  }
}

void main() {
  for (final hora in [10, 22]) {
    for (final dispositivo in [
      TipoDispositivo.telefono,
      TipoDispositivo.laptop,
    ]) {
      testWidgets('pantallas de Finanzas en $dispositivo a las $hora h', (
        tester,
      ) async {
        final semantica = tester.ensureSemantics();
        await montarFinanzasConTamano(
          tester,
          dispositivo: dispositivo,
          tamano: dispositivo == TipoDispositivo.laptop
              ? const Size(1440, 900)
              : const Size(412, 840),
          reloj: RelojFijo(DateTime(2026, 10, 20, hora)),
        );
        final rutas = dispositivo == TipoDispositivo.laptop
            ? [for (final s in SeccionFinanzas.values) s.ruta]
            : [Rutas.finanzas, SeccionFinanzas.movimientos.ruta];
        for (final ruta in rutas) {
          await irA(tester, ruta);
          await _guias(tester, ruta);
        }
        semantica.dispose();
      });
    }
  }

  testWidgets('las hojas (+) Gasto e Ingreso extra del teléfono', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await montarFinanzasConTamano(
      tester,
      dispositivo: TipoDispositivo.telefono,
      tamano: const Size(412, 840),
    );
    for (final opcion in ['Gasto', 'Ingreso extra']) {
      await abrirRegistroDelTelefono(tester, opcion);
      await _guias(tester, '(+) $opcion');
      // Cancelar queda bajo el borde de la pantalla (ver f1_i8): se desplaza.
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Cancelar'));
      await avanzar(tester);
    }
    semantica.dispose();
  });
}

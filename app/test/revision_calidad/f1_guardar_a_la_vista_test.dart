// F1 (revisión de calidad, Fase 1): en (+) Gasto el botón Guardar no se ve sin
// desplazar la hoja en los teléfonos habituales.
//
// El flujo F1 (DISENO_UX_UI sección 14, criterio 28) es "teclado → categoría →
// cuenta → Guardar" en menos de 10 s. La hoja arma el teclado numérico, el
// monto, las categorías, las cuentas, la fecha y la nota antes del botón, que
// queda más abajo del borde de la pantalla (p. ej. a 971 dp en una pantalla de
// 850 dp): hay que arrastrar la hoja para alcanzarlo. La prueba del repositorio
// lo oculta con `ensureVisible`. (+) Ingreso extra solo lo deja a la vista en
// pantallas de 850 dp o más.
//
// FALLA HOY A PROPÓSITO (etiqueta `hallazgo`).
@Tags(['hallazgo'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';

import 'ayuda_calidad.dart';

void main() {
  for (final (nombre, llave) in [
    ('Gasto', 'gasto-guardar'),
    ('Ingreso extra', 'extra-guardar'),
  ]) {
    for (final tamano in [const Size(360, 800), const Size(411, 850)]) {
      testWidgets(
        '(+) $nombre en $tamano: Guardar se alcanza sin desplazar la hoja',
        (tester) async {
          await montarFinanzasConTamano(
            tester,
            dispositivo: TipoDispositivo.telefono,
            tamano: tamano,
          );
          await abrirRegistroDelTelefono(tester, nombre);
          final guardar = find.byKey(ValueKey(llave));
          expect(guardar, findsOneWidget, reason: 'preparación');
          expect(
            guardar.hitTestable(),
            findsOneWidget,
            reason:
                'Guardar está en y=${tester.getRect(guardar).bottom.round()} '
                'dp de una pantalla de ${tamano.height.round()} dp',
          );
        },
        tags: ['hallazgo'],
      );
    }
  }
}

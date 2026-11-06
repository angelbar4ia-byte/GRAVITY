// Guardia de la revisión de calidad de la Fase 1, criterio 36: "casilla y
// orden en Compromisos y deudas". El dominio (`grupo_prioritario_test`) estaba
// probado; la pantalla no tenía ninguna prueba. Hoy PASA.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';

import '../modulos/finanzas/ayuda_finanzas.dart';
import 'ayuda_calidad.dart';

void main() {
  testWidgets(
    'la casilla arma el grupo, Subir y Bajar lo ordenan y quitarla lo '
    'deshace',
    (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1440, 1400),
      );
      ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
          .read(libroElegidoProvider.notifier)
          .elegir(IdsDemostracion.libroCasa);
      await irA(tester, SeccionFinanzas.compromisos.ruta);

      final deudas = repo.datos.deudasDe(IdsDemostracion.libroCasa);
      expect(deudas.length, greaterThanOrEqualTo(2), reason: 'preparación');
      final a = deudas[0];
      final b = deudas[1];
      expect(
        deudas.any((d) => d.grupoPrioritario),
        isFalse,
        reason: 'preparación',
      );

      Finder casilla(String id) => find.byKey(ValueKey('deuda-grupo-$id'));

      await tester.ensureVisible(casilla(b.id));
      await tester.tap(casilla(b.id));
      await avanzar(tester);
      await tester.ensureVisible(casilla(a.id));
      await tester.tap(casilla(a.id));
      await avanzar(tester);
      var ahora = repo.datos.deudasDe(IdsDemostracion.libroCasa);
      expect(ahora.singleWhere((d) => d.id == b.id).ordenGrupo, 1);
      expect(ahora.singleWhere((d) => d.id == a.id).ordenGrupo, 2);

      // "Bajar" a la primera del grupo (b): pasa al segundo lugar. Los botones
      // están en la misma fila que su casilla.
      final bajarDeB = find.descendant(
        of: find.ancestor(of: casilla(b.id), matching: find.byType(Row)).first,
        matching: find.byTooltip('Bajar'),
      );
      await tester.ensureVisible(bajarDeB);
      await tester.tap(bajarDeB);
      await avanzar(tester);
      ahora = repo.datos.deudasDe(IdsDemostracion.libroCasa);
      expect(ahora.singleWhere((d) => d.id == b.id).ordenGrupo, 2);
      expect(ahora.singleWhere((d) => d.id == a.id).ordenGrupo, 1);

      // Quitar la casilla la saca del grupo.
      await tester.ensureVisible(casilla(a.id));
      await tester.tap(casilla(a.id));
      await avanzar(tester);
      ahora = repo.datos.deudasDe(IdsDemostracion.libroCasa);
      expect(ahora.singleWhere((d) => d.id == a.id).grupoPrioritario, isFalse);
      expect(ahora.singleWhere((d) => d.id == a.id).ordenGrupo, isNull);
    },
  );
}

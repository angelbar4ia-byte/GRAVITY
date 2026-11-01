// Revisión de calidad de la Fase 2 (docs/revisiones/fase-2.md).
//
// F2-6  Los recordatorios locales de un vencimiento programan SOLO el aviso más
//       próximo (3 días antes). El de 1 día antes no existe hasta que la app se
//       vuelva a abrir o sincronice; sin señal ni Firebase puede no llegar nunca.
//       Cerrado el 1/nov/2026: se quitó el `break` de calcularRecordatorios.
// Guardias (pasan): el texto de la notificación local nunca lleva cifras.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/pantalla_segura.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/recordatorios.dart';

void main() {
  test('F2-6: se programan los avisos de 3 y de 1 día antes del vencimiento',
      () {
    final r = calcularRecordatorios(
      preferencias: const PreferenciasAvisos(),
      ahora: DateTime(2026, 11, 1, 8),
      vencimientos: [
        Vencimiento(objetoId: 'oc-1', fecha: DateTime(2026, 11, 10)),
      ],
    ).where((x) => x.tipo == 'pago_proximo').toList();
    expect(r.length, 2, reason: 'hoy solo queda: $r');
  });

  test('guardia: ningún título del catálogo lleva cifras ni signo de dinero', () {
    for (final e in {...titulosDeAviso, 'generico': textoAvisoGenerico,
        'publico': textoAvisoPublico}.entries) {
      expect(e.value.length <= largoMaximoTituloAviso, isTrue, reason: e.key);
      expect(RegExp(r'[0-9$]').hasMatch(e.value), isFalse,
          reason: '${e.key}: ${e.value}');
    }
  });

  test('guardia: FLAG_SECURE en deudas, ahorro y vencimientos (dinero)', () {
    for (final seccion in [
      SeccionFinanzas.deudas,
      SeccionFinanzas.ahorro,
      SeccionFinanzas.vencimientos,
    ]) {
      final ruta = '/finanzas/${seccion.segmento}';
      expect(esPantallaSensible(ruta, Rol.dueno), isTrue, reason: ruta);
    }
  });
}

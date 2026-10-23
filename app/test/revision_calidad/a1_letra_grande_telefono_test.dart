// A1 (revisión de calidad, Fase 1): con la letra grande del sistema las
// pantallas del teléfono de Finanzas se desbordan. Un teléfono de 360 dp con
// "Tamaño de fuente: grande" (1.3) ya corta el botón Guardar de (+) Gasto y de
// (+) Ingreso extra y el encabezado de la semana; con la letra más grande (2.0)
// la fila de un movimiento deja el monto sin lugar.
//
// FALLAN HOY A PROPÓSITO las pruebas con la etiqueta `hallazgo` (demuestran el
// hallazgo y pasarán al arreglarlo). Los controles a letra normal pasan hoy y
// deben seguir pasando. Línea base: `flutter test --exclude-tags hallazgo`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

import 'ayuda_calidad.dart';

const _telefono360 = Size(360, 840);

void main() {
  group('control: con letra normal no hay desbordes en 360 dp', () {
    testWidgets('semana, movimientos y las dos hojas del (+)', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono360,
      );
      final errores = await recolectar(() async {
        await irA(tester, Rutas.finanzas);
        await irA(tester, SeccionFinanzas.movimientos.ruta);
        await abrirRegistroDelTelefono(tester, 'Gasto');
      });
      expect(errores.desbordes, isEmpty);
    });
  });

  group('A1: con letra grande (hallazgo)', () {
    testWidgets(
      'la semana del teléfono (360 dp, letra 1.3) no se desborda',
      (tester) async {
        await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.telefono,
          tamano: _telefono360,
          escalaDeLetra: 1.3,
        );
        final errores = await recolectar(() => irA(tester, Rutas.finanzas));
        expect(
          errores.desbordes,
          isEmpty,
          reason:
              'El encabezado de la tarjeta de la semana (título + semáforo '
              '"Remanente …") no cabe: TarjetaModulo pone la acción fuera de '
              'un Flexible (tarjeta_modulo.dart)',
        );
      },
      tags: ['hallazgo'],
    );

    for (final opcion in ['Gasto', 'Ingreso extra']) {
      testWidgets(
        '(+) $opcion (360 dp, letra 1.3): Cancelar y Guardar caben',
        (tester) async {
          await montarFinanzasConTamano(
            tester,
            dispositivo: TipoDispositivo.telefono,
            tamano: _telefono360,
            escalaDeLetra: 1.3,
          );
          final errores = await recolectar(
            () => abrirRegistroDelTelefono(tester, opcion),
          );
          expect(
            errores.desbordes,
            isEmpty,
            reason:
                'La fila Cancelar · Spacer · Guardar es un Row rígido; con '
                'letra grande Guardar queda cortado (hoja_gasto.dart, '
                'hoja_ingreso_extra.dart)',
          );
        },
        tags: ['hallazgo'],
      );
    }

    testWidgets(
      'la fila de un movimiento (360 dp, letra 2.0) deja lugar al monto',
      (tester) async {
        await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.telefono,
          tamano: _telefono360,
          escalaDeLetra: 2.0,
        );
        final errores = await recolectar(
          () => irA(tester, SeccionFinanzas.movimientos.ruta),
        );
        expect(
          errores.desbordes,
          isEmpty,
          reason:
              'El trailing de FilaMovimiento (monto + menú) ocupa todo el '
              'ancho del ListTile (fila_movimiento.dart)',
        );
      },
      tags: ['hallazgo'],
    );
  });
}

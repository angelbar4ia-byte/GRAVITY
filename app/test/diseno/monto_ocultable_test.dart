import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_pruebas.dart';

void main() {
  group('formatearCentavos', () {
    test('formato de México con separador de miles', () {
      expect(formatearCentavos(123450), r'$1,234.50');
      expect(formatearCentavos(100000000), r'$1,000,000.00');
      expect(formatearCentavos(99999), r'$999.99');
    });

    test('cantidades pequeñas', () {
      expect(formatearCentavos(0), r'$0.00');
      expect(formatearCentavos(5), r'$0.05');
      expect(formatearCentavos(100), r'$1.00');
    });

    test('negativos y signo', () {
      expect(formatearCentavos(-8500), r'-$85.00');
      expect(formatearCentavos(8500, mostrarSigno: true), r'+$85.00');
      expect(formatearCentavos(0, mostrarSigno: true), r'$0.00');
    });

    test('texto del monto oculto', () {
      expect(montoOculto, r'$ • • • • •');
    });
  });

  group('MontoOcultable', () {
    testWidgets('muestra los centavos con formato', (tester) async {
      await montar(
        tester,
        const Scaffold(body: MontoOcultable(centavos: 123450)),
      );
      expect(find.text(r'$1,234.50'), findsOneWidget);
    });

    testWidgets('oculto no muestra la cifra ni al lector de pantalla', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        const Scaffold(body: MontoOcultable(centavos: 123450, oculto: true)),
      );
      expect(find.text(r'$ • • • • •'), findsOneWidget);
      expect(find.text(r'$1,234.50'), findsNothing);
      expect(find.bySemanticsLabel('Monto oculto'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'1,234')), findsNothing);
      semantica.dispose();
    });

    testWidgets('al tocar avisa y tiene zona táctil de 48', (tester) async {
      var toques = 0;
      await montar(
        tester,
        Scaffold(
          body: Center(
            child: MontoOcultable(
              centavos: 500,
              oculto: true,
              alTocar: () => toques++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(MontoOcultable));
      expect(toques, 1);
      expect(
        tester.getSize(find.byType(MontoOcultable)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('Fechas', () {
    final t = DateTime(2026, 10, 20, 19, 42);

    test('formatos cortos y largos', () {
      expect(fechaCorta(t), 'mar 20 oct');
      expect(fechaLarga(t), 'Martes 20 de octubre');
      expect(horaMinutos(t), '19:42');
      expect(horaMinutos(DateTime(2026, 1, 4, 7, 5)), '07:05');
      expect(fechaYHora(t), 'mar 20 oct · 19:42');
    });

    test('semana ISO (empieza en lunes)', () {
      expect(semanaIso(t), 43);
      expect(semanaIso(DateTime(2026, 1, 1)), 1);
      expect(semanaIso(DateTime(2026, 12, 31)), 53);
      expect(semanaIso(DateTime(2027, 1, 3)), 53);
      expect(semanaIso(DateTime(2027, 1, 4)), 1);
      expect(semanaIso(DateTime(2024, 12, 30)), 1);
      expect(semanaIso(DateTime(2026, 10, 19)), 43);
      expect(semanaIso(DateTime(2026, 10, 18)), 42);
    });
  });
}

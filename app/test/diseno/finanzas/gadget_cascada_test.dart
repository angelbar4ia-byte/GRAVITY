import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_finanzas.dart';

/// Ejemplo 5.6 bis-1 de FINANZAS: la cascada planeada.
const _planeada = [
  EscalonCascada(etiqueta: 'Ingreso', planeadoCentavos: 738462),
  EscalonCascada(etiqueta: 'Presupuesto', planeadoCentavos: 547231),
  EscalonCascada(etiqueta: 'Deuda', planeadoCentavos: 39231),
  EscalonCascada(
    etiqueta: 'Remanente → abono extra',
    planeadoCentavos: 152000,
    tono: TonoEscalon.exito,
  ),
];

/// Ejemplo 5.6 bis-2: sobregasto de $300.
const _conReal = [
  EscalonCascada(
    etiqueta: 'Ingreso',
    planeadoCentavos: 738462,
    realCentavos: 738462,
  ),
  EscalonCascada(
    etiqueta: 'Presupuesto',
    planeadoCentavos: 547231,
    realCentavos: 577231,
    tono: TonoEscalon.alerta,
  ),
  EscalonCascada(
    etiqueta: 'Deuda',
    planeadoCentavos: 39231,
    realCentavos: 39231,
  ),
  EscalonCascada(
    etiqueta: 'Remanente',
    planeadoCentavos: 152000,
    realCentavos: 122000,
    tono: TonoEscalon.alerta,
  ),
];

/// Ancho de la barra sólida (la de lo real o, sin comparar, la planeada) de
/// la fila [i], medido como fracción de su pista.
List<double> _anchosSolidos(WidgetTester tester) {
  final cajas = find.descendant(
    of: find.byType(GadgetCascada),
    matching: find.byType(FractionallySizedBox),
  );
  return tester
      .widgetList<FractionallySizedBox>(cajas)
      .map((f) => f.widthFactor ?? 0)
      .toList();
}

void main() {
  group('GadgetCascada sin real', () {
    testWidgets('un monto por escalón, barras a la misma escala', (
      tester,
    ) async {
      await montarEnFinanzas(tester, const GadgetCascada(escalones: _planeada));
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text(r'$7,384.62'), findsOneWidget);
      expect(find.text(r'$5,472.31'), findsOneWidget);
      expect(find.text(r'$392.31'), findsOneWidget);
      expect(find.text(r'$1,520.00'), findsOneWidget);
      // Sin real no hay leyenda ni "de".
      expect(find.text('Real'), findsNothing);
      expect(find.text(' de '), findsNothing);

      final anchos = _anchosSolidos(tester);
      expect(anchos, hasLength(4));
      expect(anchos[0], 1); // El ingreso es la escala.
      expect(anchos[1], closeTo(547231 / 738462, 1e-9));
      expect(anchos[3], closeTo(152000 / 738462, 1e-9));
    });

    testWidgets('el tono no depende solo del color: icono y lector', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(tester, const GadgetCascada(escalones: _planeada));
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      final v = valoresDe(tester, find.byType(GadgetCascada));
      final icono = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_outline),
      );
      expect(icono.color, v.exito);
      expect(
        find.bySemanticsLabel(r'Remanente → abono extra: $1,520.00, en verde'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(r'Ingreso: $7,384.62'), findsOneWidget);
      semantica.dispose();
    });
  });

  group('GadgetCascada con real', () {
    testWidgets('"real de planeado", leyenda y barras de lo real', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(tester, const GadgetCascada(escalones: _conReal));
      expect(find.text(r'$5,772.31'), findsOneWidget);
      expect(find.text(r'$5,472.31'), findsOneWidget);
      expect(find.text(r'$1,220.00'), findsOneWidget);
      expect(find.text(' de '), findsNWidgets(4));
      expect(find.text('Real'), findsOneWidget);
      expect(find.text('Planeado'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(
          r'Remanente: real $1,220.00 de $1,520.00 planeado, en ámbar',
        ),
        findsOneWidget,
      );
      // Tres capas por escalón: planeado, real y contorno de lo planeado.
      final anchos = _anchosSolidos(tester);
      expect(anchos, hasLength(12));
      // La escala es la cifra mayor: lo real del presupuesto no pasa del ingreso.
      expect(anchos.reduce((a, b) => a > b ? a : b), 1);
      semantica.dispose();
    });

    testWidgets('un escalón sin real dice "Plan" y no se cae', (tester) async {
      await montarEnFinanzas(
        tester,
        const GadgetCascada(
          escalones: [
            EscalonCascada(
              etiqueta: 'Ingreso',
              planeadoCentavos: 738462,
              realCentavos: 650000,
            ),
            EscalonCascada(etiqueta: 'Deuda', planeadoCentavos: 39231),
          ],
        ),
      );
      expect(find.text('Plan '), findsOneWidget);
      expect(find.text(r'$6,500.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un déficit mide por su valor absoluto y lleva su signo', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const GadgetCascada(
          escalones: [
            EscalonCascada(
              etiqueta: 'Ingreso',
              planeadoCentavos: 10000,
              realCentavos: 10000,
            ),
            EscalonCascada(
              etiqueta: 'Remanente',
              planeadoCentavos: 2000,
              realCentavos: -8769,
              tono: TonoEscalon.peligro,
            ),
          ],
        ),
      );
      expect(find.text(r'-$87.69'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('GadgetCascada privacidad y tamaños', () {
    testWidgets('montos ocultos: barras sí, pesos no', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        const GadgetCascada(escalones: _conReal, montosOcultos: true),
      );
      expect(find.textContaining(r'$7'), findsNothing);
      expect(find.textContaining(r'$1'), findsNothing);
      expect(find.text(montoOculto), findsNWidgets(8));
      expect(
        find.bySemanticsLabel(
          'Ingreso: real monto oculto de monto oculto planeado',
        ),
        findsOneWidget,
      );
      expect(_anchosSolidos(tester), hasLength(12));
      semantica.dispose();
    });

    testWidgets('sin escalones no dibuja nada; con ceros, barras vacías', (
      tester,
    ) async {
      await montarEnFinanzas(tester, const GadgetCascada(escalones: []));
      expect(find.byType(FractionallySizedBox), findsNothing);
      await montarEnFinanzas(
        tester,
        const GadgetCascada(
          escalones: [EscalonCascada(etiqueta: 'Ingreso', planeadoCentavos: 0)],
        ),
      );
      expect(_anchosSolidos(tester), [0]);
      expect(find.text(r'$0.00'), findsOneWidget);
    });

    testWidgets('de un gadget de 160 dp a la laptop, sin desbordarse', (
      tester,
    ) async {
      fijarVentanaGrande(tester);
      for (final ancho in [160.0, 240.0, 320.0, 1000.0]) {
        for (final escalones in [_planeada, _conReal]) {
          await montarEnFinanzas(
            tester,
            GadgetCascada(
              escalones: [
                ...escalones,
                const EscalonCascada(
                  etiqueta: 'Un escalón con nombre muy largo para la prueba',
                  planeadoCentavos: 99999999999,
                  realCentavos: 99999999999,
                ),
              ],
            ),
            ancho: ancho,
          );
          expect(tester.takeException(), isNull, reason: 'ancho $ancho');
        }
      }
    });

    testWidgets('toma el acento de Finanzas en los escalones neutros', (
      tester,
    ) async {
      await montarEnFinanzas(tester, const GadgetCascada(escalones: _planeada));
      final v = valoresDe(tester, find.byType(GadgetCascada));
      expect(v.acento, PersonalidadModulo.precisa.acentoNoche);
      final colores = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(GadgetCascada),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toSet();
      expect(colores, containsAll([v.acento, v.exito, v.pista]));
    });
  });
}

/// Ventana de laptop para que quepan los anchos grandes.
void fijarVentanaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

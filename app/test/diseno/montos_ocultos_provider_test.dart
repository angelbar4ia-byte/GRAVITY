// Decisión del 23/oct: los montos se ocultan solos y volver a verlos pide el
// PIN. Ningún componente de dinero dibuja una cifra mientras
// `montosOcultosProvider` diga "ocultos", aunque quien lo dibuja no lo pida; y
// la marca "Montos ocultos · Toca para ver" es accesible y pide verlos por el
// flujo de plataforma (`revelarMontosProvider`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_pruebas.dart';
import 'finanzas/ayuda_finanzas.dart';

const _escalones = [
  EscalonCascada(etiqueta: 'Ingreso', planeadoCentavos: 738462),
  EscalonCascada(etiqueta: 'Presupuesto', planeadoCentavos: 547231),
];

/// Todo el texto visible junto.
String _textos(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' · ');

void main() {
  group('los componentes de dinero leen el provider', () {
    testWidgets('GadgetCascada: sin pedirlo, las barras sí y los pesos no', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        const GadgetCascada(escalones: _escalones),
        montosVisibles: false,
      );
      expect(_textos(tester), isNot(contains(r'$')));
      expect(find.text(montoOculto), findsNWidgets(2));
      expect(find.bySemanticsLabel(RegExp(r'7,384')), findsNothing);
      expect(tester.takeException(), isNull);
      semantica.dispose();
    });

    testWidgets('GadgetCascada: a la vista salen los pesos', (tester) async {
      await montarEnFinanzas(
        tester,
        const GadgetCascada(escalones: _escalones),
      );
      expect(find.text(r'$7,384.62'), findsOneWidget);
    });

    testWidgets('MedidorPresupuesto: el porcentaje se ve, los pesos no', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(
          asignadoCentavos: 500000,
          gastadoCentavos: 310000,
        ),
        montosVisibles: false,
      );
      expect(_textos(tester), isNot(contains(r'$')));
      expect(find.textContaining('62'), findsWidgets);
      expect(find.text(montoOculto), findsWidgets);
      semantica.dispose();
    });

    testWidgets('TarjetaIndicador: oculta si es monto; el porcentaje no', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const Column(
          children: [
            TarjetaIndicador(
              etiqueta: 'Patrimonio',
              valor: r'$1,234.50',
              esMonto: true,
            ),
            TarjetaIndicador(etiqueta: 'Remanente', valor: '20.58 %'),
          ],
        ),
        montosVisibles: false,
      );
      expect(find.text(r'$1,234.50'), findsNothing);
      expect(find.text(montoOculto), findsOneWidget);
      expect(find.text('20.58 %'), findsOneWidget);
    });

    testWidgets('CeldaMonto: oculta y el rojo de un negativo no delata nada', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const CeldaMonto(-5000),
        montosVisibles: false,
      );
      expect(find.text(r'-$50.00'), findsNothing);
      final texto = tester.widget<Text>(find.text(montoOculto));
      final v = valoresDe(tester, find.byType(CeldaMonto));
      expect(texto.style?.color, isNot(v.peligro));
    });

    testWidgets('CeldaMonto: a la vista, el negativo va en rojo', (
      tester,
    ) async {
      await montarEnFinanzas(tester, const CeldaMonto(-5000));
      expect(
        tester.widget<Text>(find.text(r'-$50.00')).style?.color,
        valoresDe(tester, find.byType(CeldaMonto)).peligro,
      );
    });
  });

  group('MarcaMontosOcultos', () {
    testWidgets('no dibuja nada con los montos a la vista', (tester) async {
      await montar(
        tester,
        const Scaffold(body: MarcaMontosOcultos()),
        montosVisibles: true,
      );
      expect(find.byType(Text), findsNothing);
      expect(find.byKey(const ValueKey('marca-montos-ocultos')), findsNothing);
    });

    testWidgets('oculta: texto, icono, 48 dp y lector de pantalla', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const Scaffold(body: MarcaMontosOcultos()));
      expect(find.text('Montos ocultos · Toca para ver'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      final tamano = tester.getSize(
        find.byKey(const ValueKey('marca-montos-ocultos')),
      );
      expect(tamano.height, greaterThanOrEqualTo(zonaTactilMinima));
      expect(tamano.width, greaterThanOrEqualTo(zonaTactilMinima));
      final nodo = tester.getSemantics(find.bySemanticsLabel('Montos ocultos'));
      expect(nodo, isSemantics(isButton: true, hasTapAction: true));
      expect(nodo.hint, contains('Toca para ver'));
      expect(nodo.hint, contains('PIN'));
      final v = valoresDe(tester, find.byType(MarcaMontosOcultos));
      expect(
        razonContraste(v.textoFuerte, v.panel),
        greaterThanOrEqualTo(contrasteMinimoTexto),
      );
      semantica.dispose();
    });

    testWidgets('al tocarla pide ver los montos; sin PIN no los muestra', (
      tester,
    ) async {
      var pedidos = 0;
      await montar(
        tester,
        const Scaffold(
          body: Column(
            children: [MarcaMontosOcultos(), MontoOcultable(centavos: 12345)],
          ),
        ),
        overrides: [
          revelarMontosProvider.overrideWithValue((context) async {
            pedidos++;
            return false;
          }),
        ],
      );
      await tester.tap(find.byType(MarcaMontosOcultos));
      await tester.pump();
      expect(pedidos, 1);
      expect(find.text(montoOculto), findsOneWidget);
      expect(find.text(r'$123.45'), findsNothing);
    });

    testWidgets('por omisión (demostración y pruebas) los muestra y se va', (
      tester,
    ) async {
      await montar(
        tester,
        const Scaffold(
          body: Column(
            children: [MarcaMontosOcultos(), MontoOcultable(centavos: 12345)],
          ),
        ),
      );
      await tester.tap(find.byType(MarcaMontosOcultos));
      await tester.pump();
      expect(find.text(r'$123.45'), findsOneWidget);
      expect(find.byType(MarcaMontosOcultos), findsOneWidget);
      expect(find.text('Montos ocultos · Toca para ver'), findsNothing);
    });

    testWidgets('modo privado: lo dice y no se toca', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const Scaffold(body: MarcaMontosOcultos()));
      contenedorDe(
        tester,
        find.byType(MarcaMontosOcultos),
      ).read(modoPrivadoProvider.notifier).fijar(true);
      await tester.pump();
      expect(find.text(MarcaMontosOcultos.textoPrivado), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      final nodo = tester.getSemantics(
        find.bySemanticsLabel('Montos ocultos por el modo privado'),
      );
      expect(nodo, isSemantics(hasTapAction: false));
      semantica.dispose();
    });

    for (final escala in [1.0, 2.0]) {
      testWidgets('letra x$escala en 360 dp no desborda', (tester) async {
        fijarVentana(tester, const Size(360, 800));
        fijarEscalaDeLetra(tester, escala);
        final desbordes = await recolectarDesbordes(() async {
          await montar(
            tester,
            const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MarcaMontosOcultos(),
                ),
              ),
            ),
          );
        });
        expect(desbordes, isEmpty);
        final marca = tester.getRect(
          find.byKey(const ValueKey('marca-montos-ocultos')),
        );
        expect(marca.right, lessThanOrEqualTo(360 - 16 + 0.5));
      });
    }
  });
}

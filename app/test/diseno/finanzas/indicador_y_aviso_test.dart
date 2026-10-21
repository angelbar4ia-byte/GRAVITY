import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_finanzas.dart';

void main() {
  group('TarjetaIndicador', () {
    testWidgets('remanente 20.58 % en verde con su meta (T1)', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        TarjetaIndicador(
          etiqueta: 'Remanente',
          valor: formatearPuntosBase(2058),
          estado: EstadoSemaforo.verde,
          detalle: 'Meta 20 %',
        ),
      );
      expect(find.text('REMANENTE'), findsOneWidget);
      expect(find.text('20.58 %'), findsOneWidget);
      expect(find.text('En verde'), findsOneWidget);
      expect(find.text('Meta 20 %'), findsOneWidget);
      final v = valoresDe(tester, find.byType(TarjetaIndicador));
      expect(
        tester.widget<Text>(find.text('20.58 %')).style?.fontFamily,
        FuentesGravity.mono,
      );
      final nodo = tester.getSemantics(find.byType(TarjetaIndicador));
      expect(nodo.label, 'Remanente');
      expect(nodo.value, '20.58 %, En verde, Meta 20 %');
      expect(colorDelTexto(tester, 'En verde'), v.exito);
      semantica.dispose();
    });

    testWidgets(r'con $300 de más, 16.52 % en ámbar con texto propio (T2)', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        TarjetaIndicador(
          etiqueta: 'Remanente',
          valor: formatearPuntosBase(1652),
          estado: EstadoSemaforo.ambar,
          textoEstado: r'Alimentación +$300.00',
        ),
      );
      expect(find.text('16.52 %'), findsOneWidget);
      expect(find.text(r'Alimentación +$300.00'), findsOneWidget);
    });

    testWidgets('patrimonio oculto en modo privado', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        TarjetaIndicador(
          etiqueta: 'Patrimonio',
          valor: formatearCentavos(2068000),
          oculto: true,
        ),
      );
      expect(find.text(montoOculto), findsOneWidget);
      expect(find.textContaining('20,680'), findsNothing);
      final nodo = tester.getSemantics(find.byType(TarjetaIndicador));
      expect(nodo.value, 'oculto');
      semantica.dispose();
    });

    testWidgets('si se toca, es botón de 48 dp o más', (tester) async {
      var tocada = false;
      await montarEnFinanzas(
        tester,
        TarjetaIndicador(
          etiqueta: 'Carga de deuda',
          valor: formatearPuntosBase(531),
          alTocar: () => tocada = true,
        ),
        ancho: 200,
      );
      revisarZonasTactiles(tester, find.byType(TarjetaIndicador));
      await tester.tap(find.byType(TarjetaIndicador));
      expect(tocada, isTrue);
    });
  });

  group('mostrarAvisoDeshacer', () {
    testWidgets('"Guardado · Deshacer" y deshacer llama de vuelta', (
      tester,
    ) async {
      var deshecho = 0;
      await montarEnFinanzas(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => mostrarAvisoDeshacer(
              context,
              mensaje: 'Gasto guardado',
              alDeshacer: () => deshecho++,
            ),
            child: const Text('Guardar'),
          ),
        ),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Gasto guardado'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      expect(deshecho, 1);
    });

    testWidgets('se va solo aunque tenga acción, y no se apilan', (
      tester,
    ) async {
      var veces = 0;
      await montarEnFinanzas(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => mostrarAvisoDeshacer(
              context,
              mensaje: 'Gasto ${++veces} guardado',
              alDeshacer: () {},
              duracion: const Duration(seconds: 2),
            ),
            child: const Text('Guardar'),
          ),
        ),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Gasto 1 guardado'), findsNothing);
      expect(find.text('Gasto 2 guardado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Gasto 2 guardado'), findsNothing);
    });
  });
}

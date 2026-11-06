import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_finanzas.dart';

void main() {
  group('Semáforo con texto o icono (nunca solo color)', () {
    test('cada estado tiene icono de forma distinta', () {
      final iconos = EstadoSemaforo.values.map((e) => e.icono).toSet();
      expect(iconos, hasLength(EstadoSemaforo.values.length));
    });

    testWidgets('por defecto: punto y texto, como en la Fase 0', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const Semaforo(estado: EstadoSemaforo.verde),
      );
      expect(find.text('En verde'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('con icono: icono del estado y texto en su color', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const Semaforo(
          estado: EstadoSemaforo.ambar,
          etiqueta: 'Cerca del límite',
          conIcono: true,
        ),
      );
      final v = valoresDe(tester, find.byType(Semaforo));
      final icono = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );
      expect(icono.color, v.alerta);
      expect(colorDelTexto(tester, 'Cerca del límite'), v.alerta);
    });

    testWidgets('solo icono: el texto va al lector y al texto emergente', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        const Semaforo(
          estado: EstadoSemaforo.rojo,
          etiqueta: 'Excedido',
          soloIcono: true,
        ),
      );
      expect(find.text('Excedido'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.bySemanticsLabel('Semáforo: Excedido'), findsOneWidget);
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'Excedido');
      semantica.dispose();
    });

    testWidgets('en una tabla: icono y texto; o solo icono', (tester) async {
      await montarEnFinanzas(
        tester,
        const TablaDensa(
          columnas: [ColumnaTabla('Partida'), ColumnaTabla('Estado')],
          filas: [
            FilaTabla(
              celdas: [
                CeldaTexto('Alimentación'),
                CeldaSemaforo(EstadoSemaforo.verde, etiqueta: 'Bien'),
              ],
            ),
            FilaTabla(
              celdas: [
                CeldaTexto('Personal'),
                CeldaSemaforo(
                  EstadoSemaforo.rojo,
                  etiqueta: 'Excedido',
                  soloIcono: true,
                ),
              ],
            ),
          ],
        ),
      );
      expect(find.text('Bien'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Excedido'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}

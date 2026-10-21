import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../ayuda_pruebas.dart';
import 'ayuda_finanzas.dart';

const _columnas = [
  ColumnaTabla('Categoría', flex: 3),
  ColumnaTabla('Presupuesto', numerica: true, flex: 2),
  ColumnaTabla('Gastado', numerica: true, flex: 2),
  ColumnaTabla('Disponible', numerica: true, flex: 2),
  ColumnaTabla('Estado', ancho: 180),
];

FilaTabla _fila(
  String categoria,
  int asignado,
  int gastado, {
  String? detalle,
  bool oculto = false,
  VoidCallback? alTocar,
  bool seleccionada = false,
}) {
  final uso = UsoPresupuesto(
    asignadoCentavos: asignado,
    gastadoCentavos: gastado,
  );
  return FilaTabla(
    alTocar: alTocar,
    seleccionada: seleccionada,
    etiquetaSemantica: alTocar == null
        ? null
        : '$categoria: ${uso.textoPorcentaje} usado, ${uso.textoEstado}',
    celdas: [
      CeldaTexto(categoria, detalle: detalle),
      CeldaMonto(asignado, oculto: oculto),
      CeldaMonto(gastado, oculto: oculto),
      CeldaMonto(uso.restanteCentavos, oculto: oculto),
      CeldaSemaforo(uso.estado, etiqueta: uso.textoEstado),
    ],
  );
}

/// Las filas del boceto *Laptop · Finanzas › Semana* (datos de ejemplo).
List<FilaTabla> _filas({
  bool oculto = false,
  void Function(String)? alTocar,
  String? seleccionada,
}) => [
  for (final (categoria, asignado, gastado, detalle) in [
    ('Alimentación', 180000, 124000, null),
    ('Transporte', 60000, 52000, null),
    ('Servicios', 90000, 90000, 'protegida'),
    ('Personal', 30000, 34000, null),
  ])
    _fila(
      categoria,
      asignado,
      gastado,
      detalle: detalle,
      oculto: oculto,
      alTocar: alTocar == null ? null : () => alTocar(categoria),
      seleccionada: categoria == seleccionada,
    ),
];

Future<void> _montarLaptop(WidgetTester tester, Widget tabla) async {
  fijarVentana(tester, const Size(1280, 800));
  await montarEnFinanzas(
    tester,
    tabla,
    ancho: 900,
    overrides: [densidadBaseProvider.overrideWithValue(Densidad.compacta)],
  );
}

void main() {
  group('TablaDensa', () {
    testWidgets('encabezados, cifras a la derecha y semáforo con texto', (
      tester,
    ) async {
      await _montarLaptop(
        tester,
        TablaDensa(columnas: _columnas, filas: _filas()),
      );
      for (final c in _columnas) {
        expect(find.text(c.titulo), findsOneWidget);
      }
      expect(find.text('Cerca del límite'), findsOneWidget);
      expect(find.text('Al límite'), findsOneWidget);
      expect(find.text('Excedido'), findsOneWidget);
      expect(find.text('Bien'), findsOneWidget);

      // Las cifras de una columna numérica terminan en el mismo borde.
      final bordes = [
        r'$1,800.00',
        r'$600.00',
        r'$900.00',
        r'$300.00',
      ].map((t) => tester.getTopRight(find.text(t).first).dx).toSet();
      expect(bordes, hasLength(1));
      // Y quedan a la derecha de su encabezado (también alineado a la derecha).
      expect(
        tester.getTopRight(find.text('Presupuesto')).dx,
        closeTo(bordes.single, 0.5),
      );

      // Negativo: con signo y en rojo.
      final v = valoresDe(tester, find.byType(TablaDensa));
      expect(find.text(r'-$40.00'), findsOneWidget);
      expect(colorDelTexto(tester, r'-$40.00'), v.peligro);
      // Números de ancho fijo con cifras tabulares.
      final monto = tester.widget<Text>(find.text(r'$1,800.00'));
      expect(monto.style?.fontFamily, FuentesGravity.mono);
      expect(
        monto.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(find.text('Servicios · protegida', findRichText: true), findsOne);
    });

    testWidgets('filas de solo lectura densas; las que se tocan, de 48 dp', (
      tester,
    ) async {
      await _montarLaptop(
        tester,
        TablaDensa(columnas: _columnas, filas: _filas()),
      );
      final v = valoresDe(tester, find.byType(TablaDensa));
      expect(v.densidad, Densidad.compacta);
      // Encabezado de 36 dp y filas de 40 dp: más densa que 48 dp por fila.
      expect(
        tester.getSize(find.byType(TablaDensa)).height,
        lessThan(v.densidad.altoEncabezadoTabla + 4 * zonaTactilMinima),
      );
      expect(
        find.descendant(
          of: find.byType(TablaDensa),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );

      final tocadas = <String>[];
      await _montarLaptop(
        tester,
        TablaDensa(
          columnas: _columnas,
          filas: _filas(alTocar: tocadas.add),
        ),
      );
      revisarZonasTactiles(tester, find.byType(TablaDensa));
      await tester.tap(find.text('Transporte'));
      expect(tocadas, ['Transporte']);
    });

    testWidgets('fila seleccionada: fondo, franja y "seleccionado"', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await _montarLaptop(
        tester,
        TablaDensa(
          columnas: _columnas,
          filas: _filas(alTocar: (_) {}, seleccionada: 'Personal'),
          etiquetaSemantica: 'Cuentas de gasto',
        ),
      );
      final v = valoresDe(tester, find.byType(TablaDensa));
      final nodo = tester.getSemantics(
        find.bySemanticsLabel('Personal: 114 % usado, Excedido'),
      );
      expect(nodo, isSemantics(isSelected: true, isButton: true));
      final otra = tester.getSemantics(
        find.bySemanticsLabel('Alimentación: 69 % usado, Bien'),
      );
      expect(otra, isSemantics(isSelected: false, isButton: true));

      final fondos = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(TablaDensa),
              matching: find.byType(Material),
            ),
          )
          .map((m) => m.color)
          .toList();
      expect(fondos.where((c) => c == v.filaSeleccionada), hasLength(1));
      semantica.dispose();
    });

    testWidgets('montos ocultos en las celdas, sin color que delate', (
      tester,
    ) async {
      await _montarLaptop(
        tester,
        TablaDensa(columnas: _columnas, filas: _filas(oculto: true)),
      );
      expect(find.text(montoOculto), findsNWidgets(12));
      expect(find.textContaining(r'$4'), findsNothing);
      final v = valoresDe(tester, find.byType(TablaDensa));
      for (final texto in tester.widgetList<Text>(find.text(montoOculto))) {
        expect(texto.style?.color, isNot(v.peligro));
      }
    });

    testWidgets('fila de total con énfasis y encabezado que ordena', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      var ordenes = 0;
      await _montarLaptop(
        tester,
        TablaDensa(
          columnas: [
            const ColumnaTabla('Cuenta', flex: 3),
            ColumnaTabla('Saldo', numerica: true, alOrdenar: () => ordenes++),
          ],
          columnaOrdenada: 1,
          ascendente: false,
          filas: const [
            FilaTabla(celdas: [CeldaTexto('Efectivo'), CeldaMonto(98000)]),
            FilaTabla(celdas: [CeldaTexto('Banco'), CeldaMonto(2200000)]),
          ],
          pie: const FilaTabla(
            celdas: [CeldaTexto('Total'), CeldaMonto(2298000)],
          ),
        ),
      );
      final total = tester.widget<Text>(find.text(r'$22,980.00'));
      expect(total.style?.fontWeight, FontWeight.w700);
      final normal = tester.widget<Text>(find.text(r'$980.00'));
      expect(normal.style?.fontWeight, FontWeight.w500);

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      final encabezado = tester.getSemantics(find.bySemanticsLabel('Saldo'));
      expect(encabezado.value, 'orden descendente');
      expect(
        encabezado,
        isSemantics(isHeader: true, isButton: true, hasTapAction: true),
      );
      // El encabezado que ordena es zona táctil de 48 dp.
      revisarZonasTactiles(tester, find.byType(TablaDensa));
      await tester.tap(find.text('Saldo'));
      expect(ordenes, 1);
      semantica.dispose();
    });

    testWidgets('vacía: muestra el estado vacío bajo el encabezado', (
      tester,
    ) async {
      await _montarLaptop(
        tester,
        const TablaDensa(
          columnas: _columnas,
          filas: [],
          vacio: Text('Aún no hay movimientos esta semana'),
        ),
      );
      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('Aún no hay movimientos esta semana'), findsOneWidget);
    });

    testWidgets('ventana angosta: se desplaza a lo ancho, sin apretarse', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        TablaDensa(columnas: _columnas, filas: _filas(), anchoMinimo: 760),
        ancho: 360,
        overrides: [densidadBaseProvider.overrideWithValue(Densidad.compacta)],
      );
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(TablaDensa),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      // Con espacio de sobra no hay desplazamiento.
      await _montarLaptop(
        tester,
        TablaDensa(columnas: _columnas, filas: _filas(), anchoMinimo: 760),
      );
      expect(
        find.descendant(
          of: find.byType(TablaDensa),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
    });

    testWidgets('en el teléfono las filas son más cómodas', (tester) async {
      await montarEnFinanzas(
        tester,
        TablaDensa(columnas: _columnas, filas: _filas()),
        ancho: 900,
      );
      final v = valoresDe(tester, find.byType(TablaDensa));
      expect(v.densidad, Densidad.comoda);
      expect(Densidad.comoda.altoFilaTabla, zonaTactilMinima);
      expect(Densidad.compacta.altoFilaTabla, lessThan(zonaTactilMinima));
      expect(tester.takeException(), isNull);
      // Que el módulo importado sí sea Finanzas.
      expect(PersonalidadModulo.automatica(Modulo.finanzas).id, 'precisa');
    });
  });
}

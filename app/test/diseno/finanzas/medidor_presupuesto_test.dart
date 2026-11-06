import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../ayuda_pruebas.dart';
import 'ayuda_finanzas.dart';

PintorArcoMedidor _pintor(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(MedidorPresupuesto),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((c) => c.painter)
    .whereType<PintorArcoMedidor>()
    .single;

void main() {
  group('MedidorPresupuesto', () {
    testWidgets('62 % en verde, con texto y lo que queda', (tester) async {
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(
          asignadoCentavos: 180000,
          gastadoCentavos: 111600,
          etiqueta: 'Alimentación',
        ),
      );
      expect(find.text('Alimentación'), findsOneWidget);
      expect(find.text('62 %'), findsOneWidget);
      expect(find.text('del presupuesto usado'), findsOneWidget);
      expect(find.text('Bien'), findsOneWidget);
      expect(find.text('Quedan'), findsOneWidget);
      expect(find.text(r'$684.00'), findsOneWidget);

      final v = valoresDe(tester, find.byType(MedidorPresupuesto));
      final pintor = _pintor(tester);
      expect(pintor.color, v.exito);
      expect(pintor.pista, v.pista);
      expect(pintor.fraccion, closeTo(0.62, 1e-9));
      // El semáforo dice su estado con texto, en el color del estado.
      expect(colorDelTexto(tester, 'Bien'), v.exito);
    });

    testWidgets('cerca del límite en ámbar', (tester) async {
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(
          asignadoCentavos: 30000,
          gastadoCentavos: 26000,
        ),
      );
      expect(find.text('87 %'), findsOneWidget);
      expect(find.text('Cerca del límite'), findsOneWidget);
      final v = valoresDe(tester, find.byType(MedidorPresupuesto));
      expect(_pintor(tester).color, v.alerta);
    });

    testWidgets(
      'excedido en rojo: arco lleno, "Excedido por" y monto en rojo',
      (tester) async {
        await montarEnFinanzas(
          tester,
          const MedidorPresupuesto(
            asignadoCentavos: 30000,
            gastadoCentavos: 34000,
            etiqueta: 'Personal',
          ),
        );
        expect(find.text('114 %'), findsOneWidget);
        expect(find.text('Excedido'), findsOneWidget);
        expect(find.text('Excedido por'), findsOneWidget);
        expect(find.text(r'$40.00'), findsOneWidget);
        final v = valoresDe(tester, find.byType(MedidorPresupuesto));
        expect(_pintor(tester).color, v.peligro);
        expect(_pintor(tester).fraccion, 1);
        expect(colorDelTexto(tester, r'$40.00'), v.peligro);
      },
    );

    testWidgets('umbrales propios', (tester) async {
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(
          asignadoCentavos: 100000,
          gastadoCentavos: 75000,
          ambarDesdePuntosBase: 7000,
          rojoArribaDePuntosBase: 9000,
        ),
      );
      expect(find.text('Cerca del límite'), findsOneWidget);
    });

    testWidgets('montos ocultos: el porcentaje se ve, los pesos no', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(
          asignadoCentavos: 30000,
          gastadoCentavos: 34000,
          etiqueta: 'Personal',
          montosOcultos: true,
        ),
      );
      expect(find.text('114 %'), findsOneWidget);
      expect(find.text(montoOculto), findsOneWidget);
      expect(find.textContaining(r'$40'), findsNothing);
      // En modo privado el color no delata el exceso.
      final v = valoresDe(tester, find.byType(MedidorPresupuesto));
      expect(colorDelTexto(tester, montoOculto), v.textoFuerte);

      final nodo = tester.getSemantics(find.byType(MedidorPresupuesto));
      expect(nodo.label, 'Medidor de presupuesto: Personal');
      expect(nodo.value, contains('114 % usado'));
      expect(nodo.value, contains('monto oculto'));
      expect(nodo.value, contains('Excedido'));
      expect(nodo.value, isNot(contains(r'$')));
      semantica.dispose();
    });

    testWidgets('lector de pantalla con montos visibles', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(
          asignadoCentavos: 180000,
          gastadoCentavos: 111600,
        ),
      );
      final nodo = tester.getSemantics(find.byType(MedidorPresupuesto));
      expect(nodo.label, 'Medidor de presupuesto');
      expect(nodo.value, '62 % usado. Quedan \$684.00. Bien');
      semantica.dispose();
    });

    testWidgets('sin presupuesto asignado', (tester) async {
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(asignadoCentavos: 0, gastadoCentavos: 0),
      );
      expect(find.text('Sin presupuesto asignado'), findsOneWidget);
      expect(find.text('Sin gasto'), findsOneWidget);
      expect(_pintor(tester).fraccion, 0);
    });

    testWidgets('cabe en un gadget angosto y en uno ancho sin desbordarse', (
      tester,
    ) async {
      for (final ancho in [140.0, 260.0, 600.0]) {
        await montarEnFinanzas(
          tester,
          const MedidorPresupuesto(
            asignadoCentavos: 999999999,
            gastadoCentavos: 123456789,
            etiqueta: 'Cuidados de largo plazo y medicamentos',
          ),
          ancho: ancho,
        );
        expect(tester.takeException(), isNull, reason: 'ancho $ancho');
      }
    });

    testWidgets('anima poco y se queda quieto con "reducir movimiento"', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(
          asignadoCentavos: 100000,
          gastadoCentavos: 50000,
        ),
        reducirMovimiento: false,
      );
      // Precisa y serena: 120 ms × 2; pumpAndSettle ya terminó.
      expect(tester.hasRunningAnimations, isFalse);
      expect(_pintor(tester).fraccion, closeTo(0.5, 1e-9));
    });

    testWidgets('toma los colores del tema y cambia sin reiniciar', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const MedidorPresupuesto(
          asignadoCentavos: 180000,
          gastadoCentavos: 111600,
        ),
        momento: momentoNoche,
      );
      final noche = valoresDe(tester, find.byType(MedidorPresupuesto));
      expect(noche.brillo, Brightness.dark);
      expect(noche.acento, PersonalidadModulo.precisa.acentoNoche);
      expect(_pintor(tester).color, noche.exito);

      final contenedor = contenedorDe(tester, find.byType(MedidorPresupuesto));
      contenedor
          .read(preferenciaClaroOscuroProvider.notifier)
          .cambiarModo(ModoClaroOscuro.claro);
      await tester.pumpAndSettle();

      final dia = valoresDe(tester, find.byType(MedidorPresupuesto));
      expect(dia.brillo, Brightness.light);
      expect(dia.acento, PersonalidadModulo.precisa.acentoDia);
      expect(_pintor(tester).color, dia.exito);
      expect(_pintor(tester).pista, dia.pista);
      expect(dia.exito, isNot(noche.exito));
    });
  });

  test('la personalidad de Finanzas fija números de ancho fijo', () {
    for (final brillo in Brightness.values) {
      final v = valoresPara(
        estilo: estiloFuturista,
        brillo: brillo,
        personalidad: PersonalidadModulo.precisa,
      );
      expect(v.fuenteNumeros, FuentesGravity.mono);
      expect(
        v.numero().fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(v.duracionAnimacion, const Duration(milliseconds: 120));
    }
    // Aunque el estilo global usara otra letra para los números.
    final otro = Estilo(
      id: 'otro',
      nombre: 'Otro',
      dia: futuristaDia.copyWith(fuenteNumeros: FuentesGravity.titulos),
      noche: futuristaNoche.copyWith(fuenteNumeros: FuentesGravity.titulos),
    );
    expect(
      valoresPara(
        estilo: otro,
        brillo: Brightness.dark,
        personalidad: PersonalidadModulo.precisa,
      ).fuenteNumeros,
      FuentesGravity.mono,
    );
    // "Igual al estilo global" sí respeta la letra del estilo.
    expect(
      valoresPara(
        estilo: otro,
        brillo: Brightness.dark,
        personalidad: PersonalidadModulo.resolver(
          Modulo.finanzas,
          opcion: OpcionPersonalidad.igualAlEstilo,
        ),
      ).fuenteNumeros,
      FuentesGravity.titulos,
    );
  });

  test('el tema trae la tabla de Material con las superficies', () {
    final tema = temaPara(
      estilo: estiloFuturista,
      brillo: Brightness.dark,
      personalidad: PersonalidadModulo.precisa,
      densidadBase: Densidad.compacta,
    );
    final v = tema.extension<ValoresDiseno>()!;
    expect(tema.dataTableTheme.dataRowMinHeight, zonaTactilMinima);
    expect(tema.dataTableTheme.headingRowColor!.resolve({}), v.encabezadoTabla);
    expect(
      tema.dataTableTheme.dataRowColor!.resolve({WidgetState.selected}),
      v.filaSeleccionada,
    );
    expect(tema.dataTableTheme.headingTextStyle!.color, v.etiqueta);
  });
}

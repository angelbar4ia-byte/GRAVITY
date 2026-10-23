import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import 'ayuda_pruebas.dart';

/// Envuelve con la opción "reducir movimiento" del sistema.
Widget _conMovimiento(bool reducir, Widget hijo) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducir),
    child: hijo,
  ),
);

void main() {
  group('NucleoGravity', () {
    testWidgets('gira cuando no se pide reducir movimiento', (tester) async {
      await montar(
        tester,
        _conMovimiento(false, const Center(child: NucleoGravity())),
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('se detiene con MediaQuery.disableAnimations', (tester) async {
      await montar(
        tester,
        _conMovimiento(true, const Center(child: NucleoGravity())),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(NucleoGravity), findsOneWidget);
    });

    testWidgets('se detiene si el sistema lo pide con la app abierta', (
      tester,
    ) async {
      final reducir = ValueNotifier(false);
      await montar(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: reducir,
          builder: (_, valor, _) =>
              _conMovimiento(valor, const Center(child: NucleoGravity())),
        ),
      );
      expect(tester.hasRunningAnimations, isTrue);
      reducir.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      reducir.value = false;
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('se detiene en una personalidad sin animación', (tester) async {
      await montar(
        tester,
        const TemaModulo(
          modulo: Modulo.habitos,
          submodulo: Submodulo.espiritual,
          child: Center(child: NucleoGravity()),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('anuncia su estado al lector de pantalla', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        const Center(child: NucleoGravity(estado: EstadoNucleo.escuchando)),
      );
      expect(
        find.bySemanticsLabel('Núcleo de GRAVITY: escuchando'),
        findsOneWidget,
      );
      semantica.dispose();
    });
  });

  group('Semaforo', () {
    testWidgets('siempre lleva texto, no solo color', (tester) async {
      await montar(
        tester,
        const Scaffold(
          body: Column(
            children: [
              Semaforo(estado: EstadoSemaforo.verde),
              Semaforo(estado: EstadoSemaforo.ambar),
              Semaforo(estado: EstadoSemaforo.rojo, etiqueta: 'Excedido'),
            ],
          ),
        ),
      );
      expect(find.text('En verde'), findsOneWidget);
      expect(find.text('En ámbar'), findsOneWidget);
      expect(find.text('Excedido'), findsOneWidget);
    });

    test('toma el color de los valores de diseño', () {
      expect(EstadoSemaforo.verde.color(futuristaNoche), futuristaNoche.exito);
      expect(EstadoSemaforo.ambar.color(futuristaDia), futuristaDia.alerta);
      expect(EstadoSemaforo.rojo.color(futuristaDia), futuristaDia.peligro);
    });
  });

  group('BarraProgreso', () {
    testWidgets('muestra el porcentaje y limita el valor', (tester) async {
      await montar(
        tester,
        const Scaffold(
          body: Column(
            children: [
              BarraProgreso(valor: 0.62, etiqueta: 'Presupuesto usado'),
              BarraProgreso(valor: 1.7, etiqueta: 'Excedido'),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Presupuesto usado'), findsOneWidget);
      expect(find.text('62 %'), findsOneWidget);
      expect(find.text('100 %'), findsOneWidget);
    });
  });

  group('TarjetaConfirmacion', () {
    testWidgets('confirma o cancela con botones de 48 o más', (tester) async {
      var confirmado = 0;
      var cancelado = 0;
      await montar(
        tester,
        Scaffold(
          body: TarjetaConfirmacion(
            titulo: 'Registrar gasto',
            detalles: const [
              DetalleConfirmacion('Categoría', 'Alimentación'),
              DetalleConfirmacion('Cuenta', 'Efectivo'),
            ],
            alConfirmar: () => confirmado++,
            alCancelar: () => cancelado++,
          ),
        ),
      );
      expect(find.text('Registrar gasto'), findsOneWidget);
      expect(find.text('CONFIRMA · GRAVITY'), findsOneWidget);
      expect(find.text('Alimentación'), findsOneWidget);
      for (final texto in ['Confirmar', 'Cancelar']) {
        final boton = find.ancestor(
          of: find.text(texto),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('Confirmar'));
      await tester.tap(find.text('Cancelar'));
      expect(confirmado, 1);
      expect(cancelado, 1);
    });
  });

  group('EstadoVacio', () {
    testWidgets('mensaje con una sola acción', (tester) async {
      var accion = 0;
      await montar(
        tester,
        Scaffold(
          body: EstadoVacio(
            mensaje: 'Aún no hay movimientos',
            detalle: 'Registra el primero con (+).',
            textoAccion: 'Registrar gasto',
            alAccionar: () => accion++,
          ),
        ),
      );
      expect(find.text('Aún no hay movimientos'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.tap(find.text('Registrar gasto'));
      expect(accion, 1);
    });
  });

  group('TarjetaModulo', () {
    testWidgets('etiqueta en mayúsculas y contenido', (tester) async {
      var toques = 0;
      await montar(
        tester,
        Scaffold(
          body: TarjetaModulo(
            titulo: 'Hábitos de hoy',
            alTocar: () => toques++,
            child: const Text('3 de 5'),
          ),
        ),
      );
      expect(find.text('HÁBITOS DE HOY'), findsOneWidget);
      await tester.tap(find.text('3 de 5'));
      expect(toques, 1);
    });

    testWidgets('sin decoración en Cuidados', (tester) async {
      await montar(
        tester,
        const TemaModulo(
          modulo: Modulo.cuidados,
          child: Scaffold(
            body: TarjetaModulo(titulo: 'Turno', child: Text('Hoy')),
          ),
        ),
      );
      final pinturas = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(TarjetaModulo),
              matching: find.byType(CustomPaint),
            ),
          )
          .where((c) => c.foregroundPainter is MarcasEsquina);
      expect(pinturas, isEmpty);
    });

    Widget tarjeta({
      String titulo = 'Semana 43 · 19 al 25 oct',
      Widget? accion,
      IconData? icono = Icons.waterfall_chart,
    }) => Scaffold(
      body: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TarjetaModulo(
            titulo: titulo,
            icono: icono,
            accion: accion,
            child: const Text('contenido'),
          ),
        ),
      ),
    );

    testWidgets('con espacio, la acción va a la derecha en la misma línea', (
      tester,
    ) async {
      fijarVentana(tester, const Size(600, 800));
      await montar(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 560,
              child: TarjetaModulo(
                titulo: 'Semana',
                accion: const Semaforo(estado: EstadoSemaforo.verde),
                child: const Text('contenido'),
              ),
            ),
          ),
        ),
      );
      final titulo = tester.getRect(find.text('SEMANA'));
      final accion = tester.getRect(find.text('En verde'));
      final tarjeta = tester.getRect(find.byType(TarjetaModulo));
      expect((titulo.center.dy - accion.center.dy).abs(), lessThan(8));
      expect(accion.left, greaterThan(titulo.right));
      expect(accion.right, greaterThan(tarjeta.right - 60));
    });

    for (final escala in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('letra x$escala en 360 dp: la acción cabe, sin desbordes', (
        tester,
      ) async {
        fijarVentana(tester, const Size(360, 800));
        fijarEscalaDeLetra(tester, escala);
        final desbordes = await recolectarDesbordes(() async {
          await montar(
            tester,
            tarjeta(
              accion: const Semaforo(
                estado: EstadoSemaforo.ambar,
                etiqueta: 'Remanente 33.9 %',
                tamanoTexto: 12,
              ),
            ),
          );
        });
        expect(desbordes, isEmpty);
        // Todo queda dentro de la tarjeta.
        final tarjetaRect = tester.getRect(find.byType(TarjetaModulo));
        for (final texto in ['SEMANA 43 · 19 AL 25 OCT', 'Remanente 33.9 %']) {
          final r = tester.getRect(find.text(texto));
          expect(r.left, greaterThanOrEqualTo(tarjetaRect.left));
          expect(r.right, lessThanOrEqualTo(tarjetaRect.right));
        }
      });
    }

    testWidgets('si no caben juntos, la acción baja a su propia línea', (
      tester,
    ) async {
      fijarVentana(tester, const Size(360, 800));
      fijarEscalaDeLetra(tester, 2);
      await montar(
        tester,
        tarjeta(
          accion: const Semaforo(
            estado: EstadoSemaforo.rojo,
            etiqueta: 'Remanente 33.9 %',
            tamanoTexto: 12,
          ),
        ),
      );
      final titulo = tester.getRect(find.textContaining('SEMANA 43'));
      final accion = tester.getRect(find.text('Remanente 33.9 %'));
      expect(accion.top, greaterThanOrEqualTo(titulo.bottom - 1));
    });

    testWidgets('una acción más ancha que la tarjeta se recorta, no desborda', (
      tester,
    ) async {
      fijarVentana(tester, const Size(360, 800));
      fijarEscalaDeLetra(tester, 2);
      final desbordes = await recolectarDesbordes(() async {
        await montar(
          tester,
          tarjeta(
            titulo: 'Un título bastante largo para una tarjeta del teléfono',
            accion: const Semaforo(
              estado: EstadoSemaforo.verde,
              etiqueta: 'Remanente de la semana con un texto larguísimo',
            ),
          ),
        );
      });
      expect(desbordes, isEmpty);
    });

    testWidgets('sin acción ni icono, el título ocupa lo suyo', (tester) async {
      await montar(tester, tarjeta(icono: null));
      expect(find.text('SEMANA 43 · 19 AL 25 OCT'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });
}

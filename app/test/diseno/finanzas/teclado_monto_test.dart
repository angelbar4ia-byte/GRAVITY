import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show fijarEscalaDeLetra, recolectarDesbordes;
import 'ayuda_finanzas.dart';

/// Aplica una secuencia de teclas: dígitos, '.' y '<' (borrar).
CapturaMonto _teclear(String teclas, [CapturaMonto? desde]) {
  var c = desde ?? CapturaMonto.vacia;
  for (final t in teclas.split('')) {
    c = switch (t) {
      '.' => c.conPuntoDecimal(),
      '<' => c.sinUltimo(),
      _ => c.conDigito(int.parse(t)),
    };
  }
  return c;
}

/// Toca las teclas en pantalla: dígitos, '.' y '<' (borrar).
Future<void> _tocar(WidgetTester tester, String teclas) async {
  for (final t in teclas.split('')) {
    final etiqueta = switch (t) {
      '.' => 'Punto decimal',
      '<' => 'Borrar',
      _ => t,
    };
    await tester.tap(find.bySemanticsLabel(etiqueta));
    await tester.pump();
  }
}

void main() {
  group('CapturaMonto: secuencias de teclas → centavos', () {
    final casos = <String, int>{
      '': 0,
      '85': 8500,
      '85.5': 8550,
      '85.50': 8550,
      '85.05': 8505,
      '.5': 50,
      '.05': 5,
      '0.99': 99,
      '1234.56': 123456,
      '007': 700,
      '1.234': 123, // el tercer decimal se ignora
      '1..2': 120, // el segundo punto se ignora
      '12<': 100,
      '85.<': 8500,
      '.<': 0,
      '1.5<<3': 1300,
      '9<<<': 0, // borrar de más no truena
      '1234567890': 12345678900, // tope: 9 dígitos enteros
      '999999999.99': 99999999999,
    };
    casos.forEach((teclas, centavos) {
      test('"$teclas" → $centavos', () {
        expect(_teclear(teclas).centavos, centavos);
      });
    });

    test('texto tal cual se tecleó', () {
      expect(_teclear('').texto, '0');
      expect(_teclear('.').texto, '0.');
      expect(_teclear('85.').texto, '85.');
      expect(_teclear('85.5').texto, '85.5');
      expect(_teclear('00').texto, '0');
    });

    test('desde centavos iniciales, como si se hubieran tecleado', () {
      expect(CapturaMonto.desdeCentavos(0), CapturaMonto.vacia);
      expect(CapturaMonto.desdeCentavos(8500).texto, '85');
      expect(CapturaMonto.desdeCentavos(8550).texto, '85.5');
      expect(CapturaMonto.desdeCentavos(8555).texto, '85.55');
      expect(CapturaMonto.desdeCentavos(5).texto, '0.05');
      expect(CapturaMonto.desdeCentavos(50).texto, '0.5');
      for (final c in [0, 1, 5, 50, 99, 100, 8550, 8555, 123456789]) {
        expect(CapturaMonto.desdeCentavos(c).centavos, c);
      }
      // Seguir tecleando y borrar desde un monto inicial.
      expect(_teclear('<', CapturaMonto.desdeCentavos(8550)).centavos, 8500);
      expect(_teclear('5', CapturaMonto.desdeCentavos(8550)).centavos, 8555);
      expect(_teclear('<<', CapturaMonto.desdeCentavos(8500)).centavos, 0);
    });
  });

  group('TecladoMonto en pantalla', () {
    testWidgets('las teclas reportan centavos solo cuando el monto cambia', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final reportes = <int>[];
      await montarEnFinanzas(tester, TecladoMonto(alCambiar: reportes.add));
      await _tocar(tester, '85.5');
      // El punto no cambia el monto: no se reporta.
      expect(reportes, [800, 8500, 8550]);
      await _tocar(tester, '0');
      expect(reportes.last, 8550, reason: '85.50 sigue siendo 8550');
      await _tocar(tester, '9');
      expect(reportes, [800, 8500, 8550]); // ya hay dos decimales
      await _tocar(tester, '<<<');
      expect(reportes, [800, 8500, 8550, 8500]);
      semantica.dispose();
    });

    testWidgets('mantener presionado Borrar deja el monto en cero', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final reportes = <int>[];
      await montarEnFinanzas(
        tester,
        TecladoMonto(alCambiar: reportes.add, centavosIniciales: 12345),
      );
      await tester.longPress(find.bySemanticsLabel('Borrar'));
      await tester.pump();
      expect(reportes, [0]);
      semantica.dispose();
    });

    testWidgets('centavosIniciales: empieza ahí y se reinicia si cambia', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final reportes = <int>[];
      final inicial = ValueNotifier(8500);
      await montarEnFinanzas(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: inicial,
          builder: (_, valor, _) =>
              TecladoMonto(alCambiar: reportes.add, centavosIniciales: valor),
        ),
      );
      await _tocar(tester, '.2');
      expect(reportes.last, 8520);
      // La pantalla le pasa el mismo valor que recibió: no se reinicia.
      inicial.value = 8520;
      await tester.pump();
      await _tocar(tester, '5');
      expect(reportes.last, 8525);
      // Después de guardar, la pantalla lo regresa a cero.
      inicial.value = 0;
      await tester.pump();
      await _tocar(tester, '7');
      expect(reportes.last, 700);
      semantica.dispose();
    });

    testWidgets('teclas de 48 dp o más, de teléfono a laptop', (tester) async {
      for (final ancho in [200.0, 360.0, 600.0]) {
        await montarEnFinanzas(
          tester,
          TecladoMonto(alCambiar: (_) {}),
          ancho: ancho,
        );
        revisarZonasTactiles(tester, find.byType(TecladoMonto));
        expect(
          find.descendant(
            of: find.byType(TecladoMonto),
            matching: find.byType(InkWell),
          ),
          findsNWidgets(12),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('compacto: teclas de 48 dp, 204 dp en total, mismo orden', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(tester, TecladoMonto(alCambiar: (_) {}));
      final normal = tester.getSize(find.byType(TecladoMonto)).height;
      final posiciones = {
        for (final t in ['1', '5', '9', '0'])
          t: tester.getTopLeft(find.bySemanticsLabel(t)).dy,
      };

      for (final ancho in [200.0, 360.0, 600.0]) {
        await montarEnFinanzas(
          tester,
          TecladoMonto(alCambiar: (_) {}, compacto: true),
          ancho: ancho,
        );
        expect(tester.takeException(), isNull);
        revisarZonasTactiles(tester, find.byType(TecladoMonto));
        final alto = tester.getSize(find.byType(TecladoMonto)).height;
        expect(alto, TecladoMonto.altoCompacto);
        expect(alto, 204);
        expect(alto, lessThan(normal - 30), reason: 'normal: $normal dp');
        for (final tecla
            in find
                .descendant(
                  of: find.byType(TecladoMonto),
                  matching: find.byType(InkWell),
                )
                .evaluate()) {
          expect(
            tester.getSize(find.byWidget(tecla.widget)).height,
            TecladoMonto.altoTeclaCompacta,
          );
        }
      }

      // Mismo orden de teclas: el 1 arriba, el 0 abajo, de arriba abajo.
      final y = {
        for (final t in ['1', '5', '9', '0'])
          t: tester.getTopLeft(find.bySemanticsLabel(t)).dy,
      };
      expect(y['1']!, lessThan(y['5']!));
      expect(y['5']!, lessThan(y['9']!));
      expect(y['9']!, lessThan(y['0']!));
      expect(posiciones['1']!, lessThan(posiciones['0']!));
      semantica.dispose();
    });

    testWidgets(
      'compacto: se comporta igual (centavos, borrar, teclado físico)',
      (tester) async {
        final semantica = tester.ensureSemantics();
        final reportes = <int>[];
        await montarEnFinanzas(
          tester,
          TecladoMonto(
            alCambiar: reportes.add,
            compacto: true,
            autofocus: true,
          ),
        );
        await _tocar(tester, '85.5');
        expect(reportes, [800, 8500, 8550]);
        await _tocar(tester, '<');
        expect(reportes.last, 8500);
        await tester.longPress(find.bySemanticsLabel('Borrar'));
        await tester.pump();
        expect(reportes.last, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
        expect(reportes.last, 700);
        // Las teclas siguen nombradas para el lector de pantalla.
        for (final etiqueta in ['Punto decimal', 'Borrar']) {
          expect(
            tester.getSemantics(find.bySemanticsLabel(etiqueta)),
            isSemantics(isButton: true, hasTapAction: true),
            reason: etiqueta,
          );
        }
        semantica.dispose();
      },
    );

    testWidgets('compacto con letra al 200 % no desborda en 360 dp', (
      tester,
    ) async {
      fijarEscalaDeLetra(tester, 2);
      final desbordes = await recolectarDesbordes(() async {
        await montarEnFinanzas(
          tester,
          TecladoMonto(alCambiar: (_) {}, compacto: true),
          ancho: 360,
        );
      });
      expect(desbordes, isEmpty);
    });

    testWidgets('lector de pantalla: nombre de cada tecla y monto actual', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        TecladoMonto(alCambiar: (_) {}, centavosIniciales: 8500),
      );
      for (final etiqueta in [
        for (var d = 0; d <= 9; d++) '$d',
        'Punto decimal',
        'Borrar',
      ]) {
        final nodo = tester.getSemantics(find.bySemanticsLabel(etiqueta));
        expect(
          nodo,
          isSemantics(isButton: true, hasTapAction: true),
          reason: etiqueta,
        );
      }
      final borrar = tester.getSemantics(find.bySemanticsLabel('Borrar'));
      expect(borrar.hint, 'Mantén presionado para borrar todo');
      expect(borrar, isSemantics(hasLongPressAction: true));
      final grupo = tester.getSemantics(
        find.bySemanticsLabel('Teclado numérico'),
      );
      expect(grupo.value, r'$85.00');
      semantica.dispose();
    });

    testWidgets('teclado físico en la laptop: dígitos, coma y retroceso', (
      tester,
    ) async {
      final reportes = <int>[];
      await montarEnFinanzas(
        tester,
        TecladoMonto(alCambiar: reportes.add, autofocus: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      expect(reportes, [400, 4200, 4250]);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(reportes.last, 4200);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);
      expect(reportes.last, 4270);
    });

    testWidgets('colores del tema: tecla y número con contraste', (
      tester,
    ) async {
      await montarEnFinanzas(tester, TecladoMonto(alCambiar: (_) {}));
      final v = valoresDe(tester, find.byType(TecladoMonto));
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text('5'), matching: find.byType(Material))
            .first,
      );
      expect(material.color, v.superficieTecla);
      final texto = tester.widget<Text>(find.text('5'));
      expect(texto.style?.color, v.textoFuerte);
      expect(texto.style?.fontFamily, FuentesGravity.mono);
      expect(
        razonContraste(v.textoFuerte, v.superficieTecla),
        greaterThanOrEqualTo(contrasteMinimoTexto),
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/ordenes/barra_ordenes.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

void _sinNavegar(String ruta) {}

/// La barra abajo, como en la pantalla principal de la laptop.
Widget _app(Rol rol, List<String> rutas) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        const Expanded(child: Center(child: Text('Núcleo'))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: BarraOrdenes(rol: rol, onNavegar: rutas.add),
        ),
      ],
    ),
  ),
);

Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.tap(find.byType(TextField));
  await tester.pump();
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump();
}

Future<void> _enviar(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await tester.pump();
}

String _textoDelCampo(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  test('constructor del contrato', () {
    // Si cambia la firma, esto deja de compilar.
    const barra = BarraOrdenes(rol: Rol.dueno, onNavegar: _sinNavegar);
    expect(barra.rol, Rol.dueno);
  });

  testWidgets('"abre presupuesto" + Enter abre Finanzas y limpia la barra', (
    tester,
  ) async {
    final rutas = <String>[];
    await tester.pumpWidget(_app(Rol.dueno, rutas));
    await _escribir(tester, 'abre presupuesto');
    await _enviar(tester);
    expect(rutas, [Rutas.finanzas]);
    expect(_textoDelCampo(tester), isEmpty);
  });

  testWidgets('sugiere mientras se escribe y abre al tocar', (tester) async {
    final rutas = <String>[];
    await tester.pumpWidget(_app(Rol.dueno, rutas));
    await _escribir(tester, 'abre pre');
    expect(find.text('Abrir Finanzas'), findsOneWidget);
    expect(find.text('«presupuesto» → Finanzas'), findsOneWidget);
    // El panel se abre hacia arriba: la barra está abajo.
    expect(
      tester.getTopLeft(find.text('Abrir Finanzas')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    await tester.tap(find.text('Abrir Finanzas'));
    await tester.pump();
    expect(rutas, [Rutas.finanzas]);
    expect(find.text('Abrir Finanzas'), findsNothing);
  });

  testWidgets('"¿Quisiste decir…?" con un error de dedo', (tester) async {
    final rutas = <String>[];
    await tester.pumpWidget(_app(Rol.dueno, rutas));
    await _escribir(tester, 'abre presupusto');
    await _enviar(tester);
    expect(rutas, isEmpty);
    expect(find.text('¿Quisiste decir…?'), findsOneWidget);
    await tester.tap(find.text('Abrir Finanzas'));
    await tester.pump();
    expect(rutas, [Rutas.finanzas]);
  });

  testWidgets('si no entiende, ofrece lo que el rol puede abrir', (
    tester,
  ) async {
    final rutas = <String>[];
    await tester.pumpWidget(_app(Rol.familiar, rutas));
    await _escribir(tester, 'abre finanzas');
    await _enviar(tester);
    expect(rutas, isEmpty);
    expect(find.textContaining('No entendí «abre finanzas»'), findsOneWidget);
    expect(find.text('Abrir Hábitos'), findsOneWidget);
    expect(find.text('Abrir Finanzas'), findsNothing);
  });

  testWidgets('familiar: no sugiere Finanzas ni Desarrollador', (tester) async {
    await tester.pumpWidget(_app(Rol.familiar, []));
    for (final texto in ['fin', 'pre', 'din', 'des', 'abre ']) {
      await _escribir(tester, texto);
      expect(find.text('Abrir Finanzas'), findsNothing, reason: texto);
      expect(find.text('Abrir Desarrollador'), findsNothing, reason: texto);
    }
  });

  testWidgets('dueño: "desarrollador" abre Ajustes › Desarrollador', (
    tester,
  ) async {
    final rutas = <String>[];
    await tester.pumpWidget(_app(Rol.dueno, rutas));
    await _escribir(tester, 'desarrollador');
    await _enviar(tester);
    expect(rutas, [Rutas.desarrollador]);
  });

  testWidgets('flechas para elegir y Enter para abrir', (tester) async {
    final rutas = <String>[];
    await tester.pumpWidget(_app(Rol.dueno, rutas));
    await _escribir(tester, 'abre ');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await _enviar(tester);
    // Sugerencias en orden: Inicio, Finanzas, …
    expect(rutas, [Rutas.finanzas]);
  });

  testWidgets('Esc cierra y limpia', (tester) async {
    await tester.pumpWidget(_app(Rol.dueno, []));
    await _escribir(tester, 'abre pre');
    expect(find.text('Abrir Finanzas'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Abrir Finanzas'), findsNothing);
    expect(_textoDelCampo(tester), isEmpty);
  });

  testWidgets('Ctrl+K enfoca la barra', (tester) async {
    await tester.pumpWidget(_app(Rol.dueno, []));
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.focusNode!.hasFocus, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(campo.focusNode!.hasFocus, isTrue);
  });

  testWidgets('al cambiar de rol se actualizan los destinos', (tester) async {
    await tester.pumpWidget(_app(Rol.dueno, []));
    await _escribir(tester, 'fin');
    expect(find.text('Abrir Finanzas'), findsOneWidget);
    await tester.pumpWidget(_app(Rol.familiar, []));
    await tester.pump();
    expect(find.text('Abrir Finanzas'), findsNothing);
  });
}

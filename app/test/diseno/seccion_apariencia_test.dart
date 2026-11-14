import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import 'ayuda_pruebas.dart';

const _pantalla = Scaffold(
  body: SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: SeccionApariencia(),
  ),
);

void main() {
  for (final tamano in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets('se construye en ${tamano.width.toInt()} de ancho', (
      tester,
    ) async {
      fijarVentana(tester, tamano);
      await montar(tester, _pantalla);
      expect(tester.takeException(), isNull);
      expect(find.text('Futurista'), findsOneWidget);
      expect(find.text('Glass'), findsOneWidget);
      expect(find.byKey(const ValueKey('texto-sol')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('modo-automaticoPorHora')),
      );
      await tester.tap(find.byKey(const ValueKey('modo-automaticoPorHora')));
      await tester.pump();
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('19:00'), findsOneWidget);
    });
  }

  testWidgets('cambiar a "Siempre claro" cambia el tema en vivo', (
    tester,
  ) async {
    fijarVentana(tester, const Size(1440, 900));
    await montar(tester, _pantalla);
    ValoresDiseno valores() =>
        ValoresDiseno.de(tester.element(find.byType(SeccionApariencia)));
    expect(valores().brillo, Brightness.dark);

    await tester.tap(find.byKey(const ValueKey('modo-claro')));
    await tester.pump();
    await tester.pump(duracionCambioTema);
    expect(valores().brillo, Brightness.light);
    expect(valores().fondo, futuristaDia.fondo);
    // El horario solo se muestra en modo automático.
    expect(find.byKey(const ValueKey('horario-inicio')), findsNothing);
  });

  testWidgets('la personalidad por módulo se puede fijar', (tester) async {
    fijarVentana(tester, const Size(1440, 900));
    await montar(tester, _pantalla);
    expect(
      find.text('Clara y cálida · siempre en alto contraste'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('personalidad-finanzas')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Igual al estilo').last);
    await tester.pumpAndSettle();

    final c = contenedorDe(tester, find.byType(SeccionApariencia));
    expect(
      c.read(opcionesPersonalidadProvider)[Modulo.finanzas],
      OpcionPersonalidad.igualAlEstilo,
    );
    expect(
      c.read(personalidadProvider(Modulo.finanzas)),
      PersonalidadModulo.igualAlEstilo,
    );
  });
}

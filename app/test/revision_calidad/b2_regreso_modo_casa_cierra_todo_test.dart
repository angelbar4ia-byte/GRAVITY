// HALLAZGO B2 (BLOQUEANTE) · docs/revisiones/fase-0.md
//
// FALLA HOY A PROPÓSITO: demuestra el hallazgo. Pasará cuando se arregle.
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// Al regresar solo al modo Casa (2 min sin uso, D14), las hojas y diálogos
// que la persona dejó abiertos siguen encima del modo Casa: la hoja
// "Registrar" del Dueño (Gasto, Ingreso extra) queda al alcance de cualquiera
// (criterio 6). Las hojas y diálogos van en el navegador raíz, fuera del
// cascarón, y `volverAModoCasa` solo cambia la ruta del cascarón.
@Tags(['hallazgo'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../app/ayuda_plataforma.dart';

Finder enRiel(String etiqueta) => find.descendant(
  of: find.byType(NavigationRail),
  matching: find.text(etiqueta),
);

void main() {
  testWidgets('tras 2 min sin uso no queda abierta la hoja del Dueño', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.casa),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    await tester.tap(find.text('Dueño de ejemplo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-pin')), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    await tester.tap(enRiel('Registrar'));
    await tester.pumpAndSettle();
    expect(find.text('Gasto'), findsOneWidget, reason: 'la hoja se abrió');

    // Nadie toca la tablet.
    await tester.pump(const Duration(minutes: 3));
    await tester.pumpAndSettle();

    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    expect(find.text('Gasto'), findsNothing, reason: 'hoja del Dueño abierta');
    expect(find.text('Ingreso extra'), findsNothing);
  });
}

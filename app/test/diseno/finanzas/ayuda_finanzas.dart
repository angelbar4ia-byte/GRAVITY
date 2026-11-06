// Ayudas de las pruebas de los gadgets y componentes de Finanzas. No es una
// prueba (no termina en _test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../ayuda_pruebas.dart';

/// Monta [hijo] con la personalidad de Finanzas ("precisa y serena"), en una
/// columna de [ancho] dp. Por omisión, de noche y con "reducir movimiento"
/// activado para que las barras lleguen a su valor sin esperar. Los montos se
/// ven (con [montosVisibles] en falso empiezan ocultos, como en la app).
Future<void> montarEnFinanzas(
  WidgetTester tester,
  Widget hijo, {
  double ancho = 360,
  DateTime? momento,
  bool reducirMovimiento = true,
  bool montosVisibles = true,
  List<Override> overrides = const [],
}) async {
  await montar(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: reducirMovimiento),
        child: Scaffold(
          body: TemaModulo(
            modulo: Modulo.finanzas,
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: ancho, child: hijo),
              ),
            ),
          ),
        ),
      ),
    ),
    momento: momento,
    montosVisibles: montosVisibles,
    overrides: overrides,
  );
  await tester.pumpAndSettle();
}

/// Los valores de diseño que ve el widget encontrado.
ValoresDiseno valoresDe(WidgetTester tester, Finder dentroDe) =>
    ValoresDiseno.de(tester.element(dentroDe.first));

/// Color del primer texto con [texto] (busca también dentro de `Text.rich`).
Color? colorDelTexto(WidgetTester tester, String texto) {
  final widget = tester.widget<Text>(find.text(texto).first);
  return widget.style?.color ?? widget.textSpan?.style?.color;
}

/// Revisa que ninguna zona tocable del árbol mida menos de 48 × 48 dp.
void revisarZonasTactiles(WidgetTester tester, Finder dentroDe) {
  final tocables = find.descendant(
    of: dentroDe,
    matching: find.byType(InkWell),
  );
  expect(tocables, findsWidgets);
  for (final elemento in tocables.evaluate()) {
    final tamano = tester.getSize(find.byWidget(elemento.widget));
    expect(
      tamano.width >= zonaTactilMinima && tamano.height >= zonaTactilMinima,
      isTrue,
      reason: 'Zona táctil de ${tamano.width} × ${tamano.height}',
    );
  }
}

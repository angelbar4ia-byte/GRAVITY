// HALLAZGO B1 (BLOQUEANTE) · docs/revisiones/fase-0.md
//
// Prueba de regresión: el hallazgo se resolvió el 20/oct/2026 (docs/revisiones/fase-0.md, sección 11).
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// "Hoy" (teléfono y tablet) y la pantalla principal (laptop) muestran el panel
// de Finanzas (semáforo, "Quedan" con botón para mostrar el monto, "Presupuesto
// usado", aviso de la tarjeta) y el de Cuidados a roles que no ven dinero ni
// cuidados (D5, criterios 2 y 6). `resumenGravityProvider` y
// `modulosBarraProvider` no dependen del rol.
//
// La prueba existente "Familiar no ve dinero, ni por enlace directo"
// (test/app/navegacion_por_rol_test.dart) pasa en vacío: busca 'Finanzas'
// y el título se dibuja en mayúsculas ("FINANZAS · SEMANA"), además de que la
// lista de "Hoy" construye sus tarjetas de forma perezosa.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../app/ayuda_plataforma.dart';

/// Todo el texto visible, en minúsculas.
String todoElTexto(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' · ')
    .toLowerCase();

/// En el teléfono la lista de "Hoy" es perezosa: con una pantalla alta se
/// construyen todas las tarjetas.
Future<void> construirTodo(WidgetTester tester, TipoDispositivo d) async {
  if (d == TipoDispositivo.laptop) return;
  tester.view.physicalSize = Size(tamanoDe(d).width, 4000);
  await tester.pumpAndSettle();
}

const llavesDinero = ['tarjeta-finanzas', 'panel-finanzas', 'monto-quedan'];
const textosDinero = ['quedan', 'presupuesto usado', 'tarjeta de crédito'];
const llavesCuidados = ['tarjeta-cuidados', 'panel-cuidados'];
const textosCuidados = ['medicamento', 'entrega de turno'];

void revisarSinDinero(WidgetTester tester, String donde) {
  for (final llave in llavesDinero) {
    expect(find.byKey(ValueKey(llave)), findsNothing, reason: '$donde: $llave');
  }
  final texto = todoElTexto(tester);
  for (final prohibido in textosDinero) {
    expect(texto, isNot(contains(prohibido)), reason: '$donde: «$prohibido»');
  }
}

void revisarSinCuidados(WidgetTester tester, String donde) {
  for (final llave in llavesCuidados) {
    expect(find.byKey(ValueKey(llave)), findsNothing, reason: '$donde: $llave');
  }
  final texto = todoElTexto(tester);
  for (final prohibido in textosCuidados) {
    expect(texto, isNot(contains(prohibido)), reason: '$donde: «$prohibido»');
  }
}

void main() {
  for (final dispositivo in [TipoDispositivo.telefono, TipoDispositivo.laptop]) {
    testWidgets('Familiar en ${dispositivo.name}: inicio sin dinero ni cuidados', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: dispositivo,
        sesion: sesionCon(Rol.familiar),
      );
      await construirTodo(tester, dispositivo);
      revisarSinDinero(tester, 'Familiar/${dispositivo.name}');
      revisarSinCuidados(tester, 'Familiar/${dispositivo.name}');
    });

    testWidgets('Casa en ${dispositivo.name}: inicio sin dinero', (tester) async {
      await montarApp(
        tester,
        dispositivo: dispositivo,
        sesion: sesionCon(Rol.casa),
      );
      await construirTodo(tester, dispositivo);
      revisarSinDinero(tester, 'Casa/${dispositivo.name}');
    });
  }

  testWidgets('tablet: Familiar con PIN ve "Hoy" sin dinero ni cuidados', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.casa),
      almacen: await almacenConPersonas({Rol.familiar: '1234'}),
    );
    await tester.tap(find.text('Familiar de ejemplo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-pin')), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    await construirTodo(tester, TipoDispositivo.tablet);
    revisarSinDinero(tester, 'Familiar/tablet');
    revisarSinCuidados(tester, 'Familiar/tablet');
  });

  testWidgets('laptop: la barra de módulos solo ofrece lo que el rol abre', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.familiar),
    );
    expect(find.byKey(const ValueKey('modulo-finanzas')), findsNothing);
    expect(find.byKey(const ValueKey('modulo-cuidados')), findsNothing);
  });

  testWidgets('laptop: la cuenta Casa no ve Finanzas, Hábitos ni Ajustes', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.casa),
    );
    expect(find.byKey(const ValueKey('modulo-finanzas')), findsNothing);
    expect(find.byKey(const ValueKey('modulo-habitos')), findsNothing);
    expect(find.byKey(const ValueKey('modulo-ajustes')), findsNothing);
  });
}

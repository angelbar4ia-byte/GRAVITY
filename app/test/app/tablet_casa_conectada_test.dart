// F8-7.1, grupo 3: la hoja "Registrar" de la tablet de la casa ya no promete
// fases. "Algo de Cuidados" entra con nombre y PIN al turno de la persona;
// "Lista de compras" y "Recordatorio de la casa" quedan pendientes (la cuenta
// Casa no tiene permiso en Alimentación ni escribe en Cuidados) y lo dicen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/tablet/pantalla_modo_casa.dart';
import 'package:gravity/app/tablet/registro_tablet_casa.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

import 'ayuda_plataforma.dart';
import 'tablet_tipos_test.dart'
    show escribirPin, estadoTablet, id, montarPublica, ubicacion;

Future<void> abrirRegistrar(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('registrar-tablet-casa')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('las acciones de la casa dicen que aún no están, sin fase', (
    tester,
  ) async {
    await montarPublica(tester);
    await abrirRegistrar(tester);
    for (final accion in accionesDeLaCasa) {
      expect(find.text(accion.etiqueta), findsOneWidget);
    }
    expect(find.text('Aún no disponible aquí'), findsNWidgets(2));
    await tester.tap(find.text('Lista de compras'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('La lista de compras todavía no se puede usar'),
      findsOneWidget,
    );
    // Sin sesión de nadie y sin registrar nada.
    expect(estadoTablet(tester).usuarioActivo, isNull);
    expect(find.textContaining('llega en la Fase'), findsNothing);
  });

  testWidgets('el recordatorio de la casa tampoco promete una fase', (
    tester,
  ) async {
    await montarPublica(tester);
    await abrirRegistrar(tester);
    await tester.tap(find.text('Recordatorio de la casa'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Los recordatorios de la casa todavía no'),
      findsOneWidget,
    );
    expect(find.textContaining('llega en la Fase'), findsNothing);
  });

  testWidgets('Algo de Cuidados: nombre, PIN y llega al turno de la persona', (
    tester,
  ) async {
    await montarPublica(tester);
    await abrirRegistrar(tester);
    await tester.tap(find.byKey(const ValueKey('casa-personal-cuidados')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('elegir-nombre')), findsOneWidget);
    // Solo quien puede registrar en Cuidados (el dueño; el familiar no).
    expect(find.byKey(ValueKey('nombre-${id(Rol.familiar)}')), findsNothing);
    await tester.tap(find.byKey(ValueKey('nombre-${id(Rol.dueno)}')));
    await tester.pumpAndSettle();
    await escribirPin(tester, '246813');
    expect(ubicacion(tester), Rutas.cuidados);
    expect(find.byType(PantallaModoCasa), findsNothing);
    expect(estadoTablet(tester).usuarioActivo?.personaId, id(Rol.dueno));
  });

  testWidgets('Algo de Cuidados con PIN equivocado no entra', (tester) async {
    await montarPublica(tester);
    await abrirRegistrar(tester);
    await tester.tap(find.byKey(const ValueKey('casa-personal-cuidados')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('nombre-${id(Rol.dueno)}')));
    await tester.pumpAndSettle();
    await escribirPin(tester, '000000');
    expect(find.text('PIN incorrecto.'), findsOneWidget);
    expect(estadoTablet(tester).usuarioActivo, isNull);
    expect(ubicacion(tester), isNot(Rutas.cuidados));
  });

  testWidgets('sin nadie que pueda registrar en Cuidados, no se ofrece', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.casa),
      almacen: await almacenConPersonas({Rol.familiar: '3333'}),
    );
    await abrirRegistrar(tester);
    expect(find.byKey(const ValueKey('casa-personal-cuidados')), findsNothing);
  });

  testWidgets('las tarjetas de la tablet no prometen fases', (tester) async {
    await montarPublica(tester);
    for (final contexto in ['General', 'Cocina', 'Gimnasio', 'Cuidados']) {
      await tester.tap(find.widgetWithText(ChoiceChip, contexto));
      await tester.pumpAndSettle();
      expect(textoVisible(tester), isNot(contains('fase')), reason: contexto);
    }
  });
}

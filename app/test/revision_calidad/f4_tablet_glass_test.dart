// REVISIÓN DE CALIDAD · FASE 4 (docs/revisiones/fase-4.md) · D14 con Glass.
//
// La tablet pública (modo Casa) no muestra dinero, datos clínicos ni nada de
// Hábitos con ningún estilo, y el estilo de la persona que entra con su PIN
// solo se aplica después del PIN: al volver al modo Casa (2 minutos sin uso)
// regresa el de la casa.
//
// Excluir los hallazgos: flutter test --exclude-tags hallazgo
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../app/ayuda_plataforma.dart';

Finder enRiel(String etiqueta) => find.descendant(
  of: find.byType(NavigationRail),
  matching: find.text(etiqueta),
);

ProviderContainer _c(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppGravity)));

void _sinDineroNiHabitos(WidgetTester tester, {required String donde}) {
  expect(find.byType(MontoOcultable), findsNothing, reason: donde);
  expect(find.textContaining(r'$'), findsNothing, reason: donde);
  for (final palabra in [
    'Hábitos',
    'Finanzas',
    'Alzheimer',
    'Papá',
    'Medicamento',
  ]) {
    // El riel y el selector de contexto no deben nombrar módulos reservados.
    expect(find.text(palabra), findsNothing, reason: '$donde · $palabra');
  }
}

void main() {
  testWidgets(
    'modo Casa con Glass (noche y día): sin dinero, sin Hábitos, sin perfil clínico',
    (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: sesionCon(Rol.casa),
        almacen: await almacenConPersonas({Rol.dueno: '246813'}),
      );
      final c = _c(tester);
      for (final modo in [ModoClaroOscuro.oscuro, ModoClaroOscuro.claro]) {
        c.read(estiloProvider.notifier).elegir(estiloGlass);
        c.read(preferenciaClaroOscuroProvider.notifier).cambiarModo(modo);
        await tester.pumpAndSettle();
        expect(find.text('GRAVITY · Casa'), findsOneWidget);
        _sinDineroNiHabitos(tester, donde: 'Glass ${modo.name}');
      }
    },
  );

  testWidgets(
    'el estilo de la persona se aplica después del PIN y al volver a Casa '
    'regresa el de la casa',
    (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: sesionCon(Rol.casa),
        almacen: await almacenConPersonas({Rol.dueno: '246813'}),
      );
      final c = _c(tester);
      expect(c.read(estiloProvider).id, 'futurista');

      await tester.tap(find.text('Dueño de ejemplo'));
      await tester.pumpAndSettle();
      // Con el PIN pedido todavía no hay estilo de la persona.
      expect(c.read(estiloProvider).id, 'futurista');
      await tester.enterText(find.byKey(const Key('campo-pin')), '246813');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      c.read(estiloProvider.notifier).elegir(estiloGlass);
      await tester.pumpAndSettle();
      expect(c.read(estiloProvider).id, 'glass');
      expect(enRiel('Finanzas'), findsOneWidget);

      // Nadie toca la tablet: vuelve la casa, con su estilo y sin dinero.
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(find.text('GRAVITY · Casa'), findsOneWidget);
      expect(
        c.read(estiloProvider).id,
        'futurista',
        reason: 'el estilo del dueño no se queda en la tablet pública',
      );
      _sinDineroNiHabitos(tester, donde: 'después de volver a Casa');
    },
  );

  // Guardia: el modo Casa de la tablet no ofrece Alimentación en su riel (el
  // hallazgo F4-A2 de f4_alimentacion_test.dart es la RUTA, que sí se abre).
  testWidgets('el riel de la tablet pública no lista Alimentación', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.casa),
      almacen: await almacenConPersonas({Rol.dueno: '246813'}),
    );
    expect(enRiel('Alimentación'), findsNothing);
  });
}

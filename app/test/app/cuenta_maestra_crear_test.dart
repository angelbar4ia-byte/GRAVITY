// Ajustes › Personas › "Crear cuenta maestra" (D19, 23/oct/2026): el dueño
// invita un correo; la app muestra el código una sola vez.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/invitaciones/invitaciones.dart';

import 'ayuda_plataforma.dart';

Future<void> irAPersonas(WidgetTester tester) async {
  ProviderScope.containerOf(
    tester.element(find.byType(AppGravity)),
  ).read(routerProvider).go('/ajustes/personas');
  await tester.pumpAndSettle();
}

void main() {
  final ahora = DateTime(2026, 10, 24, 12);

  testWidgets('el dueño crea la cuenta maestra y ve el código', (tester) async {
    final repo = RepositorioInvitacionesEnMemoria(reloj: () => ahora);
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.dueno),
      extras: [repositorioInvitacionesProvider.overrideWithValue(repo)],
    );
    await irAPersonas(tester);
    expect(find.byKey(const ValueKey('seccion-cuenta-maestra')), findsOneWidget);
    expect(find.text('Aún no hay cuenta maestra'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('crear-cuenta-maestra')));
    await tester.pumpAndSettle();
    // Un correo mal escrito no se manda.
    await tester.enterText(find.byKey(const ValueKey('correo-maestra')), 'no-es-un-correo');
    await tester.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    expect(await repo.pendientes('x'), isEmpty);

    await tester.enterText(find.byKey(const ValueKey('correo-maestra')), 'maestra@ejemplo.test');
    await tester.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await tester.pumpAndSettle();
    // El código se ve una vez, con lo que hay que hacer.
    expect(find.text('Invitación creada'), findsOneWidget);
    expect(find.byKey(const ValueKey('codigo-invitacion')), findsOneWidget);
    expect(find.textContaining('una sola'), findsOneWidget);
    expect(find.textContaining('no se manda por correo'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Listo'));
    await tester.pumpAndSettle();
    expect(find.text('maestra@ejemplo.test'), findsOneWidget);
    expect(find.textContaining('Invitación pendiente'), findsOneWidget);
    // El código ya no se puede volver a ver.
    expect(find.byKey(const ValueKey('codigo-invitacion')), findsNothing);
  });

  testWidgets('copiar el código lo deja en el portapapeles', (tester) async {
    final repo = RepositorioInvitacionesEnMemoria(reloj: () => ahora);
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (llamada) async {
        if (llamada.method == 'Clipboard.setData') {
          copiado = (llamada.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.dueno),
      extras: [repositorioInvitacionesProvider.overrideWithValue(repo)],
    );
    await irAPersonas(tester);
    await tester.tap(find.byKey(const ValueKey('crear-cuenta-maestra')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('correo-maestra')), 'maestra@ejemplo.test');
    await tester.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copiar-codigo')));
    await tester.pumpAndSettle();
    expect(copiado, startsWith('token-de-ejemplo-'));
  });

  testWidgets('un correo que ya es del hogar se rechaza con el motivo', (tester) async {
    final repo = RepositorioInvitacionesEnMemoria(
      reloj: () => ahora,
      correosDeMiembros: {'dueno@ejemplo.test'},
    );
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.dueno),
      extras: [repositorioInvitacionesProvider.overrideWithValue(repo)],
    );
    await irAPersonas(tester);
    await tester.tap(find.byKey(const ValueKey('crear-cuenta-maestra')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('correo-maestra')), 'dueno@ejemplo.test');
    await tester.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('es otra persona'), findsOneWidget);
    expect(find.text('Invitación creada'), findsNothing);
  });

  testWidgets('se ve quién es la maestra y se puede revocar una invitación', (
    tester,
  ) async {
    final repo = RepositorioInvitacionesEnMemoria(
      reloj: () => ahora,
      maestra: const CuentaMaestraActual(personaId: 'p', nombre: 'Marta (ejemplo)'),
    );
    await repo.crearCuentaMaestra(hogarId: 'h', correo: 'otra@ejemplo.test');
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.dueno),
      extras: [repositorioInvitacionesProvider.overrideWithValue(repo)],
    );
    await irAPersonas(tester);
    expect(find.text('Marta (ejemplo)'), findsOneWidget);
    expect(find.text('otra@ejemplo.test'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Revocar'));
    await tester.pumpAndSettle();
    expect(find.text('otra@ejemplo.test'), findsNothing);
    expect(repo.revocadas, hasLength(1));
  });

  testWidgets('sin señal lo dice y no deja a medias', (tester) async {
    final repo = RepositorioInvitacionesEnMemoria(reloj: () => ahora)
      ..sinConexion = true;
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.dueno),
      extras: [repositorioInvitacionesProvider.overrideWithValue(repo)],
    );
    await irAPersonas(tester);
    expect(find.byKey(const ValueKey('maestra-error')), findsOneWidget);
    expect(find.textContaining('Sin conexión'), findsOneWidget);
  });

  testWidgets('quien no es el dueño no ve Personas (ni la cuenta maestra)', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.coadministrador),
    );
    await irAPersonas(tester);
    expect(find.byKey(const ValueKey('seccion-cuenta-maestra')), findsNothing);
  });
}

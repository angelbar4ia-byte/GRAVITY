// D18 (21/oct/2026): la cuidadora ve Cuidados y su bandeja "Solicitudes de
// GRAVITY" (recordatorios y solicitudes que confirma con Hecho o No se pudo,
// con nota). No conversa con GRAVITY y no ve nada de la familia.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/pantallas/pantalla_solicitudes.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/solicitudes/solicitudes.dart';

import 'ayuda_plataforma.dart';

ProviderContainer contenedorDe(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

String ubicacion(WidgetTester tester) =>
    contenedorDe(tester)
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

Future<void> ir(WidgetTester tester, String ruta) async {
  contenedorDe(tester).read(routerProvider).go(ruta);
  await tester.pumpAndSettle();
}

Finder pestana(String etiqueta) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(etiqueta),
);

Finder enRiel(String etiqueta) => find.descendant(
  of: find.byType(NavigationRail),
  matching: find.text(etiqueta),
);

/// Nada de la familia: ni dinero, ni hábitos, ni menús, ni GRAVITY para
/// conversar.
void revisarSinNadaDeLaFamilia(WidgetTester tester) {
  revisarSinDinero(tester);
  final texto = textoVisible(tester);
  // ("gastos de cuidado" sí son de su turno: Fase 5.)
  for (final prohibido in ['hábito', 'menú', 'presupuesto', 'ingreso']) {
    expect(texto, isNot(contains(prohibido)), reason: prohibido);
  }
  expect(find.byTooltip('Hablar con GRAVITY'), findsNothing);
}

void main() {
  group('modelo', () {
    final base = solicitudesDeEjemplo(DateTime(2026, 10, 21)).first;
    final en = DateTime(2026, 10, 21, 9, 5);

    test('Hecho no pide nota; No se pudo sí', () {
      expect(
        base.confirmar(EstadoSolicitud.hecha, en: en).estado,
        EstadoSolicitud.hecha,
      );
      expect(
        () => base.confirmar(EstadoSolicitud.noSePudo, nota: '  ', en: en),
        throwsArgumentError,
      );
      final noSePudo = base.confirmar(
        EstadoSolicitud.noSePudo,
        nota: ' No quiso. ',
        en: en,
      );
      expect(noSePudo.nota, 'No quiso.');
      expect(noSePudo.confirmadaEn, en);
      expect(noSePudo.reabrir().pendiente, isTrue);
    });

    test('la nota no pasa de 200 caracteres y "pendiente" no confirma', () {
      expect(
        () => base.confirmar(
          EstadoSolicitud.hecha,
          nota: 'x' * (largoMaximoNota + 1),
          en: en,
        ),
        throwsArgumentError,
      );
      expect(
        () => base.confirmar(EstadoSolicitud.pendiente, en: en),
        throwsArgumentError,
      );
    });

    test('los ejemplos no traen nombres ni medicamentos', () {
      for (final s in solicitudesDeEjemplo(DateTime(2026, 10, 21))) {
        final texto = '${s.titulo} ${s.detalle ?? ''}'.toLowerCase();
        for (final prohibido in ['medicamento', 'mg', 'papá', 'pastilla']) {
          expect(texto, isNot(contains(prohibido)), reason: s.titulo);
        }
      }
    });
  });

  testWidgets('teléfono: confirma con Hecho y No se pudo (con nota)', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.cuidador),
    );
    expect(ubicacion(tester), Rutas.cuidados);
    await tester.tap(pestana('Solicitudes'));
    await tester.pumpAndSettle();
    expect(ubicacion(tester), RutasApp.solicitudes);
    expect(find.text('Solicitudes de GRAVITY'), findsOneWidget);
    expect(find.text('4 pendientes', skipOffstage: false), findsOneWidget);

    // Hecho: un toque.
    await tester.tap(find.byKey(const ValueKey('hecho-ejemplo-1')));
    await tester.pumpAndSettle();
    expect(find.text('Hecho a las 10:00'), findsOneWidget);
    expect(find.text('3 pendientes', skipOffstage: false), findsOneWidget);

    // No se pudo: pide la nota.
    await tester.ensureVisible(
      find.byKey(const ValueKey('no-se-pudo-ejemplo-2')),
    );
    await tester.tap(find.byKey(const ValueKey('no-se-pudo-ejemplo-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe por qué no se pudo.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('nota-solicitud')),
      'Llovió toda la tarde.',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo: Llovió toda la tarde.'), findsOneWidget);
    expect(find.text('2 pendientes', skipOffstage: false), findsOneWidget);

    // Deshacer la vuelve a pendiente.
    final deshacer = find.descendant(
      of: find.byKey(const ValueKey('solicitud-ejemplo-1')),
      matching: find.text('Deshacer'),
    );
    // De vuelta arriba de la lista.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(deshacer);
    await tester.pumpAndSettle();
    expect(
      contenedorDe(tester).read(solicitudesProvider).where((s) => s.pendiente),
      hasLength(3),
    );
    expect(find.byKey(const ValueKey('hecho-ejemplo-1')), findsOneWidget);
    revisarSinNadaDeLaFamilia(tester);
  });

  testWidgets('teléfono: nada de la familia ni GRAVITY para conversar', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.cuidador),
    );
    final etiquetas = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(etiquetas, isNot(contains('Hoy')));
    expect(etiquetas, isNot(contains('Finanzas')));
    expect(etiquetas, isNot(contains('Hábitos')));
    expect(etiquetas, isNot(contains('Registrar')));
    revisarSinNadaDeLaFamilia(tester);

    for (final ruta in [
      Rutas.inicio,
      Rutas.finanzas,
      Rutas.habitos,
      Rutas.alimentacion,
      Rutas.casa,
    ]) {
      await ir(tester, ruta);
      expect(ubicacion(tester), Rutas.cuidados, reason: ruta);
    }
  });

  testWidgets('las solicitudes de la cuidadora no se ven en otra sesión', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
    );
    await ir(tester, RutasApp.solicitudes);
    expect(ubicacion(tester), RutasApp.solicitudes);
    expect(find.text('Sin solicitudes por ahora.'), findsOneWidget);
    expect(find.byKey(const ValueKey('solicitud-ejemplo-1')), findsNothing);
  });

  testWidgets('tablet: con su PIN ve su bandeja; al salir, nadie más la ve', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.casa),
      almacen: await almacenConPersonas({
        Rol.cuidador: '5678',
        Rol.dueno: '246813',
      }),
    );
    // Modo Casa: sin las solicitudes de nadie.
    expect(find.textContaining('Ofrecer agua'), findsNothing);

    Future<void> entrar(String nombre, String pin) async {
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo-pin')), pin);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();
    }

    await entrar('Cuidadora de ejemplo', '5678');
    await tester.tap(enRiel('Solicitudes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('solicitud-ejemplo-1')), findsOneWidget);
    revisarSinNadaDeLaFamilia(tester);

    await tester.tap(find.byTooltip('Volver al modo Casa'));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    expect(find.textContaining('Ofrecer agua'), findsNothing);

    await entrar('Dueño de ejemplo', '246813');
    await ir(tester, RutasApp.solicitudes);
    expect(find.text('Sin solicitudes por ahora.'), findsOneWidget);
  });
}

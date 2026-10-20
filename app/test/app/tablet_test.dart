import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

import 'ayuda_plataforma.dart';

const nombreDueno = 'Dueño de ejemplo';
const nombreCuidadora = 'Cuidadora de ejemplo';

GoRouter routerDe(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AppGravity)),
).read(routerProvider);

String ubicacion(WidgetTester tester) =>
    routerDe(tester).routerDelegate.currentConfiguration.uri.path;

Finder enRiel(String etiqueta) => find.descendant(
  of: find.byType(NavigationRail),
  matching: find.text(etiqueta),
);

/// La tablet entra con la cuenta Casa.
ServicioSesionFalso sesionCasa() => sesionCon(Rol.casa);

Future<void> entrarConPin(
  WidgetTester tester,
  String nombre,
  String pin,
) async {
  await tester.tap(find.text(nombre));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('campo-pin')), pin);
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('modo Casa por omisión: contextos, personas y sin dinero', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.dueno), // aun con la cuenta del Dueño
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    for (final contexto in contextosCasa) {
      expect(find.text(contexto.nombre), findsWidgets);
    }
    expect(find.text('¿Quién usa la tablet?'), findsOneWidget);
    expect(find.text(nombreDueno), findsOneWidget);
    expect(find.text('Mantén para hablar'), findsOneWidget);
    expect(find.textContaining('Finanzas'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);

    await tester.tap(find.text('Cocina'));
    await tester.pumpAndSettle();
    expect(find.text('Receta paso a paso'), findsOneWidget);

    routerDe(tester).go(Rutas.finanzas);
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.inicio);
  });

  testWidgets('PIN abre las pantallas de la persona; PIN incorrecto no', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    await entrarConPin(tester, nombreDueno, '9999');
    expect(find.text('PIN incorrecto.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);

    await entrarConPin(tester, nombreDueno, '1234');
    expect(find.text('GRAVITY · Casa'), findsNothing);
    expect(enRiel('Finanzas'), findsOneWidget);
    expect(enRiel('Hábitos'), findsOneWidget);
    await tester.tap(enRiel('Finanzas'));
    await tester.pumpAndSettle();
    expect(find.text('Finanzas llega en la Fase 1.'), findsOneWidget);
  });

  testWidgets('la cuidadora entra a Mi turno y solo ve Cuidados', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({
        Rol.dueno: '1234',
        Rol.cuidador: '5678',
      }),
    );
    await entrarConPin(tester, nombreCuidadora, '5678');
    expect(ubicacion(tester), Rutas.cuidados);
    final etiquetas = tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .destinations
        .map((d) => (d.label as Text).data)
        .toList();
    expect(etiquetas, ['Mi turno', 'Medicamentos', 'Comidas', 'Bitácora']);
  });

  testWidgets('regresa sola al modo Casa tras 2 minutos sin uso', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    await entrarConPin(tester, nombreDueno, '1234');
    await tester.tap(enRiel('Finanzas'));
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.finanzas);

    // Un toque a los 90 s reinicia la cuenta.
    await tester.pump(const Duration(seconds: 90));
    await tester.tap(find.text('Finanzas llega en la Fase 1.'));
    await tester.pump(const Duration(seconds: 90));
    expect(find.text('GRAVITY · Casa'), findsNothing);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    expect(ubicacion(tester), Rutas.inicio);
    expect(find.textContaining('Finanzas'), findsNothing);
  });

  testWidgets('el tiempo de regreso es configurable', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas(
        {Rol.familiar: '1234'},
        configuracion: const ConfiguracionTablet(
          regresoModoCasa: Duration(seconds: 30),
        ),
      ),
    );
    await entrarConPin(tester, 'Familiar de ejemplo', '1234');
    expect(find.text('GRAVITY · Casa'), findsNothing);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
  });

  testWidgets('en modo Casa no corre el temporizador', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    await tester.tap(find.text('Alimentación'));
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.alimentacion);
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.alimentacion);
  });

  testWidgets('volver al modo Casa a mano', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    await entrarConPin(tester, nombreDueno, '1234');
    await tester.tap(find.byTooltip('Volver al modo Casa'));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
  });

  testWidgets('huella opcional', (tester) async {
    final biometria = BiometriaFalsa();
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      biometria: biometria,
      almacen: await almacenConPersonas(
        {Rol.dueno: '1234'},
        conHuella: {Rol.dueno},
      ),
    );
    await tester.tap(find.text(nombreDueno));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar huella'));
    await tester.pumpAndSettle();
    expect(biometria.intentos, 1);
    expect(enRiel('Finanzas'), findsOneWidget);
  });

  testWidgets('agregar persona con su correo y contraseña', (tester) async {
    final sesion = ServicioSesionFalso(
      inicial: sesionDeEjemplo(Rol.casa),
      cuentas: {
        'ana@ejemplo.test': CuentaFalsa('clave', sesionDeEjemplo(Rol.cuidador)),
      },
    );
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesion,
    );
    expect(find.text('Aún no hay personas en esta tablet.'), findsOneWidget);
    await tester.tap(find.text('Agregar persona'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('agregar-correo')), 'ana@ejemplo.test');
    await tester.enterText(find.byKey(const Key('agregar-contrasena')), 'mala');
    await tester.enterText(find.byKey(const Key('agregar-pin')), '2468');
    await tester.enterText(find.byKey(const Key('agregar-confirmacion')), '2468');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('agregar-contrasena')), 'clave');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(find.text(nombreCuidadora), findsOneWidget);
    expect(sesion.sesionActual?.rol, Rol.casa);

    await entrarConPin(tester, nombreCuidadora, '2468');
    expect(ubicacion(tester), Rutas.cuidados);
  });

  testWidgets('vertical: modo Casa y riel sin desbordes', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    tester.view.physicalSize = const Size(800, 1280);
    await tester.pumpAndSettle();
    expect(find.text('¿Quién usa la tablet?'), findsOneWidget);
    await entrarConPin(tester, nombreDueno, '1234');
    expect(enRiel('Finanzas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

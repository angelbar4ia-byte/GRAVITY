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
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    for (final contexto in contextosCasa) {
      expect(find.text(contexto.nombre), findsWidgets);
    }
    expect(find.text('¿Quién usa la tablet?'), findsOneWidget);
    expect(find.text(nombreDueno), findsOneWidget);
    expect(find.text('Mantén para hablar'), findsOneWidget);
    revisarSinDinero(tester);

    await tester.tap(find.text('Cocina'));
    await tester.pumpAndSettle();
    expect(find.text('Receta paso a paso'), findsOneWidget);

    routerDe(tester).go(Rutas.finanzas);
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.inicio);
  });

  // D14 (revisión de la Fase 0, I6): la tablet trabaja con la cuenta de rol
  // Casa. Antes esta prueba mostraba el modo Casa "aun con la cuenta del
  // Dueño"; ahora con otra cuenta no se presenta el modo Casa: se pide la
  // cuenta de la casa.
  testWidgets('con la cuenta del Dueño pide la cuenta Casa', (tester) async {
    final sesion = sesionCon(Rol.dueno);
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesion,
      almacen: await almacenConPersonas({Rol.familiar: '1234'}),
    );
    expect(find.text('GRAVITY · Casa'), findsNothing);
    expect(ubicacion(tester), Rutas.entrar);
    expect(find.byKey(const ValueKey('aviso-cuenta-casa')), findsOneWidget);
    expect(find.text('Entra con la cuenta Casa'), findsOneWidget);
    revisarSinDinero(tester);

    // Ni por enlace directo.
    routerDe(tester).go(Rutas.finanzas);
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.entrar);

    await tester.tap(find.text('Cerrar la cuenta de $nombreDueno'));
    await tester.pumpAndSettle();
    expect(sesion.sesionActual, isNull);
    expect(find.byKey(const ValueKey('aviso-cuenta-casa')), findsNothing);
  });

  testWidgets('I6: con el PIN, la sesión del servidor es la de la persona', (
    tester,
  ) async {
    final sesion = sesionCasa();
    final casa = sesionDeEjemplo(Rol.casa).persona.id;
    final dueno = sesionDeEjemplo(Rol.dueno).persona.id;
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesion,
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    expect(sesion.personaEnServidor, casa);
    await entrarConPin(tester, nombreDueno, '1234');
    expect(enRiel('Finanzas'), findsOneWidget);
    expect(sesion.personaEnServidor, dueno);
    expect(sesion.sesionActual?.rol, Rol.casa, reason: 'la cuenta del equipo');

    await tester.pump(const Duration(minutes: 3));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    expect(sesion.personaEnServidor, casa);
  });

  testWidgets('I6: sin su cuenta guardada, la persona no entra', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas(
        {Rol.dueno: '1234'},
        conCredencial: false,
      ),
    );
    await entrarConPin(tester, nombreDueno, '1234');
    expect(find.textContaining('Falta tu cuenta en esta tablet'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
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
    expect(ubicacion(tester), Rutas.finanzas);
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
    expect(etiquetas, [
      'Mi turno',
      'Solicitudes',
      'Medicamentos',
      'Comidas',
      'Bitácora',
    ]);
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
    await tester.tap(enRiel('Finanzas'));
    await tester.pump(const Duration(seconds: 90));
    expect(find.text('GRAVITY · Casa'), findsNothing);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    expect(ubicacion(tester), Rutas.inicio);
    revisarSinDinero(tester);
  });

  testWidgets('B2: al volver a Casa se cierran sus menús y diálogos', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    await entrarConPin(tester, nombreDueno, '1234');
    // El Dueño abre el menú de su cuenta y se va.
    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('$nombreDueno · Dueño'), findsOneWidget);
    await tester.pump(const Duration(minutes: 3));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    expect(find.text('$nombreDueno · Dueño'), findsNothing);

    // Lo mismo con un diálogo, al volver a mano desde el riel.
    await entrarConPin(tester, nombreDueno, '1234');
    await tester.tap(enRiel('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar la sesión de la tablet'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar la sesión de la tablet?'), findsOneWidget);
    await tester.pump(const Duration(minutes: 3));
    await tester.pumpAndSettle();
    expect(find.text('GRAVITY · Casa'), findsOneWidget);
    expect(find.text('¿Cerrar la sesión de la tablet?'), findsNothing);
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

  // B3: la tablet compartida se abre solo con PIN (la huella no dice de
  // quién es). Aunque una versión anterior la hubiera activado, no se ofrece.
  testWidgets('B3: sin huella en la tablet, solo PIN', (tester) async {
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
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    await tester.tap(find.text(nombreDueno));
    await tester.pumpAndSettle();
    expect(find.text('Usar huella'), findsNothing);
    expect(find.byKey(const Key('campo-pin')), findsOneWidget);
    expect(biometria.intentos, 0);
  });

  testWidgets('I2: tras 5 PIN incorrectos dice cuánto esperar', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCasa(),
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    await tester.tap(find.text(nombreDueno));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byKey(const Key('campo-pin')), '9999');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Demasiados intentos. Espera 30 segundos.'),
      findsOneWidget,
    );
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

  testWidgets('M9: agregar persona no acepta un PIN trivial', (tester) async {
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
    await tester.tap(find.text('Agregar persona'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('agregar-correo')), 'ana@ejemplo.test');
    await tester.enterText(find.byKey(const Key('agregar-contrasena')), 'clave');
    for (final (pin, texto) in [
      ('1234', 'Ese PIN es una secuencia'),
      ('0000', 'Ese PIN repite el mismo número'),
      ('1212', 'Ese PIN repite un mismo bloque'),
    ]) {
      await tester.enterText(find.byKey(const Key('agregar-pin')), pin);
      await tester.enterText(find.byKey(const Key('agregar-confirmacion')), pin);
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();
      expect(find.textContaining(texto), findsOneWidget, reason: pin);
      expect(find.text(nombreCuidadora), findsNothing, reason: 'no se agregó');
    }
    expect(sesion.vecesVerificar, 0, reason: 'ni siquiera se consultó al servidor');

    // Con un PIN que no es trivial, sí.
    await tester.enterText(find.byKey(const Key('agregar-pin')), '2846');
    await tester.enterText(find.byKey(const Key('agregar-confirmacion')), '2846');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(find.text(nombreCuidadora), findsOneWidget);
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

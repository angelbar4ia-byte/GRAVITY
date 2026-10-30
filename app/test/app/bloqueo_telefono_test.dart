// Bloqueo del teléfono con PIN o huella (revisión de la Fase 0, I8).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/bloqueo.dart';
import 'package:gravity/nucleo/seguridad/pin_de_montos.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import 'ayuda_plataforma.dart';

const pantallaBloqueo = ValueKey('pantalla-bloqueo');

/// Almacén con el bloqueo del Dueño ya configurado (PIN 246813).
AlmacenSeguroEnMemoria almacenConBloqueo({bool huella = false}) =>
    AlmacenSeguroEnMemoria({
      ControladorBloqueo.claveConfiguracion(
        sesionDeEjemplo(Rol.dueno).persona.id,
      ): jsonEncode(
        ConfiguracionBloqueo(
          hashPin: hashDePrueba('246813'),
          huella: huella,
        ).aJson(),
      ),
    });

/// Almacén con el bloqueo de [rol] como estaba antes de la regla de 6 dígitos
/// (D18, 23/oct): PIN de 4 dígitos, 2468.
AlmacenSeguroEnMemoria almacenConBloqueoAnterior(Rol rol) =>
    AlmacenSeguroEnMemoria({
      ControladorBloqueo.claveConfiguracion(sesionDeEjemplo(rol).persona.id):
          jsonEncode(ConfiguracionBloqueo(hashPin: hashDePrueba('2468')).aJson()),
    });

Future<void> escribirPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.byKey(const Key('campo-pin-bloqueo')), pin);
  await tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
  await tester.pumpAndSettle();
}

void main() {
  late DateTime ahora;

  setUp(() => ahora = DateTime(2026, 10, 20, 9));

  testWidgets('al abrir pide el PIN y no deja ver nada antes', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      almacen: almacenConBloqueo(),
      extras: [relojSeguridadProvider.overrideWithValue(() => ahora)],
    );
    expect(find.byKey(pantallaBloqueo), findsOneWidget);
    expect(find.text('GRAVITY está bloqueado'), findsOneWidget);
    // Lo de abajo no recibe toques.
    await tester.tap(find.text('Hábitos').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(pantallaBloqueo), findsOneWidget);

    await escribirPin(tester, '0000');
    expect(find.text('PIN incorrecto.'), findsOneWidget);
    await escribirPin(tester, '246813');
    expect(find.byKey(pantallaBloqueo), findsNothing);
    expect(find.text('Hoy'), findsWidgets);
  });

  testWidgets('tras 1 minuto en segundo plano vuelve a pedirlo', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      almacen: almacenConBloqueo(),
      extras: [relojSeguridadProvider.overrideWithValue(() => ahora)],
    );
    await escribirPin(tester, '246813');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    ahora = ahora.add(const Duration(seconds: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(pantallaBloqueo), findsNothing, reason: 'solo 20 s');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    ahora = ahora.add(const Duration(minutes: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(pantallaBloqueo), findsOneWidget);
  });

  testWidgets('con huella activada se puede abrir con la huella', (tester) async {
    final biometria = BiometriaFalsa();
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      almacen: almacenConBloqueo(huella: true),
      biometria: biometria,
    );
    await tester.tap(find.text('Usar huella'));
    await tester.pumpAndSettle();
    expect(biometria.intentos, 1);
    expect(find.byKey(pantallaBloqueo), findsNothing);
  });

  testWidgets('olvidé mi PIN: cierra la sesión y quita el bloqueo', (tester) async {
    final sesion = sesionCon(Rol.dueno);
    final almacen = almacenConBloqueo();
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesion,
      almacen: almacen,
    );
    await tester.tap(find.text('Olvidé mi PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(sesion.sesionActual, isNull);
    expect(find.byKey(pantallaBloqueo), findsNothing);
    expect(almacen.datos.keys.where((k) => k.startsWith('bloqueo.0')), isEmpty);
  });

  testWidgets('"Olvidé mi PIN" borra también el PIN propio de los montos: quien '
      'vuelve a entrar con su correo empieza de cero', (tester) async {
    final dueno = sesionDeEjemplo(Rol.dueno);
    final almacen = almacenConBloqueo();
    almacen.datos[claveConfiguracionMontos(dueno.persona.id)] =
        jsonEncode({'hash_pin': hashDePrueba('246813')});
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      almacen: almacen,
    );
    await tester.tap(find.text('Olvidé mi PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(await leerPinPropioDeMontos(almacen, dueno.persona.id), isNull);
  });

  testWidgets('solo en el teléfono: ni la tablet ni la laptop lo muestran', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.dueno),
      almacen: almacenConBloqueo(),
    );
    expect(find.byKey(pantallaBloqueo), findsNothing);
  });

  testWidgets('M9: el PIN del teléfono no puede ser trivial', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      extras: [relojSeguridadProvider.overrideWithValue(() => ahora)],
    );
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bloqueo-activo')));
    await tester.pumpAndSettle();
    // D18 (23/oct): el dueño usa 6 dígitos; uno de 4 no se acepta, trivial o no.
    for (final (pin, texto) in [
      ('7382', 'El PIN es de 6 dígitos.'),
      ('1234', 'El PIN es de 6 dígitos.'),
      ('123456', 'Ese PIN es una secuencia'),
      ('777777', 'repite el mismo número'),
    ]) {
      await tester.enterText(find.byKey(const Key('bloqueo-pin')), pin);
      await tester.enterText(find.byKey(const Key('bloqueo-confirmacion')), pin);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining(texto), findsOneWidget, reason: pin);
      expect(find.text('Bloquear tras'), findsNothing, reason: 'no se activó');
    }
  });

  testWidgets('se activa en Ajustes › Privacidad', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      extras: [relojSeguridadProvider.overrideWithValue(() => ahora)],
    );
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacidad'));
    await tester.pumpAndSettle();
    expect(find.text('Bloqueo del teléfono'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bloqueo-activo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bloqueo-pin')), '135792');
    await tester.enterText(find.byKey(const Key('bloqueo-confirmacion')), '135792');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Bloquear tras'), findsOneWidget);
    expect(find.text('1 minuto'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    ahora = ahora.add(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(pantallaBloqueo), findsOneWidget);
    await escribirPin(tester, '135792');
    expect(find.text('Bloqueo del teléfono'), findsOneWidget);
  });

  group('PIN anterior corto de quien ve dinero (D18, 23/oct)', () {
    Future<void> abrir(WidgetTester tester, Rol rol) => montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(rol),
      almacen: almacenConBloqueoAnterior(rol),
      extras: [relojSeguridadProvider.overrideWithValue(() => ahora)],
    );

    Future<void> guardar(WidgetTester tester, String pin, String repetido) async {
      await tester.enterText(find.byKey(const Key('pin-nuevo-cambio')), pin);
      await tester.enterText(
        find.byKey(const Key('pin-nuevo-cambio-confirmacion')),
        repetido,
      );
      await tester.tap(find.byKey(const ValueKey('guardar-pin-y-abrir')));
      await tester.pumpAndSettle();
    }

    testWidgets('el dueño escribe su PIN de 4 dígitos, elige uno de 6 y abre', (
      tester,
    ) async {
      await abrir(tester, Rol.dueno);
      await escribirPin(tester, '2468');
      // Su PIN era el bueno, pero no abre todavía: pide el nuevo.
      expect(find.byKey(pantallaBloqueo), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-pin-corto')), findsOneWidget);
      expect(find.byKey(const Key('campo-pin-bloqueo')), findsNothing);

      await guardar(tester, '7391', '7391');
      expect(find.text('El PIN es de 6 dígitos.'), findsOneWidget);
      await guardar(tester, '123456', '123456');
      expect(find.textContaining('secuencia'), findsOneWidget);
      await guardar(tester, '739150', '739151');
      expect(find.text('Los PIN no coinciden.'), findsOneWidget);
      expect(find.byKey(pantallaBloqueo), findsOneWidget);

      await guardar(tester, '739150', '739150');
      expect(find.byKey(pantallaBloqueo), findsNothing);
      expect(find.text('Hoy'), findsWidgets);
    });

    testWidgets('el PIN nuevo queda: al bloquear otra vez, el viejo ya no sirve', (
      tester,
    ) async {
      await abrir(tester, Rol.dueno);
      await escribirPin(tester, '2468');
      await guardar(tester, '739150', '739150');
      expect(find.byKey(pantallaBloqueo), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      ahora = ahora.add(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(pantallaBloqueo), findsOneWidget);
      await escribirPin(tester, '2468');
      expect(find.text('PIN incorrecto.'), findsOneWidget);
      await escribirPin(tester, '739150');
      expect(find.byKey(pantallaBloqueo), findsNothing);
    });

    testWidgets('quien no ve dinero conserva su PIN de 4 dígitos y abre directo', (
      tester,
    ) async {
      await abrir(tester, Rol.familiar);
      await escribirPin(tester, '2468');
      expect(find.byKey(pantallaBloqueo), findsNothing);
      expect(find.byKey(const ValueKey('aviso-pin-corto')), findsNothing);
    });
  });
}

// Bloqueo del teléfono con PIN o huella (revisión de la Fase 0, I8).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/bloqueo.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import 'ayuda_plataforma.dart';

const pantallaBloqueo = ValueKey('pantalla-bloqueo');

/// Almacén con el bloqueo del Dueño ya configurado (PIN 2468).
AlmacenSeguroEnMemoria almacenConBloqueo({bool huella = false}) =>
    AlmacenSeguroEnMemoria({
      ControladorBloqueo.claveConfiguracion(
        sesionDeEjemplo(Rol.dueno).persona.id,
      ): jsonEncode(
        ConfiguracionBloqueo(
          hashPin: hashDePrueba('2468'),
          huella: huella,
        ).aJson(),
      ),
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
    await escribirPin(tester, '2468');
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
    await escribirPin(tester, '2468');

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
    await tester.enterText(find.byKey(const Key('bloqueo-pin')), '1234');
    await tester.enterText(find.byKey(const Key('bloqueo-confirmacion')), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ese PIN es una secuencia'), findsOneWidget);
    expect(find.text('Bloquear tras'), findsNothing, reason: 'no se activó');
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
    await tester.enterText(find.byKey(const Key('bloqueo-pin')), '1357');
    await tester.enterText(find.byKey(const Key('bloqueo-confirmacion')), '1357');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Bloquear tras'), findsOneWidget);
    expect(find.text('1 minuto'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    ahora = ahora.add(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(pantallaBloqueo), findsOneWidget);
    await escribirPin(tester, '1357');
    expect(find.text('Bloqueo del teléfono'), findsOneWidget);
  });
}

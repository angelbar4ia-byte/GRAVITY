/// Ayuda para las pruebas de la plataforma: monta la app con un dispositivo,
/// una sesión falsa y almacenes en memoria.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/dispositivo.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/pin.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

/// Tamaño lógico de cada dispositivo en las pruebas.
Size tamanoDe(TipoDispositivo dispositivo) => switch (dispositivo) {
  TipoDispositivo.laptop => const Size(1440, 900),
  TipoDispositivo.tablet => const Size(1280, 800),
  TipoDispositivo.telefono => const Size(400, 840),
};

/// Monta la app completa (router, cascarones y permisos).
Future<void> montarApp(
  WidgetTester tester, {
  required TipoDispositivo dispositivo,
  required ServicioSesion sesion,
  AlmacenSeguro? almacen,
  ServicioBiometria? biometria,
  List<Override> extras = const [],
}) async {
  tester.view.physicalSize = tamanoDe(dispositivo);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // "Reducir movimiento": el núcleo animado de GRAVITY se detiene y
  // pumpAndSettle puede terminar.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tipoDispositivoProvider.overrideWithValue(dispositivo),
        servicioSesionProvider.overrideWithValue(sesion),
        almacenSeguroProvider.overrideWithValue(
          almacen ?? AlmacenSeguroEnMemoria(),
        ),
        biometriaProvider.overrideWithValue(
          biometria ?? const BiometriaNoDisponible(),
        ),
        ...extras,
      ],
      child: const AppGravity(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Sesión falsa abierta con la persona de ejemplo del [rol].
ServicioSesionFalso sesionCon(Rol rol) => ServicioSesionFalso.con(rol);

/// PIN de las pruebas (hash con pocas iteraciones para que sean rápidas).
String hashDePrueba(String pin) => HashPin.crear(pin, iteraciones: 50);

/// Almacén con personas de la tablet ya registradas (PIN 1234, salvo que se
/// indique otro).
Future<AlmacenSeguroEnMemoria> almacenConPersonas(
  Map<Rol, String> pinPorRol, {
  Set<Rol> conHuella = const {},
  ConfiguracionTablet? configuracion,
}) async {
  final almacen = AlmacenSeguroEnMemoria();
  final repositorio = RepositorioTablet(almacen);
  await repositorio.guardarUsuarios([
    for (final MapEntry(key: rol, value: pin) in pinPorRol.entries)
      UsuarioTablet.desdeSesion(
        sesionDeEjemplo(rol),
        hashPin: hashDePrueba(pin),
        huella: conHuella.contains(rol),
      ),
  ]);
  if (configuracion != null) {
    await repositorio.guardarConfiguracion(configuracion);
  }
  return almacen;
}

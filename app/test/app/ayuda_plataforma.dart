/// Ayuda para las pruebas de la plataforma: monta la app con un dispositivo,
/// una sesión falsa y almacenes en memoria.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/arranque.dart';
import 'package:gravity/app/dispositivo.dart';
import 'package:gravity/diseno/proveedores.dart' show Reloj, RelojFijo, relojProvider;
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
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
  BaseLocal? base,
  Reloj? reloj,
  List<Override> extras = const [],
}) async {
  final baseUsada = base ?? BaseLocal.enMemoria();
  if (base == null) addTearDown(baseUsada.close);
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
        ...conexionesDeLaApp(),
        tipoDispositivoProvider.overrideWithValue(dispositivo),
        servicioSesionProvider.overrideWithValue(sesion),
        almacenSeguroProvider.overrideWithValue(
          almacen ?? AlmacenSeguroEnMemoria(),
        ),
        biometriaProvider.overrideWithValue(
          biometria ?? const BiometriaNoDisponible(),
        ),
        baseLocalProvider.overrideWithValue(baseUsada),
        // Hora fija (de día): las pantallas no dependen de la hora real.
        relojProvider.overrideWithValue(reloj ?? relojDePrueba),
        ...extras,
      ],
      child: const AppGravity(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Hora de las pruebas que montan la app: martes 20 de octubre, 10:00.
final relojDePrueba = RelojFijo(DateTime(2026, 10, 20, 10));

/// Sesión falsa abierta con la persona de ejemplo del [rol].
ServicioSesionFalso sesionCon(Rol rol) => ServicioSesionFalso.con(rol);

/// PIN de las pruebas (hash con pocas iteraciones para que sean rápidas).
String hashDePrueba(String pin) => HashPin.crear(pin, iteraciones: 50);

/// Almacén con personas de la tablet ya registradas, cada una con su PIN y
/// su credencial del servidor (la de [ServicioSesionFalso]) cifrada con él.
///
/// [conHuella] simula datos de una versión anterior en los que la persona
/// había activado la huella: ya no abre (B3).
Future<AlmacenSeguroEnMemoria> almacenConPersonas(
  Map<Rol, String> pinPorRol, {
  Set<Rol> conHuella = const {},
  ConfiguracionTablet? configuracion,
  bool conCredencial = true,
}) async {
  final almacen = AlmacenSeguroEnMemoria();
  final repositorio = RepositorioTablet(almacen);
  final usuarios = <Map<String, Object?>>[];
  for (final MapEntry(key: rol, value: pin) in pinPorRol.entries) {
    final sesion = sesionDeEjemplo(rol);
    usuarios.add({
      ...UsuarioTablet.desdeSesion(sesion, hashPin: hashDePrueba(pin)).aJson(),
      if (conHuella.contains(rol)) 'huella': true,
    });
    if (conCredencial) {
      await repositorio.guardarCredencial(
        sesion.persona.id,
        LlavePin.derivar(pin, iteraciones: 50),
        ServicioSesionFalso.credencialDe(sesion),
      );
    }
  }
  await almacen.escribir(RepositorioTablet.claveUsuarios, jsonEncode(usuarios));
  if (configuracion != null) {
    await repositorio.guardarConfiguracion(configuracion);
  }
  return almacen;
}

/// Todo el texto visible, en minúsculas (los títulos de las tarjetas van en
/// mayúsculas: buscar "Finanzas" tal cual pasaría en vacío, B1).
String textoVisible(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' · ')
    .toLowerCase();

/// Con una pantalla muy alta, las listas perezosas construyen todo.
Future<void> construirTodo(WidgetTester tester) async {
  tester.view.physicalSize = Size(tester.view.physicalSize.width, 4000);
  await tester.pumpAndSettle();
}

/// Sin rastro de dinero: ni las piezas de Finanzas (por llave) ni su texto.
void revisarSinDinero(WidgetTester tester) {
  for (final llave in ['tarjeta-finanzas', 'panel-finanzas', 'monto-quedan']) {
    expect(find.byKey(ValueKey(llave)), findsNothing, reason: llave);
  }
  final texto = textoVisible(tester);
  for (final prohibido in ['finanzas', 'quedan', 'presupuesto usado']) {
    expect(texto, isNot(contains(prohibido)), reason: prohibido);
  }
  expect(find.textContaining(r'$'), findsNothing);
}

/// Sin datos de cuidados (ni por llave ni por texto).
void revisarSinCuidados(WidgetTester tester) {
  for (final llave in ['tarjeta-cuidados', 'panel-cuidados']) {
    expect(find.byKey(ValueKey(llave)), findsNothing, reason: llave);
  }
  final texto = textoVisible(tester);
  for (final prohibido in ['medicamento', 'entrega de turno']) {
    expect(texto, isNot(contains(prohibido)), reason: prohibido);
  }
}

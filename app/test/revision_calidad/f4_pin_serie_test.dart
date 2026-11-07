// REVISIÓN DE CALIDAD · FASE 4 (docs/revisiones/fase-4.md) · PIN en hilo aparte.
//
// D22 pasó la derivación del PIN a un `Isolate` (600 000 vueltas). Por eso
// `SerieDePin` pone las verificaciones en fila: sin ella, varios toques
// seguidos empezarían varias verificaciones en paralelo y se saltarían el
// límite de intentos (el bloqueo se revisa ANTES de calcular).
//
// Guardias: `desbloquearConPin` y `comprobarPin` (revisan el bloqueo dentro de
// la fila). Hallazgo F4-S1: `cambiarPin` (y sus equivalentes en la tablet y en
// los montos) revisa el bloqueo FUERA de la fila, así que N llamadas
// simultáneas pasan todas la revisión antes de que se anote el primer fallo.
//
// Excluir los hallazgos: flutter test --exclude-tags hallazgo
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/bloqueo.dart';
import 'package:gravity/nucleo/seguridad/pin.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;
  final dueno = sesionDeEjemplo(Rol.dueno);

  Future<ControladorBloqueo> abrir() async {
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(
          ServicioSesionFalso(inicial: dueno),
        ),
        biometriaProvider.overrideWithValue(BiometriaFalsa()),
        relojSeguridadProvider.overrideWithValue(() => ahora),
      ],
    );
    addTearDown(contenedor.dispose);
    contenedor.listen(controladorBloqueoProvider, (_, _) {});
    final controlador = contenedor.read(controladorBloqueoProvider.notifier);
    await controlador.listo;
    return controlador;
  }

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    ahora = DateTime(2026, 11, 7, 9);
    almacen.datos[ControladorBloqueo.claveConfiguracion(
      dueno.persona.id,
    )] = jsonEncode(
      ConfiguracionBloqueo(
        hashPin: HashPin.crear('246813', iteraciones: 50),
        tras: bloqueoTrasPorOmision,
      ).aJson(),
    );
  });

  test('el PIN nuevo es de 600 000 vueltas y los viejos se reconocen', () {
    // Las pruebas bajan `iteracionesPorDefecto` (flutter_test_config.dart); la
    // constante de producción es la que decide la fase.
    expect(HashPin.iteracionesActuales, 600000);
    for (final vueltas in [10000, 100000]) {
      expect(
        HashPin.iteracionesDe(HashPin.crear('246813', iteraciones: vueltas)),
        vueltas,
      );
      expect(vueltas < HashPin.iteracionesActuales, isTrue);
    }
  });

  test('desbloquearConPin simultáneos: el límite de 5 se respeta (guardia)',
      () async {
    final controlador = await abrir();
    final resultados = await Future.wait([
      for (var i = 0; i < 8; i++) controlador.desbloquearConPin('000000'),
      controlador.desbloquearConPin('246813'),
    ]);
    expect(
      resultados.where((r) => r == ResultadoBloqueo.pinIncorrecto).length,
      lessThanOrEqualTo(4),
      reason: 'a partir del quinto fallo, bloqueado',
    );
    expect(resultados.last, ResultadoBloqueo.bloqueado);
  });

  test('comprobarPin simultáneos: el límite de 5 se respeta (guardia)',
      () async {
    final controlador = await abrir();
    final resultados = await Future.wait([
      for (var i = 0; i < 8; i++) controlador.comprobarPin('000000'),
      controlador.comprobarPin('246813'),
    ]);
    expect(
      resultados.where((r) => r == ResultadoBloqueo.pinIncorrecto).length,
      lessThanOrEqualTo(4),
    );
    expect(resultados.last, ResultadoBloqueo.bloqueado);
  });

  // F4-S1 (IMPORTANTE) · `cambiarPin` revisa `_intentos.bloqueado` antes de
  // entrar a la fila (bloqueo.dart, ControladorBloqueo.cambiarPin). Con ocho
  // llamadas a la vez (doble toque, o un guion) todas pasan la revisión; la
  // fila las ejecuta una por una SIN volver a revisar, así que se prueban
  // más de 5 PIN y el PIN bueno entra aunque la cuenta ya estuviera bloqueada.
  // Igual en `ControladorTablet.cambiarPin` y en `ControladorMontos`
  // (`_cambiarPropio` y `verificar` con fuente propia).
  test('F4-S1: cambiarPin simultáneos respetan el límite de 5 intentos',
      () async {
    final controlador = await abrir();
    final resultados = await Future.wait([
      for (var i = 0; i < 8; i++) controlador.cambiarPin('000000', '135792'),
      controlador.cambiarPin('246813', '135792'),
    ]);
    expect(
      resultados.where((r) => r == ResultadoBloqueo.pinIncorrecto).length,
      lessThanOrEqualTo(4),
      reason: 'a partir del quinto fallo, bloqueado',
    );
    expect(
      resultados.last,
      ResultadoBloqueo.bloqueado,
      reason: 'el PIN bueno no debe pasar con la cuenta ya bloqueada',
    );
  });
}

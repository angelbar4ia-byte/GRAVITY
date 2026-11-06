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
  late ServicioSesionFalso servicio;
  late BiometriaFalsa biometria;
  late DateTime ahora;
  final dueno = sesionDeEjemplo(Rol.dueno);

  Future<(ProviderContainer, ControladorBloqueo)> abrir() async {
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(servicio),
        biometriaProvider.overrideWithValue(biometria),
        relojSeguridadProvider.overrideWithValue(() => ahora),
      ],
    );
    addTearDown(contenedor.dispose);
    contenedor.listen(controladorBloqueoProvider, (_, _) {});
    final controlador = contenedor.read(controladorBloqueoProvider.notifier);
    await controlador.listo;
    return (contenedor, controlador);
  }

  void guardarBloqueo({bool huella = false, Duration? tras}) {
    almacen.datos[ControladorBloqueo.claveConfiguracion(
      dueno.persona.id,
    )] = jsonEncode(
      ConfiguracionBloqueo(
        hashPin: HashPin.crear('246813', iteraciones: 50),
        huella: huella,
        tras: tras ?? bloqueoTrasPorOmision,
      ).aJson(),
    );
  }

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    servicio = ServicioSesionFalso(inicial: dueno);
    biometria = BiometriaFalsa();
    ahora = DateTime(2026, 10, 20, 9);
  });

  test('sin bloqueo configurado no bloquea', () async {
    final (contenedor, _) = await abrir();
    final estado = contenedor.read(controladorBloqueoProvider);
    expect(estado.cargado, isTrue);
    expect(estado.activo, isFalse);
    expect(estado.bloqueado, isFalse);
  });

  test('bloquea al abrir; el PIN correcto abre', () async {
    guardarBloqueo();
    final (contenedor, controlador) = await abrir();
    expect(contenedor.read(controladorBloqueoProvider).bloqueado, isTrue);
    expect(
      controlador.desbloquearConPin('0000'),
      ResultadoBloqueo.pinIncorrecto,
    );
    expect(contenedor.read(controladorBloqueoProvider).bloqueado, isTrue);
    expect(controlador.desbloquearConPin('246813'), ResultadoBloqueo.abierto);
    expect(contenedor.read(controladorBloqueoProvider).bloqueado, isFalse);
  });

  test('tras 1 minuto en segundo plano vuelve a bloquear; antes, no', () async {
    guardarBloqueo();
    final (contenedor, controlador) = await abrir();
    controlador.desbloquearConPin('246813');

    controlador.alIrASegundoPlano();
    ahora = ahora.add(const Duration(seconds: 59));
    controlador.alVolver();
    expect(contenedor.read(controladorBloqueoProvider).bloqueado, isFalse);

    controlador.alIrASegundoPlano();
    ahora = ahora.add(const Duration(minutes: 1));
    controlador.alVolver();
    expect(contenedor.read(controladorBloqueoProvider).bloqueado, isTrue);
  });

  test('el tiempo es configurable', () async {
    guardarBloqueo();
    final (contenedor, controlador) = await abrir();
    controlador.desbloquearConPin('246813');
    await controlador.fijarTiempo(const Duration(minutes: 5));
    controlador.alIrASegundoPlano();
    ahora = ahora.add(const Duration(minutes: 2));
    controlador.alVolver();
    expect(contenedor.read(controladorBloqueoProvider).bloqueado, isFalse);
    await controlador.fijarTiempo(Duration.zero);
    controlador.alIrASegundoPlano();
    controlador.alVolver();
    expect(contenedor.read(controladorBloqueoProvider).bloqueado, isTrue);
  });

  test('intentos fallidos: se bloquea y sobrevive al reinicio', () async {
    guardarBloqueo();
    var (_, controlador) = await abrir();
    for (var i = 0; i < 5; i++) {
      controlador.desbloquearConPin('0000');
    }
    expect(controlador.desbloquearConPin('246813'), ResultadoBloqueo.bloqueado);
    (_, controlador) = await abrir();
    expect(controlador.desbloquearConPin('246813'), ResultadoBloqueo.bloqueado);
    ahora = ahora.add(const Duration(seconds: 30));
    expect(controlador.desbloquearConPin('246813'), ResultadoBloqueo.abierto);
  });

  test('huella: solo si la persona la activó (teléfono personal)', () async {
    guardarBloqueo();
    final (contenedor, controlador) = await abrir();
    expect(
      await controlador.desbloquearConHuella(),
      ResultadoBloqueo.huellaFallida,
    );
    await controlador.fijarHuella(true);
    biometria.acepta = false;
    expect(
      await controlador.desbloquearConHuella(),
      ResultadoBloqueo.huellaFallida,
    );
    biometria.acepta = true;
    expect(await controlador.desbloquearConHuella(), ResultadoBloqueo.abierto);
    expect(contenedor.read(controladorBloqueoProvider).bloqueado, isFalse);
  });

  test('configurar y quitar; entrar con contraseña no bloquea', () async {
    servicio = ServicioSesionFalso();
    final (contenedor, controlador) = await abrir();
    servicio.fijarSesion(dueno);
    await pumpEventQueue();
    await controlador.listo;
    expect(contenedor.read(controladorBloqueoProvider).activo, isFalse);

    await controlador.configurarPin('135792');
    final estado = contenedor.read(controladorBloqueoProvider);
    expect(estado.activo, isTrue);
    expect(estado.bloqueado, isFalse);
    final guardado =
        almacen.datos[ControladorBloqueo.claveConfiguracion(dueno.persona.id)]!;
    expect(guardado, isNot(contains('135792')));

    await controlador.quitarBloqueo();
    expect(contenedor.read(controladorBloqueoProvider).activo, isFalse);
    expect(
      almacen.datos.containsKey(
        ControladorBloqueo.claveConfiguracion(dueno.persona.id),
      ),
      isFalse,
    );
    expect(() => controlador.configurarPin('12'), throwsArgumentError);
    // M9: tampoco un PIN trivial.
    for (final trivial in ['0000', '1234', '4321', '2222', '123456']) {
      await expectLater(
        controlador.configurarPin(trivial),
        throwsArgumentError,
        reason: trivial,
      );
    }
  });
}

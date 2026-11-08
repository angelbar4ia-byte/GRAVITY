// Desbloqueo por huella (P10 del dueño, D22): alternativa al PIN en el
// teléfono (bloqueo de la app y ver montos), con el PIN siempre de respaldo.
// En la tablet no hay huella: solo PIN (D14, B3 de la revisión de la Fase 0).
// Todo con la biometría simulada (`BiometriaFalsa`).
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/bloqueo.dart';
import 'package:gravity/nucleo/seguridad/montos.dart';
import 'package:gravity/nucleo/seguridad/pin.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late BiometriaFalsa biometria;
  final dueno = sesionDeEjemplo(Rol.dueno);

  Future<(ProviderContainer, ControladorBloqueo)> abrir({
    bool conBloqueo = true,
    bool huella = false,
  }) async {
    if (conBloqueo) {
      almacen.datos[ControladorBloqueo.claveConfiguracion(
        dueno.persona.id,
      )] = jsonEncode(
        ConfiguracionBloqueo(
          hashPin: HashPin.crear('246813', iteraciones: 50),
          huella: huella,
        ).aJson(),
      );
    }
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(
          ServicioSesionFalso(inicial: dueno),
        ),
        biometriaProvider.overrideWithValue(biometria),
      ],
    );
    addTearDown(contenedor.dispose);
    contenedor.listen(controladorBloqueoProvider, (_, _) {});
    final controlador = contenedor.read(controladorBloqueoProvider.notifier);
    await controlador.listo;
    return (contenedor, controlador);
  }

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    biometria = BiometriaFalsa();
  });

  group('activar la huella', () {
    test('se activa solo si la persona se identifica ahora', () async {
      final (contenedor, controlador) = await abrir();
      expect(await controlador.activarHuella(), isTrue);
      expect(biometria.intentos, 1);
      expect(
        contenedor.read(controladorBloqueoProvider).configuracion!.huella,
        isTrue,
      );
    });

    test('si la huella no se reconoce, no queda activa', () async {
      biometria.acepta = false;
      final (contenedor, controlador) = await abrir();
      expect(await controlador.activarHuella(), isFalse);
      expect(
        contenedor.read(controladorBloqueoProvider).configuracion!.huella,
        isFalse,
      );
    });

    test('sin huellas registradas en el teléfono no se activa', () async {
      biometria.hayHuella = false;
      final (contenedor, controlador) = await abrir();
      expect(await controlador.activarHuella(), isFalse);
      expect(biometria.intentos, 0, reason: 'ni siquiera se pide');
      expect(
        contenedor.read(controladorBloqueoProvider).configuracion!.huella,
        isFalse,
      );
    });

    test('sin bloqueo con PIN no hay huella (el PIN es el respaldo)', () async {
      final (_, controlador) = await abrir(conBloqueo: false);
      expect(await controlador.activarHuella(), isFalse);
      expect(biometria.intentos, 0);
    });

    test('apagarla no pide nada', () async {
      final (contenedor, controlador) = await abrir(huella: true);
      await controlador.fijarHuella(false);
      expect(biometria.intentos, 0);
      expect(
        contenedor.read(controladorBloqueoProvider).configuracion!.huella,
        isFalse,
      );
    });
  });

  group('desbloquear', () {
    test('con la huella activada, la huella abre', () async {
      final (contenedor, controlador) = await abrir(huella: true);
      expect(contenedor.read(controladorBloqueoProvider).bloqueado, isTrue);
      expect(
        await controlador.desbloquearConHuella(),
        ResultadoBloqueo.abierto,
      );
      expect(contenedor.read(controladorBloqueoProvider).bloqueado, isFalse);
    });

    test('con la huella apagada, la huella no abre aunque coincida', () async {
      final (contenedor, controlador) = await abrir();
      expect(
        await controlador.desbloquearConHuella(),
        ResultadoBloqueo.huellaFallida,
      );
      expect(biometria.intentos, 0);
      expect(contenedor.read(controladorBloqueoProvider).bloqueado, isTrue);
    });

    test('si la huella falla, el PIN sigue abriendo (respaldo)', () async {
      biometria.acepta = false;
      final (contenedor, controlador) = await abrir(huella: true);
      expect(
        await controlador.desbloquearConHuella(),
        ResultadoBloqueo.huellaFallida,
      );
      expect(contenedor.read(controladorBloqueoProvider).bloqueado, isTrue);
      expect(
        await controlador.desbloquearConPin('246813'),
        ResultadoBloqueo.abierto,
      );
      expect(contenedor.read(controladorBloqueoProvider).bloqueado, isFalse);
    });

    test('si el teléfono ya no tiene huellas, cae al PIN', () async {
      biometria.hayHuella = false;
      final (_, controlador) = await abrir(huella: true);
      expect(
        await controlador.desbloquearConHuella(),
        ResultadoBloqueo.huellaFallida,
      );
      expect(
        await controlador.desbloquearConPin('246813'),
        ResultadoBloqueo.abierto,
      );
    });

    test('la huella fallida no cuenta como intento fallido del PIN', () async {
      biometria.acepta = false;
      final (_, controlador) = await abrir(huella: true);
      for (var i = 0; i < 8; i++) {
        await controlador.desbloquearConHuella();
      }
      expect(controlador.esperaRestante(), isNull);
      expect(
        await controlador.desbloquearConPin('246813'),
        ResultadoBloqueo.abierto,
      );
    });
  });

  group('ver los montos', () {
    test('en el teléfono con bloqueo, la huella los revela', () async {
      final (contenedor, _) = await abrir(huella: true);
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      expect(await montos.huellaDisponible(), isTrue);
      expect(await montos.verificarConHuella(), ResultadoRevelar.revelado);
    });

    test('si no se reconoce, no se revelan (queda el PIN)', () async {
      biometria.acepta = false;
      final (contenedor, _) = await abrir(huella: true);
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      expect(await montos.verificarConHuella(), ResultadoRevelar.huellaFallida);
      expect(await montos.verificar('246813'), ResultadoRevelar.revelado);
    });
  });
}

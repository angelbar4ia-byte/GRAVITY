// Montos ocultos automáticos (decisión del 23/oct/2026): el tiempo es de cada
// persona, y para volver a verlos se pide un PIN (el de la tablet, el del
// bloqueo del teléfono o uno propio) o la huella en el teléfono.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/bloqueo.dart';
import 'package:gravity/nucleo/seguridad/montos.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late ServicioSesionFalso servicio;
  late BiometriaFalsa biometria;
  late DateTime ahora;

  final dueno = sesionDeEjemplo(Rol.dueno);
  final pareja = sesionDeEjemplo(Rol.coadministrador);

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    servicio = ServicioSesionFalso(inicial: dueno);
    biometria = BiometriaFalsa();
    ahora = DateTime(2026, 10, 24, 10);
  });

  ProviderContainer crear({ServicioSesionFalso? servicioPropio}) {
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(servicioPropio ?? servicio),
        biometriaProvider.overrideWithValue(biometria),
        relojSeguridadProvider.overrideWithValue(() => ahora),
      ],
    );
    addTearDown(contenedor.dispose);
    return contenedor;
  }

  Future<ControladorMontos> listo(ProviderContainer contenedor) async {
    final controlador = contenedor.read(controladorMontosProvider.notifier);
    await controlador.listo;
    return controlador;
  }

  group('tiempo sin uso', () {
    test('por omisión, 2 minutos', () async {
      final contenedor = crear();
      await listo(contenedor);
      expect(
        contenedor.read(controladorMontosProvider).ocultarTras,
        const Duration(minutes: 2),
      );
      expect(ocultarMontosTrasPorOmision, const Duration(minutes: 2));
      expect(opcionesOcultarMontosTras, contains(ocultarMontosTrasPorOmision));
    });

    test('es editable, se guarda y sobrevive al reinicio', () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      await controlador.fijarOcultarTras(const Duration(minutes: 10));
      expect(
        contenedor.read(controladorMontosProvider).ocultarTras,
        const Duration(minutes: 10),
      );
      final otra = crear();
      await listo(otra);
      expect(
        otra.read(controladorMontosProvider).ocultarTras,
        const Duration(minutes: 10),
      );
    });

    test('es de cada persona', () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      await controlador.fijarOcultarTras(const Duration(minutes: 30));

      final deLaPareja = crear(
        servicioPropio: ServicioSesionFalso(inicial: pareja),
      );
      await listo(deLaPareja);
      expect(
        deLaPareja.read(controladorMontosProvider).ocultarTras,
        const Duration(minutes: 2),
        reason: 'lo del dueño no cambia lo de la pareja',
      );
    });

    test(
      'lo guardado que no se entiende vuelve a los valores por omisión',
      () async {
        await almacen.escribir(
          ControladorMontos.claveConfiguracion(dueno.persona.id),
          'esto no es json',
        );
        final contenedor = crear();
        await listo(contenedor);
        expect(
          contenedor.read(controladorMontosProvider).ocultarTras,
          ocultarMontosTrasPorOmision,
        );
        await almacen.escribir(
          ControladorMontos.claveConfiguracion(dueno.persona.id),
          jsonEncode({'ocultar_tras_segundos': -5}),
        );
        final otra = crear();
        await listo(otra);
        expect(
          otra.read(controladorMontosProvider).ocultarTras,
          ocultarMontosTrasPorOmision,
        );
      },
    );
  });

  group('PIN propio (laptop o teléfono sin bloqueo)', () {
    test('la primera vez hay que crearlo', () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      expect(controlador.fuente, FuenteDePinMontos.propio);
      expect(controlador.hayQueCrearPin, isTrue);
      expect(await controlador.verificar('284651'), ResultadoRevelar.faltaPin);
    });

    test('no acepta PIN triviales ni mal formados', () async {
      final controlador = await listo(crear());
      for (final pin in ['0000', '1234', '4321', '1111', '123456', '1212']) {
        await expectLater(
          controlador.crearPin(pin),
          throwsArgumentError,
          reason: pin,
        );
      }
      await expectLater(controlador.crearPin('12'), throwsArgumentError);
      await expectLater(controlador.crearPin('12a4'), throwsArgumentError);
      expect(controlador.hayQueCrearPin, isTrue);
    });

    test('se guarda solo su hash y sirve para verlos; otro PIN no', () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      await controlador.crearPin('284651');
      expect(controlador.hayQueCrearPin, isFalse);
      final guardado = almacen
          .datos[ControladorMontos.claveConfiguracion(dueno.persona.id)]!;
      expect(guardado, isNot(contains('284651')));
      expect(guardado, contains('pbkdf2-sha256'));

      expect(await controlador.verificar('284651'), ResultadoRevelar.revelado);
      expect(
        await controlador.verificar('9999'),
        ResultadoRevelar.pinIncorrecto,
      );
      // Sobrevive al reinicio.
      final otra = crear();
      final controladorOtra = await listo(otra);
      expect(controladorOtra.hayQueCrearPin, isFalse);
      expect(
        await controladorOtra.verificar('284651'),
        ResultadoRevelar.revelado,
      );
    });

    test('cambiar el tiempo no borra el PIN, ni al revés', () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      await controlador.crearPin('284651');
      await controlador.fijarOcultarTras(const Duration(minutes: 5));
      expect(await controlador.verificar('284651'), ResultadoRevelar.revelado);
      expect(
        await controlador.crearPin('739150', actual: '284651'),
        ResultadoRevelar.revelado,
      );
      expect(
        await controlador.verificar('284651'),
        ResultadoRevelar.pinIncorrecto,
      );
      expect(await controlador.verificar('739150'), ResultadoRevelar.revelado);
      expect(
        contenedor.read(controladorMontosProvider).ocultarTras,
        const Duration(minutes: 5),
      );
    });

    test(
      'tras 5 fallos se bloquea y la espera se duplica (30 s, 1 min…)',
      () async {
        final controlador = await listo(crear());
        await controlador.crearPin('284651');
        for (var i = 0; i < 4; i++) {
          expect(
            await controlador.verificar('0001'),
            ResultadoRevelar.pinIncorrecto,
          );
        }
        expect(await controlador.verificar('0001'), ResultadoRevelar.bloqueado);
        expect(controlador.esperaRestante(), const Duration(seconds: 30));
        // Con el PIN bueno tampoco, mientras dure la espera.
        expect(
          await controlador.verificar('284651'),
          ResultadoRevelar.bloqueado,
        );

        ahora = ahora.add(const Duration(seconds: 31));
        expect(controlador.esperaRestante(), isNull);
        expect(
          await controlador.verificar('284651'),
          ResultadoRevelar.revelado,
        );
      },
    );

    test('los fallos sobreviven al reinicio de la app', () async {
      final controlador = await listo(crear());
      await controlador.crearPin('284651');
      for (var i = 0; i < 5; i++) {
        await controlador.verificar('0001');
      }
      final otra = crear();
      final controladorOtra = await listo(otra);
      expect(
        await controladorOtra.verificar('284651'),
        ResultadoRevelar.bloqueado,
      );
    });
  });

  group('con el bloqueo del teléfono', () {
    test('se usa el PIN del bloqueo, sin pedir otro', () async {
      final contenedor = crear();
      await contenedor.read(controladorBloqueoProvider.notifier).listo;
      await contenedor
          .read(controladorBloqueoProvider.notifier)
          .configurarPin('246813');
      final controlador = await listo(contenedor);

      expect(controlador.fuente, FuenteDePinMontos.bloqueo);
      expect(controlador.hayQueCrearPin, isFalse);
      expect(await controlador.verificar('246813'), ResultadoRevelar.revelado);
      expect(
        await controlador.verificar('0001'),
        ResultadoRevelar.pinIncorrecto,
      );
    });

    test('comprobar el PIN no desbloquea ni cambia el bloqueo', () async {
      final contenedor = crear();
      final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin('246813');
      final antes = contenedor.read(controladorBloqueoProvider);
      expect(await bloqueo.comprobarPin('246813'), ResultadoBloqueo.abierto);
      expect(
        await bloqueo.comprobarPin('0001'),
        ResultadoBloqueo.pinIncorrecto,
      );
      final despues = contenedor.read(controladorBloqueoProvider);
      expect(despues.bloqueado, antes.bloqueado);
      expect(despues.activo, isTrue);
    });

    test('los fallos al ver los montos cuentan para el bloqueo', () async {
      final contenedor = crear();
      final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin('246813');
      final controlador = await listo(contenedor);
      for (var i = 0; i < 5; i++) {
        await controlador.verificar('0001');
      }
      // El mismo contador: el bloqueo del teléfono también espera.
      expect(
        await bloqueo.desbloquearConPin('246813'),
        ResultadoBloqueo.bloqueado,
      );
    });
  });

  group('en la tablet', () {
    Future<(ProviderContainer, ControladorTablet)> conPersonaDentro() async {
      final casa = ServicioSesionFalso(
        cuentas: {
          'casa@ejemplo.test': CuentaFalsa('clave', sesionDeEjemplo(Rol.casa)),
        },
        inicial: sesionDeEjemplo(Rol.casa),
      );
      final contenedor = crear(servicioPropio: casa);
      final tablet = contenedor.read(controladorTabletProvider.notifier);
      await tablet.listo;
      await tablet.agregarUsuario(
        dueno,
        pin: '284651',
        credencial: ServicioSesionFalso.credencialDe(dueno),
      );
      expect(
        await tablet.entrarConPin(dueno.persona.id, '284651'),
        ResultadoDesbloqueo.abierto,
      );
      return (contenedor, tablet);
    }

    test('se pide el PIN de la persona que entró', () async {
      final (contenedor, _) = await conPersonaDentro();
      final controlador = await listo(contenedor);
      expect(controlador.fuente, FuenteDePinMontos.tablet);
      expect(controlador.hayQueCrearPin, isFalse);
      expect(await controlador.verificar('284651'), ResultadoRevelar.revelado);
      expect(
        await controlador.verificar('0001'),
        ResultadoRevelar.pinIncorrecto,
      );
    });

    test('nunca con huella (Android no dice de quién es el dedo)', () async {
      final (contenedor, _) = await conPersonaDentro();
      final controlador = await listo(contenedor);
      expect(await controlador.huellaDisponible(), isFalse);
      expect(
        await controlador.verificarConHuella(),
        ResultadoRevelar.huellaFallida,
      );
      expect(biometria.intentos, 0, reason: 'ni siquiera se pide');
    });

    test('los fallos cuentan igual que al entrar con el PIN', () async {
      final (contenedor, tablet) = await conPersonaDentro();
      final controlador = await listo(contenedor);
      for (var i = 0; i < 5; i++) {
        await controlador.verificar('0001');
      }
      expect(await controlador.verificar('284651'), ResultadoRevelar.bloqueado);
      expect(tablet.esperaRestante(dueno.persona.id), isNotNull);
      expect(
        await tablet.comprobarPin(dueno.persona.id, '284651'),
        ResultadoDesbloqueo.bloqueado,
      );
    });
  });

  group('huella (teléfono personal)', () {
    test('si hay huella y acepta, se ven los montos', () async {
      final controlador = await listo(crear());
      expect(await controlador.huellaDisponible(), isTrue);
      expect(await controlador.verificarConHuella(), ResultadoRevelar.revelado);
      expect(biometria.intentos, 1);
    });

    test('si no la reconoce, falla (y queda el PIN)', () async {
      biometria.acepta = false;
      final controlador = await listo(crear());
      expect(
        await controlador.verificarConHuella(),
        ResultadoRevelar.huellaFallida,
      );
    });

    test('sin huella en el equipo (la laptop), no se ofrece', () async {
      biometria.hayHuella = false;
      final controlador = await listo(crear());
      expect(await controlador.huellaDisponible(), isFalse);
      expect(
        await controlador.verificarConHuella(),
        ResultadoRevelar.huellaFallida,
      );
    });
  });
}

// Migración de las vueltas de PBKDF2 (M9' de la revisión de la Fase 1b): los
// hashes y sobres hechos con menos vueltas (los de 10 000) siguen
// verificándose y se rehacen con las de hoy en cuanto su dueño escribe el PIN,
// el único momento en que se tiene.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/bloqueo.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
import 'package:gravity/nucleo/seguridad/montos.dart';
import 'package:gravity/nucleo/seguridad/pin.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

const pin = '738291';
const vueltasViejas = 10;

void main() {
  late AlmacenSeguroEnMemoria almacen;
  final dueno = sesionDeEjemplo(Rol.dueno);
  final casa = sesionDeEjemplo(Rol.casa);

  setUp(() => almacen = AlmacenSeguroEnMemoria());

  test('"las de hoy" son más que las de antes (las pruebas bajan ambas)', () {
    expect(HashPin.iteracionesPorDefecto, greaterThan(vueltasViejas));
  });

  group('el hash', () {
    test('un hash de antes sigue verificando y se reconoce como viejo', () {
      final viejo = HashPin.crear(pin, iteraciones: HashPin.iteracionesAnteriores);
      expect(HashPin.verificar(pin, viejo), isTrue);
      expect(HashPin.verificar('738290', viejo), isFalse);
      expect(HashPin.iteracionesDe(viejo), 10000);
      final nuevo = HashPin.crear(pin);
      expect(HashPin.iteracionesDe(nuevo), HashPin.iteracionesPorDefecto);
    });

    test('necesitaActualizarse: solo si tiene menos vueltas que las de hoy', () {
      expect(HashPin.necesitaActualizarse(HashPin.crear(pin, iteraciones: vueltasViejas)), isTrue);
      expect(HashPin.necesitaActualizarse(HashPin.crear(pin)), isFalse);
      expect(
        HashPin.necesitaActualizarse(
          HashPin.crear(pin, iteraciones: HashPin.iteracionesPorDefecto + 1),
        ),
        isFalse,
      );
      // Lo que no se entiende no se "actualiza".
      expect(HashPin.necesitaActualizarse('basura'), isFalse);
      expect(HashPin.iteracionesDe('basura'), isNull);
    });

    test('el sobre guarda sus vueltas: uno de antes se abre y uno nuevo lleva las de hoy',
        () {
      final viejo = CifradoPin.cifrar(
        LlavePin.derivar(pin, iteraciones: vueltasViejas),
        'credencial',
      );
      expect(CifradoPin.descifrar(pin, viejo)?.$2, 'credencial');
      expect(CifradoPin.descifrar(pin, viejo)?.$1.iteraciones, vueltasViejas);
      final nuevo = CifradoPin.cifrar(LlavePin.derivar(pin), 'credencial');
      expect(jsonDecode(nuevo)['it'], HashPin.iteracionesPorDefecto);
    });
  });

  group('tablet: al entrar se rehacen el hash y el sobre', () {
    Future<(ProviderContainer, ControladorTablet)> abrir() async {
      final contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso(inicial: casa)),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
          relojSeguridadProvider.overrideWithValue(() => DateTime(2026, 10, 30, 9)),
        ],
      );
      addTearDown(contenedor.dispose);
      final controlador = contenedor.read(controladorTabletProvider.notifier);
      await controlador.listo;
      return (contenedor, controlador);
    }

    /// La tablet como estaba con las vueltas de antes.
    Future<void> tabletDeAntes({int vueltas = vueltasViejas}) async {
      final repositorio = RepositorioTablet(almacen);
      await repositorio.guardarUsuarios([
        UsuarioTablet.desdeSesion(
          dueno,
          hashPin: HashPin.crear(pin, iteraciones: vueltas),
        ),
      ]);
      await repositorio.guardarCredencial(
        dueno.persona.id,
        LlavePin.derivar(pin, iteraciones: vueltas),
        ServicioSesionFalso.credencialDe(dueno),
      );
    }

    test('entra con el PIN de antes y deja hash y sobre con las vueltas de hoy', () async {
      await tabletDeAntes();
      final sobreAntes = almacen.datos[RepositorioTablet.claveCredencial(dueno.persona.id)];
      expect(jsonDecode(sobreAntes!)['it'], vueltasViejas);

      final (contenedor, tablet) = await abrir();
      expect(
        await tablet.entrarConPin(dueno.persona.id, pin),
        ResultadoDesbloqueo.abierto,
      );
      tablet.volverAlReposo();
      await tablet.cambiosEnServidor;

      final usuario = contenedor.read(controladorTabletProvider).usuarios.single;
      expect(HashPin.iteracionesDe(usuario.hashPin), HashPin.iteracionesPorDefecto);
      expect(HashPin.verificar(pin, usuario.hashPin), isTrue);
      // Lo guardado en el almacén también: sobrevive al reinicio.
      final otro = await abrir();
      final guardado = otro.$1.read(controladorTabletProvider).usuarios.single;
      expect(HashPin.iteracionesDe(guardado.hashPin), HashPin.iteracionesPorDefecto);

      final sobre = almacen.datos[RepositorioTablet.claveCredencial(dueno.persona.id)]!;
      expect(jsonDecode(sobre)['it'], HashPin.iteracionesPorDefecto);
      final abierto = await RepositorioTablet(almacen).leerCredencial(dueno.persona.id, pin);
      expect(abierto, isNotNull, reason: 'la credencial no se perdió');
      expect(ServicioSesionFalso.leerCredencial(abierto!.$2)?.$1.persona.id, dueno.persona.id);

      // Y con el hash y el sobre nuevos se vuelve a entrar.
      expect(
        await otro.$2.entrarConPin(dueno.persona.id, pin),
        ResultadoDesbloqueo.abierto,
      );
    });

    test('un PIN equivocado no cambia nada de lo guardado', () async {
      await tabletDeAntes();
      final antes = Map.of(almacen.datos);
      final (_, tablet) = await abrir();
      expect(
        await tablet.entrarConPin(dueno.persona.id, '000000'),
        ResultadoDesbloqueo.pinIncorrecto,
      );
      for (final entrada in antes.entries) {
        if (entrada.key.contains('intentos')) continue;
        expect(almacen.datos[entrada.key], entrada.value, reason: entrada.key);
      }
    });

    test('si ya tienen las vueltas de hoy no se reescriben', () async {
      await tabletDeAntes(vueltas: HashPin.iteracionesPorDefecto);
      final hashAntes = (await RepositorioTablet(almacen).leerUsuarios()).single.hashPin;
      final sobreAntes = almacen.datos[RepositorioTablet.claveCredencial(dueno.persona.id)];
      final (_, tablet) = await abrir();
      expect(
        await tablet.entrarConPin(dueno.persona.id, pin),
        ResultadoDesbloqueo.abierto,
      );
      tablet.volverAlReposo();
      await tablet.cambiosEnServidor;
      expect((await RepositorioTablet(almacen).leerUsuarios()).single.hashPin, hashAntes);
      // El sobre se vuelve a cifrar al salir (nonce nuevo), pero con las mismas vueltas.
      expect(
        jsonDecode(almacen.datos[RepositorioTablet.claveCredencial(dueno.persona.id)]!)['it'],
        jsonDecode(sobreAntes!)['it'],
      );
    });
  });

  group('bloqueo del teléfono', () {
    Future<ControladorBloqueo> abrir() async {
      final contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso(inicial: dueno)),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
          relojSeguridadProvider.overrideWithValue(() => DateTime(2026, 10, 30, 9)),
        ],
      );
      addTearDown(contenedor.dispose);
      contenedor.listen(controladorBloqueoProvider, (_, _) {});
      final controlador = contenedor.read(controladorBloqueoProvider.notifier);
      await controlador.listo;
      return controlador;
    }

    String? hashGuardado() {
      final texto = almacen.datos[ControladorBloqueo.claveConfiguracion(dueno.persona.id)];
      return texto == null ? null : jsonDecode(texto)['hash_pin'] as String?;
    }

    test('al desbloquear con el PIN de antes se rehace el hash', () async {
      almacen.datos[ControladorBloqueo.claveConfiguracion(dueno.persona.id)] = jsonEncode(
        ConfiguracionBloqueo(
          hashPin: HashPin.crear(pin, iteraciones: vueltasViejas),
          huella: true,
        ).aJson(),
      );
      final controlador = await abrir();
      expect(controlador.desbloquearConPin(pin), ResultadoBloqueo.abierto);
      await pumpEventQueue();
      expect(HashPin.iteracionesDe(hashGuardado()!), HashPin.iteracionesPorDefecto);
      expect(controlador.comprobarPin(pin), ResultadoBloqueo.abierto);
      expect(controlador.state.configuracion!.huella, isTrue, reason: 'el resto se conserva');
      expect(controlador.state.bloqueado, isFalse);
    });

    test('un PIN equivocado no lo toca', () async {
      final viejo = HashPin.crear(pin, iteraciones: vueltasViejas);
      almacen.datos[ControladorBloqueo.claveConfiguracion(dueno.persona.id)] =
          jsonEncode(ConfiguracionBloqueo(hashPin: viejo).aJson());
      final controlador = await abrir();
      expect(controlador.desbloquearConPin('000000'), ResultadoBloqueo.pinIncorrecto);
      await pumpEventQueue();
      expect(hashGuardado(), viejo);
    });
  });

  group('PIN propio de los montos', () {
    test('al ver los montos con el PIN de antes se rehace el hash', () async {
      almacen.datos[ControladorMontos.claveConfiguracion(dueno.persona.id)] = jsonEncode({
        'hash_pin': HashPin.crear(pin, iteraciones: vueltasViejas),
        'ocultar_tras_segundos': 600,
      });
      final contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso(inicial: dueno)),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
          relojSeguridadProvider.overrideWithValue(() => DateTime(2026, 10, 30, 9)),
        ],
      );
      addTearDown(contenedor.dispose);
      contenedor.listen(controladorBloqueoProvider, (_, _) {});
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      expect(await montos.verificar(pin), ResultadoRevelar.revelado);
      await pumpEventQueue();
      final guardado = jsonDecode(
        almacen.datos[ControladorMontos.claveConfiguracion(dueno.persona.id)]!,
      ) as Map;
      expect(HashPin.iteracionesDe(guardado['hash_pin'] as String), HashPin.iteracionesPorDefecto);
      expect(guardado['ocultar_tras_segundos'], 600, reason: 'el tiempo se conserva');
      expect(await montos.verificar(pin), ResultadoRevelar.revelado);
    });
  });
}

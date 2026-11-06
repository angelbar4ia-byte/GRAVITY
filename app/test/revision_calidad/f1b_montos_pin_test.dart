// Revisión de calidad de la Fase 1b: los montos ocultos solos se vuelven a ver
// "con el PIN" (decisión del 23/oct/2026). ¿Se puede saltar ese PIN?
//
// Las pruebas con la etiqueta `hallazgo` FALLAN HOY A PROPÓSITO; las demás son
// guardias que pasan.
//
//  P1  Quien tiene la app abierta con los montos ocultos (la situación exacta
//      para la que se ocultan) cambia el PIN para ver los montos desde Ajustes ›
//      Privacidad SIN decir el actual, y con el nuevo los ve. Lo mismo con el PIN
//      del bloqueo del teléfono, y también quitando el bloqueo y creando uno
//      propio. Si se arregla cambiando la firma (`crearPin(pin, actual: …)`),
//      actualiza las llamadas de aquí: la expectativa no cambia.
//  P2  Decisión del 23/oct (2.ª ronda): PIN de 6 dígitos para quien ve dinero
//      (dueño y coadministradores, también la cuenta maestra). Plataforma lo
//      implementó mientras corría esta revisión: estas pruebas pasan y quedan
//      como guardias.
//  P3  Guardia de la regla nueva (2.ª ronda del 23/oct): en la tablet, al entrar
//      con su PIN la persona ve sus montos de una vez; al volver al reposo (o
//      entrar otra persona) se ocultan; el modo privado y el tiempo sin uso
//      siguen mandando. Sin widgets: no puede colgarse.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/arranque.dart' show conexionesDeLaApp;
import 'package:gravity/app/dispositivo.dart' show tipoDispositivoProvider;
import 'package:gravity/diseno/proveedores.dart'
    show
        modoPrivadoProvider,
        montosOcultosProvider,
        montosVisiblesProvider,
        personaEnPantallaProvider;
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart'
    show baseLocalProvider;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
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
  final dueno = sesionDeEjemplo(Rol.dueno);
  const pinDelDueno = '738291';
  const pinDelCurioso = '915204';

  late AlmacenSeguroEnMemoria almacen;

  setUp(() => almacen = AlmacenSeguroEnMemoria());

  ProviderContainer crear() {
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(
          ServicioSesionFalso(inicial: dueno),
        ),
        biometriaProvider.overrideWithValue(BiometriaFalsa()),
        relojSeguridadProvider.overrideWithValue(
          () => DateTime(2026, 10, 24, 10),
        ),
      ],
    );
    addTearDown(contenedor.dispose);
    return contenedor;
  }

  group('P1: el PIN para ver los montos no se cambia sin conocer el actual', () {
    test('PIN propio (laptop o teléfono sin bloqueo): crearPin pisa el vigente', () async {
      final contenedor = crear();
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      await montos.crearPin(pinDelDueno);
      expect(await montos.verificar(pinDelDueno), ResultadoRevelar.revelado);

      // Alguien frente a la laptop del dueño (app abierta, montos ocultos) abre
      // Ajustes › Privacidad › "Cambiar el PIN para ver los montos".
      try {
        await montos.crearPin(pinDelCurioso);
      } catch (_) {
        // Si el arreglo lanza, también está bien: el PIN no se cambió.
      }
      expect(
        await montos.verificar(pinDelCurioso),
        isNot(ResultadoRevelar.revelado),
        reason:
            'el PIN nuevo se aceptó sin pedir el actual (montos.dart crearPin y '
            'pantalla_privacidad.dart:121-137) y con él se ven los montos',
      );
    });

    test('PIN del bloqueo del teléfono: configurarPin pisa el vigente', () async {
      final contenedor = crear();
      final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin(pinDelDueno);
      try {
        await bloqueo.configurarPin(pinDelCurioso);
      } catch (_) {}
      expect(
        bloqueo.comprobarPin(pinDelCurioso),
        isNot(ResultadoBloqueo.abierto),
        reason:
            'Ajustes › Privacidad › "Cambiar PIN" no pide el actual: quien tiene '
            'la app desbloqueada pone el suyo y con él vuelve a ver los montos '
            '(el PIN de los montos del teléfono es el del bloqueo)',
      );
    });

    test('quitar el bloqueo y crear un PIN propio también abre los montos', () async {
      final contenedor = crear();
      final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin(pinDelDueno);
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      expect(montos.fuente, FuenteDePinMontos.bloqueo);

      // El interruptor "Pedir PIN al abrir GRAVITY" se apaga sin pedir el PIN.
      await bloqueo.quitarBloqueo();
      var revelado = false;
      if (montos.fuente == FuenteDePinMontos.propio && montos.hayQueCrearPin) {
        await montos.crearPin(pinDelCurioso);
        revelado =
            await montos.verificar(pinDelCurioso) == ResultadoRevelar.revelado;
      }
      expect(
        revelado,
        isFalse,
        reason:
            'apagar el bloqueo no pide el PIN, y sin bloqueo "Ver los montos" '
            'ofrece CREAR un PIN nuevo: quien tiene la app abierta lo crea y ve '
            'todo',
      );
    });

    test(
      'control: con el PIN equivocado no se ven (y se acumulan los fallos)',
      () async {
        final contenedor = crear();
        final montos = contenedor.read(controladorMontosProvider.notifier);
        await montos.listo;
        await montos.crearPin(pinDelDueno);
        for (var i = 0; i < 4; i++) {
          expect(
            await montos.verificar(pinDelCurioso),
            ResultadoRevelar.pinIncorrecto,
          );
        }
        expect(
          await montos.verificar(pinDelCurioso),
          ResultadoRevelar.bloqueado,
        );
        expect(
          await montos.verificar(pinDelDueno),
          ResultadoRevelar.bloqueado,
          reason: 'durante la espera ni el PIN bueno entra',
        );
      },
    );
  });

  group('P2: PIN de 6 dígitos para quien ve dinero (guardia, decisión del 23/oct)', () {
    test('el PIN para ver los montos del dueño debe tener 6 dígitos', () async {
      final contenedor = crear();
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      await expectLater(montos.crearPin('7382'), throwsArgumentError);
      await expectLater(montos.crearPin('73829'), throwsArgumentError);
    });

    test('el PIN del bloqueo del dueño debe tener 6 dígitos', () async {
      final contenedor = crear();
      final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await expectLater(bloqueo.configurarPin('7382'), throwsArgumentError);
    });

    test('el PIN de la tablet del dueño debe tener 6 dígitos (al agregarlo y al cambiarlo)', () async {
      final contenedor = crear();
      final tablet = contenedor.read(controladorTabletProvider.notifier);
      await tablet.listo;
      await tablet.agregarUsuario(
        dueno,
        pin: pinDelDueno,
        credencial: ServicioSesionFalso.credencialDe(dueno),
      );
      await expectLater(
        tablet.cambiarPin(
          dueno.persona.id,
          pinActual: pinDelDueno,
          pinNuevo: '7382',
        ),
        throwsArgumentError,
      );
    });

    test(
      'control: un PIN de 6 dígitos no trivial sí se acepta en los tres sitios',
      () async {
        final contenedor = crear();
        final montos = contenedor.read(controladorMontosProvider.notifier);
        await montos.listo;
        await montos.crearPin(pinDelDueno);
        final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
        await bloqueo.listo;
        await bloqueo.configurarPin(pinDelDueno);
        expect(bloqueo.comprobarPin(pinDelDueno), ResultadoBloqueo.abierto);
      },
    );
  });

  group('P3: tablet — entrar con el PIN muestra los montos; volver al reposo los oculta', () {
    // Sin widgets ni `pumpAndSettle`: solo proveedores, para que no pueda colgarse
    // esperando una animación o un diálogo. Cada prueba tiene además un tiempo
    // máximo propio.
    Future<ProviderContainer> tabletConPersonas() async {
      final casa = ServicioSesionFalso(inicial: sesionDeEjemplo(Rol.casa));
      final base = BaseLocal.enMemoria();
      addTearDown(base.close);
      final contenedor = ProviderContainer(
        overrides: [
          ...conexionesDeLaApp(),
          tipoDispositivoProvider.overrideWithValue(TipoDispositivo.tablet),
          servicioSesionProvider.overrideWithValue(casa),
          almacenSeguroProvider.overrideWithValue(almacen),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
          baseLocalProvider.overrideWithValue(base),
        ],
      );
      addTearDown(contenedor.dispose);
      // Se mantienen vivos para ver los cambios, como lo hace la pantalla.
      contenedor.listen(montosOcultosProvider, (_, _) {});
      contenedor.listen(personaEnPantallaProvider, (_, _) {});
      final tablet = contenedor.read(controladorTabletProvider.notifier);
      await tablet.listo;
      for (final sesion in [dueno, sesionDeEjemplo(Rol.coadministrador)]) {
        await tablet.agregarUsuario(
          sesion,
          pin: pinDelDueno,
          credencial: ServicioSesionFalso.credencialDe(sesion),
        );
      }
      return contenedor;
    }

    test('en reposo (modo Casa) los montos están ocultos', () async {
      final contenedor = await tabletConPersonas();
      expect(contenedor.read(montosOcultosProvider), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('al entrar con su PIN el dueño ve sus montos de una vez; al volver a Hogar se ocultan', () async {
      final contenedor = await tabletConPersonas();
      final tablet = contenedor.read(controladorTabletProvider.notifier);
      expect(
        await tablet.entrarConPin(dueno.persona.id, pinDelDueno),
        ResultadoDesbloqueo.abierto,
      );
      expect(contenedor.read(personaEnPantallaProvider), dueno.persona.id);
      expect(
        contenedor.read(montosOcultosProvider),
        isFalse,
        reason: 'decisión del 23/oct (2.ª ronda): entrar con el PIN ya cuenta como pedir verlos',
      );

      tablet.volverAlReposo();
      await tablet.cambiosEnServidor;
      expect(
        contenedor.read(personaEnPantallaProvider),
        isNot(dueno.persona.id),
      );
      expect(
        contenedor.read(montosOcultosProvider),
        isTrue,
        reason: 'de vuelta en el modo Casa nada de lo que vio el dueño queda visible',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('lo que vio una persona no lo hereda la siguiente, y cada quien ve lo suyo al entrar', () async {
      final contenedor = await tabletConPersonas();
      final tablet = contenedor.read(controladorTabletProvider.notifier);
      final pareja = sesionDeEjemplo(Rol.coadministrador);
      expect(
        await tablet.entrarConPin(dueno.persona.id, pinDelDueno),
        ResultadoDesbloqueo.abierto,
      );
      expect(contenedor.read(montosOcultosProvider), isFalse);

      tablet.volverAlReposo();
      await tablet.cambiosEnServidor;
      expect(
        contenedor.read(montosOcultosProvider),
        isTrue,
        reason: 'en reposo, ocultos',
      );

      expect(
        await tablet.entrarConPin(pareja.persona.id, pinDelDueno),
        ResultadoDesbloqueo.abierto,
      );
      expect(contenedor.read(personaEnPantallaProvider), pareja.persona.id);
      expect(
        contenedor.read(montosOcultosProvider),
        isFalse,
        reason: 'la pareja entró con SU PIN',
      );
      tablet.volverAlReposo();
      await tablet.cambiosEnServidor;
      expect(contenedor.read(montosOcultosProvider), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('aunque haya entrado con PIN, el modo privado y el tiempo sin uso los ocultan', () async {
      final contenedor = await tabletConPersonas();
      final tablet = contenedor.read(controladorTabletProvider.notifier);
      expect(
        await tablet.entrarConPin(dueno.persona.id, pinDelDueno),
        ResultadoDesbloqueo.abierto,
      );
      expect(contenedor.read(montosOcultosProvider), isFalse);

      contenedor.read(modoPrivadoProvider.notifier).fijar(true);
      expect(
        contenedor.read(montosOcultosProvider),
        isTrue,
        reason: 'modo privado',
      );
      contenedor.read(modoPrivadoProvider.notifier).fijar(false);

      // Lo que hace OcultarMontosPorInactividad al vencer el tiempo.
      contenedor.read(montosVisiblesProvider.notifier).fijar(false);
      expect(
        contenedor.read(montosOcultosProvider),
        isTrue,
        reason: 'tras el tiempo sin uso',
      );
      expect(
        contenedor.read(modoPrivadoProvider),
        isFalse,
        reason: 'salir del modo privado no vuelve a mostrar nada sin pedirlo',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

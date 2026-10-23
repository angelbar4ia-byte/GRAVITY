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
//  P2  Decisión del 23/oct (2.ª ronda), aún sin implementar: PIN de 6 dígitos
//      para quien ve dinero (dueño y coadministradores, también la cuenta maestra).
//  P3  Guardia: al volver la tablet al reposo, los montos quedan ocultos. La
//      regla nueva ("al entrar con su PIN la persona ve sus montos de una vez") no
//      debe dejar a la vista los de quien acaba de salir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/montos/revelar_montos.dart';
import 'package:gravity/diseno/proveedores.dart'
    show montosOcultosProvider, revelarMontosProvider;
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

import '../app/ayuda_plataforma.dart';

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
        servicioSesionProvider.overrideWithValue(ServicioSesionFalso(inicial: dueno)),
        biometriaProvider.overrideWithValue(BiometriaFalsa()),
        relojSeguridadProvider.overrideWithValue(() => DateTime(2026, 10, 24, 10)),
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
    }, tags: ['hallazgo']);

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
    }, tags: ['hallazgo']);

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
        revelado = await montos.verificar(pinDelCurioso) == ResultadoRevelar.revelado;
      }
      expect(
        revelado,
        isFalse,
        reason:
            'apagar el bloqueo no pide el PIN, y sin bloqueo "Ver los montos" '
            'ofrece CREAR un PIN nuevo: quien tiene la app abierta lo crea y ve '
            'todo',
      );
    }, tags: ['hallazgo']);

    test('control: con el PIN equivocado no se ven (y se acumulan los fallos)', () async {
      final contenedor = crear();
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      await montos.crearPin(pinDelDueno);
      for (var i = 0; i < 4; i++) {
        expect(await montos.verificar(pinDelCurioso), ResultadoRevelar.pinIncorrecto);
      }
      expect(await montos.verificar(pinDelCurioso), ResultadoRevelar.bloqueado);
      expect(await montos.verificar(pinDelDueno), ResultadoRevelar.bloqueado,
          reason: 'durante la espera ni el PIN bueno entra');
    });
  });

  group('P2: PIN de 6 dígitos para quien ve dinero (decisión del 23/oct, 2.ª ronda)', () {
    test('el PIN para ver los montos del dueño debe tener 6 dígitos', () async {
      final contenedor = crear();
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      await expectLater(montos.crearPin('7382'), throwsArgumentError);
      await expectLater(montos.crearPin('73829'), throwsArgumentError);
    }, tags: ['hallazgo']);

    test('el PIN del bloqueo del dueño debe tener 6 dígitos', () async {
      final contenedor = crear();
      final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await expectLater(bloqueo.configurarPin('7382'), throwsArgumentError);
    }, tags: ['hallazgo']);

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
        tablet.cambiarPin(dueno.persona.id, pinActual: pinDelDueno, pinNuevo: '7382'),
        throwsArgumentError,
      );
    }, tags: ['hallazgo']);

    test('control: un PIN de 6 dígitos no trivial sí se acepta en los tres sitios', () async {
      final contenedor = crear();
      final montos = contenedor.read(controladorMontosProvider.notifier);
      await montos.listo;
      await montos.crearPin(pinDelDueno);
      final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin(pinDelDueno);
      expect(bloqueo.comprobarPin(pinDelDueno), ResultadoBloqueo.abierto);
    });
  });

  group('P3: al volver al reposo los montos de quien salió quedan ocultos', () {
    testWidgets('tablet pública: entra el dueño, ve sus montos, regresa a Hogar', (tester) async {
      final casa = ServicioSesionFalso(inicial: sesionDeEjemplo(Rol.casa));
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: casa,
        almacen: await almacenConPersonas({Rol.dueno: '2846'}),
        biometria: BiometriaFalsa(),
      );
      final contenedor = ProviderScope.containerOf(tester.element(find.byType(AppGravity)));
      await tester.tap(find.text('Dueño de ejemplo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo-pin')), '2846');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      // Pide ver los montos con su PIN (hoy hace falta; la regla nueva los muestra
      // al entrar: esta prueba vale con las dos).
      if (contenedor.read(montosOcultosProvider)) {
        final contexto = tester.element(find.byType(Scaffold).first);
        final futuro = contenedor.read(revelarMontosProvider)(contexto);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('revelar-pin')), '2846');
        await tester.tap(find.byKey(const ValueKey('revelar-aceptar')));
        await tester.pumpAndSettle();
        expect(await futuro, isTrue);
      }
      expect(contenedor.read(montosOcultosProvider), isFalse, reason: 'el dueño ve sus montos');

      contenedor.read(controladorTabletProvider.notifier).volverAlReposo();
      await tester.pumpAndSettle();
      expect(
        contenedor.read(montosOcultosProvider),
        isTrue,
        reason: 'de vuelta en el modo Casa nada de lo que vio el dueño queda visible',
      );
    });
  });
}

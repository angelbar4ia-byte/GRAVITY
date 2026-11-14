// Cambiar o quitar el PIN con el que se vuelven a ver los montos exige conocer
// el actual (P1 de la revisión de la Fase 1b, `docs/revisiones/fase-1b.md`):
// quien tiene la app abierta con los montos ocultos —justo la situación para la
// que se ocultan— no puede poner el suyo para verlos. Crear uno solo se puede
// cuando no hay ninguno.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/bloqueo.dart';
import 'package:gravity/nucleo/seguridad/montos.dart';
import 'package:gravity/nucleo/seguridad/pin_de_montos.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

const elDueno = '738291';
const elCurioso = '915204';
const otroMas = '482915';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  final dueno = sesionDeEjemplo(Rol.dueno);

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
          () => DateTime(2026, 10, 30, 10),
        ),
      ],
    );
    addTearDown(contenedor.dispose);
    contenedor.listen(controladorBloqueoProvider, (_, _) {});
    return contenedor;
  }

  Future<(ControladorMontos, ControladorBloqueo)> abrir(
    ProviderContainer contenedor,
  ) async {
    final montos = contenedor.read(controladorMontosProvider.notifier);
    final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
    await montos.listo;
    await bloqueo.listo;
    return (montos, bloqueo);
  }

  group('PIN propio de los montos', () {
    test('la primera vez se crea sin pedir nada', () async {
      final (montos, _) = await abrir(crear());
      expect(await montos.crearPin(elDueno), ResultadoRevelar.revelado);
      expect(await montos.verificar(elDueno), ResultadoRevelar.revelado);
    });

    test('cambiarlo sin el actual lanza y no cambia nada', () async {
      final (montos, _) = await abrir(crear());
      await montos.crearPin(elDueno);
      await expectLater(montos.crearPin(elCurioso), throwsStateError);
      expect(await montos.verificar(elCurioso), ResultadoRevelar.pinIncorrecto);
      expect(await montos.verificar(elDueno), ResultadoRevelar.revelado);
    });

    test(
      'con un actual equivocado cuenta como fallo y no cambia nada',
      () async {
        final (montos, _) = await abrir(crear());
        await montos.crearPin(elDueno);
        expect(
          await montos.crearPin(elCurioso, actual: otroMas),
          ResultadoRevelar.pinIncorrecto,
        );
        expect(
          await montos.verificar(elCurioso),
          ResultadoRevelar.pinIncorrecto,
        );
        expect(await montos.verificar(elDueno), ResultadoRevelar.revelado);
      },
    );

    test(
      'los intentos para cambiarlo sin saber el actual se bloquean (no es un '
      'adivinador sin límite)',
      () async {
        final (montos, _) = await abrir(crear());
        await montos.crearPin(elDueno);
        for (var i = 0; i < 4; i++) {
          expect(
            await montos.crearPin(elCurioso, actual: '00000$i'),
            ResultadoRevelar.pinIncorrecto,
          );
        }
        expect(
          await montos.crearPin(elCurioso, actual: '000009'),
          ResultadoRevelar.bloqueado,
        );
        // Durante la espera ni el actual bueno cambia nada.
        expect(
          await montos.crearPin(elCurioso, actual: elDueno),
          ResultadoRevelar.bloqueado,
        );
        expect(await montos.verificar(elDueno), ResultadoRevelar.bloqueado);
      },
    );

    test(
      'con el actual correcto se cambia, y el nuevo es el que sirve',
      () async {
        final (montos, _) = await abrir(crear());
        await montos.crearPin(elDueno);
        expect(
          await montos.crearPin(elCurioso, actual: elDueno),
          ResultadoRevelar.revelado,
        );
        expect(await montos.verificar(elDueno), ResultadoRevelar.pinIncorrecto);
        expect(await montos.verificar(elCurioso), ResultadoRevelar.revelado);
      },
    );

    test('el PIN nuevo también debe ser válido (largo y no trivial)', () async {
      final (montos, _) = await abrir(crear());
      await montos.crearPin(elDueno);
      for (final malo in ['7382', '123456']) {
        await expectLater(
          montos.crearPin(malo, actual: elDueno),
          throwsArgumentError,
          reason: malo,
        );
      }
      expect(await montos.verificar(elDueno), ResultadoRevelar.revelado);
    });
  });

  group('PIN del bloqueo del teléfono', () {
    test('la primera vez se activa sin pedir nada', () async {
      final (_, bloqueo) = await abrir(crear());
      expect(await bloqueo.configurarPin(elDueno), ResultadoBloqueo.abierto);
      expect(await bloqueo.comprobarPin(elDueno), ResultadoBloqueo.abierto);
    });

    test('cambiarlo sin el actual lanza y no cambia nada', () async {
      final (_, bloqueo) = await abrir(crear());
      await bloqueo.configurarPin(elDueno);
      await expectLater(bloqueo.configurarPin(elCurioso), throwsStateError);
      expect(
        await bloqueo.comprobarPin(elCurioso),
        ResultadoBloqueo.pinIncorrecto,
      );
      expect(await bloqueo.comprobarPin(elDueno), ResultadoBloqueo.abierto);
    });

    test(
      'con un actual equivocado cuenta como fallo; con el bueno se cambia',
      () async {
        final (_, bloqueo) = await abrir(crear());
        await bloqueo.configurarPin(elDueno);
        expect(
          await bloqueo.configurarPin(elCurioso, actual: otroMas),
          ResultadoBloqueo.pinIncorrecto,
        );
        expect(
          await bloqueo.comprobarPin(elCurioso),
          ResultadoBloqueo.pinIncorrecto,
        );
        expect(
          await bloqueo.configurarPin(elCurioso, actual: elDueno),
          ResultadoBloqueo.abierto,
        );
        expect(await bloqueo.comprobarPin(elCurioso), ResultadoBloqueo.abierto);
        expect(
          await bloqueo.comprobarPin(elDueno),
          ResultadoBloqueo.pinIncorrecto,
        );
      },
    );

    test('cambiar el PIN conserva la huella y el tiempo del bloqueo', () async {
      final (_, bloqueo) = await abrir(crear());
      await bloqueo.configurarPin(elDueno);
      await bloqueo.fijarHuella(true);
      await bloqueo.fijarTiempo(const Duration(minutes: 5));
      await bloqueo.configurarPin(elCurioso, actual: elDueno);
      final config = bloqueo.state.configuracion!;
      expect(config.huella, isTrue);
      expect(config.tras, const Duration(minutes: 5));
    });
  });

  group('quitar el bloqueo conserva su PIN como el propio de los montos', () {
    test('el PIN del bloqueo sigue sirviendo para ver los montos y no se puede '
        'crear otro sin conocerlo', () async {
      final contenedor = crear();
      final (montos, bloqueo) = await abrir(contenedor);
      await bloqueo.configurarPin(elDueno);
      expect(montos.fuente, FuenteDePinMontos.bloqueo);

      await bloqueo.quitarBloqueo();
      expect(montos.fuente, FuenteDePinMontos.propio);
      expect(
        montos.hayQueCrearPin,
        isFalse,
        reason: 'ya hay un PIN: el del bloqueo',
      );
      expect(montos.state.tienePinPropio, isTrue);
      expect(await montos.verificar(elDueno), ResultadoRevelar.revelado);
      expect(await montos.verificar(elCurioso), ResultadoRevelar.pinIncorrecto);
      await expectLater(montos.crearPin(elCurioso), throwsStateError);
      expect(
        await montos.crearPin(elCurioso, actual: elDueno),
        ResultadoRevelar.revelado,
      );
    });

    test(
      'lo guardado sobrevive al reinicio y respeta el tiempo ya elegido',
      () async {
        final contenedor = crear();
        final (montos, bloqueo) = await abrir(contenedor);
        await montos.fijarOcultarTras(const Duration(minutes: 10));
        await bloqueo.configurarPin(elDueno);
        await bloqueo.quitarBloqueo();

        final otra = crear();
        final (montosOtra, _) = await abrir(otra);
        expect(montosOtra.hayQueCrearPin, isFalse);
        expect(await montosOtra.verificar(elDueno), ResultadoRevelar.revelado);
        expect(
          otra.read(controladorMontosProvider).ocultarTras,
          const Duration(minutes: 10),
        );
      },
    );

    test(
      'también si el controlador de los montos no existía al quitarlo',
      () async {
        final primera = crear();
        final bloqueo = primera.read(controladorBloqueoProvider.notifier);
        await bloqueo.listo;
        await bloqueo.configurarPin(elDueno);
        await bloqueo.quitarBloqueo();
        expect(
          await leerPinPropioDeMontos(almacen, dueno.persona.id),
          isNotNull,
          reason: 'ya quedó guardado',
        );
        final otra = crear();
        final (montos, _) = await abrir(otra);
        expect(montos.hayQueCrearPin, isFalse);
      },
    );

    test(
      'quitar y poner otro PIN de bloqueo sin el actual no abre los montos',
      () async {
        final (montos, bloqueo) = await abrir(crear());
        await bloqueo.configurarPin(elDueno);
        await bloqueo.quitarBloqueo();

        // El atajo de P1: apagar el bloqueo y activarlo con un PIN propio.
        await expectLater(bloqueo.configurarPin(elCurioso), throwsStateError);
        expect(bloqueo.state.activo, isFalse);
        expect(
          await montos.verificar(elCurioso),
          ResultadoRevelar.pinIncorrecto,
        );
        // Con el PIN de antes sí se puede (y es lo mismo que el actual).
        expect(
          await bloqueo.configurarPin(elCurioso, actual: elDueno),
          ResultadoBloqueo.abierto,
        );
      },
    );

    test(
      'activar el bloqueo con el mismo PIN propio no pide otro paso',
      () async {
        final (montos, bloqueo) = await abrir(crear());
        await montos.crearPin(elDueno);
        expect(await bloqueo.configurarPin(elDueno), ResultadoBloqueo.abierto);
      },
    );

    test('activar el bloqueo con otro PIN y un PIN propio ya creado pide el '
        'propio, y los intentos cuentan', () async {
      final (montos, bloqueo) = await abrir(crear());
      await montos.crearPin(elDueno);
      await expectLater(bloqueo.configurarPin(elCurioso), throwsStateError);
      for (var i = 0; i < 3; i++) {
        expect(
          await bloqueo.configurarPin(elCurioso, actual: '00000$i'),
          ResultadoBloqueo.pinIncorrecto,
        );
      }
      // Los dos intentos de arriba (uno sin actual y uno con otro) ya sumaron.
      expect(
        await bloqueo.configurarPin(elCurioso, actual: '000009'),
        ResultadoBloqueo.bloqueado,
      );
      expect(bloqueo.state.activo, isFalse);
      expect(
        await bloqueo.configurarPin(elCurioso, actual: elDueno),
        ResultadoBloqueo.bloqueado,
        reason: 'durante la espera ni el bueno',
      );
    });

    test('quitar el bloqueo y luego volver a activarlo con el propio, sin '
        'perder el tiempo ni la huella configurados antes', () async {
      final (montos, bloqueo) = await abrir(crear());
      await bloqueo.configurarPin(elDueno);
      await bloqueo.quitarBloqueo();
      expect(
        await bloqueo.configurarPin(elCurioso, actual: elDueno),
        ResultadoBloqueo.abierto,
      );
      // Con el bloqueo otra vez, el PIN de los montos vuelve a ser el del bloqueo.
      expect(montos.fuente, FuenteDePinMontos.bloqueo);
      expect(await montos.verificar(elCurioso), ResultadoRevelar.revelado);
    });
  });

  group('"Olvidé mi PIN"', () {
    test(
      'quitar con olvido borra también el PIN propio de los montos',
      () async {
        final (montos, bloqueo) = await abrir(crear());
        await montos.crearPin(elCurioso);
        await bloqueo.configurarPin(elDueno, actual: elCurioso);
        await bloqueo.quitarBloqueo(olvido: true);

        expect(await leerPinPropioDeMontos(almacen, dueno.persona.id), isNull);
        expect(montos.state.tienePinPropio, isFalse);
        expect(
          montos.hayQueCrearPin,
          isTrue,
          reason: 'vuelve a empezar con su correo',
        );
        expect(await montos.verificar(elDueno), ResultadoRevelar.faltaPin);
      },
    );

    test('olvido sin tiempo guardado de antes tampoco deja nada', () async {
      final (montos, bloqueo) = await abrir(crear());
      await bloqueo.configurarPin(elDueno);
      await bloqueo.quitarBloqueo(olvido: true);
      expect(montos.hayQueCrearPin, isTrue);
    });
  });

  group('pin_de_montos: guardar sin tocar el resto', () {
    test('conserva el tiempo y quita solo el PIN', () async {
      await guardarPinPropioDeMontos(almacen, 'p', 'hash-1');
      await almacen.escribir(
        claveConfiguracionMontos('p'),
        '{"ocultar_tras_segundos":600,"hash_pin":"hash-1"}',
      );
      await guardarPinPropioDeMontos(almacen, 'p', 'hash-2');
      expect(await leerPinPropioDeMontos(almacen, 'p'), 'hash-2');
      expect(almacen.datos[claveConfiguracionMontos('p')], contains('600'));
      await guardarPinPropioDeMontos(almacen, 'p', null);
      expect(await leerPinPropioDeMontos(almacen, 'p'), isNull);
      expect(almacen.datos[claveConfiguracionMontos('p')], contains('600'));
    });

    test('lo ilegible se reemplaza sin lanzar', () async {
      await almacen.escribir(claveConfiguracionMontos('p'), 'no es json');
      expect(await leerPinPropioDeMontos(almacen, 'p'), isNull);
      await guardarPinPropioDeMontos(almacen, 'p', 'hash');
      expect(await leerPinPropioDeMontos(almacen, 'p'), 'hash');
    });
  });
}

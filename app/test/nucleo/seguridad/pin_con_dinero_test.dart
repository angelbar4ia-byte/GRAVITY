// PIN de 6 dígitos para quien ve dinero (decisión del dueño, 23/oct/2026, D18):
// dueño y coadministradores (también la cuenta maestra) usan 6 dígitos; familiar
// y cuidador conservan de 4 a 6. Los PIN triviales se siguen rechazando. Quien ya
// tiene un PIN más corto y ve dinero lo cambia al usarlo, en los cuatro lugares
// donde se teclea un PIN: la tablet, el bloqueo del teléfono, ver los montos y
// el PIN propio de los montos.
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
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

const corto = '2468';
const nuevo = '739150';

void main() {
  group('reglas de largo', () {
    test('ven dinero el dueño y el coadministrador; los demás no', () {
      expect(
        [for (final rol in Rol.values) if (rolVeDinero(rol)) rol],
        [Rol.dueno, Rol.coadministrador],
      );
    });

    test('quien ve dinero: exactamente 6 dígitos', () {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        for (final pin in ['2846', '28465', '284651']) {
          expect(pinValidoPara(rol, pin), pin.length == 6, reason: '$rol $pin');
        }
        expect(pinValidoPara(rol, '2846512'), isFalse);
        expect(pinValidoPara(rol, '28465a'), isFalse);
      }
    });

    test('familiar y cuidador conservan de 4 a 6 dígitos', () {
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        for (final pin in ['2846', '28465', '284651']) {
          expect(pinValidoPara(rol, pin), isTrue, reason: '$rol $pin');
        }
        expect(pinValidoPara(rol, '284'), isFalse);
        expect(pinValidoPara(rol, '2846512'), isFalse);
      }
    });

    test('sin rol conocido vale el formato general (4 a 6)', () {
      expect(pinValidoPara(null, '2846'), isTrue);
      expect(pinValidoPara(null, '284'), isFalse);
    });

    test('un PIN correcto pero corto es "corto" solo para quien ve dinero', () {
      expect(pinEsCortoParaSuRol(Rol.dueno, corto), isTrue);
      expect(pinEsCortoParaSuRol(Rol.coadministrador, '28465'), isTrue);
      expect(pinEsCortoParaSuRol(Rol.dueno, nuevo), isFalse);
      expect(pinEsCortoParaSuRol(Rol.familiar, corto), isFalse);
      expect(pinEsCortoParaSuRol(Rol.cuidador, corto), isFalse);
      expect(pinEsCortoParaSuRol(null, corto), isFalse);
    });

    test('mensajes: el largo del rol y lo trivial', () {
      expect(errorDePinNuevo('7382', rol: Rol.dueno), 'El PIN es de 6 dígitos.');
      expect(errorDePinNuevo('73829', rol: Rol.coadministrador),
          'El PIN es de 6 dígitos.');
      expect(errorDePinNuevo('7382a', rol: Rol.dueno), 'El PIN es de 6 dígitos.');
      expect(errorDePinNuevo(nuevo, rol: Rol.dueno), isNull);
      // Los triviales se siguen rechazando, también de 6 dígitos.
      expect(errorDePinNuevo('123456', rol: Rol.dueno), contains('secuencia'));
      expect(errorDePinNuevo('111111', rol: Rol.dueno), contains('mismo número'));
      expect(errorDePinNuevo('121212', rol: Rol.dueno), contains('bloque'));
      // Los demás conservan el mensaje y el largo de siempre.
      expect(errorDePinNuevo('7382', rol: Rol.familiar), isNull);
      expect(errorDePinNuevo('738', rol: Rol.familiar), 'De 4 a 6 dígitos.');
      expect(errorDePinNuevo('1234', rol: Rol.familiar), contains('secuencia'));
      // Sin rol, como antes.
      expect(errorDePinNuevo('7382'), isNull);
      expect(errorDePinNuevo('738'), 'De 4 a 6 dígitos.');
    });

    test('con confirmación: el PIN y su repetición coinciden', () {
      expect(errorDePinNuevoConfirmado(nuevo, nuevo, rol: Rol.dueno), isNull);
      expect(
        errorDePinNuevoConfirmado(nuevo, '739151', rol: Rol.dueno),
        'Los PIN no coinciden.',
      );
      expect(
        errorDePinNuevoConfirmado('7382', '7382', rol: Rol.dueno),
        'El PIN es de 6 dígitos.',
        reason: 'primero el largo',
      );
    });

    test('textos para las etiquetas', () {
      expect(textoDelLargoDelPin(Rol.dueno), '6 dígitos');
      expect(textoDelLargoDelPin(Rol.coadministrador), '6 dígitos');
      expect(textoDelLargoDelPin(Rol.familiar), '4 a 6 dígitos');
      expect(textoDelLargoDelPin(null), '4 a 6 dígitos');
    });

    test('el hash sigue aceptando de 4 a 6 dígitos (los PIN anteriores)', () {
      final hash = HashPin.crear(corto, iteraciones: 10);
      expect(HashPin.verificar(corto, hash), isTrue);
    });
  });

  group('bloqueo del teléfono', () {
    late AlmacenSeguroEnMemoria almacen;
    late DateTime ahora;

    setUp(() {
      almacen = AlmacenSeguroEnMemoria();
      ahora = DateTime(2026, 10, 24, 9);
    });

    Future<ControladorBloqueo> abrir(Sesion sesion) async {
      final contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioSesionProvider.overrideWithValue(
            ServicioSesionFalso(inicial: sesion),
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

    /// El bloqueo como estaba antes de la regla: con un PIN de 4 dígitos.
    void bloqueoAnterior(Sesion sesion) {
      almacen.datos[ControladorBloqueo.claveConfiguracion(sesion.persona.id)] =
          jsonEncode(
            ConfiguracionBloqueo(
              hashPin: HashPin.crear(corto, iteraciones: 50),
            ).aJson(),
          );
    }

    test('el dueño y la pareja configuran su bloqueo con 6 dígitos', () async {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        final controlador = await abrir(sesionDeEjemplo(rol));
        for (final malo in ['7382', '73829']) {
          await expectLater(
            controlador.configurarPin(malo),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'mensaje',
                'El PIN es de 6 dígitos.',
              ),
            ),
            reason: '$rol $malo',
          );
        }
        await expectLater(controlador.configurarPin('123456'), throwsArgumentError);
        await controlador.configurarPin(nuevo);
        expect(controlador.comprobarPin(nuevo), ResultadoBloqueo.abierto);
      }
    });

    test('familiar y cuidador conservan de 4 a 6 dígitos', () async {
      for (final (rol, pin) in [
        (Rol.familiar, '7382'),
        (Rol.cuidador, '73829'),
        (Rol.familiar, nuevo),
      ]) {
        final controlador = await abrir(sesionDeEjemplo(rol));
        await controlador.configurarPin(pin);
        expect(controlador.comprobarPin(pin), ResultadoBloqueo.abierto);
      }
    });

    test('PIN anterior corto: lo reconoce pero no abre; pide uno nuevo', () async {
      final dueno = sesionDeEjemplo(Rol.dueno);
      bloqueoAnterior(dueno);
      final controlador = await abrir(dueno);
      expect(controlador.state.bloqueado, isTrue);

      expect(controlador.desbloquearConPin(corto), ResultadoBloqueo.debeCambiarPin);
      expect(controlador.state.bloqueado, isTrue, reason: 'sigue bloqueado');
      expect(controlador.comprobarPin(corto), ResultadoBloqueo.debeCambiarPin);
      expect(controlador.esperaRestante(), isNull, reason: 'no cuenta como fallo');
    });

    test('un PIN equivocado sigue siendo un fallo (y el contador sigue)', () async {
      final dueno = sesionDeEjemplo(Rol.dueno);
      bloqueoAnterior(dueno);
      final controlador = await abrir(dueno);
      for (var i = 0; i < 4; i++) {
        expect(controlador.desbloquearConPin('0001'), ResultadoBloqueo.pinIncorrecto);
      }
      // El PIN corto bueno reinicia el contador.
      expect(controlador.desbloquearConPin(corto), ResultadoBloqueo.debeCambiarPin);
      for (var i = 0; i < 4; i++) {
        expect(controlador.desbloquearConPin('0001'), ResultadoBloqueo.pinIncorrecto);
      }
      expect(controlador.desbloquearConPin('0001'), ResultadoBloqueo.bloqueado);
    });

    test('cambiar el PIN corto por uno de 6: abre y el viejo ya no sirve', () async {
      final dueno = sesionDeEjemplo(Rol.dueno);
      bloqueoAnterior(dueno);
      final controlador = await abrir(dueno);
      expect(controlador.desbloquearConPin(corto), ResultadoBloqueo.debeCambiarPin);

      expect(await controlador.cambiarPin(corto, nuevo), ResultadoBloqueo.abierto);
      expect(controlador.state.bloqueado, isFalse);
      expect(controlador.comprobarPin(corto), ResultadoBloqueo.pinIncorrecto);
      expect(controlador.comprobarPin(nuevo), ResultadoBloqueo.abierto);
      // Se guardó: la próxima vez que abra la app pide el nuevo.
      final otra = await abrir(dueno);
      expect(otra.state.bloqueado, isTrue);
      expect(otra.desbloquearConPin(nuevo), ResultadoBloqueo.abierto);
      // El resto de su configuración se conserva.
      expect(otra.state.configuracion!.tras, bloqueoTrasPorOmision);
    });

    test('el cambio pide el PIN actual y el nuevo de 6 dígitos no trivial', () async {
      final dueno = sesionDeEjemplo(Rol.dueno);
      bloqueoAnterior(dueno);
      final controlador = await abrir(dueno);
      expect(await controlador.cambiarPin('0001', nuevo), ResultadoBloqueo.pinIncorrecto);
      for (final malo in ['7391', '73915', '123456', '111111', '121212']) {
        await expectLater(
          controlador.cambiarPin(corto, malo),
          throwsArgumentError,
          reason: malo,
        );
      }
      // Nada cambió: el PIN de antes sigue reconocido.
      expect(controlador.comprobarPin(corto), ResultadoBloqueo.debeCambiarPin);
      expect(controlador.state.bloqueado, isTrue);
    });

    test('quien no ve dinero conserva su PIN corto y entra sin cambiarlo', () async {
      for (final rol in [Rol.familiar, Rol.cuidador]) {
        final sesion = sesionDeEjemplo(rol);
        bloqueoAnterior(sesion);
        final controlador = await abrir(sesion);
        expect(controlador.desbloquearConPin(corto), ResultadoBloqueo.abierto);
      }
    });
  });

  group('ver los montos', () {
    late AlmacenSeguroEnMemoria almacen;
    late DateTime ahora;

    setUp(() {
      almacen = AlmacenSeguroEnMemoria();
      ahora = DateTime(2026, 10, 24, 10);
    });

    ProviderContainer crear(Sesion sesion) {
      final contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioSesionProvider.overrideWithValue(
            ServicioSesionFalso(inicial: sesion),
          ),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
          relojSeguridadProvider.overrideWithValue(() => ahora),
        ],
      );
      addTearDown(contenedor.dispose);
      return contenedor;
    }

    Future<ControladorMontos> montos(ProviderContainer contenedor) async {
      final controlador = contenedor.read(controladorMontosProvider.notifier);
      await controlador.listo;
      return controlador;
    }

    /// El PIN propio como estaba antes de la regla: de 4 dígitos.
    void pinPropioAnterior(Sesion sesion) {
      almacen.datos[ControladorMontos.claveConfiguracion(sesion.persona.id)] =
          jsonEncode({'hash_pin': HashPin.crear(corto, iteraciones: 50)});
    }

    test('el PIN propio del dueño y de la pareja es de 6 dígitos', () async {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        final controlador = await montos(crear(sesionDeEjemplo(rol)));
        expect(controlador.rol, rol);
        for (final malo in ['7382', '73829', '123456']) {
          await expectLater(controlador.crearPin(malo), throwsArgumentError,
              reason: '$rol $malo');
        }
        await controlador.crearPin(nuevo);
        expect(await controlador.verificar(nuevo), ResultadoRevelar.revelado);
      }
    });

    test('familiar y cuidador conservan de 4 a 6 dígitos', () async {
      for (final rol in [Rol.familiar, Rol.cuidador]) {
        final controlador = await montos(crear(sesionDeEjemplo(rol)));
        await controlador.crearPin('7382');
        expect(await controlador.verificar('7382'), ResultadoRevelar.revelado);
      }
    });

    test('PIN propio anterior corto: no revela, pide uno nuevo', () async {
      final dueno = sesionDeEjemplo(Rol.dueno);
      pinPropioAnterior(dueno);
      final controlador = await montos(crear(dueno));
      expect(controlador.fuente, FuenteDePinMontos.propio);
      expect(await controlador.verificar(corto), ResultadoRevelar.debeCambiarPin);
      expect(controlador.esperaRestante(), isNull, reason: 'no cuenta como fallo');
      expect(await controlador.verificar('0001'), ResultadoRevelar.pinIncorrecto);
    });

    test('cambiar el PIN propio corto por uno de 6 y ver los montos', () async {
      final dueno = sesionDeEjemplo(Rol.dueno);
      pinPropioAnterior(dueno);
      final contenedor = crear(dueno);
      final controlador = await montos(contenedor);
      expect(await controlador.verificar(corto), ResultadoRevelar.debeCambiarPin);

      expect(await controlador.cambiarPin(corto, nuevo), ResultadoRevelar.revelado);
      expect(await controlador.verificar(corto), ResultadoRevelar.pinIncorrecto);
      expect(await controlador.verificar(nuevo), ResultadoRevelar.revelado);
      // Se guardó, con el resto de su configuración, y solo como hash.
      final guardado = almacen.datos[
          ControladorMontos.claveConfiguracion(dueno.persona.id)]!;
      expect(guardado, isNot(contains(nuevo)));
      final otra = await montos(crear(dueno));
      expect(await otra.verificar(nuevo), ResultadoRevelar.revelado);
    });

    test('el cambio pide el PIN actual (los fallos cuentan) y un nuevo válido',
        () async {
      final dueno = sesionDeEjemplo(Rol.dueno);
      pinPropioAnterior(dueno);
      final controlador = await montos(crear(dueno));
      expect(await controlador.cambiarPin('0001', nuevo),
          ResultadoRevelar.pinIncorrecto);
      for (final malo in ['7391', '123456']) {
        await expectLater(controlador.cambiarPin(corto, malo), throwsArgumentError,
            reason: malo);
      }
      expect(await controlador.verificar(corto), ResultadoRevelar.debeCambiarPin,
          reason: 'nada cambió');
      for (var i = 0; i < 4; i++) {
        await controlador.cambiarPin('0001', nuevo);
      }
      expect(await controlador.cambiarPin('0001', nuevo),
          ResultadoRevelar.bloqueado);
    });

    test('con el bloqueo del teléfono, el PIN corto del bloqueo se cambia desde '
        'aquí y cambia el del bloqueo', () async {
      final dueno = sesionDeEjemplo(Rol.dueno);
      almacen.datos[ControladorBloqueo.claveConfiguracion(dueno.persona.id)] =
          jsonEncode(
            ConfiguracionBloqueo(
              hashPin: HashPin.crear(corto, iteraciones: 50),
            ).aJson(),
          );
      final contenedor = crear(dueno);
      final bloqueo = contenedor.read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      final controlador = await montos(contenedor);
      expect(controlador.fuente, FuenteDePinMontos.bloqueo);
      expect(await controlador.verificar(corto), ResultadoRevelar.debeCambiarPin);

      expect(await controlador.cambiarPin(corto, nuevo), ResultadoRevelar.revelado);
      expect(bloqueo.comprobarPin(nuevo), ResultadoBloqueo.abierto);
      expect(bloqueo.comprobarPin(corto), ResultadoBloqueo.pinIncorrecto);
      expect(await controlador.verificar(nuevo), ResultadoRevelar.revelado);
    });

    test('quien no ve dinero con PIN corto no tiene que cambiarlo', () async {
      final familiar = sesionDeEjemplo(Rol.familiar);
      pinPropioAnterior(familiar);
      final controlador = await montos(crear(familiar));
      expect(await controlador.verificar(corto), ResultadoRevelar.revelado);
    });
  });

  group('tablet', () {
    late AlmacenSeguroEnMemoria almacen;
    late ServicioSesionFalso servicio;
    late DateTime ahora;
    final casa = sesionDeEjemplo(Rol.casa);

    setUp(() {
      almacen = AlmacenSeguroEnMemoria();
      servicio = ServicioSesionFalso(
        cuentas: {
          'dueno@ejemplo.test':
              CuentaFalsa('clave', sesionDeEjemplo(Rol.dueno)),
          'pareja@ejemplo.test':
              CuentaFalsa('clave', sesionDeEjemplo(Rol.coadministrador)),
          'tia@ejemplo.test':
              CuentaFalsa('clave', sesionDeEjemplo(Rol.familiar)),
          'ana@ejemplo.test':
              CuentaFalsa('clave', sesionDeEjemplo(Rol.cuidador)),
        },
        inicial: casa,
      );
      ahora = DateTime(2026, 10, 24, 9);
    });

    Future<(ProviderContainer, ControladorTablet)> abrir() async {
      final contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioSesionProvider.overrideWithValue(servicio),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
          relojSeguridadProvider.overrideWithValue(() => ahora),
        ],
      );
      addTearDown(contenedor.dispose);
      final controlador = contenedor.read(controladorTabletProvider.notifier);
      await controlador.listo;
      return (contenedor, controlador);
    }

    test('agregar al dueño o a la pareja pide 6 dígitos (al conocer su rol)',
        () async {
      final (contenedor, controlador) = await abrir();
      for (final correo in ['dueno@ejemplo.test', 'pareja@ejemplo.test']) {
        for (final malo in ['7382', '73829']) {
          await expectLater(
            controlador.agregarConCredenciales(
              correo: correo,
              contrasena: 'clave',
              pin: malo,
            ),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'mensaje',
                contains('6 dígitos'),
              ),
            ),
            reason: '$correo $malo',
          );
        }
      }
      expect(contenedor.read(controladorTabletProvider).usuarios, isEmpty,
          reason: 'ninguno quedó en la tablet');
      final usuario = await controlador.agregarConCredenciales(
        correo: 'dueno@ejemplo.test',
        contrasena: 'clave',
        pin: nuevo,
      );
      expect(usuario.rol, Rol.dueno);
    });

    test('agregar con agregarUsuario aplica el mismo largo por rol', () async {
      final (_, controlador) = await abrir();
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        await expectLater(
          controlador.agregarUsuario(sesionDeEjemplo(rol), pin: corto),
          throwsArgumentError,
        );
        await controlador.agregarUsuario(sesionDeEjemplo(rol), pin: nuevo);
      }
      for (final rol in [Rol.familiar, Rol.cuidador]) {
        await controlador.agregarUsuario(sesionDeEjemplo(rol), pin: corto);
      }
    });

    test('familiar y cuidador siguen eligiendo de 4 a 6 dígitos', () async {
      final (_, controlador) = await abrir();
      for (final (correo, pin) in [
        ('tia@ejemplo.test', '7382'),
        ('ana@ejemplo.test', '73829'),
      ]) {
        final usuario = await controlador.agregarConCredenciales(
          correo: correo,
          contrasena: 'clave',
          pin: pin,
        );
        expect(
          await controlador.entrarConPin(usuario.personaId, pin),
          ResultadoDesbloqueo.abierto,
          reason: correo,
        );
        controlador.volverAlReposo();
        await controlador.cambiosEnServidor;
      }
    });

    test('cambiar el PIN del dueño o la pareja: 6 dígitos; del familiar, de 4 a 6',
        () async {
      final (_, controlador) = await abrir();
      final dueno = await controlador.agregarUsuario(
        sesionDeEjemplo(Rol.dueno),
        pin: nuevo,
      );
      final familiar = await controlador.agregarUsuario(
        sesionDeEjemplo(Rol.familiar),
        pin: corto,
      );
      await expectLater(
        controlador.cambiarPin(dueno.personaId, pinActual: nuevo, pinNuevo: '7391'),
        throwsArgumentError,
      );
      await expectLater(
        controlador.cambiarPin(dueno.personaId, pinActual: nuevo, pinNuevo: '73915'),
        throwsArgumentError,
      );
      expect(
        await controlador.cambiarPin(
          familiar.personaId,
          pinActual: corto,
          pinNuevo: '7391',
        ),
        ResultadoDesbloqueo.abierto,
      );
    });

    test('un PIN anterior corto del dueño no abre la tablet pública ni la '
        'personal: pide cambiarlo', () async {
      final (contenedor, controlador) = await abrir();
      final dueno = sesionDeEjemplo(Rol.dueno);
      // Como estaba antes de la regla: hash y credencial con el PIN corto.
      final repositorio = RepositorioTablet(almacen);
      await repositorio.guardarUsuarios([
        UsuarioTablet.desdeSesion(
          dueno,
          hashPin: HashPin.crear(corto, iteraciones: 50),
        ),
      ]);
      contenedor.dispose();
      final (otro, nuevaApp) = await abrir();
      final id = dueno.persona.id;

      expect(nuevaApp.comprobarPin(id, corto), ResultadoDesbloqueo.debeCambiarPin);
      expect(nuevaApp.desbloquearConPin(id, corto), ResultadoDesbloqueo.debeCambiarPin);
      expect(nuevaApp.desbloquearConPin(id, corto, soloAccion: true),
          ResultadoDesbloqueo.debeCambiarPin);
      expect(await nuevaApp.entrarParaAccion(id, corto),
          ResultadoDesbloqueo.debeCambiarPin);
      expect(otro.read(controladorTabletProvider).usuarioActivo, isNull);
      expect(nuevaApp.esperaRestante(id), isNull, reason: 'no cuenta como fallo');
      expect(nuevaApp.desbloquearConPin(id, '0001'),
          ResultadoDesbloqueo.pinIncorrecto);
    });

    test('el servidor lo ascendió a un rol que ve dinero con un PIN corto: no '
        'entra y regresa a Hogar', () async {
      final (contenedor, controlador) = await abrir();
      final familiar = sesionDeEjemplo(Rol.familiar);
      // Guardada como familiar; el servidor ya lo tiene como coadministrador.
      final ascendido = Sesion(
        persona: familiar.persona,
        rol: Rol.coadministrador,
        hogarId: familiar.hogarId,
      );
      await controlador.agregarUsuario(
        familiar,
        pin: corto,
        credencial: ServicioSesionFalso.credencialDe(ascendido),
      );
      expect(
        await controlador.entrarConPin(familiar.persona.id, corto),
        ResultadoDesbloqueo.debeCambiarPin,
      );
      expect(contenedor.read(controladorTabletProvider).usuarioActivo, isNull);
      await controlador.cambiosEnServidor;
      expect(servicio.personaEnServidor, casa.persona.id);
      // El rol nuevo quedó guardado: ahora el cambio pide 6 dígitos.
      expect(
        contenedor
            .read(controladorTabletProvider)
            .usuarios
            .single
            .rol,
        Rol.coadministrador,
      );
      await expectLater(
        controlador.cambiarPinYEntrar(
          familiar.persona.id,
          pinActual: corto,
          pinNuevo: '7391',
        ),
        throwsArgumentError,
      );
      expect(
        await controlador.cambiarPinYEntrar(
          familiar.persona.id,
          pinActual: corto,
          pinNuevo: nuevo,
        ),
        ResultadoDesbloqueo.abierto,
      );
    });
  });
}

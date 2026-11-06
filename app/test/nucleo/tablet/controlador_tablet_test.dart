import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late ServicioSesion servicio;
  late BiometriaFalsa biometria;
  late DateTime ahora;

  ServicioSesionFalso falso() => servicio as ServicioSesionFalso;

  ProviderContainer crear() {
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(servicio),
        biometriaProvider.overrideWithValue(biometria),
        relojSeguridadProvider.overrideWithValue(() => ahora),
      ],
    );
    addTearDown(contenedor.dispose);
    return contenedor;
  }

  Future<ControladorTablet> listo(ProviderContainer contenedor) async {
    final controlador = contenedor.read(controladorTabletProvider.notifier);
    await controlador.listo;
    return controlador;
  }

  /// Agrega a la persona de ejemplo del [rol] con su credencial del servidor.
  Future<UsuarioTablet> agregar(
    ControladorTablet controlador,
    Rol rol, {
    String pin = '246813',
  }) => controlador.agregarUsuario(
    sesionDeEjemplo(rol),
    pin: pin,
    credencial: ServicioSesionFalso.credencialDe(sesionDeEjemplo(rol)),
  );

  /// Credencial guardada (descifrada con [pin]) y su vuelta de renovación.
  Future<int?> vueltaGuardada(String personaId, String pin) async {
    final guardada = await RepositorioTablet(almacen)
        .leerCredencial(personaId, pin);
    return guardada == null
        ? null
        : ServicioSesionFalso.leerCredencial(guardada.$2)?.$2;
  }

  final casa = sesionDeEjemplo(Rol.casa).persona.id;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    servicio = ServicioSesionFalso(
      cuentas: {
        'ana@ejemplo.test': CuentaFalsa('clave', sesionDeEjemplo(Rol.cuidador)),
        'casa@ejemplo.test': CuentaFalsa('clave', sesionDeEjemplo(Rol.casa)),
      },
      inicial: sesionDeEjemplo(Rol.casa),
    );
    biometria = BiometriaFalsa();
    ahora = DateTime(2026, 10, 20, 9);
  });

  test('empieza en modo Casa, sin personas', () async {
    final contenedor = crear();
    await listo(contenedor);
    final estado = contenedor.read(controladorTabletProvider);
    expect(estado.cargado, isTrue);
    expect(estado.enModoCasa, isTrue);
    expect(estado.usuarios, isEmpty);
    expect(estado.configuracion.regresoModoCasa, const Duration(minutes: 2));
  });

  test(
    'agregar con credenciales: hash del PIN y credencial cifrada con él',
    () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      final usuario = await controlador.agregarConCredenciales(
        correo: 'ana@ejemplo.test',
        contrasena: 'clave',
        pin: '2468',
      );
      expect(usuario.rol, Rol.cuidador);
      expect(contenedor.read(controladorTabletProvider).usuarios, [usuario]);
      final guardado = almacen.datos[RepositorioTablet.claveUsuarios]!;
      expect(guardado, isNot(contains('2468')));
      expect(guardado, contains('pbkdf2-sha256'));

      // La credencial no se guarda en claro y solo el PIN la abre.
      final sobre =
          almacen.datos[RepositorioTablet.claveCredencial(usuario.personaId)]!;
      expect(sobre, isNot(contains('falsa:')));
      expect(CifradoPin.descifrar('0000', sobre), isNull);
      expect(await vueltaGuardada(usuario.personaId, '2468'), 0);

      // Otra instancia lee lo guardado.
      final otro = crear();
      await listo(otro);
      expect(
        otro.read(controladorTabletProvider).usuarios.single.nombre,
        usuario.nombre,
      );
    },
  );

  test('M9: no se aceptan PIN triviales al agregar ni al cambiar', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    for (final trivial in [
      '0000',
      '1234',
      '1111',
      '4321',
      '0123',
      '7890',
      '123456',
      '654321',
      '999999',
      '1212',
      '4545',
      '123123',
    ]) {
      await expectLater(
        controlador.agregarConCredenciales(
          correo: 'ana@ejemplo.test',
          contrasena: 'clave',
          pin: trivial,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'motivo',
            contains('Elige uno menos fácil de adivinar'),
          ),
        ),
        reason: trivial,
      );
    }
    expect(
      contenedor.read(controladorTabletProvider).usuarios,
      isEmpty,
      reason: 'ninguno de los rechazados quedó en la tablet',
    );

    final usuario = await agregar(controlador, Rol.dueno);
    for (final trivial in [
      '0000',
      '1234',
      '8888',
      '3456',
      '111111',
      '123456',
      '654321',
      '121212',
      '123123',
    ]) {
      await expectLater(
        controlador.cambiarPin(
          usuario.personaId,
          pinActual: '246813',
          pinNuevo: trivial,
        ),
        throwsArgumentError,
        reason: trivial,
      );
    }
    // El PIN de antes sigue valiendo: el rechazo no cambió nada.
    expect(
      await controlador.cambiarPin(
        usuario.personaId,
        pinActual: '246813',
        pinNuevo: '739150',
      ),
      ResultadoDesbloqueo.abierto,
    );
  });

  test(
    'credenciales incorrectas, PIN inválido y cuenta Casa se rechazan',
    () async {
      final controlador = await listo(crear());
      await expectLater(
        controlador.agregarConCredenciales(
          correo: 'ana@ejemplo.test',
          contrasena: 'mal',
          pin: '2468',
        ),
        throwsA(isA<ErrorSesion>()),
      );
      await expectLater(
        controlador.agregarConCredenciales(
          correo: 'ana@ejemplo.test',
          contrasena: 'clave',
          pin: '12',
        ),
        throwsArgumentError,
      );
      await expectLater(
        controlador.agregarConCredenciales(
          correo: 'casa@ejemplo.test',
          contrasena: 'clave',
          pin: '2468',
        ),
        throwsArgumentError,
      );
    },
  );

  test('I6: con el PIN la sesión del servidor es la de la persona; al volver, '
      'la de Casa', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    final usuario = await agregar(controlador, Rol.dueno, pin: '135790');
    expect(falso().personaEnServidor, casa);

    expect(
      await controlador.entrarConPin(usuario.personaId, '000000'),
      ResultadoDesbloqueo.pinIncorrecto,
    );
    expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
    expect(falso().personaEnServidor, casa);

    expect(
      await controlador.entrarConPin(usuario.personaId, '135790'),
      ResultadoDesbloqueo.abierto,
    );
    expect(
      contenedor.read(controladorTabletProvider).usuarioActivo?.rol,
      Rol.dueno,
    );
    expect(falso().personaEnServidor, usuario.personaId);
    // La credencial renovada al abrir se guardó (cifrada).
    expect(await vueltaGuardada(usuario.personaId, '135790'), 1);

    // El servidor la renueva mientras está dentro: se guarda otra vez.
    falso().renovarCredencialDePersona();
    await pumpEventQueue();
    expect(await vueltaGuardada(usuario.personaId, '135790'), 2);

    controlador.volverAModoCasa();
    expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
    await controlador.cambiosEnServidor;
    expect(falso().personaEnServidor, casa);
    expect(await vueltaGuardada(usuario.personaId, '135790'), 2);

    expect(
      controlador.desbloquearConPin('no-existe', '135790'),
      ResultadoDesbloqueo.noExiste,
    );
  });

  test('I6: el rol lo dice el servidor; dada de baja, se quita de la tablet', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    // En la tablet quedó como Familiar, pero el servidor dice Coadministrador.
    final guardado = await controlador.agregarUsuario(
      Sesion(
        persona: sesionDeEjemplo(Rol.coadministrador).persona,
        rol: Rol.familiar,
        hogarId: hogarDeEjemplo,
      ),
      pin: '246813',
      credencial: ServicioSesionFalso.credencialDe(
        sesionDeEjemplo(Rol.coadministrador),
      ),
    );
    expect(
      await controlador.entrarConPin(guardado.personaId, '246813'),
      ResultadoDesbloqueo.abierto,
    );
    expect(
      contenedor.read(controladorTabletProvider).usuarioActivo?.rol,
      Rol.coadministrador,
    );
    expect(
      contenedor.read(controladorTabletProvider).usuarios.single.rol,
      Rol.coadministrador,
    );
    controlador.volverAModoCasa();
    await controlador.cambiosEnServidor;

    // El Dueño la da de baja: con señal, ya no entra y se quita.
    falso().bajas.add(guardado.personaId);
    expect(
      await controlador.entrarConPin(guardado.personaId, '246813'),
      ResultadoDesbloqueo.sinAcceso,
    );
    final estado = contenedor.read(controladorTabletProvider);
    expect(estado.enModoCasa, isTrue);
    expect(estado.usuarios, isEmpty);
    expect(falso().personaEnServidor, casa);
    expect(
      almacen.datos.containsKey(
        RepositorioTablet.claveCredencial(guardado.personaId),
      ),
      isFalse,
    );
  });

  test('I6: sin señal entra con su credencial y su rol guardado', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    final usuario = await agregar(controlador, Rol.familiar);
    falso().sinConexion = true;
    expect(
      await controlador.entrarConPin(usuario.personaId, '246813'),
      ResultadoDesbloqueo.abierto,
    );
    expect(
      contenedor.read(controladorTabletProvider).usuarioActivo?.rol,
      Rol.familiar,
    );
    expect(falso().personaEnServidor, usuario.personaId);
  });

  test(
    'I6: sin credencial guardada no entra (hay que volver a agregarla)',
    () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      final usuario = await controlador.agregarUsuario(
        sesionDeEjemplo(Rol.dueno),
        pin: '246813',
      );
      expect(
        await controlador.entrarConPin(usuario.personaId, '246813'),
        ResultadoDesbloqueo.faltaCuenta,
      );
      expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
      expect(falso().personaEnServidor, casa);
    },
  );

  test('I6: con una cuenta que no es Casa, nadie entra', () async {
    servicio = ServicioSesionFalso(inicial: sesionDeEjemplo(Rol.dueno));
    final contenedor = crear();
    final controlador = await listo(contenedor);
    final usuario = await agregar(controlador, Rol.familiar);
    expect(
      await controlador.entrarConPin(usuario.personaId, '246813'),
      ResultadoDesbloqueo.requiereCuentaCasa,
    );
    expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
  });

  test(
    'I6: si el servidor cierra la sesión de la persona, vuelve a Casa',
    () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      final usuario = await agregar(controlador, Rol.dueno);
      await controlador.entrarConPin(usuario.personaId, '246813');
      falso().revocarSesionDePersona();
      await pumpEventQueue();
      expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
      await controlador.cambiosEnServidor;
      expect(falso().personaEnServidor, casa);
      expect(await vueltaGuardada(usuario.personaId, '246813'), isNull);
    },
  );

  test(
    'I2: 5 fallos bloquean 30 s; la espera se duplica en cada bloqueo',
    () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      final usuario = await agregar(controlador, Rol.familiar, pin: '1111');
      for (var i = 0; i < 4; i++) {
        expect(
          controlador.desbloquearConPin(usuario.personaId, '9999'),
          ResultadoDesbloqueo.pinIncorrecto,
        );
      }
      expect(
        controlador.desbloquearConPin(usuario.personaId, '9999'),
        ResultadoDesbloqueo.bloqueado,
      );
      expect(
        controlador.esperaRestante(usuario.personaId),
        const Duration(seconds: 30),
      );
      // Ni con el PIN correcto mientras dura el bloqueo.
      expect(
        controlador.desbloquearConPin(usuario.personaId, '1111'),
        ResultadoDesbloqueo.bloqueado,
      );
      ahora = ahora.add(const Duration(seconds: 31));
      for (var i = 0; i < 5; i++) {
        controlador.desbloquearConPin(usuario.personaId, '9999');
      }
      expect(
        controlador.esperaRestante(usuario.personaId),
        const Duration(minutes: 1),
      );
      ahora = ahora.add(const Duration(minutes: 1));
      expect(
        await controlador.entrarConPin(usuario.personaId, '1111'),
        ResultadoDesbloqueo.abierto,
      );
      // Un acierto reinicia la cuenta: el siguiente bloqueo vuelve a 30 s.
      controlador.volverAModoCasa();
      for (var i = 0; i < 5; i++) {
        controlador.desbloquearConPin(usuario.personaId, '9999');
      }
      expect(
        controlador.esperaRestante(usuario.personaId),
        const Duration(seconds: 30),
      );
    },
  );

  test('I2: la espera no pasa de 15 minutos', () {
    const politica = ControladorTablet.politicaIntentos;
    expect(
      [for (var i = 1; i <= 7; i++) politica.esperaDelBloqueo(i).inSeconds],
      [30, 60, 120, 240, 480, 900, 900],
    );
  });

  test(
    'B3: la huella no abre la tablet compartida, aunque esté marcada',
    () async {
      // Datos de la versión anterior: la persona había activado la huella.
      await almacen.escribir(
        RepositorioTablet.claveUsuarios,
        '[{"persona_id":"${sesionDeEjemplo(Rol.dueno).persona.id}",'
        '"nombre":"Dueño de ejemplo","rol":"dueno",'
        '"hash_pin":"pbkdf2-sha256\$1\$AA==\$AA==","huella":true}]',
      );
      final contenedor = crear();
      final controlador = await listo(contenedor);
      final dueno = sesionDeEjemplo(Rol.dueno).persona.id;
      expect(
        await controlador.desbloquearConHuella(dueno),
        ResultadoDesbloqueo.huellaNoDisponible,
      );
      expect(biometria.intentos, 0, reason: 'ni siquiera se pide la huella');
      expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
      expect(
        await controlador.desbloquearConHuella('no-existe'),
        ResultadoDesbloqueo.noExiste,
      );
    },
  );

  test('cambiar PIN pide el actual y vuelve a cifrar la credencial', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    final usuario = await agregar(controlador, Rol.dueno);
    expect(
      await controlador.cambiarPin(
        usuario.personaId,
        pinActual: '0000',
        pinNuevo: '739150',
      ),
      ResultadoDesbloqueo.pinIncorrecto,
    );
    expect(
      await controlador.cambiarPin(
        usuario.personaId,
        pinActual: '246813',
        pinNuevo: '739150',
      ),
      ResultadoDesbloqueo.abierto,
    );
    expect(await vueltaGuardada(usuario.personaId, '246813'), isNull);
    expect(await vueltaGuardada(usuario.personaId, '739150'), 0);
    expect(
      controlador.desbloquearConPin(usuario.personaId, '246813'),
      ResultadoDesbloqueo.pinIncorrecto,
    );
    expect(
      await controlador.entrarConPin(usuario.personaId, '739150'),
      ResultadoDesbloqueo.abierto,
    );

    await controlador.quitarUsuario(usuario.personaId);
    final estado = contenedor.read(controladorTabletProvider);
    expect(estado.usuarios, isEmpty);
    expect(estado.enModoCasa, isTrue);
    expect(falso().personaEnServidor, casa);
    expect(await vueltaGuardada(usuario.personaId, '739150'), isNull);
  });

  test('tiempo de regreso editable y acotado; contexto guardado', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    await controlador.fijarRegresoModoCasa(const Duration(minutes: 5));
    expect(
      contenedor.read(controladorTabletProvider).configuracion.regresoModoCasa,
      const Duration(minutes: 5),
    );
    await controlador.fijarRegresoModoCasa(const Duration(seconds: 1));
    expect(
      contenedor.read(controladorTabletProvider).configuracion.regresoModoCasa,
      regresoModoCasaMinimo,
    );
    await controlador.fijarRegresoModoCasa(const Duration(hours: 3));
    expect(
      contenedor.read(controladorTabletProvider).configuracion.regresoModoCasa,
      regresoModoCasaMaximo,
    );
    await controlador.elegirContexto('cocina');
    final otro = crear();
    await listo(otro);
    expect(
      otro.read(controladorTabletProvider).configuracion.contexto,
      'cocina',
    );
  });

  test('al cerrar la sesión de la tablet se vuelve al modo Casa', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    contenedor.listen(sesionActualProvider, (_, _) {});
    final usuario = await agregar(controlador, Rol.dueno);
    await controlador.entrarConPin(usuario.personaId, '246813');
    expect(contenedor.read(controladorTabletProvider).enModoCasa, isFalse);
    await servicio.salir();
    await pumpEventQueue();
    expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
    expect(falso().personaEnServidor, isNull);
  });

  test('en demostración hay personas de ejemplo con PIN 1234', () async {
    servicio = ServicioSesionDemostracion(inicial: sesionDeEjemplo(Rol.casa));
    final contenedor = crear();
    final controlador = await listo(contenedor);
    final usuarios = contenedor.read(controladorTabletProvider).usuarios;
    expect(usuarios.map((u) => u.rol), [
      Rol.dueno,
      Rol.coadministrador,
      Rol.familiar,
      Rol.cuidador,
    ]);
    expect(
      controlador.desbloquearConPin(
        usuarios.last.personaId,
        ControladorTablet.pinDeDemostracion,
      ),
      ResultadoDesbloqueo.abierto,
    );
    // Sin servidor solo cambia la interfaz, al instante.
    expect(
      contenedor.read(controladorTabletProvider).usuarioActivo?.rol,
      Rol.cuidador,
    );
  });
}

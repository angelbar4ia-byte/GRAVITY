import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
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

  test('agregar con credenciales guarda el hash, nunca el PIN', () async {
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

    // Otra instancia lee lo guardado.
    final otro = crear();
    await listo(otro);
    expect(otro.read(controladorTabletProvider).usuarios.single.nombre,
        usuario.nombre);
  });

  test('credenciales incorrectas, PIN inválido y cuenta Casa se rechazan',
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
        pin: '1234',
      ),
      throwsArgumentError,
    );
  });

  test('PIN correcto abre a la persona; volver al modo Casa la cierra',
      () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    final usuario = await controlador.agregarUsuario(
      sesionDeEjemplo(Rol.dueno),
      pin: '135790',
    );
    expect(
      controlador.desbloquearConPin(usuario.personaId, '000000'),
      ResultadoDesbloqueo.pinIncorrecto,
    );
    expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
    expect(
      controlador.desbloquearConPin(usuario.personaId, '135790'),
      ResultadoDesbloqueo.abierto,
    );
    expect(
      contenedor.read(controladorTabletProvider).usuarioActivo?.rol,
      Rol.dueno,
    );
    controlador.volverAModoCasa();
    expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
    expect(
      controlador.desbloquearConPin('no-existe', '135790'),
      ResultadoDesbloqueo.noExiste,
    );
  });

  test('5 intentos fallidos bloquean 30 segundos', () async {
    final controlador = await listo(crear());
    final usuario = await controlador.agregarUsuario(
      sesionDeEjemplo(Rol.familiar),
      pin: '1111',
    );
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
    // Ni con el PIN correcto mientras dura el bloqueo.
    expect(
      controlador.desbloquearConPin(usuario.personaId, '1111'),
      ResultadoDesbloqueo.bloqueado,
    );
    ahora = ahora.add(const Duration(seconds: 31));
    expect(
      controlador.desbloquearConPin(usuario.personaId, '1111'),
      ResultadoDesbloqueo.abierto,
    );
  });

  test('huella: solo si la persona la activó y el dispositivo la tiene',
      () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    final usuario = await controlador.agregarUsuario(
      sesionDeEjemplo(Rol.coadministrador),
      pin: '1234',
    );
    expect(
      await controlador.desbloquearConHuella(usuario.personaId),
      ResultadoDesbloqueo.huellaNoDisponible,
    );
    await controlador.cambiarHuella(usuario.personaId, activa: true);
    biometria.acepta = false;
    expect(
      await controlador.desbloquearConHuella(usuario.personaId),
      ResultadoDesbloqueo.huellaFallida,
    );
    biometria.acepta = true;
    expect(
      await controlador.desbloquearConHuella(usuario.personaId),
      ResultadoDesbloqueo.abierto,
    );
    biometria.hayHuella = false;
    controlador.volverAModoCasa();
    expect(
      await controlador.desbloquearConHuella(usuario.personaId),
      ResultadoDesbloqueo.huellaNoDisponible,
    );
  });

  test('cambiar PIN y quitar persona', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    final usuario = await controlador.agregarUsuario(
      sesionDeEjemplo(Rol.dueno),
      pin: '1234',
    );
    await controlador.cambiarPin(usuario.personaId, '98765');
    expect(
      controlador.desbloquearConPin(usuario.personaId, '1234'),
      ResultadoDesbloqueo.pinIncorrecto,
    );
    expect(
      controlador.desbloquearConPin(usuario.personaId, '98765'),
      ResultadoDesbloqueo.abierto,
    );
    await controlador.quitarUsuario(usuario.personaId);
    final estado = contenedor.read(controladorTabletProvider);
    expect(estado.usuarios, isEmpty);
    expect(estado.enModoCasa, isTrue);
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
    expect(otro.read(controladorTabletProvider).configuracion.contexto, 'cocina');
  });

  test('al cerrar la sesión de la tablet se vuelve al modo Casa', () async {
    final contenedor = crear();
    final controlador = await listo(contenedor);
    contenedor.listen(sesionActualProvider, (_, _) {});
    final usuario = await controlador.agregarUsuario(
      sesionDeEjemplo(Rol.dueno),
      pin: '1234',
    );
    controlador.desbloquearConPin(usuario.personaId, '1234');
    await servicio.salir();
    await pumpEventQueue();
    expect(contenedor.read(controladorTabletProvider).enModoCasa, isTrue);
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
  });
}

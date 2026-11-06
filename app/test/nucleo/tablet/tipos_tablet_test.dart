// D14 (actualizada el 21/oct/2026): dos tipos de tablet. La personal solo deja
// entrar a las personas permitidas (dueño y pareja); la pública deja entrar a
// alguien solo para una acción personal.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late ServicioSesionFalso servicio;

  ProviderContainer crear() {
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(servicio),
        biometriaProvider.overrideWithValue(const BiometriaNoDisponible()),
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

  Future<UsuarioTablet> agregar(ControladorTablet controlador, Rol rol) =>
      controlador.agregarUsuario(
        sesionDeEjemplo(rol),
        pin: '246813',
        credencial: ServicioSesionFalso.credencialDe(sesionDeEjemplo(rol)),
      );

  String id(Rol rol) => sesionDeEjemplo(rol).persona.id;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    servicio = ServicioSesionFalso(inicial: sesionDeEjemplo(Rol.casa));
  });

  test(
    'configuración: tipo y permitidas se guardan; lo desconocido es pública',
    () {
      const personal = ConfiguracionTablet(
        tipo: TipoTablet.personal,
        permitidas: {'b', 'a'},
      );
      final copia = ConfiguracionTablet.desdeJson(
        (jsonDecode(jsonEncode(personal.aJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(copia.tipo, TipoTablet.personal);
      expect(copia.permitidas, {'a', 'b'});
      // Datos de la Fase 0 (sin tipo) o un tipo que no existe: pública.
      expect(ConfiguracionTablet.desdeJson(const {}).tipo, TipoTablet.publica);
      expect(
        ConfiguracionTablet.desdeJson(const {'tipo': 'otra'}).tipo,
        TipoTablet.publica,
      );
    },
  );

  test(
    'por omisión es pública: cualquiera de la tablet entra con su PIN',
    () async {
      final controlador = await listo(crear());
      await agregar(controlador, Rol.familiar);
      expect(controlador.state.configuracion.tipo, TipoTablet.publica);
      expect(
        await controlador.entrarConPin(id(Rol.familiar), '246813'),
        ResultadoDesbloqueo.abierto,
      );
      expect(controlador.state.bloqueada, isFalse);
    },
  );

  test(
    'pasar a personal deja permitido a quien la cambia y se guarda',
    () async {
      final contenedor = crear();
      final controlador = await listo(contenedor);
      await agregar(controlador, Rol.dueno);
      await agregar(controlador, Rol.coadministrador);
      await agregar(controlador, Rol.familiar);
      await controlador.entrarConPin(id(Rol.dueno), '246813');

      await controlador.elegirTipo(TipoTablet.personal);
      expect(controlador.state.configuracion.esPersonal, isTrue);
      expect(controlador.state.configuracion.permitidas, {id(Rol.dueno)});

      controlador.volverAlReposo();
      expect(controlador.state.bloqueada, isTrue);
      expect(controlador.state.muestraModoCasa, isFalse);
      expect(
        controlador.state.usuariosQuePuedenEntrar.map((u) => u.personaId),
        [id(Rol.dueno)],
      );

      // Otra vez la app: sigue personal.
      final otra = await listo(crear());
      expect(otra.state.configuracion.esPersonal, isTrue);
      expect(otra.state.configuracion.permitidas, {id(Rol.dueno)});
    },
  );

  test(
    'personal: quien no está permitido no entra, ni gasta intentos',
    () async {
      final controlador = await listo(crear());
      await agregar(controlador, Rol.dueno);
      await agregar(controlador, Rol.coadministrador);
      await agregar(controlador, Rol.familiar);
      await controlador.elegirTipo(TipoTablet.personal);
      await controlador.permitir(id(Rol.dueno), permitida: true);

      for (final rol in [Rol.coadministrador, Rol.familiar]) {
        for (var i = 0; i < 6; i++) {
          expect(
            await controlador.entrarConPin(id(rol), '246813'),
            ResultadoDesbloqueo.noPermitida,
            reason: '${rol.name} #$i',
          );
        }
        expect(controlador.esperaRestante(id(rol)), isNull);
      }

      // La pareja se permite; el familiar no puede serlo.
      await controlador.permitir(id(Rol.coadministrador), permitida: true);
      expect(
        await controlador.entrarConPin(id(Rol.coadministrador), '246813'),
        ResultadoDesbloqueo.abierto,
      );
      expect(
        () => controlador.permitir(id(Rol.familiar), permitida: true),
        throwsArgumentError,
      );

      // Quitarle el permiso la saca de la tablet.
      await controlador.permitir(id(Rol.coadministrador), permitida: false);
      expect(controlador.state.usuarioActivo, isNull);
      expect(controlador.state.bloqueada, isTrue);
    },
  );

  test(
    'personal: el dueño o la pareja que se agrega queda permitido',
    () async {
      final controlador = await listo(crear());
      await controlador.elegirTipo(TipoTablet.personal);
      await agregar(controlador, Rol.coadministrador);
      await agregar(controlador, Rol.cuidador);
      expect(controlador.state.configuracion.permitidas, {
        id(Rol.coadministrador),
      });
      await controlador.quitarUsuario(id(Rol.coadministrador));
      expect(controlador.state.configuracion.permitidas, isEmpty);
    },
  );

  test('pública: entrar solo para una acción y volver al modo Casa', () async {
    final controlador = await listo(crear());
    await agregar(controlador, Rol.dueno);
    expect(
      await controlador.entrarParaAccion(id(Rol.dueno), '246813'),
      ResultadoDesbloqueo.abierto,
    );
    expect(controlador.state.usuarioActivo?.personaId, id(Rol.dueno));
    expect(controlador.state.soloAccion, isTrue);
    // La pantalla sigue en el modo Casa; el servidor ya es de la persona.
    expect(controlador.state.muestraModoCasa, isTrue);
    await controlador.cambiosEnServidor;
    expect(servicio.personaEnServidor, id(Rol.dueno));

    controlador.volverAlReposo();
    await controlador.cambiosEnServidor;
    expect(controlador.state.usuarioActivo, isNull);
    expect(controlador.state.soloAccion, isFalse);
    expect(servicio.personaEnServidor, id(Rol.casa));

    // Con PIN incorrecto no entra.
    expect(
      await controlador.entrarParaAccion(id(Rol.dueno), '9999'),
      ResultadoDesbloqueo.pinIncorrecto,
    );
  });

  test('cambiar a personal saca a quien entró solo para una acción', () async {
    final controlador = await listo(crear());
    await agregar(controlador, Rol.dueno);
    await controlador.entrarParaAccion(id(Rol.dueno), '246813');
    await controlador.elegirTipo(TipoTablet.personal);
    expect(controlador.state.usuarioActivo, isNull);
    expect(controlador.state.bloqueada, isTrue);
  });
}

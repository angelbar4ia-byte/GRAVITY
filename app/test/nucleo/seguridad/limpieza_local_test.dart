// M5 (revisión de la Fase 1): lo que la app guarda en el equipo por persona
// (copias locales de los módulos) se borra al salir, en una baja y al quitar
// a la persona de la tablet. El gancho vive en nucleo/seguridad/limpieza_local
// y no depende de ningún módulo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_supabase.dart'
    show CopiaLocalFinanzas;
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/limpieza_local.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _usuarioId = 'a0000000-0000-4000-8000-000000000001';

/// Almacén que falla al borrar [claveQueFalla].
class _AlmacenQueFalla extends AlmacenSeguroEnMemoria {
  _AlmacenQueFalla(this.claveQueFalla, super.datos);

  final String claveQueFalla;

  @override
  Future<void> borrar(String clave) async {
    if (clave == claveQueFalla) throw StateError('no se pudo');
    await super.borrar(clave);
  }
}

Future<SupabaseClient> _clienteConSesion() async {
  final cliente = SupabaseClient(
    'http://127.0.0.1:9',
    'llave-publica-de-prueba',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await cliente.auth.setInitialSession(
    jsonEncode({
      'access_token': 'token-de-prueba',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'renovar-de-prueba',
      'user': {
        'id': _usuarioId,
        'aud': 'authenticated',
        'created_at': '2026-10-20T00:00:00Z',
        'app_metadata': <String, Object?>{},
        'user_metadata': <String, Object?>{},
      },
    }),
  );
  return cliente;
}

void main() {
  final dueno = sesionDeEjemplo(Rol.dueno);
  final pareja = sesionDeEjemplo(Rol.coadministrador);
  final idDueno = dueno.persona.id;
  final idPareja = pareja.persona.id;

  /// Deja una copia de cada módulo de [personaId] y algo que no es copia.
  Future<void> llenar(AlmacenSeguroEnMemoria almacen, String personaId) async {
    for (final modulo in Modulo.values) {
      await almacen.escribir(claveCopiaLocal(modulo, personaId), '{"x":1}');
    }
  }

  List<String> copiasDe(AlmacenSeguroEnMemoria almacen, String personaId) => [
    for (final clave in almacen.datos.keys)
      if (clave.endsWith('.copia.$personaId')) clave,
  ];

  group('LimpiezaLocal', () {
    late AlmacenSeguroEnMemoria almacen;
    late LimpiezaLocal limpieza;

    setUp(() {
      almacen = AlmacenSeguroEnMemoria({'sesion.ultima': 'no es una copia'});
      limpieza = LimpiezaLocal(almacen);
    });

    test('la clave de la convención es la de CopiaLocalFinanzas', () async {
      final copia = CopiaLocalFinanzas(almacen, personaId: idDueno);
      await copia.guardar({'fin_libros': <Object>[]});
      expect(almacen.datos.keys, contains(claveCopiaLocal(Modulo.finanzas, idDueno)));
      expect(claveCopiaLocal(Modulo.finanzas, idDueno), 'finanzas.copia.$idDueno');
    });

    test('alQuitarPersona borra las copias de la persona y nada más', () async {
      await llenar(almacen, idDueno);
      await llenar(almacen, idPareja);

      await limpieza.alQuitarPersona(idDueno);

      expect(copiasDe(almacen, idDueno), isEmpty);
      expect(copiasDe(almacen, idPareja), hasLength(Modulo.values.length));
      expect(almacen.datos['sesion.ultima'], 'no es una copia');
    });

    test('corre los ganchos registrados con el id de la persona', () async {
      final llamadas = <String>[];
      limpieza
        ..registrar((id) async => llamadas.add('a:$id'))
        ..registrar((id) async => llamadas.add('b:$id'));
      await limpieza.alQuitarPersona(idDueno);
      expect(llamadas, ['a:$idDueno', 'b:$idDueno']);
    });

    test('una limpieza que falla no impide las demás ni lanza', () async {
      final fallido = _AlmacenQueFalla(claveCopiaLocal(Modulo.cuidados, idDueno), {});
      await llenar(fallido, idDueno);
      final llamadas = <String>[];
      final conFalla = LimpiezaLocal(
        fallido,
        ganchos: [
          (_) async => throw StateError('gancho roto'),
          (id) async => llamadas.add(id),
        ],
      );

      await conFalla.alQuitarPersona(idDueno);

      expect(llamadas, [idDueno], reason: 'el gancho siguiente sí corre');
      expect(
        copiasDe(fallido, idDueno),
        [claveCopiaLocal(Modulo.cuidados, idDueno)],
        reason: 'solo queda la que no se pudo borrar',
      );
    });

    test('alQuitarTodas barre las copias de cualquier persona', () async {
      await llenar(almacen, idDueno);
      await llenar(almacen, idPareja);
      await almacen.escribir('tablet.pin', 'hash');
      await almacen.escribir('copia.suelta', 'x');

      await limpieza.alQuitarTodas();

      expect(copiasDe(almacen, idDueno), isEmpty);
      expect(copiasDe(almacen, idPareja), isEmpty);
      expect(
        almacen.datos.keys.toSet(),
        {'sesion.ultima', 'tablet.pin', 'copia.suelta'},
      );
    });
  });

  group('al salir y en una baja (ServicioSesionSupabase)', () {
    late AlmacenSeguroEnMemoria almacen;

    setUp(() async {
      almacen = AlmacenSeguroEnMemoria();
      await llenar(almacen, idDueno);
      await llenar(almacen, idPareja);
    });

    Future<ServicioSesionSupabase> servicio({
      required LectorPerfil lector,
      LimpiezaLocal? limpieza,
    }) async {
      final cliente = await _clienteConSesion();
      addTearDown(cliente.dispose);
      final servicio = ServicioSesionSupabase(
        cliente: cliente,
        almacen: almacen,
        url: 'http://127.0.0.1:9',
        llavePublica: 'llave-publica-de-prueba',
        lectorPerfil: lector,
        limpieza: limpieza,
      );
      addTearDown(servicio.cerrar);
      return servicio;
    }

    test('salir() borra lo de quien sale y no lo de otra persona', () async {
      final s = await servicio(lector: (_) async => dueno);
      await s.iniciar();

      await s.salir();

      expect(copiasDe(almacen, idDueno), isEmpty);
      expect(
        copiasDe(almacen, idPareja),
        hasLength(Modulo.values.length),
        reason: 'la tablet puede tener lo de otras personas',
      );
    });

    test('salir() corre los ganchos de los módulos', () async {
      final llamadas = <String>[];
      final limpieza = LimpiezaLocal(almacen)
        ..registrar((id) async => llamadas.add(id));
      final s = await servicio(lector: (_) async => dueno, limpieza: limpieza);
      await s.iniciar();

      await s.salir();

      expect(llamadas, [idDueno]);
    });

    test('salir() sin sesión abierta no borra nada', () async {
      final s = await servicio(lector: (_) async => throw ErrorSesion.sinRol);
      // No se llamó a iniciar(): nadie ha entrado.
      await s.salir();
      expect(copiasDe(almacen, idDueno), hasLength(Modulo.values.length));
    });

    test('una baja al abrir borra la persona de la última sesión guardada',
        () async {
      await almacen.escribir(
        ServicioSesionSupabase.claveSesionGuardada,
        jsonEncode({'usuario_id': _usuarioId, 'sesion': dueno.aJson()}),
      );
      final s = await servicio(lector: (_) async => throw ErrorSesion.sinRol);

      await s.iniciar();

      expect(s.sesionActual, isNull);
      expect(copiasDe(almacen, idDueno), isEmpty);
      expect(
        copiasDe(almacen, idPareja),
        hasLength(Modulo.values.length),
        reason: 'se sabe de quién era: solo se borra lo suyo',
      );
      expect(
        almacen.datos.containsKey(ServicioSesionSupabase.claveSesionGuardada),
        isFalse,
      );
    });

    test('una baja al abrir sin sesión guardada barre todas las copias', () async {
      final s = await servicio(lector: (_) async => throw ErrorSesion.sinRol);
      await s.iniciar();
      expect(copiasDe(almacen, idDueno), isEmpty);
      expect(copiasDe(almacen, idPareja), isEmpty);
    });

    test('sin señal al abrir no se borra nada (se usa la copia)', () async {
      await almacen.escribir(
        ServicioSesionSupabase.claveSesionGuardada,
        jsonEncode({'usuario_id': _usuarioId, 'sesion': dueno.aJson()}),
      );
      final s = await servicio(
        lector: (_) async => throw const SocketException('sin red'),
      );
      await s.iniciar();
      expect(s.sesionActual, dueno);
      expect(copiasDe(almacen, idDueno), hasLength(Modulo.values.length));
    });
  });

  group('al quitar a la persona de la tablet', () {
    late AlmacenSeguroEnMemoria almacen;
    late ProviderContainer contenedor;
    late ControladorTablet controlador;

    setUp(() async {
      almacen = AlmacenSeguroEnMemoria();
      final servicio = ServicioSesionFalso(
        cuentas: {
          'casa@ejemplo.test': CuentaFalsa('clave', sesionDeEjemplo(Rol.casa)),
        },
        inicial: sesionDeEjemplo(Rol.casa),
      );
      contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioSesionProvider.overrideWithValue(servicio),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
        ],
      );
      addTearDown(contenedor.dispose);
      controlador = contenedor.read(controladorTabletProvider.notifier);
      await controlador.listo;
      for (final sesion in [dueno, pareja]) {
        await controlador.agregarUsuario(
          sesion,
          pin: '2846',
          credencial: ServicioSesionFalso.credencialDe(sesion),
        );
        await llenar(almacen, sesion.persona.id);
      }
    });

    test('quitarUsuario borra sus copias y deja las de las demás', () async {
      await controlador.quitarUsuario(idDueno);
      expect(copiasDe(almacen, idDueno), isEmpty);
      expect(copiasDe(almacen, idPareja), hasLength(Modulo.values.length));
      expect(
        contenedor
            .read(controladorTabletProvider)
            .usuarios
            .map((u) => u.personaId),
        [idPareja],
      );
    });

    test('quitarUsuario corre los ganchos registrados por los módulos', () async {
      final llamadas = <String>[];
      contenedor
          .read(limpiezaLocalProvider)
          .registrar((id) async => llamadas.add(id));
      await controlador.quitarUsuario(idPareja);
      expect(llamadas, [idPareja]);
    });
  });
}

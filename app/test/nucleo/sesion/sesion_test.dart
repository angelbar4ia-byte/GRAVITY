import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Sesion va y vuelve de JSON', () {
    final sesion = sesionDeEjemplo(Rol.cuidador);
    expect(Sesion.desdeJson(sesion.aJson()), sesion);
  });

  group('modo demostración', () {
    test('entrarComo abre la sesión del rol elegido y avisa', () async {
      final servicio = ServicioSesionDemostracion();
      expect(servicio.esDemostracion, isTrue);
      expect(servicio.sesionActual, isNull);
      final cambios = <Sesion?>[];
      final suscripcion = servicio.cambios.listen(cambios.add);
      await servicio.entrarComo(Rol.familiar);
      expect(servicio.sesionActual?.rol, Rol.familiar);
      await servicio.salir();
      await pumpEventQueue();
      expect(cambios.map((s) => s?.rol), [Rol.familiar, null]);
      await suscripcion.cancel();
    });

    test('el rol de ejemplo sale del correo', () async {
      expect(rolPorCorreoDeEjemplo('cuidador@ejemplo.mx'), Rol.cuidador);
      expect(rolPorCorreoDeEjemplo('Pareja@ejemplo.mx'), Rol.coadministrador);
      expect(rolPorCorreoDeEjemplo('yo@ejemplo.mx'), Rol.dueno);
      final servicio = ServicioSesionDemostracion();
      final sesion = await servicio.entrar(
        correo: 'familiar@ejemplo.mx',
        contrasena: 'x',
      );
      expect(sesion.rol, Rol.familiar);
      expect(
        () => servicio.entrar(correo: 'a@b.mx', contrasena: ''),
        throwsA(isA<ErrorSesion>()),
      );
    });

    test('verificarCredenciales no cambia la sesión abierta', () async {
      final servicio = ServicioSesionDemostracion();
      await servicio.entrarComo(Rol.casa);
      final otra = await servicio.verificarCredenciales(
        correo: 'cuidador@ejemplo.mx',
        contrasena: 'x',
      );
      expect(otra.rol, Rol.cuidador);
      expect(servicio.sesionActual?.rol, Rol.casa);
    });
  });

  group('servicio falso', () {
    final cuenta = CuentaFalsa('secreta', sesionDeEjemplo(Rol.cuidador));

    test('entra con la cuenta correcta y falla con la incorrecta', () async {
      final servicio = ServicioSesionFalso(cuentas: {'ana@ejemplo.mx': cuenta});
      await expectLater(
        servicio.entrar(correo: 'ana@ejemplo.mx', contrasena: 'mal'),
        throwsA(ErrorSesion.credencialesIncorrectas),
      );
      final sesion = await servicio.entrar(
        correo: ' ANA@ejemplo.mx ',
        contrasena: 'secreta',
      );
      expect(sesion.rol, Rol.cuidador);
      expect(servicio.vecesEntrar, 2);
    });

    test('sin conexión avisa con un mensaje claro', () async {
      final servicio = ServicioSesionFalso(
        cuentas: {'ana@ejemplo.mx': cuenta},
        sinConexion: true,
      );
      await expectLater(
        servicio.entrar(correo: 'ana@ejemplo.mx', contrasena: 'secreta'),
        throwsA(ErrorSesion.sinConexion),
      );
    });
  });

  test('sesionActualProvider sigue los cambios del servicio', () async {
    final servicio = ServicioSesionFalso();
    final contenedor = ProviderContainer(
      overrides: [servicioSesionProvider.overrideWithValue(servicio)],
    );
    addTearDown(contenedor.dispose);
    final valores = <Sesion?>[];
    contenedor.listen(
      sesionActualProvider,
      (_, siguiente) => valores.add(siguiente),
      fireImmediately: true,
    );
    servicio.fijarSesion(sesionDeEjemplo(Rol.dueno));
    await pumpEventQueue();
    await servicio.salir();
    await pumpEventQueue();
    expect(valores.map((s) => s?.rol), [null, Rol.dueno, null]);
  });

  group('Supabase (sin red)', () {
    test('sesionDesdeFila lee mi_perfil()', () {
      final sesion = sesionDesdeFila({
        'persona_id': 'p1',
        'nombre': 'Ana',
        'rol': 'cuidador',
        'hogar_id': 'h1',
      });
      expect(sesion.persona.id, 'p1');
      expect(sesion.rol, Rol.cuidador);
      expect(sesion.hogarId, 'h1');
      expect(
        () => sesionDesdeFila({'persona_id': 'p1', 'rol': 'jefe'}),
        throwsA(ErrorSesion.sinRol),
      );
    });

    test('membresiaVigente respeta desde, hasta y el orden', () {
      final ahora = DateTime.utc(2026, 10, 20, 12);
      final filas = [
        {'rol': 'familiar', 'desde': '2026-11-01T00:00:00Z', 'hasta': null},
        {
          'rol': 'cuidador',
          'desde': '2026-01-01T00:00:00Z',
          'hasta': '2026-10-01T00:00:00Z',
        },
        {'rol': 'dueno', 'desde': '2026-01-01T00:00:00+00:00', 'hasta': null},
      ];
      expect(membresiaVigente(filas, ahora)?['rol'], 'dueno');
      expect(membresiaVigente(filas.sublist(0, 2), ahora), isNull);
    });

    test('traducirErrorSesion da mensajes en español', () {
      expect(
        traducirErrorSesion(
          const AuthApiException('Invalid login credentials', statusCode: '400'),
        ),
        ErrorSesion.credencialesIncorrectas,
      );
      expect(
        traducirErrorSesion(const SocketException('sin red')),
        ErrorSesion.sinConexion,
      );
      expect(
        traducirErrorSesion(AuthRetryableFetchException()),
        ErrorSesion.sinConexion,
      );
      expect(traducirErrorSesion(ErrorSesion.sinRol), ErrorSesion.sinRol);
    });
  });
}

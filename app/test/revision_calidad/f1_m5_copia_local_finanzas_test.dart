// M5 (revisión de calidad, Fase 1): la copia local de Finanzas no se borra al
// cerrar sesión, al detectar una baja ni al quitar a una persona de la tablet.
//
// `CopiaLocalFinanzas` guarda en el almacenamiento seguro, por persona
// (`finanzas.copia.<persona>`), los libros, los miembros, las cuentas (con su
// límite), las categorías, los parámetros, los sobres (con su monto semanal),
// los nombres de las personas y quién es la cuenta maestra. Nada la borra: no
// hay un `borrar` de esa llave en ninguna parte. D5: "al darlos de baja pierden
// el acceso de inmediato"; en una tablet compartida lo guardado queda en el
// equipo (y la Fase 0, I3, pedía borrar también "la copia local").
//
// Resuelto (sin etiqueta `hallazgo`).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_supabase.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _usuarioId = 'a0000000-0000-4000-8000-000000000001';

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

/// Deja una copia de Finanzas de [personaId] en [almacen], como la que guarda
/// el repositorio al cargar.
Future<CopiaLocalFinanzas> _conCopia(
  AlmacenSeguroEnMemoria almacen,
  String personaId,
) async {
  final copia = CopiaLocalFinanzas(almacen, personaId: personaId);
  await copia.guardar({
    'fin_libros': [
      {'id': 'l1', 'nombre': 'Libro de ejemplo', 'tipo': 'personal'},
    ],
    'fin_cuentas': [
      {'id': 'c1', 'nombre': 'Cuenta de ejemplo', 'tipo': 'banco'},
    ],
    'personas': {personaId: 'Persona de ejemplo'},
    'es_maestra': false,
  });
  expect(await copia.leer(), isNotNull, reason: 'preparación de la prueba');
  return copia;
}

void main() {
  final dueno = sesionDeEjemplo(Rol.dueno);

  test('salir() borra la copia local de Finanzas de la persona', () async {
    final almacen = AlmacenSeguroEnMemoria();
    final copia = await _conCopia(almacen, dueno.persona.id);
    final cliente = await _clienteConSesion();
    addTearDown(cliente.dispose);
    final servicio = ServicioSesionSupabase(
      cliente: cliente,
      almacen: almacen,
      url: 'http://127.0.0.1:9',
      llavePublica: 'llave-publica-de-prueba',
      lectorPerfil: (_) async => dueno,
    );
    addTearDown(servicio.cerrar);
    await servicio.iniciar();
    expect(servicio.sesionActual?.rol, Rol.dueno);

    await servicio.salir();

    expect(servicio.sesionActual, isNull);
    expect(
      await copia.leer(),
      isNull,
      reason: 'cuentas, libros y sobres de la persona siguen en el equipo',
    );
  });

  test('una baja detectada al abrir la app borra la copia local', () async {
    final almacen = AlmacenSeguroEnMemoria();
    final copia = await _conCopia(almacen, dueno.persona.id);
    final cliente = await _clienteConSesion();
    addTearDown(cliente.dispose);
    final servicio = ServicioSesionSupabase(
      cliente: cliente,
      almacen: almacen,
      url: 'http://127.0.0.1:9',
      llavePublica: 'llave-publica-de-prueba',
      lectorPerfil: (_) async => throw ErrorSesion.sinRol,
    );
    addTearDown(servicio.cerrar);

    await servicio.iniciar();

    expect(servicio.sesionActual, isNull);
    expect(
      await copia.leer(),
      isNull,
      reason: 'D5: dada de baja, pierde el acceso de inmediato',
    );
  });

  test(
    'quitar a una persona de la tablet borra su copia de Finanzas',
    () async {
      final almacen = AlmacenSeguroEnMemoria();
      final servicio = ServicioSesionFalso(
        cuentas: {
          'casa@ejemplo.test': CuentaFalsa('clave', sesionDeEjemplo(Rol.casa)),
        },
        inicial: sesionDeEjemplo(Rol.casa),
      );
      final contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioSesionProvider.overrideWithValue(servicio),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
        ],
      );
      addTearDown(contenedor.dispose);
      final controlador = contenedor.read(controladorTabletProvider.notifier);
      await controlador.listo;
      await controlador.agregarUsuario(
        dueno,
        pin: '246813',
        credencial: ServicioSesionFalso.credencialDe(dueno),
      );
      final copia = await _conCopia(almacen, dueno.persona.id);

      await controlador.quitarUsuario(dueno.persona.id);

      expect(
        await copia.leer(),
        isNull,
        reason:
            'lo de Finanzas de quien ya no está en la tablet no debe quedar',
      );
    },
  );
}

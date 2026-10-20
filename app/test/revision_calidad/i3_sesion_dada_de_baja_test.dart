// HALLAZGO I3 (IMPORTANTE) · docs/revisiones/fase-0.md
//
// FALLA HOY A PROPÓSITO (la primera prueba): demuestra el hallazgo.
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// ServicioSesionSupabase.iniciar() atrapa CUALQUIER error al leer el perfil y
// vuelve a la última sesión guardada. Si el servidor responde que la cuenta
// ya no tiene rol (la cuidadora fue dada de baja: ErrorSesion.sinRol), la app
// abre igual con el rol anterior. D5: "al darlos de baja pierden el acceso de
// inmediato". La sesión guardada solo debe usarse cuando NO hay señal.
@Tags(['hallazgo'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const usuarioId = 'a0000000-0000-4000-8000-000000000004';

/// Cliente con una sesión abierta de la cuidadora, sin red (nada sale).
Future<SupabaseClient> clienteConSesion() async {
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
        'id': usuarioId,
        'aud': 'authenticated',
        'created_at': '2026-10-20T00:00:00Z',
        'app_metadata': <String, Object?>{},
        'user_metadata': <String, Object?>{},
      },
    }),
  );
  return cliente;
}

/// Almacén con la última sesión válida: la cuidadora con su rol.
AlmacenSeguroEnMemoria almacenConSesionGuardada() => AlmacenSeguroEnMemoria({
  ServicioSesionSupabase.claveSesionGuardada: jsonEncode({
    'usuario_id': usuarioId,
    'sesion': sesionDeEjemplo(Rol.cuidador).aJson(),
  }),
});

void main() {
  test('dada de baja (el servidor dice "sin rol"): no entra con el rol guardado', () async {
    final cliente = await clienteConSesion();
    addTearDown(cliente.dispose);
    final servicio = ServicioSesionSupabase(
      cliente: cliente,
      almacen: almacenConSesionGuardada(),
      url: 'http://127.0.0.1:9',
      llavePublica: 'llave-publica-de-prueba',
      lectorPerfil: (_) async => throw ErrorSesion.sinRol,
    );
    addTearDown(servicio.cerrar);

    await servicio.iniciar();

    expect(servicio.sesionActual, isNull, reason: 'abrió con el rol de antes de la baja');
  });

  test('sin señal sí usa la sesión guardada (lo que hay que conservar)', () async {
    final cliente = await clienteConSesion();
    addTearDown(cliente.dispose);
    final servicio = ServicioSesionSupabase(
      cliente: cliente,
      almacen: almacenConSesionGuardada(),
      url: 'http://127.0.0.1:9',
      llavePublica: 'llave-publica-de-prueba',
      lectorPerfil: (_) async =>
          throw const SocketException('Sin conexión (simulada)'),
    );
    addTearDown(servicio.cerrar);

    await servicio.iniciar();

    expect(servicio.sesionActual?.rol, Rol.cuidador);
  });
}

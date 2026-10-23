// Sesión del servidor por persona en la tablet (revisión de la Fase 0, I6),
// con el servicio real de Supabase contra un servidor de autenticación
// simulado en local (nada sale a internet).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const uidCasa = 'a0000000-0000-4000-8000-000000000005';
const uidDueno = 'a0000000-0000-4000-8000-000000000001';

String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// JWT sin firma válida (el cliente no la comprueba).
String jwt(String uid, {required DateTime vence}) => [
  _b64({'alg': 'HS256', 'typ': 'JWT'}),
  _b64({
    'sub': uid,
    'aud': 'authenticated',
    'role': 'authenticated',
    'iat': vence.millisecondsSinceEpoch ~/ 1000 - 3600,
    'exp': vence.millisecondsSinceEpoch ~/ 1000,
  }),
  'firma',
].join('.');

Map<String, Object?> usuario(String uid) => {
  'id': uid,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': '$uid@ejemplo.test',
  'created_at': '2026-10-20T00:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
};

Map<String, Object?> sesionJson(String uid, String renovar, {bool vencida = false}) =>
    {
      'access_token': jwt(
        uid,
        vence: DateTime.now().add(
          vencida ? const Duration(hours: -1) : const Duration(hours: 1),
        ),
      ),
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': renovar,
      'user': usuario(uid),
    };

/// Servidor de autenticación simulado (GoTrue).
class GoTrueSimulado {
  late HttpServer _servidor;
  final revocados = <String>{};
  final rutas = <String>[];
  var _vuelta = 0;

  String get url => 'http://127.0.0.1:${_servidor.port}';

  Future<void> abrir() async {
    _servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _servidor.listen((peticion) async {
      final cuerpo = await utf8.decodeStream(peticion);
      rutas.add('${peticion.method} ${peticion.uri.path}');
      final respuesta = peticion.response..headers.contentType = ContentType.json;
      final tipo = peticion.uri.queryParameters['grant_type'];
      if (peticion.uri.path == '/auth/v1/token' && tipo == 'refresh_token') {
        final token = (jsonDecode(cuerpo) as Map)['refresh_token'] as String;
        if (revocados.contains(token)) {
          respuesta
            ..statusCode = 400
            ..write(
              jsonEncode({
                'code': 400,
                'error_code': 'refresh_token_not_found',
                'msg': 'Invalid Refresh Token: Refresh Token Not Found',
              }),
            );
        } else {
          final uid = token.startsWith('casa') ? uidCasa : uidDueno;
          respuesta.write(jsonEncode(sesionJson(uid, 'renovado-${++_vuelta}')));
        }
      } else if (peticion.uri.path == '/auth/v1/token' && tipo == 'password') {
        respuesta.write(jsonEncode(sesionJson(uidDueno, 'de-la-contrasena')));
      } else if (peticion.uri.path == '/auth/v1/user') {
        respuesta.write(jsonEncode(usuario(uidDueno)));
      } else if (peticion.uri.path == '/auth/v1/logout') {
        respuesta.statusCode = 204;
      } else {
        respuesta.statusCode = 404;
      }
      await respuesta.close();
    });
  }

  Future<void> cerrar() => _servidor.close(force: true);
}

void main() {
  late GoTrueSimulado gotrue;
  late SupabaseClient equipo;
  late ServicioSesionSupabase servicio;
  late Set<String> bajas;

  final casa = sesionDeEjemplo(Rol.casa);
  final dueno = sesionDeEjemplo(Rol.dueno);

  Future<Sesion> lector(SupabaseClient cliente) async {
    final uid = cliente.auth.currentUser?.id;
    if (uid == uidCasa) return casa;
    if (uid == uidDueno && !bajas.contains(uidDueno)) return dueno;
    throw ErrorSesion.sinRol;
  }

  Future<void> preparar({String? url}) async {
    final direccion = url ?? gotrue.url;
    equipo = SupabaseClient(
      direccion,
      'llave-publica-de-prueba',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await equipo.auth.setInitialSession(jsonEncode(sesionJson(uidCasa, 'casa-0')));
    servicio = ServicioSesionSupabase(
      cliente: equipo,
      almacen: AlmacenSeguroEnMemoria(),
      url: direccion,
      llavePublica: 'llave-publica-de-prueba',
      lectorPerfil: lector,
    );
    await servicio.iniciar();
    expect(servicio.sesionActual, casa);
  }

  setUp(() async {
    bajas = {};
    gotrue = GoTrueSimulado();
    await gotrue.abrir();
  });

  tearDown(() async {
    await servicio.cerrar();
    await equipo.dispose();
    await gotrue.cerrar();
  });

  test('entra con la credencial de la persona y regresa a la cuenta Casa', () async {
    await preparar();
    expect(servicio.personaEnServidor, casa.persona.id);

    final credencial = jsonEncode(sesionJson(uidDueno, 'r0', vencida: true));
    final apertura = await servicio.abrirSesionDePersona(
      dueno.persona.id,
      credencial,
    );
    expect(apertura.sesion, dueno);
    // Se renovó: hay que guardar la nueva.
    expect(apertura.credencial, contains('renovado-1'));
    expect(servicio.personaEnServidor, dueno.persona.id);
    expect(servicio.clienteActivo, isNot(same(equipo)));
    expect(servicio.clienteActivo.auth.currentUser?.id, uidDueno);
    // La cuenta del equipo no cambió.
    expect(servicio.sesionActual, casa);
    expect(equipo.auth.currentUser?.id, uidCasa);

    final vigente = await servicio.cerrarSesionDePersona();
    expect(vigente, contains('renovado-1'));
    expect(servicio.personaEnServidor, casa.persona.id);
    expect(servicio.clienteActivo, same(equipo));
    // Sin revocar la sesión de la persona: su credencial sigue sirviendo.
    expect(gotrue.rutas, isNot(contains('POST /auth/v1/logout')));
  });

  test('dada de baja: no entra (ErrorSesion.sinRol)', () async {
    await preparar();
    bajas.add(uidDueno);
    await expectLater(
      servicio.abrirSesionDePersona(
        dueno.persona.id,
        jsonEncode(sesionJson(uidDueno, 'r0', vencida: true)),
      ),
      throwsA(ErrorSesion.sinRol),
    );
    expect(servicio.personaEnServidor, casa.persona.id);
    expect(servicio.clienteActivo, same(equipo));
  });

  test('credencial revocada en el servidor: hay que volver a agregarla', () async {
    await preparar();
    gotrue.revocados.add('r0');
    await expectLater(
      servicio.abrirSesionDePersona(
        dueno.persona.id,
        jsonEncode(sesionJson(uidDueno, 'r0', vencida: true)),
      ),
      throwsA(ErrorSesion.credencialVencida),
    );
    expect(servicio.personaEnServidor, casa.persona.id);
    await expectLater(
      servicio.abrirSesionDePersona(dueno.persona.id, 'no es una credencial'),
      throwsA(ErrorSesion.credencialVencida),
    );
  });

  test('sin señal: entra con la credencial guardada (sin rol del servidor)', () async {
    await preparar(url: 'http://127.0.0.1:9');
    final apertura = await servicio.abrirSesionDePersona(
      dueno.persona.id,
      jsonEncode(sesionJson(uidDueno, 'r0', vencida: true)),
    );
    expect(apertura.sinConexion, isTrue);
    expect(servicio.personaEnServidor, dueno.persona.id);
    expect(servicio.clienteActivo.auth.currentUser?.id, uidDueno);
    await servicio.cerrarSesionDePersona();
    expect(servicio.personaEnServidor, casa.persona.id);
  });

  test('obtenerCredencial no revoca la sesión de la persona', () async {
    await preparar();
    final obtenida = await servicio.obtenerCredencial(
      correo: 'dueno@ejemplo.test',
      contrasena: 'clave',
    );
    expect(obtenida.sesion, dueno);
    expect(obtenida.credencial, contains('de-la-contrasena'));
    expect(gotrue.rutas, isNot(contains('POST /auth/v1/logout')));
    expect(servicio.sesionActual, casa, reason: 'la tablet sigue como Casa');
  });

  test('salir también cierra la sesión de la persona', () async {
    await preparar();
    await servicio.abrirSesionDePersona(
      dueno.persona.id,
      jsonEncode(sesionJson(uidDueno, 'r0', vencida: true)),
    );
    await servicio.salir();
    expect(servicio.sesionActual, isNull);
    expect(servicio.personaEnServidor, isNull);
  });

  group('sesión aparte (bandeja de salida)', () {
    String credencialDelDueno(String renovar) =>
        jsonEncode(sesionJson(uidDueno, renovar, vencida: true));

    test('abre aparte, entrega la credencial renovada y no toca al equipo', () async {
      await preparar();
      final entregadas = <String>[];
      final aparte = await servicio.abrirSesionAparte(
        dueno.persona.id,
        credencialDelDueno('r0'),
        alRenovar: entregadas.add,
      );
      expect(aparte.personaId, dueno.persona.id);
      // El servidor rotó el refresh token: la nueva se entregó, no se perdió.
      expect(entregadas, isNotEmpty);
      expect(entregadas.last, contains('renovado-1'));
      // La cuenta del equipo y la persona en pantalla no cambiaron.
      expect(servicio.sesionActual, casa);
      expect(servicio.personaEnServidor, casa.persona.id);
      expect(servicio.clienteActivo, same(equipo));
      expect(equipo.auth.currentUser?.id, uidCasa);

      await aparte.cerrar();
      // Cerrar no revoca la credencial: sigue sirviendo para la próxima vez.
      expect(gotrue.rutas, isNot(contains('POST /auth/v1/logout')));
    });

    test('credencial revocada: no entrega nada y pide volver a agregarla', () async {
      await preparar();
      gotrue.revocados.add('r0');
      final entregadas = <String>[];
      await expectLater(
        servicio.abrirSesionAparte(
          dueno.persona.id,
          credencialDelDueno('r0'),
          alRenovar: entregadas.add,
        ),
        throwsA(ErrorSesion.credencialVencida),
      );
      expect(entregadas, isEmpty);
      expect(servicio.clienteActivo, same(equipo));
    });

    test('credencial ilegible o sin refresh token: vencida', () async {
      await preparar();
      for (final credencial in [
        'no es una credencial',
        jsonEncode(sesionJson(uidDueno, '')),
      ]) {
        await expectLater(
          servicio.abrirSesionAparte(
            dueno.persona.id,
            credencial,
            alRenovar: (_) {},
          ),
          throwsA(ErrorSesion.credencialVencida),
        );
      }
    });

    test('la credencial es de otra persona: no se usa', () async {
      await preparar();
      await expectLater(
        servicio.abrirSesionAparte(
          'otra-persona',
          credencialDelDueno('r0'),
          alRenovar: (_) {},
        ),
        throwsA(ErrorSesion.credencialVencida),
      );
    });

    test('dada de baja: sin rol, y se cierra su sesión en el servidor', () async {
      await preparar();
      bajas.add(uidDueno);
      await expectLater(
        servicio.abrirSesionAparte(
          dueno.persona.id,
          credencialDelDueno('r0'),
          alRenovar: (_) {},
        ),
        throwsA(ErrorSesion.sinRol),
      );
      expect(gotrue.rutas, contains('POST /auth/v1/logout'));
    });

    test('sin señal: sinConexion (la credencial no se descarta)', () async {
      await preparar(url: 'http://127.0.0.1:9');
      final entregadas = <String>[];
      await expectLater(
        servicio.abrirSesionAparte(
          dueno.persona.id,
          credencialDelDueno('r0'),
          alRenovar: entregadas.add,
        ),
        throwsA(ErrorSesion.sinConexion),
      );
      expect(entregadas, isEmpty);
    });
  });
}

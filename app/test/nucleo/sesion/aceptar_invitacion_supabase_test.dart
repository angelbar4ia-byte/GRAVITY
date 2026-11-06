// "Tengo una invitación" con el servicio real de Supabase contra un servidor
// simulado en local (E3 de la Fase 4): registro o entrada, `aceptar_invitacion`
// y los errores del servidor traducidos.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cola/postgrest_simulado.dart' show sesionJson;

/// GoTrue + PostgREST mínimos: anota cada petición.
class _Servidor {
  late HttpServer _http;
  final peticiones = <(String, String, Object?)>[];

  /// Respuesta de `signup`: con sesión o solo el usuario (hay que confirmar).
  bool signupConSesion = true;

  /// Respuesta de la contraseña: `null` = bien; si no, (estado, cuerpo).
  (int, Object)? errorDeContrasena;

  /// Respuesta de `aceptar_invitacion`: `null` = bien.
  (int, Object)? errorAlAceptar;

  String get url => 'http://127.0.0.1:${_http.port}';

  Future<void> abrir() async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _http.listen((peticion) async {
      final texto = await utf8.decodeStream(peticion);
      final cuerpo = texto.isEmpty ? null : jsonDecode(texto);
      peticiones.add((peticion.method, peticion.uri.path, cuerpo));
      final r = peticion.response..headers.contentType = ContentType.json;
      void escribir((int, Object) e) {
        r
          ..statusCode = e.$1
          ..write(jsonEncode(e.$2));
      }

      final ruta = peticion.uri.path;
      if (ruta == '/auth/v1/signup') {
        if (signupConSesion) {
          r.write(sesionJson('uid-nuevo'));
        } else {
          r.write(
            jsonEncode({
              'id': 'uid-nuevo',
              'aud': 'authenticated',
              'role': '',
              'email': 'luisa@ejemplo.test',
              'created_at': '2026-11-06T00:00:00Z',
              'app_metadata': <String, Object?>{},
              'user_metadata': <String, Object?>{},
            }),
          );
        }
      } else if (ruta == '/auth/v1/token') {
        final e = errorDeContrasena;
        if (e != null) {
          escribir(e);
        } else {
          r.write(sesionJson('uid-nuevo'));
        }
      } else if (ruta == '/rest/v1/rpc/aceptar_invitacion') {
        final e = errorAlAceptar;
        if (e != null) {
          escribir(e);
        } else {
          r.write(jsonEncode('hogar-1'));
        }
      } else if (ruta == '/auth/v1/logout') {
        r.statusCode = 204;
      } else {
        r.statusCode = 404;
      }
      await r.close();
    });
  }

  Future<void> cerrar() => _http.close(force: true);

  List<String> get rutas => [for (final p in peticiones) '${p.$1} ${p.$2}'];
}

void main() {
  late _Servidor servidor;
  late SupabaseClient cliente;
  late ServicioSesionSupabase servicio;
  late AlmacenSeguroEnMemoria almacen;
  var tieneRol = true;

  const luisa = Sesion(
    persona: Persona(id: 'persona-luisa', nombre: 'Luisa'),
    rol: Rol.familiar,
    hogarId: 'hogar-1',
  );

  setUp(() async {
    tieneRol = true;
    servidor = _Servidor();
    await servidor.abrir();
    cliente = SupabaseClient(
      servidor.url,
      'llave-publica-de-prueba',
      // Sin almacenamiento persistente en la prueba: el flujo implícito no
      // lo necesita (en la app, Supabase.initialize lo configura).
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    almacen = AlmacenSeguroEnMemoria();
    servicio = ServicioSesionSupabase(
      cliente: cliente,
      almacen: almacen,
      url: servidor.url,
      llavePublica: 'llave-publica-de-prueba',
      lectorPerfil: (_) async {
        if (!tieneRol) throw ErrorSesion.sinRol;
        return luisa;
      },
    );
  });

  tearDown(() async {
    await servicio.cerrar();
    await cliente.dispose();
    await servidor.cerrar();
  });

  test('cuenta nueva: se registra, acepta el código y queda dentro', () async {
    final r = await servicio.aceptarInvitacion(
      token: '  codigo-1  ',
      correo: ' luisa@ejemplo.test ',
      contrasena: 'contrasena-larga',
      nombre: 'Luisa',
      cuentaNueva: true,
    );
    expect(r.faltaConfirmarCorreo, isFalse);
    expect(r.sesion, luisa);
    expect(servicio.sesionActual, luisa);
    expect(servidor.rutas, [
      'POST /auth/v1/signup',
      'POST /rest/v1/rpc/aceptar_invitacion',
    ]);
    final registro = servidor.peticiones.first.$3! as Map;
    expect(registro['email'], 'luisa@ejemplo.test');
    expect(registro['data'], {'nombre': 'Luisa'});
    expect(servidor.peticiones.last.$3, {'p_token': 'codigo-1'});
    // La sesión queda guardada para abrir sin señal.
    expect(
      await almacen.leer(ServicioSesionSupabase.claveSesionGuardada),
      isNotNull,
    );
  });

  test('si el servidor pide confirmar el correo, no acepta todavía', () async {
    servidor.signupConSesion = false;
    final r = await servicio.aceptarInvitacion(
      token: 'codigo-1',
      correo: 'luisa@ejemplo.test',
      contrasena: 'contrasena-larga',
      nombre: 'Luisa',
      cuentaNueva: true,
    );
    expect(r.faltaConfirmarCorreo, isTrue);
    expect(r.sesion, isNull);
    expect(servicio.sesionActual, isNull);
    expect(servidor.rutas, ['POST /auth/v1/signup']);
  });

  test('ya tengo cuenta: entra con la contraseña y acepta', () async {
    final r = await servicio.aceptarInvitacion(
      token: 'codigo-1',
      correo: 'luisa@ejemplo.test',
      contrasena: 'contrasena-larga',
      cuentaNueva: false,
    );
    expect(r.sesion, luisa);
    expect(servidor.rutas, [
      'POST /auth/v1/token',
      'POST /rest/v1/rpc/aceptar_invitacion',
    ]);
  });

  test('código vencido o inválido (22023): mensaje y sesión cerrada', () async {
    servidor.errorAlAceptar = (
      400,
      {'code': '22023', 'message': 'La invitación no es válida o ya expiró.'},
    );
    await expectLater(
      servicio.aceptarInvitacion(
        token: 'viejo',
        correo: 'luisa@ejemplo.test',
        contrasena: 'contrasena-larga',
        cuentaNueva: false,
      ),
      throwsA(
        isA<ErrorSesion>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('no es válido o ya venció'),
        ),
      ),
    );
    expect(servicio.sesionActual, isNull);
    // No se deja una sesión a medias en el equipo.
    expect(servidor.rutas, contains('POST /auth/v1/logout'));
    expect(
      await almacen.leer(ServicioSesionSupabase.claveSesionGuardada),
      isNull,
    );
  });

  test('correo distinto o sin confirmar (42501)', () async {
    servidor.errorAlAceptar = (
      403,
      {'code': '42501', 'message': 'La invitación es para otro correo.'},
    );
    await expectLater(
      servicio.aceptarInvitacion(
        token: 'c',
        correo: 'otra@ejemplo.test',
        contrasena: 'contrasena-larga',
        cuentaNueva: false,
      ),
      throwsA(
        isA<ErrorSesion>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('otro correo'),
        ),
      ),
    );
  });

  test('ya pertenece al hogar (23505)', () async {
    servidor.errorAlAceptar = (
      409,
      {'code': '23505', 'message': 'Ya perteneces a este hogar.'},
    );
    await expectLater(
      servicio.aceptarInvitacion(
        token: 'c',
        correo: 'luisa@ejemplo.test',
        contrasena: 'contrasena-larga',
        cuentaNueva: false,
      ),
      throwsA(
        isA<ErrorSesion>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('Ya perteneces'),
        ),
      ),
    );
  });

  test('entrar sin haber confirmado el correo se explica', () async {
    servidor.errorDeContrasena = (
      400,
      {
        'code': 400,
        'error_code': 'email_not_confirmed',
        'msg': 'Email not confirmed',
      },
    );
    await expectLater(
      servicio.aceptarInvitacion(
        token: 'c',
        correo: 'luisa@ejemplo.test',
        contrasena: 'contrasena-larga',
        cuentaNueva: false,
      ),
      throwsA(
        isA<ErrorSesion>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('Aún no confirmas tu correo'),
        ),
      ),
    );
    // Nunca llegó a aceptar.
    expect(servidor.rutas, ['POST /auth/v1/token']);
  });

  test('contraseña mala: el mensaje de siempre', () async {
    servidor.errorDeContrasena = (
      400,
      {
        'code': 400,
        'error_code': 'invalid_credentials',
        'msg': 'Invalid login credentials',
      },
    );
    await expectLater(
      servicio.aceptarInvitacion(
        token: 'c',
        correo: 'luisa@ejemplo.test',
        contrasena: 'mala',
        cuentaNueva: false,
      ),
      throwsA(ErrorSesion.credencialesIncorrectas),
    );
  });

  test('sin señal: sin conexión', () async {
    await servidor.cerrar();
    await expectLater(
      servicio.aceptarInvitacion(
        token: 'c',
        correo: 'luisa@ejemplo.test',
        contrasena: 'contrasena-larga',
        cuentaNueva: true,
      ),
      throwsA(ErrorSesion.sinConexion),
    );
    // El cierre del tearDown ya no tiene nada que cerrar.
    servidor = _Servidor()..peticiones.clear();
    await servidor.abrir();
  });
}

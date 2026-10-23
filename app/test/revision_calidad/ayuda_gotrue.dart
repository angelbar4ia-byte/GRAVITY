/// Servidor de autenticación simulado (GoTrue) y ayudas para armar sesiones de
/// Supabase en las pruebas de calidad (revisión de la Fase 1b). Nada sale a
/// internet: es un `HttpServer` local en el puerto que el sistema asigne.
///
/// Es una copia ampliada del de `test/nucleo/sesion/sesion_por_persona_supabase_test.dart`:
/// además de revocar tokens permite responder con un estado HTTP fijo a la
/// renovación (p. ej. 429, límite de peticiones) y anota qué tokens se
/// renovaron y cuántas veces se pidió cerrar la sesión.
library;

import 'dart:convert';
import 'dart:io';

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

/// Una sesión de Supabase como la guarda la app (`Session.toJson`).
Map<String, Object?> sesionJson(String uid, String renovar, {bool vencida = false}) => {
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

class GoTrueSimulado {
  late HttpServer _servidor;
  final revocados = <String>{};
  final rutas = <String>[];

  /// Refresh tokens que el servidor vio llegar, en orden.
  final renovados = <String>[];

  /// Si no es nulo, toda renovación responde con este estado (p. ej. 429).
  int? estadoFijoAlRenovar;
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
        renovados.add(token);
        if (estadoFijoAlRenovar != null) {
          respuesta
            ..statusCode = estadoFijoAlRenovar!
            ..write(
              jsonEncode({
                'code': estadoFijoAlRenovar,
                'error_code': 'over_request_rate_limit',
                'msg': 'Request rate limit reached',
              }),
            );
        } else if (revocados.contains(token)) {
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

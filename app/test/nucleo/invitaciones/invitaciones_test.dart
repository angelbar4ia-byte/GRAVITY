// Invitaciones del hogar (cuenta maestra, D19 del 23/oct/2026): el repositorio
// habla con el servidor con la firma acordada con backend, y el de memoria
// aplica las reglas que la pantalla debe respetar.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/invitaciones/invitaciones.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cola/postgrest_simulado.dart' show sesionJson;

/// Servidor mínimo: anota cada petición y responde lo que se le programe.
class _Servidor {
  _Servidor._(this._http) {
    _http.listen((peticion) async {
      final texto = await utf8.decodeStream(peticion);
      recibidas.add((
        peticion.method,
        peticion.uri,
        texto.isEmpty ? null : jsonDecode(texto),
      ));
      final respuesta = respuestas.isEmpty ? (200, <Object>[]) : respuestas.removeAt(0);
      peticion.response.statusCode = respuesta.$1;
      peticion.response.headers.contentType = ContentType.json;
      peticion.response.write(jsonEncode(respuesta.$2));
      await peticion.response.close();
    });
  }

  static Future<_Servidor> iniciar() async =>
      _Servidor._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _http;
  final List<(String, Uri, Object?)> recibidas = [];
  final List<(int, Object)> respuestas = [];

  String get url => 'http://127.0.0.1:${_http.port}';

  Future<SupabaseClient> cliente() async {
    final cliente = SupabaseClient(
      url,
      'llave-publica-de-prueba',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await cliente.auth.recoverSession(sesionJson('uid-dueno'));
    return cliente;
  }

  Future<void> cerrar() => _http.close(force: true);
}

void main() {
  late _Servidor servidor;
  late SupabaseClient cliente;
  late RepositorioInvitacionesSupabase repositorio;
  final ahora = DateTime.utc(2026, 10, 24, 12);

  setUp(() async {
    servidor = await _Servidor.iniciar();
    cliente = await servidor.cliente();
    repositorio = RepositorioInvitacionesSupabase(() => cliente, reloj: () => ahora);
  });

  tearDown(() async {
    await cliente.dispose();
    await servidor.cerrar();
  });

  group('con servidor (Supabase)', () {
    test('crear: llama crear_invitacion con la firma acordada y lee el token',
        () async {
      servidor.respuestas.add((
        200,
        [
          {
            'invitacion_id': 'inv-1',
            'token': 'abc123',
            'expira': '2026-10-31T12:00:00+00:00',
          },
        ],
      ));
      final creada = await repositorio.crearCuentaMaestra(
        hogarId: 'hogar-1',
        correo: '  Maestra@Ejemplo.test ',
      );
      expect(creada.id, 'inv-1');
      expect(creada.token, 'abc123');
      expect(creada.expira, DateTime.utc(2026, 10, 31, 12));

      final (metodo, uri, cuerpo) = servidor.recibidas.single;
      expect(metodo, 'POST');
      expect(uri.path, '/rest/v1/rpc/crear_invitacion');
      expect(cuerpo, {
        'p_hogar_id': 'hogar-1',
        'p_correo': 'Maestra@Ejemplo.test',
        'p_rol': 'coadministrador',
        'p_vigencia_dias': 7,
        'p_es_maestra': true,
      });
    });

    test('42501: solo el dueño invita', () async {
      servidor.respuestas.add((403, {'code': '42501', 'message': 'no'}));
      await expectLater(
        repositorio.crearCuentaMaestra(hogarId: 'h', correo: 'a@b.co'),
        throwsA(
          isA<ErrorInvitacion>().having(
            (e) => e.mensaje,
            'mensaje',
            ErrorInvitacion.sinPermiso.mensaje,
          ),
        ),
      );
    });

    test('22023: el mensaje del servidor llega tal cual', () async {
      servidor.respuestas.add((
        400,
        {'code': '22023', 'message': 'La maestra es otra persona.'},
      ));
      await expectLater(
        repositorio.crearCuentaMaestra(hogarId: 'h', correo: 'a@b.co'),
        throwsA(
          isA<ErrorInvitacion>().having(
            (e) => e.mensaje,
            'mensaje',
            'La maestra es otra persona.',
          ),
        ),
      );
    });

    test('sin red: "sin conexión"', () async {
      await servidor.cerrar();
      await expectLater(
        repositorio.crearCuentaMaestra(hogarId: 'h', correo: 'a@b.co'),
        throwsA(ErrorInvitacion.sinConexion),
      );
    });

    test('pendientes: sin aceptar ni revocar y sin vencer', () async {
      servidor.respuestas.add((
        200,
        [
          {
            'id': 'i1',
            'correo': 'maestra@ejemplo.test',
            'rol': 'coadministrador',
            'es_maestra': true,
            'expira_en': '2026-10-30T00:00:00+00:00',
          },
          {
            'id': 'i2',
            'correo': 'vencida@ejemplo.test',
            'rol': 'coadministrador',
            'es_maestra': true,
            'expira_en': '2026-10-20T00:00:00+00:00',
          },
          {
            'id': 'i3',
            'correo': 'familiar@ejemplo.test',
            'rol': 'familiar',
            'es_maestra': false,
            'expira_en': '2026-10-30T00:00:00+00:00',
          },
        ],
      ));
      final lista = await repositorio.pendientes('hogar-1');
      expect([for (final i in lista) i.id], ['i1', 'i3']);
      expect(lista.first.esMaestra, isTrue);
      expect(lista.last.esMaestra, isFalse);

      final (_, uri, _) = servidor.recibidas.single;
      expect(uri.path, '/rest/v1/invitaciones');
      expect(uri.queryParameters['aceptada_en'], 'is.null');
      expect(uri.queryParameters['revocada_en'], 'is.null');
      expect(uri.queryParameters['hogar_id'], 'eq.hogar-1');
      expect(
        uri.queryParameters['select'],
        isNot(contains('token_hash')),
        reason: 'el hash del token no se pide',
      );
    });

    test('pendientes: un servidor sin la columna de la maestra todavía sigue '
        'funcionando', () async {
      servidor.respuestas
        ..add((400, {'code': '42703', 'message': 'no existe es_maestra'}))
        ..add((
          200,
          [
            {
              'id': 'i1',
              'correo': 'a@b.co',
              'rol': 'coadministrador',
              'expira_en': '2026-10-30T00:00:00+00:00',
            },
          ],
        ));
      final lista = await repositorio.pendientes('h');
      expect(lista.single.esMaestra, isFalse);
      expect(servidor.recibidas, hasLength(2));
      expect(servidor.recibidas.last.$2.queryParameters['select'], isNot(contains('es_maestra')));
    });

    test('revocar llama revocar_invitacion', () async {
      servidor.respuestas.add((200, <Object>[]));
      await repositorio.revocar('inv-9');
      final (_, uri, cuerpo) = servidor.recibidas.single;
      expect(uri.path, '/rest/v1/rpc/revocar_invitacion');
      expect(cuerpo, {'p_invitacion_id': 'inv-9'});
    });

    test('maestraActual: quién es hoy, o nadie', () async {
      servidor.respuestas
        ..add((
          200,
          [
            {'persona_id': 'p-maestra', 'nombre_visible': 'Marta (ejemplo)'},
          ],
        ))
        ..add((200, <Object>[]));
      final maestra = await repositorio.maestraActual('hogar-1');
      expect(maestra?.personaId, 'p-maestra');
      expect(maestra?.nombre, 'Marta (ejemplo)');
      expect(await repositorio.maestraActual('hogar-1'), isNull);
      expect(servidor.recibidas.first.$2.path, '/rest/v1/rpc/cuenta_maestra');
      expect(servidor.recibidas.first.$3, {'p_hogar_id': 'hogar-1'});
    });
  });

  group('en memoria (demostración y pruebas)', () {
    test('una sola invitación pendiente por correo; la anterior se revoca',
        () async {
      final repo = RepositorioInvitacionesEnMemoria(reloj: () => ahora);
      final a = await repo.crearCuentaMaestra(hogarId: 'h', correo: 'M@x.co');
      final b = await repo.crearCuentaMaestra(hogarId: 'h', correo: ' m@x.co ');
      expect(a.id, isNot(b.id));
      expect([for (final i in await repo.pendientes('h')) i.id], [b.id]);
    });

    test('la maestra es otra persona: no se invita a un miembro del hogar',
        () async {
      final repo = RepositorioInvitacionesEnMemoria(
        reloj: () => ahora,
        correosDeMiembros: {'dueno@ejemplo.test'},
      );
      await expectLater(
        repo.crearCuentaMaestra(hogarId: 'h', correo: 'Dueno@Ejemplo.test'),
        throwsA(isA<ErrorInvitacion>()),
      );
    });

    test('vencen a los 7 días', () async {
      var reloj = ahora;
      final repo = RepositorioInvitacionesEnMemoria(reloj: () => reloj);
      await repo.crearCuentaMaestra(hogarId: 'h', correo: 'a@b.co');
      expect(await repo.pendientes('h'), hasLength(1));
      reloj = ahora.add(const Duration(days: 8));
      expect(await repo.pendientes('h'), isEmpty);
    });
  });
}

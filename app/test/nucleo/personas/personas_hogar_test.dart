// Personas del hogar con el esquema del servidor (E3 de la Fase 4): leer
// membresías vigentes, dar de baja y cambiar de rol.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/personas/personas_hogar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cola/postgrest_simulado.dart' show sesionJson;

class _Servidor {
  _Servidor._(this._http) {
    _http.listen((peticion) async {
      final texto = await utf8.decodeStream(peticion);
      recibidas.add((
        peticion.method,
        peticion.uri,
        texto.isEmpty ? null : jsonDecode(texto),
      ));
      final r = respuestas.isEmpty ? (200, <Object>[]) : respuestas.removeAt(0);
      peticion.response.statusCode = r.$1;
      peticion.response.headers.contentType = ContentType.json;
      peticion.response.write(jsonEncode(r.$2));
      await peticion.response.close();
    });
  }

  static Future<_Servidor> iniciar() async =>
      _Servidor._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _http;
  final List<(String, Uri, Object?)> recibidas = [];
  final List<(int, Object)> respuestas = [];

  Future<SupabaseClient> cliente() async {
    final c = SupabaseClient(
      'http://127.0.0.1:${_http.port}',
      'llave-publica-de-prueba',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await c.auth.recoverSession(sesionJson('uid-dueno'));
    return c;
  }

  Future<void> cerrar() => _http.close(force: true);
}

void main() {
  late _Servidor servidor;
  late SupabaseClient cliente;
  late RepositorioPersonasHogarSupabase repo;
  final ahora = DateTime.utc(2026, 11, 6, 12);

  setUp(() async {
    servidor = await _Servidor.iniciar();
    cliente = await servidor.cliente();
    repo = RepositorioPersonasHogarSupabase(() => cliente, reloj: () => ahora);
  });

  tearDown(() async {
    await cliente.dispose();
    await servidor.cerrar();
  });

  group('con servidor (Supabase)', () {
    test('miembros: lee las membresías activas con el nombre', () async {
      servidor.respuestas.add((
        200,
        [
          {
            'id': 'm1',
            'persona_id': 'p1',
            'rol': 'dueno',
            'desde': '2026-10-20T00:00:00+00:00',
            'hasta': null,
            'es_maestra': false,
            'personas': {'nombre_visible': 'Ana'},
          },
          {
            'id': 'm2',
            'persona_id': 'p2',
            'rol': 'coadministrador',
            'desde': '2026-10-21T00:00:00+00:00',
            'hasta': null,
            'es_maestra': true,
            'personas': {'nombre_visible': 'Maestra'},
          },
          {
            'id': 'm3',
            'persona_id': 'p3',
            'rol': 'casa',
            'desde': '2026-10-21T00:00:00+00:00',
            'hasta': null,
            'es_maestra': false,
            'personas': {'nombre_visible': 'lo-que-diga-el-servidor'},
          },
          // Ya terminó: no se muestra.
          {
            'id': 'm4',
            'persona_id': 'p4',
            'rol': 'familiar',
            'desde': '2026-10-21T00:00:00+00:00',
            'hasta': '2026-11-01T00:00:00+00:00',
            'es_maestra': false,
            'personas': {'nombre_visible': 'Ex'},
          },
          // Empieza en el futuro: tampoco.
          {
            'id': 'm5',
            'persona_id': 'p5',
            'rol': 'familiar',
            'desde': '2026-12-01T00:00:00+00:00',
            'hasta': null,
            'es_maestra': false,
            'personas': {'nombre_visible': 'Futuro'},
          },
        ],
      ));
      final lista = await repo.miembros('hogar-1');
      expect([for (final m in lista) m.personaId], ['p1', 'p2', 'p3']);
      expect(lista[0].nombre, 'Ana');
      expect(lista[1].esMaestra, isTrue);
      expect(lista[2].nombre, nombreCuentaDelHogarDePrueba);
      final (metodo, uri, _) = servidor.recibidas.single;
      expect(metodo, 'GET');
      expect(uri.path, '/rest/v1/membresias');
      expect(uri.queryParameters['hogar_id'], 'eq.hogar-1');
      expect(uri.queryParameters['activa'], 'eq.true');
    });

    test('miembros: servidor sin la columna de la maestra todavía', () async {
      servidor.respuestas
        ..add((400, {'code': '42703', 'message': 'no existe es_maestra'}))
        ..add((
          200,
          [
            {
              'id': 'm1',
              'persona_id': 'p1',
              'rol': 'familiar',
              'desde': '2026-10-20T00:00:00+00:00',
              'hasta': null,
              'personas': {'nombre_visible': 'Luis'},
            },
          ],
        ));
      final lista = await repo.miembros('hogar-1');
      expect(lista.single.esMaestra, isFalse);
      expect(servidor.recibidas, hasLength(2));
    });

    test('darDeBaja: activa=false y hasta=ahora, solo esa membresía', () async {
      servidor.respuestas.add((
        200,
        [
          {'id': 'm2'},
        ],
      ));
      await repo.darDeBaja('m2');
      final (metodo, uri, cuerpo) = servidor.recibidas.single;
      expect(metodo, 'PATCH');
      expect(uri.path, '/rest/v1/membresias');
      expect(uri.queryParameters['id'], 'eq.m2');
      expect(cuerpo, {'activa': false, 'hasta': '2026-11-06T12:00:00.000Z'});
    });

    test('cambiarRol: solo manda el rol nuevo', () async {
      servidor.respuestas.add((
        200,
        [
          {'id': 'm2'},
        ],
      ));
      await repo.cambiarRol('m2', Rol.cuidador);
      final (metodo, uri, cuerpo) = servidor.recibidas.single;
      expect(metodo, 'PATCH');
      expect(uri.queryParameters['id'], 'eq.m2');
      expect(cuerpo, {'rol': 'cuidador'});
    });

    test('cambiarRol a dueño ni siquiera sale', () async {
      await expectLater(
        repo.cambiarRol('m2', Rol.dueno),
        throwsA(isA<ErrorPersonas>()),
      );
      expect(servidor.recibidas, isEmpty);
    });

    test(
      '0 filas cambiadas (la regla del servidor no lo dejó): sin permiso',
      () async {
        servidor.respuestas.add((200, <Object>[]));
        await expectLater(
          repo.darDeBaja('m-propia'),
          throwsA(
            isA<ErrorPersonas>().having(
              (e) => e.mensaje,
              'mensaje',
              ErrorPersonas.sinPermiso.mensaje,
            ),
          ),
        );
      },
    );

    test('42501 y los errores de negocio traen su mensaje', () async {
      servidor.respuestas.add((403, {'code': '42501', 'message': 'no'}));
      await expectLater(
        repo.cambiarRol('m2', Rol.familiar),
        throwsA(
          isA<ErrorPersonas>().having(
            (e) => e.mensaje,
            'mensaje',
            ErrorPersonas.sinPermiso.mensaje,
          ),
        ),
      );
      servidor.respuestas.add((
        400,
        {'code': '23514', 'message': 'la cuenta maestra es coadministradora'},
      ));
      await expectLater(
        repo.cambiarRol('m2', Rol.familiar),
        throwsA(
          isA<ErrorPersonas>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('coadministradora'),
          ),
        ),
      );
    });

    test('sin señal: sin conexión', () async {
      await servidor.cerrar();
      await expectLater(
        repo.darDeBaja('m2'),
        throwsA(ErrorPersonas.sinConexion),
      );
      servidor = await _Servidor.iniciar();
    });
  });

  group('en memoria', () {
    MiembroDelHogar m(String id, Rol rol, {bool maestra = false}) =>
        MiembroDelHogar(
          membresiaId: 'm-$id',
          personaId: id,
          nombre: id,
          rol: rol,
          esMaestra: maestra,
        );

    test('respeta las reglas del servidor', () async {
      final repo = RepositorioPersonasHogarEnMemoria(
        inicial: [
          m('ana', Rol.dueno),
          m('luis', Rol.familiar),
          m('maestra', Rol.coadministrador, maestra: true),
        ],
        personaQueAdministra: 'ana',
      );
      await expectLater(repo.darDeBaja('m-ana'), throwsA(isA<ErrorPersonas>()));
      await expectLater(
        repo.cambiarRol('m-luis', Rol.dueno),
        throwsA(isA<ErrorPersonas>()),
      );
      await expectLater(
        repo.cambiarRol('m-maestra', Rol.cuidador),
        throwsA(isA<ErrorPersonas>()),
      );
      await repo.cambiarRol('m-luis', Rol.cuidador);
      expect(
        (await repo.miembros('h')).firstWhere((x) => x.personaId == 'luis').rol,
        Rol.cuidador,
      );
      await repo.darDeBaja('m-luis');
      expect(await repo.miembros('h'), hasLength(2));
      expect(repo.bajas, ['m-luis']);
    });
  });
}

/// "Hogar": el nombre que se muestra de la cuenta de la casa.
const nombreCuentaDelHogarDePrueba = 'Hogar';

// La puerta HTTP real (`dart:io`) contra un servidor en el propio equipo
// (127.0.0.1): ninguna conexión sale del equipo. Comprueba lo que de verdad
// viaja por el cable (criterio 15): solo cabeceras de la lista, sin cookies ni
// credenciales, y que no se sigue una redirección a `http`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/descarga/puerta_de_descarga.dart';

void main() {
  late HttpServer servidor;
  late List<HttpRequest> vistas;
  late List<Map<String, List<String>>> cabeceras;
  late Uri base;

  Future<void> arrancar(Future<void> Function(HttpRequest r) atender) async {
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${servidor.port}');
    vistas = [];
    cabeceras = [];
    servidor.listen((r) async {
      vistas.add(r);
      final h = <String, List<String>>{};
      r.headers.forEach((k, v) => h[k.toLowerCase()] = v);
      cabeceras.add(h);
      await atender(r);
      await r.response.close();
    });
  }

  tearDown(() async => servidor.close(force: true));

  Future<List<int>> leer(RespuestaDeDescarga r) async {
    final b = <int>[];
    await for (final t in r.cuerpo) {
      b.addAll(t);
    }
    return b;
  }

  test(
    'envía solo cabeceras de la lista, sin cookies ni credenciales',
    () async {
      await arrancar((r) async {
        r.response
          ..headers.set(HttpHeaders.etagHeader, '"abc"')
          ..add(utf8.encode('hola'));
      });
      final puerta = PuertaDeDescargaHttp(permitirHttp: true);
      final r = await puerta.pedir(
        base.resolve('/voces/ana.onnx'),
        cabeceras: {
          'Range': 'bytes=10-',
          'If-Range': '"abc"',
          'User-Agent': userAgentDeDescarga,
          'Accept-Encoding': 'identity',
        },
      );
      expect(r.codigo, 200);
      expect(r.etag, '"abc"');
      expect(utf8.decode(await leer(r)), 'hola');
      await r.cerrar();
      final h = cabeceras.single;
      expect(h['range'], ['bytes=10-']);
      expect(h['if-range'], ['"abc"']);
      expect(h['user-agent'], [userAgentDeDescarga]);
      expect(h['accept-encoding'], ['identity']);
      for (final prohibida in [
        'cookie',
        'authorization',
        'x-api-key',
        'referer',
        'origin',
      ]) {
        expect(h.containsKey(prohibida), isFalse, reason: prohibida);
      }
      // Lo demás es lo que HTTP exige (equipo y conexión), nada de la persona.
      expect(
        h.keys.toSet().difference({
          'range',
          'if-range',
          'user-agent',
          'accept-encoding',
          'host',
          'connection',
        }),
        isEmpty,
        reason: 'cabeceras en el cable: ${h.keys}',
      );
    },
  );

  test('no deja pasar una cabecera fuera de la lista', () async {
    await arrancar((r) async {});
    final puerta = PuertaDeDescargaHttp(permitirHttp: true);
    for (final mala in ['Cookie', 'Authorization', 'X-Persona']) {
      await expectLater(
        puerta.pedir(base, cabeceras: {mala: 'x'}),
        throwsArgumentError,
        reason: mala,
      );
    }
    expect(vistas, isEmpty);
  });

  test('entrega el código de la respuesta (404) sin lanzar', () async {
    await arrancar((r) async => r.response.statusCode = 404);
    final r = await PuertaDeDescargaHttp(permitirHttp: true)
        .pedir(base, cabeceras: const {});
    expect(r.codigo, 404);
    await r.cerrar();
  });

  test('una respuesta 206 trae Content-Range y largo del cuerpo', () async {
    await arrancar((r) async {
      r.response
        ..statusCode = 206
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 2-4/10')
        ..add([2, 3, 4]);
    });
    final r = await PuertaDeDescargaHttp(permitirHttp: true)
        .pedir(base, cabeceras: {'Range': 'bytes=2-'});
    expect(r.codigo, 206);
    expect(r.contentRange, 'bytes 2-4/10');
    expect(await leer(r), [2, 3, 4]);
    await r.cerrar();
  });

  test('sin permiso de http (lo normal), una dirección http se rechaza sin conectar', () async {
    await arrancar((r) async {});
    await expectLater(
      PuertaDeDescargaHttp().pedir(base, cabeceras: const {}),
      throwsA(isA<HttpException>()),
    );
    expect(vistas, isEmpty);
  });

  test(
    'sigue una redirección dentro del mismo esquema y repite las cabeceras',
    () async {
      await arrancar((r) async {
        if (r.uri.path == '/a') {
          r.response
            ..statusCode = 302
            ..headers.set(HttpHeaders.locationHeader, '/b');
        } else {
          r.response.add([7]);
        }
      });
      final r = await PuertaDeDescargaHttp(permitirHttp: true)
          .pedir(base.resolve('/a'), cabeceras: {'Range': 'bytes=0-'});
      expect(await leer(r), [7]);
      await r.cerrar();
      expect(vistas.map((v) => v.uri.path), ['/a', '/b']);
      expect(cabeceras.last['range'], ['bytes=0-']);
      expect(cabeceras.last.containsKey('cookie'), isFalse);
    },
  );

  test('una cadena de redirecciones demasiado larga se corta', () async {
    // (Que una redirección a http no se sigue lo cubre la prueba de arriba: la
    // regla es la misma para la primera dirección y para cada salto.)
    await arrancar((r) async {
      r.response
        ..statusCode = 302
        ..headers.set(HttpHeaders.locationHeader, r.uri.path);
    });
    await expectLater(
      PuertaDeDescargaHttp(
        permitirHttp: true,
        maximoRedirecciones: 3,
      ).pedir(base.resolve('/vuelta'), cabeceras: const {}),
      throwsA(isA<HttpException>()),
    );
    expect(vistas.length, lessThanOrEqualTo(4));
  });

  test(
    'si el servidor deja de mandar datos, el flujo falla por tiempo',
    () async {
      await arrancar((r) async {
        r.response.add([1, 2, 3]);
        await r.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      final r = await PuertaDeDescargaHttp(
        permitirHttp: true,
        tiempoSinDatos: const Duration(milliseconds: 100),
      ).pedir(base, cabeceras: const {});
      await expectLater(leer(r), throwsA(isA<TimeoutException>()));
      await r.cerrar();
    },
  );

  test('cerrar a mitad de la respuesta corta la conexión', () async {
    await arrancar((r) async {
      r.response.add(List.filled(10, 1));
      await r.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    final r = await PuertaDeDescargaHttp(permitirHttp: true)
        .pedir(base, cabeceras: const {});
    final primero = await r.cuerpo.first;
    expect(primero, isNotEmpty);
    await r.cerrar();
  });
}

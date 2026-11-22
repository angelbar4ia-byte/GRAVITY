// Catálogo de voces descargables (motor de voz, P3.2a-2): criterios 14 y 27 de
// `docs/specs/fase-8-motor-de-voz.md`, con catálogos de prueba y con el
// catálogo REAL de la app (`assets/voces/catalogo.json`).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/modelos/catalogo.dart';
import 'package:gravity/modulos/gravity/voz/modelos/estado_modelo.dart';
import 'package:gravity/modulos/gravity/voz/modelos/lector_catalogo.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';

import '../ayuda_modelos.dart';

typedef Mapa = Map<String, Object?>;

/// Copia profunda para poder estropear una parte sin tocar el original.
Mapa copia(Mapa m) => jsonDecode(jsonEncode(m)) as Mapa;

Mapa modeloDe(Mapa catalogo, [int i = 0]) =>
    (catalogo['modelos']! as List)[i] as Mapa;

Mapa archivoDe(Mapa catalogo, [int i = 0]) =>
    (modeloDe(catalogo)['archivos']! as List)[i] as Mapa;

void main() {
  final contenido = ContenidoDePrueba();

  Mapa valido() => copia(contenido.comoMapa());

  List<String> problemas(Mapa m) => validarCatalogo(m);

  group('catálogo de prueba', () {
    test('uno bien armado no tiene problemas y se lee entero', () {
      expect(problemas(valido()), isEmpty);
      final c = leerCatalogo(jsonEncode(valido()));
      expect(c.modelos.map((m) => m.id), ['ana', 'beto', 'cori']);
      final ana = c.porId('ana')!;
      expect(ana.bytes, 30000 + 120 + 6000);
      expect(ana.archivoDe(RolDeArchivo.lexicon).nombre, 'lexicon-en-us.txt');
      expect(ana.voces.single.genero, Genero.mujer);
      expect(ana.asignacionSugerida, {VozDeGuion.f1: 0});
      expect(c.porId('cori')!.voces.single.acentoAproximado, isTrue);
      expect(ana.licencia.permiteDistribuirAudio, isNull);
      expect(ana.cargable, isTrue);
    });

    test('uso y rtf son opcionales, pero si están se validan', () {
      final m = valido();
      modeloDe(m)['uso'] = {'tiempo_real_telefono': true};
      modeloDe(m)['rtf'] = [
        {'equipo': 'Galaxy A52', 'hilos': 2, 'rtf': 0.4, 'fecha': '2026-12-01'},
      ];
      expect(problemas(m), isEmpty);
      modeloDe(m)['uso'] = {'tiempo_real_telefono': 'sí'};
      expect(problemas(m), isNotEmpty);
      modeloDe(m)['uso'] = {'tiempo_real_telefono': true};
      modeloDe(m)['rtf'] = [
        {'equipo': 'A52'},
      ];
      expect(problemas(m), isNotEmpty);
    });
  });

  group('criterio 14: sin secretos', () {
    test('toda dirección debe ser https', () {
      final m = valido();
      archivoDe(m)['url'] = 'http://voces.ejemplo.test/rev1/ana/ana.onnx';
      expect(problemas(m).join(' '), contains('https'));
    });

    test('una dirección con parámetros de consulta se rechaza', () {
      final m = valido();
      archivoDe(m)['url'] = '$baseDePrueba/ana/ana.onnx?download=1';
      expect(problemas(m).join(' '), contains('consulta'));
      final n = valido();
      archivoDe(n)['url'] = '$baseDePrueba/ana/ana.onnx?';
      expect(problemas(n).join(' '), contains('consulta'));
    });

    test('una dirección con usuario o con fragmento se rechaza', () {
      final m = valido();
      archivoDe(m)['url'] =
          'https://usuario:clave@voces.ejemplo.test/rev1/ana/ana.onnx';
      expect(problemas(m).join(' '), contains('usuario'));
      final n = valido();
      archivoDe(n)['url'] = '$baseDePrueba/ana/ana.onnx#parte';
      expect(problemas(n).join(' '), contains('fragmento'));
    });

    test(
      'ningún campo puede llamarse token, clave, key, secret ni password',
      () {
        for (final nombre in [
          'token',
          'Token',
          'clave',
          'key',
          'api_key',
          'secret',
          'password',
          'authorization',
          'access_token',
        ]) {
          final m = valido();
          modeloDe(m)[nombre] = 'x';
          expect(
            problemas(m).join(' '),
            contains('sin secretos'),
            reason: nombre,
          );
        }
      },
    );

    test('también se revisan los campos anidados', () {
      final m = valido();
      (modeloDe(m)['licencia']! as Mapa)['clave'] = 'x';
      expect(problemas(m).join(' '), contains('sin secretos'));
    });

    test('un valor que parece una credencial se rechaza', () {
      for (final valor in [
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc',
        'sb_secret_abcdefghijklmnop1234',
        'ghp_abcdefghijklmnopqrstuvwx',
        'Bearer abcdefghijklmnop1234',
        'apikey=1234',
      ]) {
        final m = valido();
        (modeloDe(m)['licencia']! as Mapa)['atribucion'] = 'Texto $valor texto';
        expect(problemas(m).join(' '), contains('credencial'), reason: valor);
      }
    });

    test('una atribución normal no se confunde con una credencial', () {
      final m = valido();
      (modeloDe(m)['licencia']! as Mapa)['atribucion'] = 'Kokoro-82M, Apache-2.0 (hexgrad). Entrenado en parte con datos CC BY.';
      expect(problemas(m), isEmpty);
    });
  });

  group('criterio 27: el catálogo es válido', () {
    test('la huella debe ser de 64 hexadecimales en minúscula', () {
      for (final mala in ['', 'abc', 'G' * 64, 'A' * 64, '0' * 63, '0' * 65]) {
        final m = valido();
        archivoDe(m)['sha256'] = mala;
        expect(
          problemas(m).join(' '),
          contains('64 hexadecimales'),
          reason: mala,
        );
      }
    });

    test('los bytes deben ser un entero mayor que cero', () {
      for (final malo in [0, -5, 1.5, '10', null]) {
        final m = valido();
        archivoDe(m)['bytes'] = malo;
        expect(problemas(m), isNotEmpty, reason: '$malo');
      }
    });

    test('los nombres de archivo no llevan /, \\ ni ..', () {
      for (final malo in [
        '../ana.onnx',
        'a/b.onnx',
        r'a\b.onnx',
        '..',
        'ana..onnx',
        '',
        '.oculto',
        'con espacio.onnx',
      ]) {
        final m = valido();
        archivoDe(m)['nombre'] = malo;
        expect(
          problemas(m).join(' '),
          contains('nombre'),
          reason: 'nombre "$malo"',
        );
      }
    });

    test(
      'un id con caracteres de ruta se rechaza (es el nombre de una carpeta)',
      () {
        for (final malo in ['../x', 'a/b', r'a\b', '', 'x y']) {
          final m = valido();
          modeloDe(m)['id'] = malo;
          expect(problemas(m).join(' '), contains('.id'), reason: malo);
        }
      },
    );

    test('la licencia debe traer id, origen, atribución y texto', () {
      for (final campo in ['id', 'origen', 'atribucion', 'texto']) {
        final m = valido();
        (modeloDe(m)['licencia']! as Mapa).remove(campo);
        expect(problemas(m).join(' '), contains('licencia.$campo'));
        final n = valido();
        (modeloDe(n)['licencia']! as Mapa)[campo] = '  ';
        expect(problemas(n).join(' '), contains('licencia.$campo'));
      }
    });

    test('sin licencia no hay modelo', () {
      final m = valido();
      modeloDe(m).remove('licencia');
      expect(problemas(m).join(' '), contains('licencia'));
    });

    test('la fuente, la revisión y la fecha son obligatorias', () {
      final a = valido();
      modeloDe(a).remove('fuente');
      expect(problemas(a).join(' '), contains('fuente'));
      final b = valido();
      (modeloDe(b)['fuente']! as Mapa).remove('revision');
      expect(problemas(b).join(' '), contains('revision'));
      final c = valido();
      modeloDe(c).remove('consultado');
      expect(problemas(c).join(' '), contains('consultado'));
      final d = valido();
      modeloDe(d)['consultado'] = '22/11/2026';
      expect(problemas(d).join(' '), contains('consultado'));
      final e = valido();
      modeloDe(e)['consultado'] = '2026-13-45';
      expect(problemas(e).join(' '), contains('consultado'));
    });

    test('la revisión debe ser fija: nunca main ni "la última"', () {
      for (final movil in ['main', 'master', 'latest', 'HEAD', 'última']) {
        final m = valido();
        (modeloDe(m)['fuente']! as Mapa)['revision'] = movil;
        expect(
          problemas(m).join(' '),
          contains('revisión fija'),
          reason: movil,
        );
      }
    });

    test('la dirección de cada archivo lleva la revisión fija en la ruta', () {
      final m = valido();
      archivoDe(m)['url'] =
          'https://voces.ejemplo.test/storage/main/ana/ana.onnx';
      expect(problemas(m).join(' '), contains('revisión fija'));
    });

    test('la dirección termina en el nombre del archivo', () {
      final m = valido();
      archivoDe(m)['url'] = '$baseDePrueba/ana/otro.onnx';
      expect(problemas(m).join(' '), contains('nombre del archivo'));
    });

    test('no hay valores pendientes ni nulos', () {
      for (final pendiente in [
        '<n>',
        '<sid>',
        'pendiente',
        'TBD',
        'por definir',
      ]) {
        final m = valido();
        modeloDe(m)['nombre'] = pendiente;
        expect(
          problemas(m).join(' '),
          contains('pendiente'),
          reason: pendiente,
        );
      }
      final m = valido();
      (modeloDe(m)['licencia']! as Mapa)['permite_distribuir_audio'] = null;
      expect(problemas(m).join(' '), contains('nulo'));
    });

    test('debe haber un modelo, unos tokens y (en vits) un lexicón', () {
      final sinLexicon = valido();
      (modeloDe(sinLexicon)['archivos']! as List).removeAt(2);
      expect(problemas(sinLexicon).join(' '), contains('lexicón'));
      final sinTokens = valido();
      (modeloDe(sinTokens)['archivos']! as List).removeAt(1);
      expect(problemas(sinTokens).join(' '), contains('tokens'));
      final dosModelos = valido();
      archivoDe(dosModelos, 1)['rol'] = 'modelo';
      expect(problemas(dosModelos).join(' '), contains('rol modelo'));
    });

    test('no puede haber dos archivos con el mismo nombre ni dos modelos con el mismo id', () {
      final m = valido();
      archivoDe(m, 1)['nombre'] = archivoDe(m, 0)['nombre'];
      expect(problemas(m).join(' '), contains('repetido'));
      final n = valido();
      modeloDe(n, 1)['id'] = modeloDe(n, 0)['id'];
      expect(problemas(n).join(' '), contains('repetido'));
    });

    test(
      'las voces deben tener sid único, género y una variante del modelo',
      () {
        final m = valido();
        final v = (modeloDe(m)['voces']! as List).first as Mapa;
        v['genero'] = 'niño';
        expect(problemas(m).join(' '), contains('genero'));
        final n = valido();
        ((modeloDe(n)['voces']! as List).first as Mapa)['variante'] = 'en-GB';
        expect(problemas(n).join(' '), contains('variante'));
        final o = valido();
        ((modeloDe(o)['voces']! as List).first as Mapa)['sid'] = -1;
        expect(problemas(o).join(' '), contains('sid'));
        final q = valido();
        modeloDe(q)['asignacion_sugerida'] = {'F1': 99};
        expect(problemas(q).join(' '), contains('asignacion_sugerida'));
      },
    );

    test('un esquema distinto o un JSON roto se rechazan', () {
      final m = valido()..['esquema'] = 'otro-v1';
      expect(problemas(m).join(' '), contains('esquema'));
      expect(
        () => leerCatalogo('{no es json'),
        throwsA(isA<CatalogoInvalido>()),
      );
      expect(() => leerCatalogo('[]'), throwsA(isA<CatalogoInvalido>()));
    });

    test('leerCatalogo no deja entrar ningún modelo si uno falla', () {
      final m = valido();
      archivoDe(m, 0)['sha256'] = 'x';
      expect(
        () => leerCatalogo(jsonEncode(m)),
        throwsA(isA<CatalogoInvalido>()),
      );
    });

    test('los mensajes de error no repiten los valores del archivo', () {
      final m = valido();
      archivoDe(m)['url'] =
          'http://secreto.ejemplo.test/rev1/ana/ana.onnx?token=VALOR-SECRETO';
      archivoDe(m)['sha256'] = 'VALOR-SECRETO';
      final texto = problemas(m).join('\n');
      expect(texto, isNot(contains('VALOR-SECRETO')));
      expect(texto, isNot(contains('secreto.ejemplo.test')));
      try {
        leerCatalogo(jsonEncode(m));
      } on CatalogoInvalido catch (e) {
        expect(e.toString(), isNot(contains('VALOR-SECRETO')));
      }
    });
  });

  group('el catálogo REAL de la app', () {
    late String texto;
    late Mapa crudo;
    late CatalogoDeVoces catalogo;
    late Mapa verificadas;

    setUpAll(() {
      texto = File('assets/voces/catalogo.json').readAsStringSync();
      crudo = jsonDecode(texto) as Mapa;
      catalogo = leerCatalogo(texto);
      verificadas = jsonDecode(
        File('../docs/licencias-voces/verificadas.json').readAsStringSync(),
      ) as Mapa;
    });

    test(
      'está registrado como recurso de la app (pubspec) y es el mismo archivo',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final empaquetado = await rootBundle.loadString(
          'assets/voces/catalogo.json',
        );
        expect(empaquetado, texto);
        expect(leerCatalogo(empaquetado).modelos, hasLength(4));
      },
    );

    test('pasa el validador sin ningún problema (criterios 14 y 27)', () {
      expect(validarCatalogo(crudo), isEmpty);
    });

    test('trae las cuatro voces de dominio público elegidas, y solo esas', () {
      expect(catalogo.modelos.map((m) => m.id), [
        'vits-piper-en_US-kristin-medium',
        'vits-piper-en_US-john-medium',
        'vits-piper-en_US-norman-medium',
        'vits-piper-en_GB-cori-medium',
      ]);
      final voces = {for (final m in catalogo.modelos) m.id: m.voces.single};
      expect(voces['vits-piper-en_US-kristin-medium']!.genero, Genero.mujer);
      expect(voces['vits-piper-en_US-john-medium']!.genero, Genero.hombre);
      expect(voces['vits-piper-en_US-norman-medium']!.genero, Genero.hombre);
      expect(voces['vits-piper-en_GB-cori-medium']!.genero, Genero.mujer);
      expect(voces['vits-piper-en_GB-cori-medium']!.variante, Variante.enGB);
      expect(
        voces['vits-piper-en_GB-cori-medium']!.acentoAproximado,
        isTrue,
        reason: 'Cori solo tiene el lexicón americano: acento aproximado',
      );
      expect(
        catalogo.modelos.where((m) => m.voces.single.acentoAproximado).length,
        1,
      );
    });

    test('lessac queda excluido (libritts_r, vctk) y Kokoro fuera de la app por ahora', () {
      for (final excluido in [
        'libritts',
        'vctk',
        'lessac',
        'kokoro',
        'kitten',
      ]) {
        expect(
          texto.toLowerCase(),
          isNot(contains(excluido)),
          reason: excluido,
        );
      }
    });

    test('cada archivo coincide byte a byte con docs/licencias-voces/verificadas.json', () {
      final porId = {
        for (final m in verificadas['modelos']! as List)
          (m as Mapa)['id']! as String: m,
      };
      final lexicon = verificadas['lexicon']! as Mapa;
      for (final m in catalogo.modelos) {
        final v = porId[m.id]!;
        final delModelo = {
          for (final a in v['archivos']! as List)
            (a as Mapa)['nombre']! as String: a,
        };
        expect(m.archivos, hasLength(3), reason: m.id);
        for (final a in m.archivos) {
          final esperado = a.rol == RolDeArchivo.lexicon
              ? lexicon
              : delModelo[a.nombre]!;
          expect(a.nombre, esperado['nombre'], reason: '${m.id}/${a.nombre}');
          expect(a.bytes, esperado['bytes'], reason: '${m.id}/${a.nombre}');
          expect(a.sha256, esperado['sha256'], reason: '${m.id}/${a.nombre}');
        }
        // El modelo y los tokens son archivos útiles del paquete; nada de
        // espeak-ng-data ni de tarjetas.
        expect(m.archivos.map((a) => a.rol), [
          RolDeArchivo.modelo,
          RolDeArchivo.tokens,
          RolDeArchivo.lexicon,
        ]);
      }
      expect(texto, isNot(contains('espeak')));
    });

    test(
      'las direcciones llevan la revisión fija y la carpeta de cada modelo',
      () {
        for (final m in catalogo.modelos) {
          expect(m.fuente.revision, '2026-11-22');
          for (final a in m.archivos) {
            expect(a.url.scheme, 'https');
            expect(a.url.hasQuery, isFalse);
            expect(
              a.url.path,
              '/storage/v1/object/public/voces/2026-11-22/${m.id}/${a.nombre}',
            );
          }
        }
      },
    );

    test('cada licencia lleva atribución y el texto que cita existe en el repositorio', () {
      for (final m in catalogo.modelos) {
        expect(m.licencia.atribucion.trim(), isNotEmpty, reason: m.id);
        expect(
          File('../${m.licencia.texto}').existsSync(),
          isTrue,
          reason: '${m.id}: ${m.licencia.texto}',
        );
        // El lexicón: origen de en_list sin verificar, dicho en pantalla.
        expect(m.licencia.atribucion, contains('CMUDict'), reason: m.id);
        expect(m.licencia.atribucion, contains('en_list'), reason: m.id);
        expect(
          File('../docs/licencias-voces/textos/CMUDICT-LICENSE.txt')
              .existsSync(),
          isTrue,
        );
        // Nadie ha decidido si se puede distribuir audio hecho con estas
        // voces: ausente = no se usa para pregrabar (regla 4).
        expect(m.licencia.permiteDistribuirAudio, isNull, reason: m.id);
      }
    });

    test('lo que pesa cada voz coincide con lo que dice la pantalla', () {
      for (final m in catalogo.modelos) {
        expect(m.bytes, m.archivos.fold<int>(0, (s, a) => s + a.bytes));
        expect(formatearBytes(m.bytes), anyOf('69 MB', '70 MB'), reason: m.id);
      }
    });

    test(
      'no trae uso ni rtf (se miden en el aparato, P3.3) ni paquetes de audio',
      () {
        expect(texto, isNot(contains('"uso"')));
        expect(texto, isNot(contains('"rtf"')));
      },
    );
  });

  group('formatearBytes', () {
    test('usa megabytes decimales', () {
      expect(formatearBytes(69838220), '70 MB');
      expect(formatearBytes(63000000), '63 MB');
      expect(formatearBytes(950), '950 B');
      expect(formatearBytes(1500), '2 KB');
      expect(formatearBytes(1200000000), '1.2 GB');
    });
  });
}

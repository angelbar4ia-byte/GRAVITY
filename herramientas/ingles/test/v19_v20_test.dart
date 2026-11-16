import 'dart:convert';
import 'dart:io';

import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/ayudas_b.dart';
import 'apoyo/casos_b.dart';

/// Una lectura de 22 palabras de relleno más la frase dada.
Doc conFrase(String id, int semilla, String frase) =>
    lectura(id, semilla: semilla, texto: '${relleno(semilla, 22)} $frase');

/// Un audio cuyo habla empieza con la frase dada (27 palabras con ella).
Doc audioConFrase(String id, int semilla, String frase) => audio(id, semilla: semilla, guion: [
      {'voz': 'F1', 'texto': '$frase ${relleno(semilla, 12)}'},
      {'voz': 'M1', 'texto': relleno(semilla + 500, 6)},
    ]);

/// Sustituye la palabra [i] de un texto separado por espacios.
String cambiaPalabra(String texto, int i, String nueva) {
  final p = texto.split(' ');
  p[i] = nueva;
  return p.join(' ');
}

void main() {
  group('V19 · regla a: la misma oración en dos archivos', () {
    final frase = fraseCompartida;

    test('bueno: dos unidades distintas no dejan ningún hallazgo', () {
      expect(propios(correrB([lectura('u-a', semilla: 1), lectura('u-b', semilla: 2)])), isEmpty);
    });
    test('malo: una oración de nueve palabras en dos unidades, reportada en las dos', () {
      final h = errores(correrB([conFrase('u-a', 1, frase), conFrase('u-b', 2, frase)]), 'V19');
      expect(h, hasLength(2));
      expect(h.map((x) => x.archivo), ['doc0.yaml', 'doc1.yaml']);
      expect(h.first.mensaje, contains('comparte 1 oración de 7 palabras o más con "u-b" (doc1.yaml)'));
      expect(h.first.mensaje, contains('The old bridge was closed because of the storm.'));
      expect(h.last.mensaje, contains('con "u-a" (doc0.yaml)'));
    });
    test('bueno: cambia una palabra de la oración y deja de ser la misma', () {
      final h = correrB([conFrase('u-a', 1, frase), conFrase('u-b', 2, frase.replaceFirst('storm', 'rain'))]);
      expect(de(h, 'V19'), isEmpty);
    });
    test('la oración se compara normalizada: sin mayúsculas ni puntuación', () {
      final otra = 'the old bridge was closed because of the storm';
      final h = errores(correrB([conFrase('u-a', 1, frase), conFrase('u-b', 2, otra)]), 'V19');
      expect(h, hasLength(2));
    });
    test('el límite es de siete palabras: siete cuentan, seis no', () {
      final siete = 'The old bridge was closed last night.';
      final seis = 'The old bridge was closed last.';
      expect(errores(correrB([conFrase('u-a', 1, siete), conFrase('u-b', 2, siete)]), 'V19'), hasLength(2));
      expect(errores(correrB([conFrase('u-a', 1, seis), conFrase('u-b', 2, seis)]), 'V19'), isEmpty);
    });
    test('una oración repetida dentro de un mismo archivo no cuenta', () {
      final d = lectura('u-a', texto: '${relleno(1, 14)} $frase $frase');
      pregunta0(d)['enunciado'] = frase;
      expect(de(correrB([d]), 'V19'), isEmpty);
    });
    test('el enunciado de una unidad también se compara con el estímulo de otra', () {
      final a = conFrase('u-a', 1, frase);
      final b = lectura('u-b', semilla: 2);
      pregunta0(b)['enunciado'] = frase;
      expect(errores(correrB([a, b]), 'V19'), hasLength(2));
    });
    test('las opciones de respuesta no se comparan', () {
      final a = lectura('u-a', semilla: 1);
      final b = lectura('u-b', semilla: 2);
      for (final d in [a, b]) {
        mapa(lista(pregunta0(d)['opciones'])[1])['texto'] = frase;
      }
      expect(de(correrB([a, b]), 'V19'), isEmpty);
    });
    test('una unidad retirada no cuenta', () {
      final retirada = conFrase('u-b', 2, frase)..['estado'] = 'retirado';
      expect(de(correrB([conFrase('u-a', 1, frase), retirada]), 'V19'), isEmpty);
    });
    test('el habla de un audio se compara; el narrador no', () {
      expect(errores(correrB([audioConFrase('u-a', 1, frase), audioConFrase('u-b', 2, frase)]), 'V19'), hasLength(2));
      final conNarrador = [
        for (final (i, s) in [1, 2].indexed)
          audio('u-n$i', semilla: s, guion: [
            {'voz': 'N', 'texto': frase},
            {'voz': 'F1', 'texto': relleno(s, 18)},
          ]),
      ];
      expect(de(correrB(conNarrador), 'V19'), isEmpty);
    });

    group('con sesiones', () {
      final au = audioConFrase('u-au', 1, frase);
      final au2 = audio('u-au2', semilla: 2);
      test('bueno: una frase de la sesión que sale de uno de sus audios no es una repetición', () {
        final s = sesionDe('t-s02-lun', audios: ['u-au'], frases: [frase]);
        expect(de(correrB([au, au2, s]), 'V19'), isEmpty);
      });
      test('malo: la misma frase, pero el audio no es uno de los de la sesión', () {
        final s = sesionDe('t-s02-lun', audios: ['u-au2'], frases: [frase]);
        final h = errores(correrB([au, au2, s]), 'V19');
        expect(h, hasLength(2));
        expect(h.map((x) => x.archivo).toSet(), {'doc0.yaml', 'doc2.yaml'});
      });
      test('malo: dos sesiones con la misma frase de siete palabras que no está en un audio', () {
        final otra = 'Another sentence about the weather this week.';
        final a = sesionDe('t-s02-lun', frases: [otra], semilla: 1);
        final b = sesionDe('t-s03-lun', frases: [otra], semilla: 2);
        final h = errores(correrB([au, au2, a, b]), 'V19');
        expect(h, hasLength(2));
        expect(h.first.mensaje, contains('"t-s03-lun"'));
      });
      test('bueno: las mismas dos sesiones con frases distintas', () {
        final a = sesionDe('t-s02-lun', frases: ['Another sentence about the weather this week.'], semilla: 1);
        final b = sesionDe('t-s03-lun', frases: ['Some other sentence about the weather today.'], semilla: 2);
        expect(de(correrB([au, au2, a, b]), 'V19'), isEmpty);
      });
      test('una frase repetida dentro de la misma sesión (traslado y ejemplos) no cuenta', () {
        final s = sesionDe('t-s02-lun', frases: ['Another sentence about the weather this week.', 'Another sentence about the weather this week.']);
        expect(de(correrB([au, au2, s]), 'V19'), isEmpty);
      });
    });
  });

  group('V19 · regla b: similitud de Jaccard sobre trigramas de palabras', () {
    // 62 palabras: 60 trigramas. Cambiar una palabra suelta cambia 3 trigramas:
    // con una, la similitud es 57/63 = 0.90; con dos, 54/66 = 0.82.
    final base = relleno(1, 62);
    Doc enParte2(String id, String texto) => lectura(id, parte: 'r-2', texto: texto, preguntas: 2, semilla: id == 'u-a' ? 10 : 20);

    test('bueno: dos palabras cambiadas dan una similitud de 0.82, bajo el límite', () {
      final copia = cambiaPalabra(cambiaPalabra(base, 10, 'quartz'), 40, 'prism');
      final h = correrB([enParte2('u-a', base), enParte2('u-b', copia)]);
      expect(de(h, 'V19'), isEmpty);
    });
    test('malo: una sola palabra cambiada da 0.90 y es un error en las dos unidades', () {
      final copia = cambiaPalabra(base, 10, 'quartz');
      final h = errores(correrB([enParte2('u-a', base), enParte2('u-b', copia)]), 'V19');
      expect(h, hasLength(2));
      expect(h.first.mensaje, contains('similitud de Jaccard 0.90'));
      expect(h.first.mensaje, contains('el límite es 0.85'));
      expect(h.first.mensaje, contains('"u-b"'));
      expect(h.first.mensaje, isNot(contains('además comparten')));
    });
    test('malo: un texto idéntico da 1.00', () {
      final h = errores(correrB([enParte2('u-a', base), enParte2('u-b', base)]), 'V19');
      expect(h.first.mensaje, contains('1.00'));
    });
    test('cuando además comparten oraciones de siete palabras, se reporta la regla b y las cuenta', () {
      final largo = [for (var i = 0; i < 8; i++) oracion(i, 8)].join(' '); // 8 oraciones de 8 palabras
      final copia = cambiaPalabra(largo, 5, 'quartz');
      final h = errores(correrB([enParte2('u-a', largo), enParte2('u-b', copia)]), 'V19');
      expect(h, hasLength(2));
      expect(h.first.mensaje, contains('similitud de Jaccard'));
      expect(h.first.mensaje, contains('además comparten 7 oraciones de 7 palabras o más'));
    });
    test('el límite es de 0.85 y cuenta: 17 de 20 trigramas comunes', () {
      final a = relleno(3, 20).split(' ');
      final b = [...a.take(19), 'quartz', 'prism'];
      final ta = trigramasDePalabras(a.join(' '));
      final tb = trigramasDePalabras(b.join(' '));
      expect([ta.length, tb.length, ta.intersection(tb).length], [18, 19, 17]);
      expect(similitudJaccard(ta, tb), closeTo(0.85, 1e-12));
      final malo = correrB([lectura('u-a', texto: a.join(' ')), lectura('u-b', texto: b.join(' '))]);
      expect(errores(malo, 'V19'), hasLength(2));
      final c = [...a.take(19), 'quartz', 'prism', 'opal'];
      final bueno = correrB([lectura('u-a', texto: a.join(' ')), lectura('u-b', texto: c.join(' '))]);
      expect(de(bueno, 'V19'), isEmpty);
    });
    test('se comparan también el habla de los audios', () {
      final a = audio('u-a', semilla: 1, palabras: 30);
      final b = audio('u-b', semilla: 2, guion: lista(mapa(a['estimulo'])['guion']).map(mapa).toList());
      expect(errores(correrB([a, b]), 'V19'), isNotEmpty);
    });
    test('una unidad retirada no cuenta', () {
      final retirada = enParte2('u-b', base)..['estado'] = 'retirado';
      expect(de(correrB([enParte2('u-a', base), retirada]), 'V19'), isEmpty);
    });

    group('trigramasDePalabras y similitudJaccard', () {
      test('los trigramas ignoran mayúsculas, puntuación y marcas de hueco', () {
        expect(trigramasDePalabras('One {1} two, THREE four.'), {'one two three', 'two three four'});
      });
      test('un texto de una o dos palabras da un trigrama con todas; sin palabras, ninguno', () {
        expect(trigramasDePalabras('No smoking'), {'no smoking'});
        expect(trigramasDePalabras('  '), isEmpty);
      });
      test('Jaccard: iguales 1, sin nada en común 0, vacíos 0', () {
        expect(similitudJaccard({'a', 'b'}, {'a', 'b'}), 1);
        expect(similitudJaccard({'a'}, {'b'}), 0);
        expect(similitudJaccard({}, {}), 0);
        expect(similitudJaccard({'a', 'b', 'c'}, {'b', 'c', 'd'}), 0.5);
      });
    });
  });

  group('V19 · regla c: una unidad en dos formas', () {
    List<Doc> cuatro() => [for (var i = 0; i < 4; i++) lectura('u-r1-$i', semilla: i + 1)];
    Doc f1([List<String>? ids]) => formaDe('f-1', {'r-1': ids ?? ['u-r1-0', 'u-r1-1']});
    Doc f2(List<String> ids, {String uso = 'simulacro', String estado = 'borrador'}) =>
        formaDe('f-2', {'r-1': ids}, uso: uso, estado: estado);

    test('bueno: dos formas con unidades distintas no dejan ningún hallazgo', () {
      expect(propios(correrB([...cuatro(), f1(), f2(['u-r1-2', 'u-r1-3'])])), isEmpty);
    });
    test('malo: la misma unidad en dos formas, reportada en las dos formas', () {
      final h = errores(correrB([...cuatro(), f1(), f2(['u-r1-1', 'u-r1-3'])]), 'V19');
      expect(h, hasLength(2));
      expect(h.every((x) => x.id == 'u-r1-1'), isTrue);
      expect(h.first.mensaje, contains('también está en la forma "f-2" (uso: simulacro)'));
      expect(h.last.mensaje, contains('también está en la forma "f-1"'));
    });
    test('malo: una unidad en una forma y en la práctica', () {
      final h = errores(correrB([...cuatro(), f1(), f2(['u-r1-1', 'u-r1-3'], uso: 'practica')]), 'V19');
      expect(h, hasLength(2));
      expect(h.first.mensaje, contains('uso: practica, la práctica'));
    });
    test('bueno: la práctica con unidades que no están en la forma', () {
      expect(de(correrB([...cuatro(), f1(), f2(['u-r1-2', 'u-r1-3'], uso: 'practica')]), 'V19'), isEmpty);
    });
    test('malo: la misma unidad dos veces en una forma', () {
      final h = errores(correrB([...cuatro(), f1(['u-r1-0', 'u-r1-0'])]), 'V19');
      expect(h.single.mensaje, contains('aparece 2 veces en esta forma'));
      expect(h.single.id, 'u-r1-0');
    });
    test('malo: la misma unidad en dos secciones de una forma', () {
      final f = formaDe('f-1', {'r-1': ['u-r1-0'], 'r-2': ['u-r1-0']});
      expect(errores(correrB([...cuatro(), f]), 'V19').single.mensaje, contains('aparece 2 veces'));
    });
    test('una forma retirada no cuenta', () {
      expect(de(correrB([...cuatro(), f1(), f2(['u-r1-1', 'u-r1-3'], estado: 'retirado')]), 'V19'), isEmpty);
    });
    test('si una de las dos formas es de uso exclusivo, lo dice V20 y no V19', () {
      final h = correrB([...cuatro(), f1(), f2(['u-r1-1', 'u-r1-3'], uso: 'etapa')]);
      expect(de(h, 'V19'), isEmpty);
      expect(errores(h, 'V20'), hasLength(2));
    });
  });

  group('V20 · las unidades reservadas no se usan en ningún otro lugar', () {
    List<Doc> unidades() => [
          for (var i = 0; i < 4; i++) lectura('u-r1-$i', semilla: i + 1),
          audio('u-au', semilla: 11, palabras: 24),
          audio('u-au2', semilla: 12, palabras: 20),
        ];
    Doc puerta(String uso, [List<String>? ids]) => formaDe('f-1', {'r-1': ids ?? ['u-r1-0', 'u-r1-1']}, uso: uso);
    Doc otra(List<String> ids, {String uso = 'simulacro'}) => formaDe('f-2', {'r-1': ids}, uso: uso);

    for (final uso in ['ubicacion', 'escalon', 'etapa']) {
      test('bueno: una forma de uso "$uso" con unidades que nadie más usa', () {
        expect(propios(correrB([...unidades(), puerta(uso), otra(['u-r1-2', 'u-r1-3'])])), isEmpty);
      });
      test('malo: una unidad de una forma de uso "$uso" también está en otra forma', () {
        final h = errores(correrB([...unidades(), puerta(uso), otra(['u-r1-1', 'u-r1-3'])]), 'V20');
        expect(h, hasLength(2));
        expect(h.first.archivo, 'doc6.yaml');
        expect(h.first.mensaje, contains('es de una forma de uso "$uso" y no se usa en ningún otro lugar'));
        expect(h.first.mensaje, contains('también la usa la forma "f-2" (uso: simulacro)'));
        expect(h.last.archivo, 'doc7.yaml');
        expect(h.last.mensaje, contains('usa la unidad "u-r1-1", reservada para la forma "f-1" (uso: $uso)'));
      });
    }
    test('bueno: las formas de otros usos pueden compartir lo que su regla permita (mini, simulacro)', () {
      final h = correrB([...unidades(), puerta('mini'), otra(['u-r1-2', 'u-r1-3'], uso: 'mini')]);
      expect(de(h, 'V20'), isEmpty);
    });
    test('malo: dos formas de uso exclusivo que comparten una unidad se reportan entre sí', () {
      final h = errores(correrB([...unidades(), puerta('etapa'), otra(['u-r1-1', 'u-r1-3'], uso: 'ubicacion')]), 'V20');
      expect(h, hasLength(2));
      expect(h.first.mensaje, contains('la forma "f-2" (uso: ubicacion)'));
      expect(h.last.mensaje, contains('también la usa la forma "f-1" (uso: etapa)'));
    });

    group('con sesiones', () {
      Doc puertaDeAudio() => formaDe('f-1', {'l-1': ['u-au', 'u-au2']}, uso: 'etapa');
      List<Doc> audios() => [audio('u-au', semilla: 11), audio('u-au2', semilla: 12), audio('u-au3', semilla: 13)];
      test('bueno: una sesión cuyo traslado usa un audio que no es de una puerta', () {
        final s = sesionDe('t-s02-lun', audios: ['u-au3'], frases: ['Nothing repeats here at all, my friend.']);
        expect(de(correrB([...audios(), puertaDeAudio(), s]), 'V20'), isEmpty);
      });
      test('malo: una sesión cuyo traslado usa un audio de una puerta, reportada en las dos', () {
        final s = sesionDe('t-s02-lun', audios: ['u-au'], frases: ['Nothing repeats here at all, my friend.']);
        final h = errores(correrB([...audios(), puertaDeAudio(), s]), 'V20');
        expect(h, hasLength(2));
        expect(h.map((x) => x.archivo).toSet(), {'doc3.yaml', 'doc4.yaml'});
        expect(h.firstWhere((x) => x.archivo == 'doc3.yaml').mensaje, contains('también la usa la sesión "t-s02-lun" (su traslado)'));
        expect(h.firstWhere((x) => x.archivo == 'doc4.yaml').mensaje, contains('usa la unidad "u-au" en su traslado, reservada para la forma "f-1" (uso: etapa)'));
      });
      test('una sesión retirada no cuenta', () {
        final s = sesionDe('t-s02-lun', audios: ['u-au'], frases: ['Nothing repeats here at all, my friend.'])..['estado'] = 'retirado';
        expect(de(correrB([...audios(), puertaDeAudio(), s]), 'V20'), isEmpty);
      });
    });
  });
  pruebasDeLaOrden();
}

Doc pregunta0(Doc d) => mapa(lista(d['preguntas']).first);

void pruebasDeLaOrden() {
  group('la orden validar con V15 a V20', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ingles_v19_'));
    tearDown(() => dir.deleteSync(recursive: true));

    void escribe(String ruta, Object contenido) {
      final f = File('${dir.path}/$ruta')..createSync(recursive: true);
      f.writeAsStringSync(contenido is String ? contenido : jsonEncode(contenido));
    }

    test('imprime los hallazgos del conjunto (duplicados entre archivos) y sale con 1', () async {
      escribe('formatos/c.yaml', contratoFidelidad());
      escribe('unidades/a.yaml', conFrase('u-a', 1, fraseCompartida));
      escribe('unidades/b.yaml', conFrase('u-b', 2, fraseCompartida));
      escribe('niveles.yaml', {'esquema': 'gravity-ingles-v1', 'tipo': 'niveles', 'id': 'niv', 'estado': 'borrador', 'niveles': ['B1'], 'escalones': ['B1.1'], 'habilidades': ['lectura'], 'focos': ['detalle'], 'temas': <String>[]});
      final p = await Process.run(Platform.resolvedExecutable, ['run', 'bin/ingles.dart', 'validar', dir.path]);
      final lineas = (p.stdout as String).trim().split('\n');
      expect(p.exitCode, 1);
      expect(lineas, contains(startsWith('unidades/a.yaml [u-a] V19 error: comparte 1 oración de 7 palabras o más con "u-b" (unidades/b.yaml)')));
      expect(lineas, contains(startsWith('unidades/b.yaml [u-b] V19 error: comparte 1 oración de 7 palabras o más con "u-a" (unidades/a.yaml)')));
      expect(lineas.last, 'Resumen: 4 archivos leídos, 2 errores, 0 avisos.');
    });
  });
}

import 'package:ingles/ingles.dart';
import 'package:ingles/src/datos/grafias.dart';
import 'package:ingles/src/datos/palabras_espanolas.dart';
import 'package:ingles/src/datos/palabras_gramaticales.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/ayudas_b.dart';
import 'apoyo/casos_b.dart';

Doc pregunta(Doc d, [int i = 0]) => mapa(lista(d['preguntas'])[i]);
Doc opcion(Doc d, int i, [int q = 0]) => mapa(lista(pregunta(d, q)['opciones'])[i]);

/// Una lectura de 22 palabras de relleno más la frase dada (hasta 18 palabras,
/// para no salirse del rango de `r-1`).
Doc lecturaCon(String frase, {String variante = 'en-GB'}) =>
    lectura('u-a', texto: '${relleno(1, 22)} $frase', variante: variante);

void main() {
  group('V17 · enunciados y opciones en inglés', () {
    test('bueno: una unidad en inglés no deja ningún hallazgo', () {
      expect(propios(correrB([lectura('u-a')])), isEmpty);
    });
    test('malo: un enunciado con dos palabras distintas del español', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'What does the writer say en el text?';
      final h = errores(correrB([d]), 'V17');
      expect(h.single.id, 'u-a-1');
      expect(h.single.mensaje, contains('en, el'));
      expect(h.single.mensaje, contains('van en inglés'));
    });
    test('malo: una opción en español', () {
      final d = lectura('u-a');
      opcion(d, 1)['texto'] = 'Dice que es muy nuevo.';
      final h = errores(correrB([d]), 'V17');
      expect(h.single.mensaje, contains('que, es, muy'));
    });
    test('malo: palabras con tilde (qué, más)', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'Which one is qué más?';
      expect(errores(correrB([d]), 'V17'), hasLength(1));
    });
    test('malo: un español de palabras de contenido se detecta por la tilde', () {
      final d = lectura('u-a');
      opcion(d, 1)['texto'] = 'Ella no pudo pagar la reparación del coche.';
      final h = errores(correrB([d]), 'V17');
      expect(h.single.mensaje, contains('del'));
      expect(h.single.mensaje, contains('reparación'));
    });
    test('malo: dos palabras con tilde en minúscula bastan', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'What is the reparación and the atención?';
      expect(errores(correrB([d]), 'V17'), hasLength(1));
    });
    test('bueno: los nombres propios con tilde no cuentan (José García, María)', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'Did José García meet María in Málaga?';
      expect(errores(correrB([d]), 'V17'), isEmpty);
    });
    test('bueno: los préstamos con tilde no cuentan (café, résumé, piñata)', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'Did she order a café and bring a résumé and a piñata?';
      expect(errores(correrB([d]), 'V17'), isEmpty);
    });
    test('bueno: una sola palabra con tilde no basta', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'What does the word reparación mean?';
      expect(errores(correrB([d]), 'V17'), isEmpty);
    });
    test('bueno: una sola palabra del español no basta (un nombre propio, un préstamo)', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'What is said about El Paso?';
      expect(errores(correrB([d]), 'V17'), isEmpty);
    });
    test('bueno: la misma palabra española repetida cuenta como una', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'Who is de Gaulle de Gaulle?';
      expect(errores(correrB([d]), 'V17'), isEmpty);
    });
    test('bueno: las palabras que también son inglesas no cuentan (a, he, no, me, pan, sin)', () {
      final d = lectura('u-a');
      pregunta(d)['enunciado'] = 'He said no to me, a pan and sin.';
      expect(errores(correrB([d]), 'V17'), isEmpty);
    });
    test('malo: también los enunciados de una transformación y las oraciones de unas oraciones omitidas', () {
      final t = transformaciones('u-t');
      pregunta(t)['original'] = 'Dice que el libro es muy bueno.';
      expect(errores(correrB([t]), 'V17').single.id, 'u-t-1');
      final o = omitidas('u-o');
      mapa(lista(pregunta(o)['oraciones'])[0])['texto'] = 'Es una frase que no es inglesa.';
      expect(errores(correrB([o]), 'V17').single.id, 'u-o-a');
    });
    test('malo: las opciones con id de la unidad (los textos de un emparejar)', () {
      final d = emparejarEnglish();
      mapa(lista(d['opciones'])[0])['texto'] = 'Es una opción que no es inglesa.';
      expect(errores(correrB([d], contrato: contratoEmparejar()), 'V17').single.id, 'u-e');
    });
    test('bueno: el estímulo no se comprueba (solo enunciados y opciones)', () {
      final d = lectura('u-a', texto: '${relleno(1, 22)} Los niños de la casa que es muy grande.');
      expect(de(correrB([d]), 'V17'), isEmpty);
    });
    test('bueno: una unidad del curso (gravity-sesion-60) mezcla español a propósito', () {
      final d = lectura('u-a', formato: 'gravity-sesion-60');
      pregunta(d)['enunciado'] = 'Qué dice el texto sobre la casa?';
      expect(de(correrB([d]), 'V17'), isEmpty);
    });
    test('bueno: una sesión del curso tampoco se comprueba', () {
      final s = sesionDe('t-s02-lun');
      final q = mapa(lista(mapa(lista(s['bloques'])[1])['preguntas']).first);
      q['enunciado'] = 'Qué es lo que dice el texto?';
      expect(de(correrB([s]), 'V17'), isEmpty);
    });

    group('la lista de palabras del español', () {
      test('las que pidió el encargo evitar están excluidas, cada una con su razón', () {
        for (final p in ['a', 'he', 'no', 'me', 'pan', 'sin']) {
          expect(palabrasEspanolasExcluidas, contains(p));
          expect(palabrasEspanolas, isNot(contains(p)));
          expect(palabrasEspanolasExcluidas[p], isNotEmpty);
        }
      });
      test('ninguna palabra excluida está en la lista', () {
        expect(palabrasEspanolas.intersection(palabrasEspanolasExcluidas.keys.toSet()), isEmpty);
      });
      test('ninguna es también una palabra gramatical del inglés', () {
        expect(palabrasEspanolas.intersection(palabrasGramaticales), isEmpty);
      });
      test('todas en minúsculas y de una sola palabra, sin repetir', () {
        final todas = [for (final l in palabrasEspanolasPorCategoria.values) ...l];
        expect(todas.toSet(), hasLength(todas.length));
        for (final p in todas) {
          expect(p, p.toLowerCase());
          expect(palabrasDe(p), [p]);
        }
      });
      test('es una lista pequeña', () {
        expect(palabrasEspanolas.length, lessThan(150));
      });
    });
  });

  group('V18 · grafías británicas y americanas', () {
    test('bueno: grafía británica en una unidad en-GB', () {
      final d = lecturaCon('The colour of the centre was grey.');
      expect(propios(correrB([d])), isEmpty);
    });
    test('bueno: grafía americana en una unidad en-US', () {
      final d = lecturaCon('The color of the center was gray.', variante: 'en-US');
      expect(propios(correrB([d])), isEmpty);
    });
    test('malo: una mezcla (colour y center) es un aviso, no un error', () {
      final d = lecturaCon('The colour of the center was grey.');
      final h = correrB([d]);
      expect(errores(h, 'V18'), isEmpty);
      final a = avisos(h, 'V18').single;
      expect(a.mensaje, contains('mezcla grafías británicas (colour, grey) y americanas (center)'));
    });
    test('malo: una unidad en-US con grafía británica', () {
      final d = lecturaCon('The colour of the centre was grey.', variante: 'en-US');
      final a = avisos(correrB([d]), 'V18').single;
      expect(a.mensaje, contains('declara la variante en-US, pero su grafía es británica (centre, colour, grey)'));
    });
    test('malo: una unidad en-GB con grafía americana', () {
      final d = lecturaCon('The color of the center was gray.');
      expect(avisos(correrB([d]), 'V18').single.mensaje, contains('declara la variante en-GB, pero su grafía es americana'));
    });
    test('malo: mezcla con dominante distinta de la declarada da los dos avisos', () {
      final d = lecturaCon('The color of the center was gray, and the colour was bright.');
      final h = avisos(correrB([d]), 'V18');
      expect(h, hasLength(2));
      expect(h.first.mensaje, startsWith('mezcla'));
      expect(h.last.mensaje, contains('declara la variante en-GB, pero su grafía es americana'));
    });
    test('un empate no tiene dominante: solo avisa de la mezcla', () {
      final d = lecturaCon('The colour of the center was bright.');
      final h = avisos(correrB([d]), 'V18');
      expect(h.single.mensaje, startsWith('mezcla'));
    });
    test('las formas americanas ambiguas no prueban nada (program, check, tire, meter, story)', () {
      final d = lecturaCon('The colour of the program, the check and the tire was bright.');
      expect(de(correrB([d]), 'V18'), isEmpty);
    });
    test('sin grafías de la lista no hay aviso, sea cual sea la variante declarada', () {
      expect(de(correrB([lectura('u-a', variante: 'en-US')]), 'V18'), isEmpty);
    });
    test('cancelled se usa también en Estados Unidos: no prueba que sea británico', () {
      final d = lecturaCon('The flight was cancelled at the color desk.', variante: 'en-US');
      expect(de(correrB([d]), 'V18'), isEmpty);
    });
    test('una palabra con guion se mira por partes', () {
      final d = lecturaCon('She is colour-blind.', variante: 'en-US');
      expect(avisos(correrB([d]), 'V18').single.mensaje, contains('colour'));
    });
    test('las explicaciones y las respuestas aceptadas no entran', () {
      final d = lectura('u-a');
      opcion(d, 0)['porque'] = 'El texto usa "colour" y "color" como dos grafías del mismo sustantivo.';
      opcion(d, 1)['porque_no'] = 'Aquí "centre" y "center" son lo mismo y no cambian la respuesta.';
      expect(de(correrB([d]), 'V18'), isEmpty);
    });
    test('también cuentan las opciones y los enunciados', () {
      final d = lecturaCon('The colour was bright.');
      opcion(d, 1)['texto'] = 'The center is new.';
      expect(avisos(correrB([d]), 'V18').single.mensaje, contains('mezcla'));
    });
    test('también se aplica a las sesiones del curso, que declaran su variante', () {
      final bueno = sesionDe('t-s02-lun', frases: ['My neighbor lives next door.'], variante: 'en-US');
      expect(de(correrB([bueno]), 'V18'), isEmpty);
      final malo = sesionDe('t-s02-lun', frases: ['My neighbor lives next door.'], variante: 'en-GB');
      expect(avisos(correrB([malo]), 'V18').single.mensaje, contains('declara la variante en-GB, pero su grafía es americana'));
    });

    group('la lista de control', () {
      test('trae las parejas que pidió el encargo', () {
        const pedidas = {
          'colour': 'color', 'behaviour': 'behavior', 'centre': 'center', 'realise': 'realize',
          'organise': 'organize', 'travelled': 'traveled', 'favourite': 'favorite',
          'neighbour': 'neighbor', 'grey': 'gray', 'theatre': 'theater', 'defence': 'defense',
          'analyse': 'analyze', 'tyre': 'tire', 'metre': 'meter', 'litre': 'liter',
          'cheque': 'check', 'catalogue': 'catalog', 'programme': 'program',
        };
        pedidas.forEach((b, a) => expect(grafiasBritanicas[b], a, reason: b));
      });
      test('ninguna palabra es a la vez británica y americana', () {
        expect(formasBritanicas.intersection(formasAmericanas), isEmpty);
      });
      test('todas en minúsculas y de una sola palabra', () {
        for (final p in [...grafiasBritanicas.keys, ...grafiasBritanicas.values]) {
          expect(p, p.toLowerCase());
          expect(palabrasDe(p), [p]);
        }
      });
      test('las ambiguas existen en la lista', () {
        expect(grafiasBritanicas.values.toSet().containsAll(americanasAmbiguas.where((a) => grafiasBritanicas.values.contains(a))), isTrue);
        expect(americanasAmbiguas, contains('program'));
        expect(britanicasAmbiguas.every(grafiasBritanicas.containsKey), isTrue);
      });
    });
  });
}

/// Un emparejar en inglés para probar las opciones con id (parte `m-em`).
Doc emparejarEnglish() => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'unidad',
      'id': 'u-e',
      'estado': 'borrador',
      'formato': 'prueba-emparejar',
      'parte': 'm-em',
      'nivel': 'B1',
      'variante': 'en-GB',
      'origen': 'nuevo',
      'estimulo': {'tipo': 'texto', 'texto': 'Read the three descriptions and the four texts.'},
      'opciones': [
        for (final (i, l) in ['A', 'B', 'C', 'D'].indexed) {'id': l, 'texto': relleno(i + 1, 6), if (i == 3) 'porque_no': 'Ninguna persona busca lo que ofrece.'},
      ],
      'preguntas': [
        for (final (i, l) in ['A', 'B', 'C'].indexed)
          {
            'id': 'u-e-${i + 1}',
            'tipo': 'emparejar',
            'habilidad': 'lectura',
            'elemento': 'Person ${i + 1} wants a quiet place.',
            'respuesta': l,
            'evidencia': 'El texto ofrece justo lo que busca esta persona.',
            'porque': 'Es el único texto que cumple todas sus condiciones.',
          },
      ],
    };

/// El contrato con la parte de emparejar de `emparejarEnglish`.
Doc contratoEmparejar() => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'formato',
      'id': 'prueba-emparejar',
      'estado': 'borrador',
      'nombre': 'Emparejar de prueba',
      'fuente': {'titulo': 'Manual de prueba', 'url': 'https://example.org/manual.pdf'},
      'variante': 'en-GB',
      'secciones': [
        {
          'id': 'reading',
          'partes': [
            {'id': 'm-em', 'tarea': 'Emparejar', 'tipo_pregunta': 'emparejar', 'tipo_estimulo': 'texto', 'unidades': 1, 'preguntas_por_unidad': 3, 'preguntas_total': 3, 'opciones': 4, 'pagina_manual': 1},
          ],
        },
      ],
    };

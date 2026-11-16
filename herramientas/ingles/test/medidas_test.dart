import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/ayudas_b.dart';
import 'apoyo/casos.dart';
import 'apoyo/casos_b.dart';

void main() {
  group('relleno (el texto de los casos)', () {
    test('tiene exactamente las palabras pedidas, en oraciones de cinco', () {
      for (final n in [1, 5, 14, 30, 60]) {
        expect(contarPalabras(relleno(3, n)), n);
      }
      expect(dividirOraciones(relleno(3, 30)).map(contarPalabras), everyElement(lessThanOrEqualTo(5)));
    });
    test('los trigramas de un relleno no se repiten (las pruebas de similitud cuentan con eso)', () {
      for (var semilla = 1; semilla <= 40; semilla++) {
        expect(trigramasDePalabras(relleno(semilla, 62)), hasLength(60), reason: 'semilla $semilla');
        expect(trigramasDePalabras(relleno(semilla, 20)), hasLength(18), reason: 'semilla $semilla');
      }
    });
    test('dos semillas dan textos sin casi nada en común', () {
      final a = trigramasDePalabras(relleno(1, 60));
      final b = trigramasDePalabras(relleno(2, 60));
      expect(similitudJaccard(a, b), lessThan(0.05));
    });
  });

  group('palabras para comparar', () {
    test('palabrasDe: minúsculas, apóstrofo recto y sin apóstrofos en los bordes', () {
      expect(palabrasDe("The 'Boat' wasn’t DOGS' well-known"), ['the', 'boat', "wasn't", 'dogs', 'well-known']);
    });
    test('palabrasDe cuenta lo mismo que contarPalabras', () {
      const t = "I don't know the well-known answer 42 {1} ' - end.";
      expect(palabrasDe(t), hasLength(contarPalabras(t)));
    });
    test('unirPalabrasCortadas: la{yer} es layer y {1} no se toca', () {
      expect(unirPalabrasCortadas('a la{yer} of se{en} wood {1}'), 'a layer of seen wood {1}');
    });
    test('contarPalabrasEstimulo: una palabra cortada cuenta una vez y un hueco numerado, una', () {
      expect(contarPalabras('a la{yer} of {1}'), 5);
      expect(contarPalabrasEstimulo('a la{yer} of {1}'), 4);
    });
    test('sinMarcasDeHueco quita los números y une las palabras cortadas', () {
      expect(sinMarcasDeHueco('One {1} two la{yer}').replaceAll(RegExp(r'\s+'), ' '), 'One two layer');
    });
  });

  group('dividirOraciones', () {
    test('corta tras punto, signo de interrogación y de exclamación', () {
      expect(dividirOraciones('It rains. Does it? Yes! Fine'), ['It rains.', 'Does it?', 'Yes!', 'Fine']);
    });
    test('un salto de línea suelto no corta: la oración atraviesa el renglón', () {
      expect(dividirOraciones('Twelve months ago, I sold\nmy car. It wasn\'t brave.'), ['Twelve months ago, I sold my car.', "It wasn't brave."]);
    });
    test('una línea en blanco corta: un título no se pega a la oración siguiente', () {
      expect(dividirOraciones('by Elena Marsh\n\nTwelve months ago, I sold my car.'), ['by Elena Marsh', 'Twelve months ago, I sold my car.']);
    });
    test('los finales de línea de Windows valen igual', () {
      expect(dividirOraciones('One.\r\n\r\nTwo three.'), ['One.', 'Two three.']);
    });
    test('un texto vacío no da oraciones', () => expect(dividirOraciones('  \n\n '), isEmpty));
  });

  group('claveDeOracion', () {
    test('no distingue mayúsculas, puntuación ni marcas de hueco', () {
      expect(claveDeOracion('Normally, my days are ALL the same!'), 'normally my days are all the same');
      expect(claveDeOracion("It's {3} a la{yer}."), "it's a layer");
    });
    test('el apóstrofo curvo y el recto dan la misma clave', () {
      expect(claveDeOracion('I don’t know'), claveDeOracion("I don't know"));
    });
  });

  group('medidasDeEstimulo', () {
    List<int> palabras(Doc d) => [for (final m in medidasDeEstimulo(unidadDe(d))) m.palabras];

    test('un texto: sus palabras, con los números de hueco', () {
      expect(palabras(lectura('u-t', texto: 'One two three {1} four.')), [5]);
    });
    test('un texto de completar palabras: cada palabra cortada cuenta una vez', () {
      expect(palabras(completarPalabras()), [contarPalabrasEstimulo(mapa(completarPalabras()['estimulo'])['texto']! as String)]);
      expect(palabras(completarPalabras()).single, lessThan(contarPalabras(mapa(completarPalabras()['estimulo'])['texto']! as String)));
    });
    test('un audio: solo los turnos de habla; el narrador no cuenta', () {
      final d = audio('u-a', palabras: 24);
      expect(palabras(d), [24]);
      lista(mapa(d['estimulo'])['guion']).insert(0, {'voz': 'N', 'texto': 'A very long introduction from the narrator that adds many words.'});
      expect(palabras(d), [24]);
    });
    test('transformaciones sueltas: la oración original de cada una', () {
      final d = transformaciones('u-t', n: 3, palabrasOriginal: 8);
      expect(palabras(d), [8, 8, 8]);
      expect([for (final m in medidasDeEstimulo(unidadDe(d))) m.id], ['u-t-1', 'u-t-2', 'u-t-3']);
    });
    test('oraciones omitidas: el texto más las oraciones disponibles, también la sobrante', () {
      expect(palabras(omitidas('u-o')), [38 + 15]);
    });
    test('emparejar: las opciones de la unidad y la descripción de cada persona', () {
      final d = emparejar();
      for (final o in lista(d['opciones'])) {
        mapa(o)['texto'] = 'one two three four five';
      }
      for (final q in lista(d['preguntas'])) {
        mapa(q)['elemento'] = 'one two three';
      }
      final u = unidadDe(d);
      // Texto de presentación (5) + 5 opciones de 5 + 3 descripciones de 3.
      expect(medidasDeEstimulo(u).single.palabras, contarPalabras('Tres personas y cinco textos.') + 25 + 9);
    });
    test('correspondencia: los textos con id, no los enunciados', () {
      final d = correspondencia();
      for (final t in lista(d['textos'])) {
        mapa(t)['texto'] = 'one two three four five six';
      }
      expect(medidasDeEstimulo(unidadDe(d)).single.palabras, contarPalabras('Cuatro secciones A, B, C y D.') + 24);
    });
    test('una imagen no tiene nada que medir', () {
      final d = lectura('u-i');
      d['estimulo'] = {'tipo': 'imagen', 'descripcion': 'A photo of a bridge.'};
      expect(medidasDeEstimulo(unidadDe(d)), isEmpty);
    });
    test('ninguno sin transformaciones no tiene nada que medir', () {
      expect(medidasDeEstimulo(unidadDe(variadas())), isEmpty);
    });
  });

  group('unidades y preguntas que aporta un archivo', () {
    test('un archivo con estímulo es una unidad con sus preguntas', () {
      final u = unidadDe(lectura('u-l', preguntas: 3));
      expect(contarUnidades(u), 1);
      expect(contarPreguntas(u), 3);
    });
    test('un archivo con estimulo: ninguno aporta tantas unidades como preguntas lleve', () {
      final u = unidadDe(transformaciones('u-t', n: 3));
      expect(contarUnidades(u), 3);
      expect(contarPreguntas(u), 3);
    });
    test('las oraciones omitidas aportan una pregunta por oración colocada, no por sobrante', () {
      expect(contarPreguntas(unidadDe(omitidas('u-o'))), 2);
    });
    test('completar palabras aporta una pregunta por hueco', () {
      expect(contarPreguntas(unidadDe(completarPalabras())), 2);
    });
    test('completar nota aporta una pregunta por hueco (cada hueco es una pregunta)', () {
      expect(contarPreguntas(unidadDe(audioNotas('u-n'))), 2);
    });
  });

  group('rangos', () {
    test('describirRango', () {
      expect(describirRango(const Rango(min: 300, max: 400)), '300 a 400');
      expect(describirRango(const Rango(min: 5, max: 5)), '5');
      expect(describirRango(const Rango(max: 250)), 'hasta 250');
      expect(describirRango(const Rango(min: 25)), 'desde 25');
      expect(describirRango(const Rango()), 'sin límite');
    });
    test('enRango: los extremos valen y un extremo ausente no limita', () {
      const r = Rango(min: 20, max: 40);
      expect([enRango(19, r), enRango(20, r), enRango(40, r), enRango(41, r)], [false, true, true, false]);
      expect(enRango(1000, const Rango(min: 20)), isTrue);
      expect(enRango(0, const Rango(max: 20)), isTrue);
    });
    test('preguntasQuePide: el total, o unidades por preguntas por unidad, o nada', () {
      Parte parte(Doc d) => (leerMapa('c.yaml', clonar(d)) as ArchivoFormato).contrato.parte('r-1')!;
      final c = contratoFidelidad();
      expect(preguntasQuePide(parte(c))!.min, 2);
      final sinTotal = clonar(c);
      final p = mapa(lista(mapa(lista(sinTotal['secciones']).first)['partes']).first)..remove('preguntas_total');
      expect(preguntasQuePide(parte(sinTotal))!.min, 2);
      p.remove('preguntas_por_unidad');
      expect(preguntasQuePide(parte(sinTotal)), isNull);
    });
  });
}

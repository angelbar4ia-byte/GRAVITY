import 'package:ingles/ingles.dart';
import 'package:ingles/src/datos/palabras_gramaticales.dart';
import 'package:test/test.dart';

void main() {
  group('contarPalabras', () {
    test('cuenta secuencias de letras, dígitos, apóstrofos y guiones', () {
      expect(contarPalabras("I don't know the well-known answer 42 {1}."), 8);
    });
    test('un apóstrofo o un guion sueltos no cuentan', () {
      expect(contarPalabras("' hello - world"), 2);
    });
    test('cuenta letras con acento', () {
      expect(contarPalabras('Cómo estás, señor'), 3);
    });
    test('texto vacío', () => expect(contarPalabras('  '), 0));
  });

  group('palabrasDeExamen', () {
    test('una contracción cuenta dos', () {
      expect(palabrasDeExamen("I'm sure it's true, don't you?"),
          ['i', "'m", 'sure', 'it', "'s", 'true', 'do', "n't", 'you']);
      expect(contarPalabrasExamen("the best book I've"), 5);
    });
    test('el posesivo cuenta una', () {
      expect(palabrasDeExamen("John's car"), ["john's", 'car']);
    });
    test("can't y won't se reparten en la raíz y n't", () {
      expect(palabrasDeExamen("can't"), ['can', "n't"]);
      expect(palabrasDeExamen("won't"), ['will', "n't"]);
    });
    test('el apóstrofo curvo vale igual', () {
      expect(palabrasDeExamen('I’d go'), ['i', "'d", 'go']);
    });
    test('las palabras con guion cuentan una', () {
      expect(contarPalabrasExamen('a well-known author'), 3);
    });
  });

  group('normalizarRespuesta', () {
    test('mayúsculas, espacios, apóstrofo y punto final', () {
      expect(normalizarRespuesta('  Wish  I’d   studied. '), "wish i'd studied");
      expect(normalizarRespuesta('Do you go?'), 'do you go');
    });
    test('solo se quita un punto o signo de interrogación final', () {
      expect(normalizarRespuesta('ok!'), 'ok!');
      expect(normalizarRespuesta('end..'), 'end.');
    });
    test('lo demás debe coincidir', () {
      expect(normalizarRespuesta('is working'), isNot(normalizarRespuesta("'s working")));
    });
  });

  test('normalizarOpcion ignora mayúsculas, espacios y puntuación', () {
    expect(normalizarOpcion('Works / is working!'), 'worksisworking');
    expect(normalizarOpcion('works/is  working'), normalizarOpcion('Works / Is Working.'));
  });

  group('palabras gramaticales', () {
    test('hay una lista por categoría, con las ocho categorías', () {
      expect(palabrasGramaticalesPorCategoria.keys, [
        'preposiciones',
        'articulos_y_determinantes',
        'auxiliares_y_modales',
        'pronombres_y_relativos',
        'conectores',
        'particulas_de_verbos_frasales',
        'cuantificadores',
        'negaciones',
      ]);
    });
    test('todas en minúsculas y de una sola palabra', () {
      for (final p in palabrasGramaticales) {
        expect(p, p.toLowerCase());
        expect(contarPalabras(p), 1, reason: p);
      }
    });
    test('contiene las de los ejemplos patrón', () {
      for (final p in ['another', 'out', 'for', 'behind', 'on', 'upon', 'without', 'which', 'since', 'none']) {
        expect(palabrasGramaticales, contains(p));
      }
    });
    test('no contiene palabras de contenido', () {
      for (final p in ['house', 'develop', 'consult', 'happy']) {
        expect(palabrasGramaticales, isNot(contains(p)));
      }
    });
  });
}

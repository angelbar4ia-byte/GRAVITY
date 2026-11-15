import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/casos.dart';

Doc pregunta(Doc d, int i) => mapa(lista(d['preguntas'])[i]);

void main() {
  group('V07 · formación de palabra', () {
    test('bueno', () => expect(de(correr([formacionPalabra()]), 'V07'), isEmpty));

    test('malo: la respuesta es la base', () {
      final d = formacionPalabra();
      pregunta(d, 0)['aceptadas'] = ['danger'];
      final h = errores(correr([d]), 'V07');
      expect(h.single.id, 't-fp-0001-1');
      expect(h.single.mensaje, contains('igual a la palabra base'));
    });
    test('malo: la respuesta es la base con otras mayúsculas', () {
      final d = formacionPalabra();
      pregunta(d, 1)['aceptadas'] = ['Unpleasant', 'PLEASE'];
      expect(errores(correr([d]), 'V07').single.id, 't-fp-0001-2');
    });
  });

  group('V08 · transformación', () {
    test('bueno', () => expect(de(correr([transformacion()]), 'V08'), isEmpty));

    test('malo: la respuesta no contiene la palabra clave', () {
      final d = transformacion();
      pregunta(d, 0)['aceptadas'] = ['the finest book I have'];
      expect(errores(correr([d]), 'V08').single.mensaje, contains('no contiene la palabra clave'));
    });
    test('malo: la respuesta cambia la palabra clave', () {
      final d = transformacion();
      pregunta(d, 0)['aceptadas'] = ['the bestest book I have'];
      expect(errores(correr([d]), 'V08').single.mensaje, contains('sin cambios'));
    });
    test('malo: demasiadas palabras', () {
      final d = transformacion();
      pregunta(d, 0)['aceptadas'] = ['the very best book I have'];
      expect(errores(correr([d]), 'V08').single.mensaje, contains('tiene 6 palabras'));
    });
    test('malo: una contracción cuenta dos', () {
      final d = transformacion();
      pregunta(d, 0)['aceptadas'] = ["the very best book I've"];
      expect(errores(correr([d]), 'V08').single.mensaje, contains('tiene 6 palabras'));
    });
    test('malo: una sola palabra', () {
      final d = transformacion();
      pregunta(d, 0)['aceptadas'] = ['best'];
      expect(errores(correr([d]), 'V08').single.mensaje, contains('tiene 1 palabras'));
    });
    test('malo: la clave aparece en "antes"', () {
      final d = transformacion();
      pregunta(d, 0)['antes'] = 'This is the best';
      expect(errores(correr([d]), 'V08').single.mensaje, contains('"antes"'));
    });
    test('malo: la clave aparece en "despues" (sin distinguir mayúsculas)', () {
      final d = transformacion();
      pregunta(d, 0)['despues'] = 'Best read ever.';
      expect(errores(correr([d]), 'V08').single.mensaje, contains('"despues"'));
    });
    test('malo: la clave son dos palabras', () {
      final d = transformacion();
      pregunta(d, 0)['clave'] = 'THE BEST';
      expect(errores(correr([d]), 'V08').single.mensaje, contains('una sola palabra'));
    });
    test('el rango del contrato manda sobre el de 2 a 5', () {
      final d = transformacion();
      expect(errores(correr([d]), 'V08'), isEmpty);
      d['parte'] = 'p-tr-3a4';
      final h = errores(correr([d]), 'V08');
      expect(h, hasLength(2));
      expect(h.first.mensaje, contains('de 3 a 4'));
    });
  });

  group('V09 · hueco abierto', () {
    test('bueno', () => expect(de(correr([huecoAbierto()]), 'V09'), isEmpty));

    test('bueno: la lista no distingue mayúsculas', () {
      final d = huecoAbierto();
      pregunta(d, 0)['aceptadas'] = ['Who'];
      expect(de(correr([d]), 'V09'), isEmpty);
    });
    test('malo: una respuesta de dos palabras', () {
      final d = huecoAbierto();
      pregunta(d, 1)['aceptadas'] = ['next to'];
      expect(errores(correr([d]), 'V09').single.mensaje, contains('tiene 2 palabras'));
    });
    test('malo: una contracción no cabe en un hueco', () {
      final d = huecoAbierto();
      pregunta(d, 0)['aceptadas'] = ["who's"];
      expect(errores(correr([d]), 'V09').single.mensaje, contains('tiene 2 palabras'));
    });
    test('malo: una palabra de contenido en un hueco gramatical', () {
      final d = huecoAbierto();
      pregunta(d, 1)['aceptadas'] = ['near', 'house'];
      final h = errores(correr([d]), 'V09');
      expect(h.single.mensaje, contains('"house" no está en la lista'));
    });
    test('bueno: sin clase gramatical, la palabra de contenido se admite', () {
      final d = huecoAbierto();
      pregunta(d, 1)
        ..remove('clase')
        ..['aceptadas'] = ['near', 'house'];
      expect(de(correr([d]), 'V09'), isEmpty);
    });
    test('malo: en Cambridge, un hueco sin clase es aviso', () {
      final d = huecoAbierto()..['formato'] = 'cambridge-b2-first';
      pregunta(d, 0).remove('clase');
      final h = correr([d]);
      expect(errores(h, 'V09'), isEmpty);
      expect(avisos(h, 'V09').single.mensaje, contains('clase'));
    });
  });

  group('V10 · oraciones omitidas', () {
    List<Object?> oraciones(Doc d) => lista(pregunta(d, 0)['oraciones']);

    test('bueno', () => expect(de(correr([oracionOmitida()]), 'V10'), isEmpty));

    test('malo: una colocada sin ancla', () {
      final d = oracionOmitida();
      mapa(oraciones(d)[1]).remove('ancla');
      expect(errores(correr([d]), 'V10').single.mensaje, contains('oración colocada 2 debe llevar "ancla"'));
    });
    test('malo: una colocada con el ancla vacía', () {
      final d = oracionOmitida();
      mapa(oraciones(d)[0])['ancla'] = '   ';
      expect(errores(correr([d]), 'V10').single.mensaje, contains('ancla'));
    });
    test('malo: la sobrante sin porque_no', () {
      final d = oracionOmitida();
      mapa(oraciones(d)[3]).remove('porque_no');
      expect(errores(correr([d]), 'V10').single.mensaje, contains('sobrante 4 debe llevar "porque_no"'));
    });
    test('malo: una oración de menos (el contrato pide cuatro)', () {
      final d = oracionOmitida();
      oraciones(d).removeLast();
      final h = errores(correr([d]), 'V10').map((x) => x.mensaje).toList();
      expect(h, anyElement(contains('tiene 3 oraciones')));
      expect(h, anyElement(contains('0 oraciones sobrantes')));
    });
    test('malo: la sobrante pasa a ser colocada y hay cuatro huecos', () {
      final d = oracionOmitida();
      mapa(oraciones(d)[3])
        ..remove('sobrante')
        ..remove('porque_no')
        ..['hueco'] = 4
        ..['ancla'] = 'Cierra el texto con la idea del último párrafo.';
      expect(errores(correr([d]), 'V10').map((x) => x.mensaje), anyElement(contains('4 oraciones colocadas')));
    });
    test('malo: una colocada sin hueco', () {
      final d = oracionOmitida();
      mapa(oraciones(d)[2]).remove('hueco');
      expect(errores(correr([d]), 'V10').map((x) => x.mensaje), anyElement(contains('no dice a qué hueco')));
    });
    test('sin contrato solo se comprueban anclas y porque_no', () {
      final d = oracionOmitida()..['formato'] = 'no-existe';
      oraciones(d).removeLast();
      expect(errores(correr([d]), 'V10'), isEmpty);
    });
  });
}

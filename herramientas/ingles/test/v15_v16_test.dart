import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/ayudas_b.dart';
import 'apoyo/casos_b.dart';

void main() {
  group('V15 · palabras del estímulo dentro del rango del contrato', () {
    // El contrato de prueba pide de 20 a 40 palabras en `r-1`.
    test('bueno: 30 palabras, sin ningún hallazgo de ninguna comprobación', () {
      expect(propios(correrB([lectura('u-a', palabras: 30)])), isEmpty);
    });
    test('malo: 41 palabras es un aviso, no un error', () {
      final h = correrB([lectura('u-a', palabras: 41)]);
      expect(errores(h, 'V15'), isEmpty);
      final a = avisos(h, 'V15').single;
      expect(a.id, 'u-a');
      expect(a.mensaje, contains('tiene 41 palabras'));
      expect(a.mensaje, contains('"r-1" pide 20 a 40 (medido)'));
    });
    test('malo: 19 palabras, por debajo del mínimo', () {
      expect(avisos(correrB([lectura('u-a', palabras: 19)]), 'V15').single.mensaje, contains('tiene 19 palabras'));
    });
    test('los extremos valen: 20 y 40 palabras no dan aviso', () {
      expect(de(correrB([lectura('u-a', palabras: 20)]), 'V15'), isEmpty);
      expect(de(correrB([lectura('u-a', palabras: 40)]), 'V15'), isEmpty);
    });
    test('un aviso de longitud no impide el estado validado (V24)', () {
      final h = correrB([lectura('u-a', palabras: 41, estado: 'validado')]);
      expect(avisos(h, 'V15'), hasLength(1));
      expect(de(h, 'V24'), isEmpty);
    });

    test('bueno: un audio cuenta solo los turnos de habla (24 de 15 a 40)', () {
      expect(propios(correrB([audio('u-a', palabras: 24)])), isEmpty);
    });
    test('malo: 10 palabras de habla, aunque el narrador lleve el total al rango', () {
      final d = audio('u-a', palabras: 10);
      mapa(lista(mapa(d['estimulo'])['guion']).first)['texto'] = relleno(9, 25); // el narrador: 25 palabras
      final h = avisos(correrB([d]), 'V15');
      expect(h.single.mensaje, contains('tiene 10 palabras'));
    });

    test('bueno: transformaciones con originales de 8 palabras (de 5 a 12)', () {
      expect(propios(correrB([transformaciones('u-t', palabrasOriginal: 8)])), isEmpty);
    });
    test('malo: originales de 13 palabras, un aviso por oración y con el id de la pregunta', () {
      final h = avisos(correrB([transformaciones('u-t', palabrasOriginal: 13)]), 'V15');
      expect(h.map((x) => x.id), ['u-t-1', 'u-t-2', 'u-t-3']);
      expect(h.first.mensaje, contains('la oración original tiene 13 palabras'));
    });

    test('bueno: oraciones omitidas con el texto y las oraciones juntos (53 en un rango de 50 a 70)', () {
      final c = contratoCon('r-oo', (p) => p['palabras_estimulo'] = {'min': 50, 'max': 70, 'origen': 'medido'});
      expect(propios(correrB([omitidas('u-o')], contrato: c)), isEmpty);
    });
    test('malo: el mismo texto con el rango de 54 a 70', () {
      final c = contratoCon('r-oo', (p) => p['palabras_estimulo'] = {'min': 54, 'max': 70, 'origen': 'medido'});
      expect(avisos(correrB([omitidas('u-o')], contrato: c), 'V15').single.mensaje, contains('tiene 53 palabras'));
    });

    test('malo: una parte pendiente da aviso de "rango pendiente" aunque la cifra quepa', () {
      final c = contratoCon('r-1', (p) => p['pendiente'] = true);
      final h = correrB([lectura('u-a', palabras: 30)], contrato: c);
      final a = avisos(h, 'V15').single;
      expect(a.mensaje, startsWith('rango pendiente'));
      expect(a.mensaje, contains('tiene 30 palabras'));
      expect(a.mensaje, contains('rango provisional: 20 a 40'));
      expect(errores(h, 'V15'), isEmpty);
    });
    test('una parte pendiente da un solo aviso, también con la cifra fuera del rango provisional', () {
      final c = contratoCon('r-1', (p) => p['pendiente'] = true);
      expect(avisos(correrB([lectura('u-a', palabras: 90)], contrato: c), 'V15'), hasLength(1));
    });
    test('una parte pendiente sin rango dice solo que está pendiente', () {
      final c = contratoCon('r-1', (p) {
        p['pendiente'] = true;
        p.remove('palabras_estimulo');
      });
      final a = avisos(correrB([lectura('u-a', palabras: 30)], contrato: c), 'V15').single;
      expect(a.mensaje, contains('tiene 30 palabras'));
      expect(a.mensaje, isNot(contains('provisional')));
    });
    test('bueno: una parte sin rango de palabras no comprueba nada', () {
      final c = contratoCon('r-1', (p) => p.remove('palabras_estimulo'));
      expect(de(correrB([lectura('u-a', palabras: 300)], contrato: c), 'V15'), isEmpty);
    });
    test('bueno: sin contrato no dice nada (V02 ya avisa "sin contrato")', () {
      final d = lectura('u-a', palabras: 300, formato: 'no-existe');
      final h = correrB([d]);
      expect(de(h, 'V15'), isEmpty);
      expect(avisos(h, 'V02').single.mensaje, contains('sin contrato'));
    });
    test('una consigna se mide como un texto (los contratos de escritura traen su rango)', () {
      Doc consigna(int n) => lectura('u-a')..['estimulo'] = {'tipo': 'consigna', 'texto': relleno(1, n)};
      expect(propios(correrB([consigna(30)])), isEmpty);
      expect(avisos(correrB([consigna(41)]), 'V15').single.mensaje, contains('tiene 41 palabras'));
    });
    test('un estímulo de imagen no tiene longitud que comprobar', () {
      final d = lectura('u-a');
      d['estimulo'] = {'tipo': 'imagen', 'descripcion': 'A photo of a bridge.'};
      expect(de(correrB([d]), 'V15'), isEmpty);
    });
  });

  group('V16 · estímulo de audio', () {
    test('bueno: dos reproducciones, como el contrato, y voces de la lista', () {
      final d = audio('u-a', guion: [
        {'voz': 'N', 'texto': 'You will hear a short talk.'},
        {'voz': 'F1', 'texto': relleno(1, 6)},
        {'voz': 'M1', 'texto': relleno(2, 6)},
        {'voz': 'F2', 'texto': relleno(3, 6)},
        {'voz': 'M2', 'texto': relleno(4, 6)},
      ]);
      expect(propios(correrB([d])), isEmpty);
    });
    test('malo: una reproducción donde el contrato pide dos', () {
      final h = errores(correrB([audio('u-a', reproducciones: 1)]), 'V16');
      expect(h.single.mensaje, contains('reproducciones: 1'));
      expect(h.single.mensaje, contains('"l-1" pide 2'));
    });
    test('malo: tres reproducciones', () {
      expect(errores(correrB([audio('u-a', reproducciones: 3)]), 'V16'), hasLength(1));
    });
    test('malo: una voz que no está en la lista', () {
      final d = audio('u-a');
      mapa(lista(mapa(d['estimulo'])['guion'])[1])['voz'] = 'X9';
      final h = correrB([d]);
      expect(errores(h, 'V16').single.mensaje, contains('X9'));
      // La lectura también la rechaza como valor fuera de una lista (V01).
      expect(errores(h, 'V01'), isNotEmpty);
    });
    test('malo: una voz mal escrita se dice una sola vez por audio, aunque la repita', () {
      final d = audio('u-a');
      for (final t in lista(mapa(d['estimulo'])['guion'])) {
        mapa(t)['voz'] = 'X9';
      }
      expect(errores(correrB([d]), 'V16'), hasLength(1));
    });
    test('bueno: si la parte no declara reproducciones, no se comparan', () {
      final c = contratoCon('l-1', (p) => p.remove('reproducciones'));
      expect(errores(correrB([audio('u-a', reproducciones: 5)], contrato: c), 'V16'), isEmpty);
    });
    test('bueno: sin contrato no se comparan las reproducciones', () {
      final d = audio('u-a', reproducciones: 5, formato: 'no-existe');
      expect(errores(correrB([d]), 'V16'), isEmpty);
    });
    test('un texto no es un audio: V16 no lo toca', () {
      expect(de(correrB([lectura('u-a')]), 'V16'), isEmpty);
    });
  });
}

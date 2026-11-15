import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/casos.dart';

List<Object?> opcionesDe(Doc d, int i) => lista(mapa(lista(d['preguntas'])[i])['opciones']);

void main() {
  group('V03 · opciones', () {
    test('bueno: cuatro opciones, como pide el contrato', () {
      expect(de(correr([opcionMultiple()]), 'V03'), isEmpty);
    });
    test('malo: tres opciones donde el contrato pide cuatro', () {
      final d = opcionMultiple();
      opcionesDe(d, 0).removeLast();
      final h = errores(correr([d]), 'V03');
      expect(h.single.id, 't-om-0001-a');
      expect(h.single.mensaje, contains('3 opciones'));
      expect(h.single.mensaje, contains('pide 4'));
    });
    test('malo: cinco opciones', () {
      final d = opcionMultiple();
      opcionesDe(d, 1).add({'texto': 'Never.', 'porque_no': 'No.'});
      expect(errores(correr([d]), 'V03').single.mensaje, contains('5 opciones'));
    });
    test('malo: dos opciones iguales sin contar mayúsculas ni puntuación', () {
      final d = opcionMultiple();
      mapa(opcionesDe(d, 0)[2])['texto'] = 'repairs COST too much';
      final h = errores(correr([d]), 'V03');
      expect(h.single.mensaje, contains('A y C son iguales'));
    });
    test('malo: el hueco de opciones también cuenta', () {
      final d = huecoOpciones();
      lista(mapa(lista(d['preguntas']).first)['opciones']).removeLast();
      expect(errores(correr([d]), 'V03').single.id, 't-ho-0001-1');
    });
    test('bueno: una parte con opciones pendientes no decide nada', () {
      final d = opcionMultiple()..['parte'] = 'p-om-pendiente';
      lista(mapa(lista(d['preguntas']).first)['opciones']).removeLast();
      expect(errores(correr([d]), 'V03'), isEmpty);
    });
    test('sin contrato se esperan 3 o 4: bueno con 3', () {
      final d = opcionMultiple()..['formato'] = 'no-existe';
      opcionesDe(d, 0).removeLast();
      expect(errores(correr([d]), 'V03'), isEmpty);
    });
    test('sin contrato se esperan 3 o 4: malo con 2', () {
      final d = opcionMultiple()..['formato'] = 'no-existe';
      opcionesDe(d, 0).removeRange(2, 4);
      expect(errores(correr([d]), 'V03').single.mensaje, contains('3 o 4'));
    });
    test('en una sesión sin contrato, 3 opciones valen y 2 no', () {
      expect(errores(correr(sesionConAudio()), 'V03'), isEmpty);
      final d = sesion();
      final q = mapa(lista(mapa(lista(d['bloques'])[1])['preguntas']).first);
      lista(q['opciones']).removeLast();
      expect(errores(correr([d, completarNota()]), 'V03').single.mensaje, contains('3 o 4'));
    });
    test('emparejar: las opciones de la unidad deben ser las del contrato', () {
      final d = emparejar();
      lista(d['opciones']).removeLast();
      final h = errores(correr([d]), 'V03');
      expect(h.single.mensaje, contains('4 opciones'));
      expect(h.single.mensaje, contains('pide 5'));
    });
    test('emparejar: dos opciones de la unidad iguales', () {
      final d = emparejar();
      mapa(lista(d['opciones'])[1])['texto'] = 'text a';
      expect(errores(correr([d]), 'V03').single.mensaje, contains('son iguales'));
    });
    test('correspondencia: los textos de la unidad deben ser los del contrato', () {
      final d = correspondencia();
      lista(d['textos']).removeLast();
      expect(errores(correr([d]), 'V03').single.mensaje, contains('3 textos'));
    });
  });

  group('V04 · una sola correcta', () {
    test('bueno', () => expect(de(correr([opcionMultiple(), huecoAbierto()]), 'V04'), isEmpty));

    test('malo: la primera opción no lleva porque', () {
      final d = opcionMultiple();
      mapa(opcionesDe(d, 0).first).remove('porque');
      expect(errores(correr([d]), 'V04').single.mensaje, contains('primera opción'));
    });
    test('malo: otra opción lleva porque (segunda correcta)', () {
      final d = opcionMultiple();
      mapa(opcionesDe(d, 0)[1])['porque'] = 'También encaja con el texto del párrafo.';
      expect(errores(correr([d]), 'V04').single.mensaje, contains('opción B lleva "porque"'));
    });
    test('malo: hueco abierto con aceptadas vacía', () {
      final d = huecoAbierto();
      mapa(lista(d['preguntas']).first)['aceptadas'] = <Object?>[];
      expect(errores(correr([d]), 'V04').single.id, 't-ha-0001-1');
    });
    test('malo: transformación con aceptadas vacía', () {
      final d = transformacion();
      mapa(lista(d['preguntas']).first)['aceptadas'] = <Object?>[];
      expect(errores(correr([d]), 'V04').single.id, 't-tr-0001-1');
    });
    test('malo: ordenar palabras con aceptadas vacía', () {
      final d = variadas();
      mapa(lista(d['preguntas']).first)['aceptadas'] = <Object?>[];
      expect(errores(correr([d]), 'V04').single.id, 't-var-0001-a');
    });
    test('malo: completar nota con aceptadas vacía', () {
      final d = completarNota();
      mapa(lista(d['preguntas']).first)['aceptadas'] = <Object?>[];
      expect(errores(correr([d]), 'V04').single.id, 't-cn-0001-1');
    });
  });

  group('V05 · la correcta no es siempre la más larga', () {
    test('bueno: la correcta es la más larga en 1 de 8', () {
      expect(de(correr([ochoPreguntas()]), 'V05'), isEmpty);
    });
    test('malo: la correcta es la más larga en 5 de 8 (aviso, no error)', () {
      final h = correr([ochoPreguntas(masLargas: 5)]);
      expect(errores(h, 'V05'), isEmpty);
      expect(avisos(h, 'V05').single.mensaje, contains('5 de 8'));
    });
    test('límite: 4 de 8 no es menos de la mitad (avisa); 3 de 8 sí', () {
      expect(avisos(correr([ochoPreguntas(masLargas: 4)]), 'V05'), hasLength(1));
      expect(avisos(correr([ochoPreguntas(masLargas: 3)]), 'V05'), isEmpty);
    });
    test('bueno: con menos de 8 preguntas no se mide', () {
      final d = ochoPreguntas(masLargas: 7);
      lista(d['preguntas']).removeLast();
      expect(de(correr([d]), 'V05'), isEmpty);
    });
    test('la parte se mide juntando unidades: el aviso sale una vez', () {
      final a = ochoPreguntas(masLargas: 8);
      final b = ochoPreguntas(masLargas: 8)..['id'] = 't-om8-0002';
      for (final q in lista(b['preguntas'])) {
        final m = mapa(q);
        m['id'] = (m['id']! as String).replaceFirst('t-om8-0001', 't-om8-0002');
      }
      expect(avisos(correr([a, b]), 'V05'), hasLength(1));
    });
  });
}

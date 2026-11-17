import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/curso.dart';

List<String> _err(List<Doc> docs, {Doc? sesion, Doc? niveles}) => [
      for (final h in correrCurso(docs, sesion: sesion, niveles: niveles))
        if (h.codigo == 'V28' && h.esError && h.archivo.startsWith('doc')) h.mensaje,
    ];

List<String> _avi(List<Doc> docs) => [
      for (final h in correrCurso(docs))
        if (h.codigo == 'V28' && !h.esError && h.archivo.startsWith('doc')) h.mensaje,
    ];

/// Una prueba por unidad sola, con su escalón de prueba.
List<Doc> _pu({int unidad = 1, String variante = 'a', bool conAudio = true}) => formaPruebaUnidad('A2.1', unidad, variante, conAudio: conAudio);

/// Las 8 pruebas por unidad y las 7 mini pruebas de un escalón.
List<Doc> _escalonCompleto() => [
      for (var u = 1; u <= 4; u++) for (final v in ['a', 'b']) ...formaPruebaUnidad('A2.1', u, v),
      for (var s = 1; s <= 7; s++) ...formaMini('A2.1', s),
    ];

void main() {
  group('V28 · casos buenos', () {
    test('una prueba por unidad con audio (6 + 4 + 5 + 5) y una sin audio (15)', () {
      expect(_err(_pu()), isEmpty);
      expect(_err(_pu(conAudio: false)), isEmpty);
    });
    test('una mini prueba de diez preguntas', () {
      expect(_err(formaMini('A2.1', 3)), isEmpty);
    });
    test('un escalón con sus 8 pruebas y 7 mini pruebas: ningún error ni aviso de V28', () {
      final docs = _escalonCompleto();
      expect(_err(docs), isEmpty);
      expect(_avi(docs), isEmpty);
    });
    test('las unidades sin errores de ninguna otra comprobación (V02, V03, V12...)', () {
      final h = propios(correrCurso(_escalonCompleto())).where((x) => x.esError);
      expect(h, isEmpty, reason: h.join('\n'));
    });
  });

  group('V28 · la prueba por unidad', () {
    test('malo: diecinueve preguntas con audio', () {
      final docs = _pu();
      lista(unidadDe(docs, 'pu-a21-u1-a-lec')['preguntas']).removeLast();
      final e = _err(docs);
      expect(e, contains('la prueba con audio trae 19 preguntas y el contrato pide 20'));
      expect(e, contains('trae 4 preguntas de lectura y la composición del contrato pide 5'));
    });
    test('malo: la composición es 7 de gramática y 3 de vocabulario', () {
      final docs = _pu();
      final voc = unidadDe(docs, 'pu-a21-u1-a-voc');
      final mover = mapa(lista(voc['preguntas']).removeLast());
      mover['habilidad'] = 'gramatica';
      lista(unidadDe(docs, 'pu-a21-u1-a-gram')['preguntas']).add(mover);
      final e = _err(docs);
      expect(e, contains('trae 7 preguntas de gramatica y la composición del contrato pide 6'));
      expect(e, contains('trae 3 preguntas de vocabulario y la composición del contrato pide 4'));
    });
    test('malo: una habilidad que no está en la composición', () {
      final docs = _pu();
      mapa(lista(unidadDe(docs, 'pu-a21-u1-a-voc')['preguntas']).first)['habilidad'] = 'escritura';
      expect(_err(docs), anyElement(contains('trae 1 preguntas de escritura, que no está en la composición del contrato')));
    });
    test('malo: sin audio con quince preguntas, pero declarando con_audio', () {
      final docs = _pu(conAudio: false);
      formaDe(docs, 'pu-a21-u1-a')['con_audio'] = true;
      final e = _err(docs);
      expect(e, contains('con_audio es true y ninguna unidad trae audio'));
      expect(e, contains('la prueba con audio trae 15 preguntas y el contrato pide 20'));
    });
    test('malo: con_audio es false y una unidad trae audio', () {
      final docs = _pu();
      formaDe(docs, 'pu-a21-u1-a')['con_audio'] = false;
      final e = _err(docs);
      expect(e, anyElement(contains('con_audio es false y la unidad "pu-a21-u1-a-esc" trae audio')));
      expect(e, anyElement(contains('la prueba sin audio trae 20 preguntas y el contrato pide 15')));
    });
    test('malo: el audio se oye una vez y el contrato pide dos', () {
      final docs = _pu();
      mapa(unidadDe(docs, 'pu-a21-u1-a-esc')['estimulo'])['reproducciones'] = 1;
      expect(_err(docs), contains('el audio de "pu-a21-u1-a-esc" se oye 1 veces y el contrato pide 2'));
    });
    test('malo: una pregunta de escucha en una unidad sin audio', () {
      final docs = _pu();
      mapa(lista(unidadDe(docs, 'pu-a21-u1-a-lec')['preguntas']).first)['habilidad'] = 'escucha';
      expect(_err(docs), anyElement(contains('la pregunta es de escucha y su unidad no tiene audio')));
    });
    test('malo: faltan unidad_del_escalon, variante y con_audio', () {
      final docs = _pu();
      final f = formaDe(docs, 'pu-a21-u1-a');
      f.remove('unidad_del_escalon');
      f.remove('variante');
      f.remove('con_audio');
      final e = _err(docs);
      expect(e, containsAll(['falta "unidad_del_escalon"', 'falta "variante" (a o b)', 'falta "con_audio"']));
    });
    test('malo: la unidad 5 no existe (el escalón tiene cuatro)', () {
      final docs = _pu();
      formaDe(docs, 'pu-a21-u1-a')['unidad_del_escalon'] = 5;
      expect(_err(docs), anyElement(contains('unidad_del_escalon 5 está fuera de 1 a 4')));
    });
    test('malo: el id no dice la misma unidad, variante ni escalón que los campos', () {
      final docs = _pu();
      final f = formaDe(docs, 'pu-a21-u1-a');
      f['unidad_del_escalon'] = 2;
      f['variante'] = 'b';
      f['escalon'] = 'A2.2';
      final e = _err(docs);
      expect(e, anyElement(contains('el id "pu-a21-u1-a" no es del escalón A2.2')));
      expect(e, anyElement(contains('dice la unidad 1 y unidad_del_escalon es 2')));
      expect(e, anyElement(contains('dice la variante a y variante es b')));
    });
    test('malo: un id que no sigue el patrón', () {
      final docs = _pu();
      final f = formaDe(docs, 'pu-a21-u1-a');
      f['id'] = 'prueba-uno';
      expect(_err(docs), anyElement(contains('el id de una prueba por unidad es pu-<escalón>-u<N>-<a|b>, no "prueba-uno"')));
    });
    test('malo: la sección es de otra parte', () {
      final docs = _pu();
      mapa(lista(formaDe(docs, 'pu-a21-u1-a')['secciones']).first)['parte'] = 'mini';
      expect(_err(docs), anyElement(contains('la sección es de la parte "mini" y debe ser "prueba-unidad"')));
    });
    test('malo: una forma de otro formato', () {
      final docs = _pu();
      formaDe(docs, 'pu-a21-u1-a')['formato'] = 'gravity-escalon';
      expect(_err(docs), anyElement(contains('es del formato gravity-sesion-60, no de "gravity-escalon"')));
    });
    test('malo: un escalón que no existe en niveles.yaml, y una forma sin escalón', () {
      var docs = _pu();
      formaDe(docs, 'pu-a21-u1-a')['escalon'] = 'A9.9';
      expect(_err(docs), anyElement(contains('el escalón "A9.9" no está en niveles.yaml')));
      docs = _pu();
      formaDe(docs, 'pu-a21-u1-a').remove('escalon');
      expect(_err(docs), anyElement(contains('falta "escalon"')));
    });
    test('malo: un tipo de pregunta que exige juicio humano (producción) y otro que no está permitido (ordenar palabras)', () {
      final docs = _pu();
      final qs = lista(unidadDe(docs, 'pu-a21-u1-a-gram')['preguntas']);
      qs[0] = {
        'id': 'pu-a21-u1-a-gram-01',
        'tipo': 'ordenar_palabras',
        'habilidad': 'gramatica',
        'palabras': ['do', 'you', 'work'],
        'aceptadas': ['do you work'],
        'porque': 'La pregunta en presente simple empieza con el auxiliar.',
      };
      expect(_err(docs).first, contains('es de tipo ordenar_palabras y estas pruebas solo admiten opcion_multiple y respuesta_corta'));
    });
    test('bueno: la respuesta corta objetiva sí se admite', () {
      final docs = _pu();
      final qs = lista(unidadDe(docs, 'pu-a21-u1-a-gram')['preguntas']);
      qs[0] = preguntaCorta('pu-a21-u1-a-gram-01', 'gramatica', 'xyz');
      expect(_err(docs), isEmpty);
    });
    test('malo: un tema que no es del temario del escalón', () {
      final docs = _pu();
      unidadDe(docs, 'pu-a21-u1-a-gram')['temas'] = ['gram.condicional_segunda'];
      expect(_err(docs).single, contains('el tema gram.condicional_segunda de la unidad "pu-a21-u1-a-gram" no es del temario de A2.1'));
    });
    test('bueno: un tema que el escalón retoma del anterior sí lo es', () {
      final docs = _pu();
      unidadDe(docs, 'pu-a21-u1-a-gram')['temas'] = ['gram.verbo_to_be'];
      expect(_err(docs), isEmpty);
    });
    test('malo: una unidad retirada', () {
      final docs = _pu();
      unidadDe(docs, 'pu-a21-u1-a-voc')['estado'] = 'retirado';
      expect(_err(docs), anyElement(contains('la unidad "pu-a21-u1-a-voc" está retirada')));
    });
    test('malo: una forma con dos secciones', () {
      final docs = _pu();
      lista(formaDe(docs, 'pu-a21-u1-a')['secciones']).add({'parte': 'prueba-unidad', 'unidades': <String>[]});
      expect(_err(docs), anyElement(contains('la forma trae 2 secciones y debe traer una')));
    });
    test('malo: los umbrales no los pone la forma: el 80 % es del contrato (V27 los contrasta)', () {
      // Cambiar el umbral del contrato sin cambiar el de la puerta es un error de V27.
      final c = contratoSesionConPruebas();
      mapa(mapa(c['viernes'])['prueba_por_unidad'])['umbral_porcentaje'] = 70;
      final h = correrCurso([], sesion: c).where((x) => x.codigo == 'V27' && x.esError);
      expect(h.map((x) => x.mensaje), anyElement(contains('el umbral de la prueba por unidad y el mínimo por habilidad de la puerta: 70 y 80 no coinciden')));
    });
    test('las cifras salen del contrato: con 18 preguntas con audio y otra composición, la misma forma falla', () {
      final c = contratoSesionConPruebas();
      mapa(mapa(mapa(c['viernes'])['prueba_por_unidad'])['preguntas'])['con_audio'] = 21;
      expect(_err(_pu(), sesion: c), contains('la prueba con audio trae 20 preguntas y el contrato pide 21'));
    });
  });

  group('V28 · la mini prueba', () {
    test('malo: nueve preguntas', () {
      final docs = formaMini('A2.1', 3);
      lista(unidadDe(docs, 'mini-a21-s03-u')['preguntas']).removeLast();
      expect(_err(docs), contains('la mini prueba trae 9 preguntas y el contrato pide 10'));
    });
    test('malo: once preguntas', () {
      expect(_err(formaMini('A2.1', 3, preguntas: 11)), contains('la mini prueba trae 11 preguntas y el contrato pide 10'));
    });
    test('malo: una pregunta de lectura (la mini prueba es de gramática y vocabulario)', () {
      final docs = formaMini('A2.1', 3);
      mapa(lista(unidadDe(docs, 'mini-a21-s03-u')['preguntas']).first)['habilidad'] = 'lectura';
      expect(_err(docs).single, 'la mini prueba es de gramática y vocabulario y esta pregunta es de lectura');
    });
    test('malo: la semana 8 no lleva mini prueba', () {
      expect(_err(formaMini('A2.1', 8)), anyElement(contains('la semana 8 no lleva mini prueba (el contrato la pone en las semanas 1, 2, 3, 4, 5, 6, 7)')));
    });
    test('malo: un id que no sigue el patrón, y un id de otro escalón', () {
      var docs = formaMini('A2.1', 3);
      formaDe(docs, 'mini-a21-s03')['id'] = 'mini-tres';
      expect(_err(docs), anyElement(contains('el id de una mini prueba es mini-<escalón>-s<NN>, no "mini-tres"')));
      docs = formaMini('A2.1', 3);
      formaDe(docs, 'mini-a21-s03')['id'] = 'mini-b11-s03';
      expect(_err(docs), anyElement(contains('el id "mini-b11-s03" no es del escalón A2.1 (mini-a21-s<NN>)')));
    });
    test('malo: una mini prueba con audio', () {
      final docs = formaMini('A2.1', 3);
      unidadDe(docs, 'mini-a21-s03-u')['estimulo'] = {
        'tipo': 'audio',
        'reproducciones': 2,
        'guion': [
          {'voz': 'F1', 'texto': palabras('x', 20)}
        ],
      };
      expect(_err(docs), anyElement(contains('la mini prueba no lleva audio: la unidad "mini-a21-s03-u" lo trae')));
    });
  });

  group('V28 · entre formas del mismo escalón', () {
    test('malo: la forma b comparte una unidad con la a', () {
      final a = _pu();
      final b = _pu(variante: 'b');
      mapa(lista(formaDe(b, 'pu-a21-u1-b')['secciones']).first)['unidades'] = [
        'pu-a21-u1-a-gram', // la misma unidad de la a
        'pu-a21-u1-b-voc',
        'pu-a21-u1-b-lec',
        'pu-a21-u1-b-esc',
      ];
      final e = _err(juntar([a, b]));
      expect(e, anyElement(contains('la forma b comparte con la a ("pu-a21-u1-a"): la unidad "pu-a21-u1-a-gram"')));
    });
    test('malo: la forma b repite un enunciado de la a', () {
      final a = _pu();
      final b = _pu(variante: 'b');
      final enunciadoA = mapa(lista(unidadDe(a, 'pu-a21-u1-a-voc')['preguntas']).first)['enunciado'];
      mapa(lista(unidadDe(b, 'pu-a21-u1-b-voc')['preguntas']).first)['enunciado'] = enunciadoA;
      final e = _err(juntar([a, b]));
      expect(e, anyElement(contains('la forma b comparte con la a ("pu-a21-u1-a")')));
    });
    test('malo: la forma b repite el texto de lectura de la a', () {
      final a = _pu();
      final b = _pu(variante: 'b');
      unidadDe(b, 'pu-a21-u1-b-lec')['estimulo'] = clonar(mapa(unidadDe(a, 'pu-a21-u1-a-lec')['estimulo']));
      final e = _err(juntar([a, b]));
      expect(e, anyElement(contains('la forma b comparte con la a')));
    });
    test('malo: una mini prueba repite una pregunta de una prueba por unidad', () {
      final a = _pu();
      final m = formaMini('A2.1', 3);
      final enunciado = mapa(lista(unidadDe(a, 'pu-a21-u1-a-gram')['preguntas']).first)['enunciado'];
      mapa(lista(unidadDe(m, 'mini-a21-s03-u')['preguntas']).first)['enunciado'] = enunciado;
      final e = _err(juntar([a, m]));
      expect(e, anyElement(contains('la mini prueba repite contenido de la prueba "pu-a21-u1-a"')));
    });
    test('malo: dos formas en la misma unidad y variante del escalón', () {
      final a = _pu();
      final otra = formaPruebaUnidad('A2.1', 1, 'a', sello: 'otra');
      for (final d in otra) {
        d['id'] = (d['id']! as String).replaceFirst('pu-a21-u1-a', 'pu-a21-u1-a2');
      }
      // La forma duplicada conserva el id de sus unidades con el prefijo nuevo.
      for (final d in otra.where((d) => d['tipo'] == 'forma')) {
        mapa(lista(d['secciones']).first)['unidades'] = [for (final u in lista(mapa(lista(d['secciones']).first)['unidades'])) (u! as String).replaceFirst('pu-a21-u1-a', 'pu-a21-u1-a2')];
      }
      final e = _err(juntar([a, otra]));
      expect(e, anyElement(contains('ocupa la misma unidad (1) y variante (a) del escalón A2.1')));
    });
    test('malo (aviso): un escalón al que le faltan pruebas y mini pruebas dice cuáles', () {
      final docs = [..._pu(), ..._pu(variante: 'b'), ...formaMini('A2.1', 1)];
      final a = _avi(docs);
      expect(a, hasLength(1));
      expect(a.single, contains('el escalón A2.1 tiene 2 de 8 pruebas por unidad y 1 de 7 mini pruebas'));
      expect(a.single, contains('pu-a21-u2-a'));
      expect(a.single, contains('mini-a21-s07'));
      expect(a.single, isNot(contains('pu-a21-u1-a,')));
    });
    test('quitar una mini prueba de un escalón completo se nota', () {
      final docs = _escalonCompleto()..removeWhere((d) => d['id'] == 'mini-a21-s05' || d['id'] == 'mini-a21-s05-u');
      final a = _avi(docs);
      expect(a.single, contains('y 6 de 7 mini pruebas'));
      expect(a.single, contains('faltan: mini-a21-s05'));
    });
    test('las formas de otro escalón no se mezclan', () {
      final docs = [..._pu(), ...formaPruebaUnidad('A2.2', 1, 'a')];
      final a = _avi(docs);
      expect(a, hasLength(2), reason: 'un aviso por escalón');
    });
  });

  group('V28 · cuando no hay contrato o niveles', () {
    test('sin el contrato gravity-sesion-60, V28 calla (V02 dice "sin contrato")', () {
      final archivos = <Archivo>[for (var i = 0; i < _pu().length; i++) leerMapa('doc$i.yaml', clonar(_pu()[i]))];
      final h = validarArchivos(archivos).hallazgos;
      expect(h.where((x) => x.codigo == 'V28'), isEmpty);
      expect(h.where((x) => x.codigo == 'V02'), isNotEmpty);
    });
  });
}

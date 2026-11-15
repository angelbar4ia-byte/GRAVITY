import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/casos.dart';

Doc pregunta(Doc d, int i) => mapa(lista(d['preguntas'])[i]);

/// Cambia una palabra de `completar_palabras`: el texto y su pista a la vez.
Doc conPalabra(String ocultaAntes, String nuevoTexto, String palabraAntes, String palabraNueva) {
  final d = completarPalabras();
  final e = mapa(d['estimulo']);
  e['texto'] = (e['texto']! as String).replaceFirst(ocultaAntes, nuevoTexto);
  final pistas = lista(mapa(lista(d['preguntas']).first)['pistas']);
  for (final p in pistas) {
    final m = mapa(p);
    if (m['palabra'] == palabraAntes) m['palabra'] = palabraNueva;
  }
  return d;
}

void main() {
  group('V11 · correspondencia y emparejar', () {
    test('bueno', () => expect(de(correr([correspondencia(), emparejar()]), 'V11'), isEmpty));

    test('malo: la respuesta apunta a un texto que no existe', () {
      final d = correspondencia();
      pregunta(d, 0)['respuesta'] = 'Z';
      expect(errores(correr([d]), 'V11').single.mensaje, contains('"Z" no es un texto'));
    });
    test('malo: falta la evidencia', () {
      final d = correspondencia();
      pregunta(d, 2).remove('evidencia');
      final h = errores(correr([d]), 'V11');
      expect(h.single.id, 't-co-0001-3');
      expect(h.single.mensaje, contains('evidencia'));
    });
    test('malo: emparejar apunta a una opción que no existe', () {
      final d = emparejar();
      pregunta(d, 1)['respuesta'] = 'Q';
      expect(errores(correr([d]), 'V11').map((x) => x.mensaje), anyElement(contains('"Q" no es un opción')));
    });
    test('malo: una opción sobrante sin porque_no', () {
      final d = emparejar();
      mapa(lista(d['opciones'])[3]).remove('porque_no');
      expect(errores(correr([d]), 'V11').single.mensaje, contains('sobrante "D"'));
    });
    test('malo: un texto concentra más de la mitad de las respuestas (aviso)', () {
      final d = emparejar();
      pregunta(d, 1)['respuesta'] = 'A';
      final h = correr([d]);
      expect(avisos(h, 'V11').single.mensaje, contains('"A" concentra 2 de 3'));
    });
    test('bueno: la mitad exacta no es más de la mitad', () {
      final d = correspondencia();
      pregunta(d, 1)['respuesta'] = 'A';
      expect(avisos(correr([d]), 'V11'), isEmpty);
    });
    test('malo: preguntas de correspondencia sin la lista de textos', () {
      final d = correspondencia()..remove('textos');
      expect(errores(correr([d]), 'V11').single.mensaje, contains('no los lista'));
    });
  });

  group('V12 · porque', () {
    test('bueno', () => expect(de(correr([opcionMultiple(), huecoAbierto(), sesion()]), 'V12'), isEmpty));

    test('malo: porque de cinco palabras en la opción correcta', () {
      final d = opcionMultiple();
      mapa(lista(mapa(lista(d['preguntas']).first)['opciones']).first)['porque'] = 'Cinco palabras en total aquí.';
      expect(errores(correr([d]), 'V12').single.mensaje, contains('5 palabras'));
    });
    test('malo: hueco abierto sin porque', () {
      final d = huecoAbierto();
      pregunta(d, 0).remove('porque');
      expect(errores(correr([d]), 'V12').single.mensaje, contains('falta "porque"'));
    });
    test('malo: transformación con porque corto', () {
      final d = transformacion();
      pregunta(d, 0)['porque'] = 'Superlativo.';
      expect(errores(correr([d]), 'V12').single.mensaje, contains('1 palabras'));
    });
    test('malo: completar palabras con porque corto', () {
      final d = completarPalabras();
      pregunta(d, 0)['porque'] = 'Se deduce.';
      expect(errores(correr([d]), 'V12').single.id, 't-cp-0001-a');
    });
    test('malo: oración omitida sin porque', () {
      final d = oracionOmitida();
      pregunta(d, 0).remove('porque');
      expect(errores(correr([d]), 'V12').single.mensaje, contains('falta'));
    });
    test('la evidencia sirve de razón en correspondencia', () {
      final d = correspondencia();
      pregunta(d, 0).remove('porque');
      expect(errores(correr([d]), 'V12'), isEmpty);
      pregunta(d, 0)['evidencia'] = 'Dos palabras.';
      expect(errores(correr([d]), 'V12').single.mensaje, contains('2 palabras'));
    });
    test('las preguntas de producción y repetir no llevan porque', () {
      expect(errores(correr([variadas()]), 'V12'), isEmpty);
    });
    test('malo: en el curso, un distractor sin porque_no', () {
      final d = sesion();
      final q = mapa(lista(mapa(lista(d['bloques'])[1])['preguntas']).first);
      mapa(lista(q['opciones'])[2]).remove('porque_no');
      final h = errores(correr([d, completarNota()]), 'V12');
      expect(h.single.mensaje, contains('opción C debe llevar "porque_no"'));
    });
    test('en un examen el distractor sin porque_no se admite', () {
      final d = opcionMultiple();
      mapa(lista(mapa(lista(d['preguntas']).first)['opciones'])[2]).remove('porque_no');
      expect(errores(correr([d]), 'V12'), isEmpty);
    });
  });

  group('V13 · niveles', () {
    test('bueno', () => expect(de(correr([opcionMultiple(), ...sesionConAudio()]), 'V13'), isEmpty));

    test('malo: habilidad que no está en niveles.yaml', () {
      final d = opcionMultiple();
      pregunta(d, 0)['habilidad'] = 'baile';
      expect(errores(correr([d]), 'V13').single.mensaje, contains('la habilidad "baile"'));
    });
    test('malo: foco que no está en niveles.yaml', () {
      final d = opcionMultiple();
      pregunta(d, 1)['foco'] = 'adivinar';
      final h = errores(correr([d]), 'V13');
      expect(h.single.id, 't-om-0001-b');
      expect(h.single.mensaje, contains('el foco "adivinar"'));
    });
    test('malo: tema que no está en niveles.yaml', () {
      final d = opcionMultiple()..['temas'] = ['gram.futuro_perfecto'];
      expect(errores(correr([d]), 'V13').single.mensaje, contains('el tema'));
    });
    test('malo: temas de una sesión', () {
      final d = sesion()..['temas'] = ['gram.otro'];
      expect(errores(correr([d, completarNota()]), 'V13').single.mensaje, contains('el tema'));
    });
    test('malo: escalón que no está en niveles.yaml', () {
      final d = sesion()..['escalon'] = 'B9.9';
      expect(errores(correr([d, completarNota()]), 'V13').single.mensaje, contains('el escalón'));
    });
    test('el foco de pronunciación es texto libre', () {
      expect(errores(correr([variadas()]), 'V13'), isEmpty);
    });
    test('malo: sin niveles.yaml es aviso en borrador', () {
      final h = correr([opcionMultiple()], niveles: false);
      expect(errores(h, 'V13'), isEmpty);
      expect(avisos(h, 'V13').single.mensaje, contains('sin niveles'));
    });
    test('malo: sin niveles.yaml es error en validado', () {
      final d = opcionMultiple()..['estado'] = 'validado';
      final h = correr([d], niveles: false);
      expect(errores(h, 'V13').single.mensaje, contains('sin niveles'));
    });
  });

  group('V14 · completar palabras', () {
    test('bueno', () => expect(de(correr([completarPalabras()]), 'V14'), isEmpty));

    test('malo: oculta menos de la segunda mitad', () {
      final d = conPalabra('la{yer}', 'lay{er}', 'layer', 'layer');
      final h = errores(correr([d]), 'V14');
      expect(h.single.mensaje, contains('oculta 2 letras y la segunda mitad de 5 son 3'));
    });
    test('malo: oculta más de la segunda mitad', () {
      final d = conPalabra('se{en}', 's{een}', 'seen', 'seen');
      expect(errores(correr([d]), 'V14').single.mensaje, contains('oculta 3 letras'));
    });
    test('malo: una palabra de dos letras oculta una sola', () {
      final d = conPalabra('la{yer}', 'i{s}', 'layer', 'is');
      expect(errores(correr([d]), 'V14').map((x) => x.mensaje), anyElement(contains('deben ser de 2 a 8')));
    });
    test('malo: una palabra que oculta más de 8 letras', () {
      final d = conPalabra('la{yer}', 'telecommu{nications}', 'layer', 'telecommunications');
      expect(errores(correr([d]), 'V14').map((x) => x.mensaje), anyElement(contains('oculta 9 letras y deben ser de 2 a 8')));
    });
    test('malo: la pista no es la palabra del texto', () {
      final d = conPalabra('la{yer}', 'la{yer}', 'layer', 'later');
      expect(errores(correr([d]), 'V14').single.mensaje, contains('el texto dice "layer" y la pista dice "later"'));
    });
    test('malo: hay un hueco más que pistas', () {
      final d = completarPalabras();
      lista(pregunta(d, 0)['pistas']).removeLast();
      expect(errores(correr([d]), 'V14').single.mensaje, contains('2 huecos y hay 1 pistas'));
    });
    test('malo: pocas palabras completas por hueco', () {
      final d = completarPalabras();
      mapa(d['estimulo'])['texto'] = 'A new la{yer} can be se{en}.';
      expect(errores(correr([d]), 'V14').single.mensaje, contains('al menos 8'));
    });
    test('malo: sin texto alrededor', () {
      final d = completarPalabras();
      d['estimulo'] = {'tipo': 'ninguno'};
      expect(errores(correr([d]), 'V14').single.mensaje, contains('estímulo de texto'));
    });
    test('aviso: la regla de ocultar es provisional en el contrato', () {
      final d = completarPalabras(parte: 'p-cp-provisional');
      final h = correr([d]);
      expect(errores(h, 'V14'), isEmpty);
      expect(avisos(h, 'V14').single.mensaje, contains('provisional'));
    });
    test('aviso: el contrato pide una regla que no se conoce, y no se comprueba la mitad', () {
      final d = conPalabra('la{yer}', 'lay{er}', 'layer', 'layer')..['parte'] = 'p-cp-otra';
      final h = correr([d]);
      expect(errores(h, 'V14'), isEmpty);
      expect(avisos(h, 'V14').single.mensaje, contains('primera_letra'));
    });
    test('sin contrato rige la segunda mitad', () {
      final d = conPalabra('la{yer}', 'lay{er}', 'layer', 'layer')..['formato'] = 'no-existe';
      expect(errores(correr([d]), 'V14').single.mensaje, contains('segunda mitad'));
    });
  });
}

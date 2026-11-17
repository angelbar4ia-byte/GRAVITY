import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/curso.dart';

List<String> _m(List<Hallazgo> h) => [for (final x in h) x.mensaje];

/// Errores de un código en los casos.
List<String> _err(List<Doc> docs, String codigo, {Doc? sesion}) => _m(errores(correrCurso(docs, sesion: sesion), codigo));
List<String> _avi(List<Doc> docs, String codigo, {Doc? sesion}) => _m(avisos(correrCurso(docs, sesion: sesion), codigo));

Doc _s(List<Doc> docs) => sesionDeLista(docs);
List<Object?> _bloques(List<Doc> docs) => lista(_s(docs)['bloques']);

void main() {
  group('V21 y V22 · casos buenos: cada día del curso, con los mínimos del contrato', () {
    final casos = <(String, int)>[
      ('lunes', 1),
      ('martes', 1),
      ('miercoles', 1),
      ('jueves', 1),
      ('viernes', 1), // mini prueba + conversación guiada
      ('viernes', 2), // mini prueba + prueba por unidad
      ('viernes', 7), // mini prueba + prueba por unidad
      ('viernes', 8), // sin mini prueba, conversación guiada
      ('lunes', 3), // el lunes de la repetición, con su lección normal
    ];
    for (final (dia, semana) in casos) {
      test('$dia de la semana $semana: ningún error de nada', () {
        final h = propios(correrCurso(sesionDelCurso(dia: dia, semana: semana)));
        expect(h.where((x) => x.esError), isEmpty, reason: '${h.where((x) => x.esError)}');
      });
    }
    test('los avisos que quedan son los de los datos que el contrato marca pendientes', () {
      final h = avisos(correrCurso(sesionDelCurso()), 'V21');
      expect(h.single.mensaje, startsWith('esta sesión se comprueba con datos que el contrato marca pendientes'));
      expect(h.single.mensaje, contains('el criterio de monólogo y diálogo del traslado'));
    });
    test('el lunes de la semana 3 puede traer la repetición de la prueba (forma b) en lugar de la lección', () {
      final docs = juntar([
        sesionDelCurso(dia: 'lunes', semana: 3),
        formaPruebaUnidad('A2.1', 1, 'b'),
      ]);
      // La repetición ocupa el lugar de la lección.
      final bs = _bloques(docs);
      bs[1] = {'tipo': 'repeticion_prueba', 'minutos': 10, 'forma': 'pu-a21-u1-b'};
      final h = propios(correrCurso(docs));
      expect(h.where((x) => x.esError), isEmpty, reason: '${h.where((x) => x.esError)}');
    });
  });

  group('V21 · estructura de la sesión', () {
    test('malo: los bloques fuera de orden', () {
      final docs = sesionDelCurso();
      final bs = _bloques(docs);
      final p = bs[2];
      bs[2] = bs[3];
      bs[3] = p;
      expect(_err(docs, 'V21').single, contains('deben ser, en orden: repaso, leccion, pronunciacion, produccion, traslado'));
    });
    test('malo: falta un bloque', () {
      final docs = sesionDelCurso();
      _bloques(docs).removeAt(2);
      expect(_err(docs, 'V21'), anyElement(contains('la sesión trae: repaso, leccion, produccion, traslado')));
    });
    test('malo: la semana 9 no existe en un escalón de ocho', () {
      final docs = sesionDelCurso(semana: 1);
      _s(docs)['semana'] = 9;
      expect(_err(docs, 'V21'), anyElement(contains('la semana 9 está fuera del escalón (de 1 a 8)')));
    });
    test('malo: el lunes de la semana 2 no admite repetición de prueba', () {
      final docs = juntar([sesionDelCurso(dia: 'lunes', semana: 2), formaPruebaUnidad('A2.1', 1, 'b')]);
      _bloques(docs)[1] = {'tipo': 'repeticion_prueba', 'minutos': 10, 'forma': 'pu-a21-u1-b'};
      expect(_err(docs, 'V21'), anyElement(contains('deben ser, en orden: repaso, leccion, pronunciacion')));
    });
    test('malo: los minutos que declara un bloque no son los del contrato', () {
      final docs = sesionDelCurso();
      mapa(_bloques(docs)[1])['minutos'] = 12;
      final e = _err(docs, 'V21');
      expect(e, anyElement(contains('el bloque leccion declara 12 minutos y el contrato pide 10')));
      expect(e, anyElement(contains('los bloques declaran 62 minutos en total y el contrato pide 60')));
    });
  });

  group('V21 · mínimos por bloque, leídos del contrato', () {
    test('malo: una lección de lunes con cinco ejemplos', () {
      final docs = sesionDelCurso();
      lista(mapa(_bloques(docs)[1])['ejemplos']).removeLast();
      expect(_err(docs, 'V21').single, 'la lección trae 5 ejemplos y el contrato pide 6 o más el lunes');
    });
    test('malo: una lección de lunes sin error común', () {
      final docs = sesionDelCurso();
      mapa(_bloques(docs)[1]).remove('error_comun');
      expect(_err(docs, 'V21').single, contains('necesita un error común'));
    });
    test('malo: una lección de lunes sin explicación', () {
      final docs = sesionDelCurso();
      mapa(_bloques(docs)[1])['explicacion'] = ' ';
      expect(_err(docs, 'V21'), anyElement(contains('necesita explicación')));
    });
    test('malo: una lección de martes con nueve preguntas', () {
      final docs = sesionDelCurso(dia: 'martes');
      final qs = lista(mapa(_bloques(docs)[1])['preguntas']);
      qs.removeRange(9, qs.length);
      expect(_err(docs, 'V21').single, 'la lección trae 9 preguntas y el contrato pide 10 o más el martes');
    });
    test('malo: pronunciación con once elementos', () {
      final docs = sesionDelCurso();
      lista(mapa(_bloques(docs)[2])['elementos']).removeRange(11, 14);
      expect(_err(docs, 'V21').single, 'la pronunciación trae 11 elementos y el contrato pide 12 o más el lunes');
    });
    test('malo: producción del jueves hablada y la del viernes escrita', () {
      final jueves = sesionDelCurso(dia: 'jueves');
      mapa(mapa(_bloques(jueves)[3])['tarea'])['modalidad'] = 'habla';
      expect(_err(jueves, 'V21').single, contains('la producción del jueves es de habla y el contrato pide escritura'));
      final viernes = sesionDelCurso(dia: 'viernes');
      mapa(mapa(_bloques(viernes)[3])['tarea'])['modalidad'] = 'escritura';
      expect(_err(viernes, 'V21').single, contains('la producción del viernes es de escritura y el contrato pide habla'));
    });
    test('malo: producción sin tarea', () {
      final docs = sesionDelCurso();
      mapa(_bloques(docs)[3]).remove('tarea');
      expect(_err(docs, 'V21'), anyElement(contains('la producción no trae tarea')));
    });
    test('malo: traslado con un solo audio, con audios repetidos y con diecinueve frases', () {
      var docs = sesionDelCurso();
      mapa(_bloques(docs)[4])['audios'] = ['au-a21-s01-a'];
      expect(_err(docs, 'V21'), anyElement(contains('el traslado trae 1 audios y el contrato pide 2')));
      docs = sesionDelCurso();
      mapa(_bloques(docs)[4])['audios'] = ['au-a21-s01-a', 'au-a21-s01-a'];
      expect(_err(docs, 'V21'), anyElement(contains('deben ser distintos entre sí')));
      docs = sesionDelCurso();
      lista(mapa(_bloques(docs)[4])['frases']).removeRange(19, 24);
      expect(_err(docs, 'V21'), anyElement(contains('el traslado trae 19 frases para repetir y el contrato pide 20 o más')));
    });
    test('malo: siete tarjetas un lunes y una tarjeta un viernes', () {
      final lunes = sesionDelCurso();
      lista(_s(lunes)['tarjetas']).removeLast();
      expect(_err(lunes, 'V21').single, 'trae 7 tarjetas y el contrato pide 8 el lunes');
      final viernes = sesionDelCurso(dia: 'viernes');
      _s(viernes)['tarjetas'] = [
        {'id': 'tt-1', 'en': 'word', 'es': 'palabra', 'ejemplo': 'This is a word.'}
      ];
      expect(_err(viernes, 'V21').single, 'trae 1 tarjetas y el contrato pide 0 el viernes');
    });
    test('malo: las sesiones de la misma semana no comparten los audios de traslado', () {
      final docs = juntar([sesionDelCurso(), sesionDelCurso(dia: 'martes')]);
      final martes = docs.firstWhere((d) => d['tipo'] == 'sesion' && d['dia'] == 'martes');
      docs.add(audioDeTraslado('au-otro'));
      mapa(bloque(martes, 'traslado'))['audios'] = ['au-a21-s01-a', 'au-otro'];
      expect(_err(docs, 'V21'), anyElement(contains('el contrato pide los mismos en las cinco sesiones de la semana')));
    });
    test('los mínimos salen del contrato, no del código: si el contrato pide siete ejemplos, la misma sesión falla', () {
      final docs = sesionDelCurso();
      expect(_err(docs, 'V21'), isEmpty);
      final c = contratoSesionConPruebas();
      mapa(mapa(mapa(lista(mapa(lista(c['secciones']).first)['partes'])[1])['por_dia'])['lunes'])['ejemplos'] = {'min': 7};
      expect(_err(docs, 'V21', sesion: c).single, 'la lección trae 6 ejemplos y el contrato pide 7 o más el lunes');
    });
    test('los mínimos salen del contrato: con 15 frases mínimas, 19 ya valen', () {
      final docs = sesionDelCurso();
      lista(mapa(_bloques(docs)[4])['frases']).removeRange(19, 24);
      final c = contratoSesionConPruebas();
      mapa(lista(mapa(lista(c['secciones'])[1])['partes'])[1])['frases'] = {'min': 15};
      expect(_err(docs, 'V21', sesion: c), isEmpty);
    });
  });

  group('V21 · monólogo y diálogo (criterio pendiente en el contrato: aviso)', () {
    List<Doc> dosMonologos() {
      final docs = sesionDelCurso();
      final b = docs.firstWhere((d) => d['id'] == 'au-a21-s01-b');
      mapa(lista(mapa(b['estimulo'])['guion'])[1])['voz'] = 'F1'; // las dos mitades, una sola voz
      return docs;
    }

    test('malo (aviso): dos monólogos', () {
      final h = _avi(dosMonologos(), 'V21').firstWhere((m) => m.contains('monólogo'));
      expect(h, contains('trae 2 monólogos y 0 diálogos'));
      expect(h, contains('criterio pendiente en el contrato'));
      expect(_err(dosMonologos(), 'V21'), isEmpty);
    });
    test('si el contrato lo da por cierto, la misma sesión es un error', () {
      final c = contratoSesionConPruebas();
      mapa(mapa(lista(mapa(lista(c['secciones'])[1])['partes']).first)['criterio_monologo_y_dialogo']).remove('pendiente');
      expect(_err(dosMonologos(), 'V21', sesion: c).single, contains('trae 2 monólogos y 0 diálogos'));
    });
  });

  group('V21 · el viernes', () {
    test('malo: el viernes de la semana 1 con repaso en vez de mini prueba', () {
      final docs = sesionDelCurso(dia: 'viernes');
      _bloques(docs)[0] = {'tipo': 'repaso', 'minutos': 5};
      expect(_err(docs, 'V21').single, contains('deben ser, en orden: mini_prueba, conversacion_guiada'));
    });
    test('malo: el viernes de la semana 8 con mini prueba (la semana es de puerta)', () {
      final docs = juntar([sesionDelCurso(dia: 'viernes', semana: 8), formaMini('A2.1', 7)]);
      _bloques(docs)[0] = {'tipo': 'mini_prueba', 'minutos': 5, 'forma': 'mini-a21-s07'};
      expect(_err(docs, 'V21'), anyElement(contains('deben ser, en orden: repaso, conversacion_guiada')));
    });
    test('malo: el viernes de la semana 2 con conversación en lugar de la prueba por unidad, y al revés', () {
      final c = sesionDelCurso(dia: 'viernes', semana: 1);
      final p = sesionDelCurso(dia: 'viernes', semana: 2);
      final dos = _bloques(p)[1];
      _bloques(p)[1] = _bloques(c)[1];
      expect(_err(p, 'V21').single, contains('deben ser, en orden: mini_prueba, prueba_unidad'));
      final uno = sesionDelCurso(dia: 'viernes', semana: 1);
      _bloques(uno)[1] = dos;
      expect(_err(uno, 'V21').single, contains('deben ser, en orden: mini_prueba, conversacion_guiada'));
    });
    test('malo: la conversación con siete turnos y solo tres de la persona', () {
      final docs = sesionDelCurso(dia: 'viernes');
      final turnos = lista(mapa(_bloques(docs)[1])['turnos']);
      turnos.removeRange(7, turnos.length);
      final e = _err(docs, 'V21');
      expect(e, anyElement(contains('la conversación guiada trae 7 turnos y el contrato pide 12 o más')));
      expect(e, anyElement(contains('trae 4 turnos de la persona'.replaceAll('4', '${turnos.where((t) => mapa(t)['rol'] == 'persona').length}'))));
    });
    test('malo: un turno de la persona con una variante, sin guía y sin modelo', () {
      final docs = sesionDelCurso(dia: 'viernes');
      final turnos = lista(mapa(_bloques(docs)[1])['turnos']);
      final t = mapa(turnos.firstWhere((x) => mapa(x)['rol'] == 'persona'));
      lista(t['variantes']).removeLast();
      expect(_err(docs, 'V21').single, contains('trae 1 variantes aceptables y se piden 2 o más'));
      t['guia'] = ' ';
      expect(_err(docs, 'V21'), anyElement(contains('no trae guía')));
    });
    test('malo (aviso): un turno sin palabras clave', () {
      final docs = sesionDelCurso(dia: 'viernes');
      final t = mapa(lista(mapa(_bloques(docs)[1])['turnos']).firstWhere((x) => mapa(x)['rol'] == 'persona'));
      t['palabras_clave'] = <String>[];
      expect(_avi(docs, 'V21'), anyElement(contains('no trae palabras clave')));
      expect(_err(docs, 'V21'), isEmpty);
    });
    test('malo: la mini prueba remite a una forma de otro uso, de otro escalón o con otro nombre', () {
      var docs = sesionDelCurso(dia: 'viernes', semana: 2);
      mapa(_bloques(docs)[0])['forma'] = 'pu-a21-u1-a';
      expect(_err(docs, 'V21'), anyElement(contains('es de uso prueba_unidad y se pide mini')));
      docs = sesionDelCurso(dia: 'viernes', semana: 2);
      formaDe(docs, 'mini-a21-s02')['escalon'] = 'A2.2';
      expect(_err(docs, 'V21'), anyElement(contains('es del escalón A2.2 y la sesión es de A2.1')));
      docs = juntar([sesionDelCurso(dia: 'viernes', semana: 2), formaMini('A2.1', 5)]);
      mapa(_bloques(docs)[0])['forma'] = 'mini-a21-s05';
      expect(_err(docs, 'V21'), anyElement(contains('debe llamarse "mini-a21-s02", no "mini-a21-s05"')));
    });
    test('malo: la prueba por unidad con otra unidad, sin repetición o con una repetición que es la variante a', () {
      var docs = sesionDelCurso(dia: 'viernes', semana: 2);
      formaDe(docs, 'pu-a21-u1-a')['unidad_del_escalon'] = 3;
      expect(_err(docs, 'V21'), anyElement(contains('es la unidad 3 del escalón y la semana 2 corresponde a la unidad 1')));
      docs = sesionDelCurso(dia: 'viernes', semana: 2);
      mapa(_bloques(docs)[1]).remove('repeticion');
      expect(_err(docs, 'V21'), anyElement(contains('no trae "repeticion"')));
      docs = sesionDelCurso(dia: 'viernes', semana: 2);
      mapa(_bloques(docs)[1])['repeticion'] = 'pu-a21-u1-a';
      expect(_err(docs, 'V21'), anyElement(contains('es la variante a y aquí va la b')));
    });
    test('malo: el viernes de la semana 4 con la unidad 1 en lugar de la 2', () {
      final docs = juntar([sesionDelCurso(dia: 'viernes', semana: 4), formaPruebaUnidad('A2.1', 1, 'a')]);
      mapa(_bloques(docs)[1])['forma'] = 'pu-a21-u1-a';
      expect(_err(docs, 'V21'), anyElement(contains('la semana 4 corresponde a la unidad 2')));
    });
  });

  group('V22 · minutos estimados', () {
    test('bueno: la sesión del ejemplo patrón estima lo que dice su cabecera (58.6 minutos)', () {
      final archivos = leerRuta('../../data/ingles');
      final s = archivos.whereType<Sesion>().single;
      final est = estimarSesion(s, Contexto(archivos))!;
      expect([for (final b in est.bloques) double.parse(b.minutos.toStringAsFixed(1))], [5.0, 12.3, 6.0, 12.0, 23.3]);
      expect(est.total.toStringAsFixed(1), '58.6');
      expect(est.incompleta, isEmpty);
    });
    test('malo: una lección de lunes por debajo del 70 %', () {
      final docs = sesionDelCurso();
      lista(mapa(_bloques(docs)[1])['preguntas']).removeRange(4, 14);
      final e = _err(docs, 'V22');
      expect(e.first, contains('el bloque leccion declara 10 minutos y estima'));
      expect(e.first, contains('el contrato pide entre 70 % y 150 %'));
    });
    test('malo: una pronunciación por encima del 150 % (25 elementos son 12.5 minutos)', () {
      final docs = sesionDelCurso();
      final els = lista(mapa(_bloques(docs)[2])['elementos']);
      for (var i = 0; i < 11; i++) {
        els.add({'texto': 'Extra ${palabras('extra$i', 2)}.'});
      }
      expect(_err(docs, 'V22').first, contains('el bloque pronunciacion declara 8 minutos y estima 12.5 (156 %)'));
    });
    test('malo: la sesión se queda por debajo de 54 minutos', () {
      final docs = sesionDelCurso();
      lista(mapa(_bloques(docs)[1])['preguntas']).removeRange(10, 14);
      lista(mapa(_bloques(docs)[2])['elementos']).removeRange(12, 14);
      lista(mapa(_bloques(docs)[4])['frases']).removeRange(20, 24);
      final e = _err(docs, 'V22');
      expect(e.last, matches(RegExp(r'la sesión estima 5\d\.\d minutos en total y el contrato pide entre 54 y 66')));
    });
    test('los límites salen del contrato: con un total mínimo de 40, la misma sesión vale', () {
      final docs = sesionDelCurso();
      lista(mapa(_bloques(docs)[1])['preguntas']).removeRange(10, 14);
      lista(mapa(_bloques(docs)[2])['elementos']).removeRange(12, 14);
      lista(mapa(_bloques(docs)[4])['frases']).removeRange(20, 24);
      final c = contratoSesionConPruebas();
      mapa(mapa(c['tolerancias_de_minutos'])['total'])['min'] = 40;
      expect(_err(docs, 'V22', sesion: c), isEmpty);
    });
    test('un dato pendiente no decide: la lección de martes fuera de banda es un aviso con su razón', () {
      final docs = sesionDelCurso(dia: 'martes');
      lista(mapa(_bloques(docs)[1])['preguntas']).removeRange(10, 14);
      final b = mapa(_bloques(docs)[1]);
      b['explicacion'] = 'Corta.';
      b['ejemplos'] = [
        {'en': 'One example.', 'es': 'Un ejemplo.'}
      ];
      expect(_err(docs, 'V22'), isEmpty);
      final a = _avi(docs, 'V22').firstWhere((m) => m.contains('el bloque leccion'));
      expect(a, contains('Estimación incompleta: el contrato marca pendiente la lección del martes'));
    });
    test('malo: una mini prueba de cuatro preguntas estima 2.7 minutos, el 53 % de 5', () {
      final docs = sesionDelCurso(dia: 'viernes', semana: 1);
      final u = unidadDe(docs, 'mini-a21-s01-u');
      lista(u['preguntas']).removeRange(4, 10);
      expect(_err(docs, 'V22').first, contains('el bloque mini_prueba declara 5 minutos y estima 2.7 (53 %)'));
    });
    test('malo: una prueba por unidad con un audio de 300 palabras pasa del 150 % (20 preguntas más 4 minutos de audio)', () {
      final docs = sesionDelCurso(dia: 'viernes', semana: 2);
      final esc = unidadDe(docs, 'pu-a21-u1-a-esc');
      final g = lista(mapa(esc['estimulo'])['guion']);
      mapa(g[0])['texto'] = palabras('largo', 150);
      mapa(g[1])['texto'] = palabras('largob', 150);
      final e = _err(docs, 'V22');
      expect(e.first, contains('el bloque prueba_unidad declara 10 minutos y estima 17.3 (173 %)'));
    });
    test('calibración: el mínimo de 12 turnos (6 de la persona) estima 7.5 minutos, el 75 % de 10; con 8 y 4 V21 la rechaza', () {
      final minimo = sesionDelCurso(dia: 'viernes', turnosDePersona: 6);
      expect(_err(minimo, 'V21'), isEmpty);
      expect(_err(minimo, 'V22'), isEmpty);
      final corta = sesionDelCurso(dia: 'viernes', turnosDePersona: 4);
      expect(_err(corta, 'V21'), isNotEmpty);
    });
    test('una tarea de producción incompleta no suma sus 12 minutos', () {
      final docs = sesionDelCurso();
      mapa(mapa(_bloques(docs)[3])['tarea'])['modelo'] = ' ';
      final e = _err(docs, 'V22');
      expect(e.first, contains('el bloque produccion declara 12 minutos y estima 0.0 (0 %)'));
    });
    test('un audio de traslado que no se puede leer deja la estimación incompleta (aviso)', () {
      final docs = sesionDelCurso()..removeWhere((d) => d['id'] == 'au-a21-s01-b');
      // Sin ese audio la sesión queda por debajo de 54 minutos, pero no se sabe cuánto dura el audio.
      lista(mapa(_bloques(docs)[4])['frases']).removeRange(20, 24);
      lista(mapa(_bloques(docs)[1])['preguntas']).removeRange(11, 14);
      expect(_err(docs, 'V22'), isEmpty);
      expect(_avi(docs, 'V22'), anyElement(contains('el audio "au-a21-s01-b" no se puede leer')));
    });
    test('el tiempo de un tipo de pregunta que el contrato no da deja la estimación incompleta (aviso)', () {
      final docs = sesionDelCurso();
      final qs = lista(mapa(_bloques(docs)[1])['preguntas']);
      qs[0] = {
        'id': 's-a21-s01-lun-nota',
        'tipo': 'completar_nota',
        'habilidad': 'escucha',
        'hueco': 1,
        'aceptadas': ['nine'],
        'porque': 'La razón explica la respuesta con palabras suficientes.',
      };
      lista(mapa(_bloques(docs)[1])['preguntas']).removeRange(5, 14);
      final a = _avi(docs, 'V22').firstWhere((m) => m.contains('el bloque leccion'));
      expect(a, contains('el contrato no da el tiempo de una pregunta de tipo completar_nota'));
    });
  });
}

import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/curso.dart';

Doc _tarjeta(String id, String en, String es, String ejemplo) => {'id': id, 'en': en, 'es': es, 'ejemplo': ejemplo};

List<Hallazgo> _v23(List<Doc> docs) => errores(correrCurso(docs), 'V23');

/// La sesión de lunes con estas tarjetas (el resto no cambia).
List<Doc> _con(List<Doc> tarjetas) {
  final docs = sesionDelCurso();
  sesionDeLista(docs)['tarjetas'] = tarjetas;
  return docs;
}

void main() {
  group('V23 · tarjetas', () {
    test('bueno: las tarjetas de la sesión de prueba', () {
      expect(_v23(sesionDelCurso()), isEmpty);
    });
    test('bueno: las tarjetas del ejemplo patrón', () {
      final h = validarRuta('../../data/ingles').hallazgos;
      expect(h.where((x) => x.codigo == 'V23'), isEmpty);
    });

    group('el ejemplo contiene la palabra o una forma suya', () {
      final buenos = <(String, String)>[
        ('at the moment', 'At the moment, I am working.'),
        ('belong to', 'This bike belongs to my neighbor.'),
        ('get better', 'My English is getting better.'),
        ('miss', 'I miss my friends from school.'),
        ('coworker', 'My coworkers are very friendly.'),
        ('stop', 'The bus stopped at the corner.'),
        ('study', 'She studies every night.'),
        ('carry', 'He carried the bag.'),
        ('go', 'They went home early.'),
        ('buy', 'I bought a new phone.'),
        ('good', 'This one is better than that one.'),
        ('child', 'The children are asleep.'),
        ('make a decision', 'It is hard to make a decision today.'),
        ('make / do', 'I did my homework.'),
        ('look (at)', 'Look, the sun is coming out.'),
        ('give sb a lift', 'Can you give me a lift?'),
        ('run', 'He is running late.'),
      ];
      for (final (en, ejemplo) in buenos) {
        test('«$en» está en «$ejemplo»', () {
          expect(ejemploContiene(en, ejemplo), isTrue);
        });
      }
      final malos = <(String, String)>[
        ('at the moment', 'Right now I am working.'),
        ('belong to', 'This bike belongs my neighbor.'),
        ('miss', 'I mist the bus.'),
        ('coworker', 'My boss is very friendly.'),
        ('go', 'They stayed home.'),
        ('get better', 'My English is good.'),
      ];
      for (final (en, ejemplo) in malos) {
        test('«$en» no está en «$ejemplo»', () {
          expect(ejemploContiene(en, ejemplo), isFalse);
        });
      }
    });

    test('malo: el ejemplo no trae la palabra', () {
      final h = _v23(_con([_tarjeta('t-1', 'schedule', 'horario', 'My plan changes every week.')]));
      expect(h.single.mensaje, 'el ejemplo "My plan changes every week." no contiene "schedule" ni una forma suya');
      expect(h.single.id, 't-1');
    });
    test('malo: sin traducción (V01 la rechaza al leer y V23 la dice con su nombre)', () {
      final docs = _con([_tarjeta('t-1', 'schedule', 'horario', 'My schedule changes.')]);
      mapa(lista(sesionDeLista(docs)['tarjetas']).first)['es'] = '  ';
      final h = correrCurso(docs);
      expect(errores(h, 'V23').single.mensaje, 'la tarjeta no trae traducción (es)');
      expect(errores(h, 'V01'), isNotEmpty);
    });
    test('malo: id de tarjeta repetido en la misma sesión', () {
      final h = _v23(_con([
        _tarjeta('t-1', 'schedule', 'horario', 'My schedule changes.'),
        _tarjeta('t-1', 'coworker', 'compañero', 'My coworker is kind.'),
      ]));
      expect(h.single.mensaje, contains('"t-1" está repetido en esta sesión'));
    });
    test('malo: id de tarjeta repetido en otra sesión del curso', () {
      final docs = juntar([sesionDelCurso(), sesionDelCurso(dia: 'martes')]);
      final otra = docs.firstWhere((d) => d['tipo'] == 'sesion' && d['dia'] == 'martes');
      mapa(lista(otra['tarjetas']).first)['id'] = mapa(lista(sesionDeLista(docs)['tarjetas']).first)['id'];
      final h = _v23(docs);
      expect(h, hasLength(2), reason: 'se dice en las dos sesiones');
      expect(h.first.mensaje, contains('debe ser único en todo el curso'));
    });
    test('una sesión retirada no cuenta para el id único', () {
      final docs = juntar([sesionDelCurso(), sesionDelCurso(dia: 'martes')]);
      final otra = docs.firstWhere((d) => d['tipo'] == 'sesion' && d['dia'] == 'martes');
      mapa(lista(otra['tarjetas']).first)['id'] = mapa(lista(sesionDeLista(docs)['tarjetas']).first)['id'];
      otra['estado'] = 'retirado';
      expect(_v23(docs), isEmpty);
    });
  });

  group('morfología de las tarjetas', () {
    test('basesDe incluye la palabra, sin sufijos y la base irregular', () {
      expect(basesDe('stopped'), containsAll(['stopped', 'stop']));
      expect(basesDe('studies'), contains('study'));
      expect(basesDe('making'), containsAll(['make']));
      expect(basesDe('went'), contains('go'));
      expect(basesDe('better'), containsAll(['good', 'better']));
    });
    test('esFormaDe funciona en las dos direcciones', () {
      expect(esFormaDe('go', 'gone'), isTrue);
      expect(esFormaDe('gone', 'go'), isTrue);
      expect(esFormaDe('cat', 'dog'), isFalse);
    });
  });
}

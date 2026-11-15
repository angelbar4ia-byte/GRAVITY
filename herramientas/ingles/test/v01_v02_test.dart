import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/casos.dart';

void main() {
  group('V01 · esquema', () {
    test('bueno: sin hallazgos', () => expect(de(correr([opcionMultiple()]), 'V01'), isEmpty));

    test('malo: falta un campo obligatorio', () {
      final d = opcionMultiple()..remove('parte');
      final h = errores(correr([d]), 'V01');
      expect(h, hasLength(1));
      expect(h.single.mensaje, contains('parte'));
      expect(h.single.mensaje, contains('falta el campo'));
    });
    test('malo: nivel fuera de la lista', () {
      final d = opcionMultiple()..['nivel'] = 'C1';
      expect(errores(correr([d]), 'V01').single.mensaje, contains('nivel'));
    });
    test('malo: tipo de pregunta que no existe', () {
      final d = opcionMultiple();
      mapa(lista(d['preguntas']).first)['tipo'] = 'adivinanza';
      final h = errores(correr([d]), 'V01');
      expect(h.single.id, 't-om-0001-a');
      expect(h.single.mensaje, contains('adivinanza'));
    });
    test('malo: esquema distinto', () {
      final d = opcionMultiple()..['esquema'] = 'otro-v9';
      expect(errores(correr([d]), 'V01').single.mensaje, contains('gravity-ingles-v1'));
    });
    test('malo: id con mayúsculas', () {
      final d = opcionMultiple()..['id'] = 'T-Om';
      expect(errores(correr([d]), 'V01').first.mensaje, contains('minúsculas'));
    });
    test('malo: estado fuera de la lista', () {
      final d = opcionMultiple()..['estado'] = 'completo';
      expect(errores(correr([d]), 'V01').single.mensaje, contains('estado'));
    });
    test('malo: audio sin reproducciones', () {
      final d = completarNota();
      mapa(d['estimulo']).remove('reproducciones');
      expect(errores(correr([d]), 'V01').single.mensaje, contains('reproducciones'));
    });
    test('malo: voz que no existe', () {
      final d = completarNota();
      mapa(lista(mapa(d['estimulo'])['guion']).first)['voz'] = 'X9';
      expect(errores(correr([d]), 'V01').single.mensaje, contains('voz'));
    });
    test('malo: YAML roto', () {
      final a = leerTexto('roto.yaml', 'esquema: [');
      expect(a, isA<ArchivoIlegible>());
      expect(a.lectura.single.codigo, 'V01');
      expect(a.lectura.single.mensaje, contains('YAML'));
    });
    test('malo: un contrato sin nombre', () {
      final a = leerTexto('c.yaml', '''
esquema: gravity-ingles-v1
tipo: formato
id: c-uno
estado: borrador
fuente: {titulo: x, url: y}
variante: en-GB
secciones:
  - {id: s, partes: [{id: p}]}
''');
      expect(a.lectura.map((h) => h.mensaje).single, contains('nombre'));
    });
  });

  group('V02 · identificadores y referencias', () {
    test('bueno: sin hallazgos', () => expect(de(correr([opcionMultiple()]), 'V02'), isEmpty));

    test('malo: el mismo id en dos archivos', () {
      final h = errores(correr([opcionMultiple(), opcionMultiple()]), 'V02');
      expect(h.where((x) => x.id == 't-om-0001' && x.mensaje.contains('ya existe')), hasLength(2));
    });
    test('malo: el mismo id de pregunta en dos unidades', () {
      final otra = huecoAbierto();
      mapa(lista(otra['preguntas']).first)['id'] = 't-om-0001-a';
      final h = errores(correr([opcionMultiple(), otra]), 'V02');
      expect(h.map((x) => x.id), contains('t-om-0001-a'));
    });
    test('malo: id repetido dentro del archivo', () {
      final d = opcionMultiple();
      mapa(lista(d['preguntas'])[1])['id'] = 't-om-0001-a';
      expect(errores(correr([d]), 'V02').single.mensaje, contains('repetido 2 veces'));
    });
    test('malo: el id de la pregunta no empieza con el de la unidad', () {
      final d = opcionMultiple();
      mapa(lista(d['preguntas']).first)['id'] = 'otra-a';
      expect(errores(correr([d]), 'V02').single.mensaje, contains('debe empezar con "t-om-0001-"'));
    });
    test('malo: formato sin contrato es aviso en borrador', () {
      final d = opcionMultiple()..['formato'] = 'no-existe';
      expect(errores(correr([d]), 'V02'), isEmpty);
      expect(avisos(correr([d]), 'V02').single.mensaje, contains('sin contrato'));
    });
    test('malo: formato sin contrato es error en validado', () {
      final d = opcionMultiple()
        ..['formato'] = 'no-existe'
        ..['estado'] = 'validado';
      expect(errores(correr([d]), 'V02').single.mensaje, contains('sin contrato'));
    });
    test('malo: la parte no existe en el contrato', () {
      final d = opcionMultiple()..['parte'] = 'p-zzz';
      expect(errores(correr([d]), 'V02').single.mensaje, contains('p-zzz'));
    });
    test('malo: un hueco sin marca en el texto', () {
      final d = huecoAbierto();
      mapa(lista(d['preguntas'])[1])['hueco'] = 3;
      final h = errores(correr([d]), 'V02').map((x) => x.mensaje).toList();
      expect(h, anyElement(contains('hueco 3 no tiene marca')));
      expect(h, anyElement(contains('marca {2}')));
    });
    test('malo: dos preguntas con el mismo hueco', () {
      final d = huecoAbierto();
      mapa(lista(d['preguntas'])[1])['hueco'] = 1;
      expect(errores(correr([d]), 'V02').map((x) => x.mensaje), anyElement(contains('hueco 1 lo usan varias')));
    });
    test('malo: textos con id repetido', () {
      final d = correspondencia();
      mapa(lista(d['textos'])[1])['id'] = 'A';
      expect(errores(correr([d]), 'V02').map((x) => x.mensaje), anyElement(contains('"A" está repetido')));
    });
    test('bueno: una forma que apunta a una unidad que existe', () {
      expect(de(correr([forma(), opcionMultiple()]), 'V02'), isEmpty);
    });
    test('malo: una forma que apunta a una unidad que no existe', () {
      final h = errores(correr([forma(unidad: 't-om-9999'), opcionMultiple()]), 'V02');
      expect(h.single.mensaje, contains('"t-om-9999" no existe'));
    });
    test('malo: una forma cuya parte no está en el contrato', () {
      final d = forma();
      mapa(lista(d['secciones']).first)['parte'] = 'p-zzz';
      expect(errores(correr([d, opcionMultiple()]), 'V02').single.mensaje, contains('p-zzz'));
    });
    test('malo: una forma que apunta a algo que no es una unidad', () {
      final h = errores(correr([forma(unidad: 't-forma-a')]), 'V02');
      expect(h.single.mensaje, contains('no una unidad'));
    });
    test('malo: la sesión remite a un audio que no existe', () {
      final d = sesion();
      mapa(lista(d['bloques']).last)['audios'] = ['no-existe'];
      expect(errores(correr([d, completarNota()]), 'V02').single.mensaje, contains('"no-existe" no existe'));
    });
    test('malo: la sesión remite a una unidad que no es de audio', () {
      final d = sesion();
      mapa(lista(d['bloques']).last)['audios'] = ['t-om-0001'];
      final h = errores(correr([d, opcionMultiple()]), 'V02');
      expect(h.single.mensaje, contains('no es una unidad de audio'));
    });
    test('malo: id de tarjeta igual al de otra sesión', () {
      final otra = sesion()..['id'] = 't-s02-lun';
      for (final b in lista(otra['bloques'])) {
        final m = mapa(b);
        if (m['tipo'] == 'leccion') mapa(lista(m['preguntas']).first)['id'] = 't-s02-lun-01';
        if (m['tipo'] == 'produccion') mapa(m['tarea'])['id'] = 't-s02-lun-prod';
      }
      final h = errores(correr([...sesionConAudio(), otra]), 'V02');
      expect(h.map((x) => x.id), everyElement('t-s01-tarjeta-0001'));
      expect(h, hasLength(2));
    });
    test('malo: la sesión sin contrato de sesión es aviso', () {
      final h = avisos(correr(sesionConAudio(), contratoSesion: false), 'V02');
      expect(h.single.mensaje, contains('gravity-sesion-60'));
    });
  });
}

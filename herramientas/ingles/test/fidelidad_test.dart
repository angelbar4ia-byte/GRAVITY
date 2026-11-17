import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/ayudas_b.dart';
import 'apoyo/casos_b.dart';

/// La forma completa de prueba con un cambio: los documentos y las secciones se
/// pueden sustituir.
Fidelidad fidelidad({
  List<Doc>? unidades,
  Map<String, List<String>>? secciones,
  Doc? contrato,
  String uso = 'simulacro',
}) =>
    fidelidadDe([
      ...(unidades ?? unidadesCompletas()),
      formaDe('f-1', secciones ?? seccionesCompletas(), uso: uso),
    ], contrato: contrato);

/// Las unidades completas con la que lleva ese id reemplazada.
List<Doc> reemplaza(String id, Doc nueva) => [
      for (final d in unidadesCompletas()) d['id'] == id ? nueva : d,
    ];

/// Las unidades completas con la que lleva ese id modificada.
List<Doc> cambia(String id, void Function(Doc) f) => [
      for (final d in unidadesCompletas())
        if (d['id'] == id) (clonar(d)..also(f)) else d,
    ];

extension on Doc {
  void also(void Function(Doc) f) => f(this);
}

Matcher motivo(String parte) => anyElement(contains(parte));

void main() {
  group('fidelidad de una forma', () {
    test('bueno: una forma con todas las partes y las medidas del contrato es completa', () {
      final f = fidelidad();
      expect(f.motivos, isEmpty);
      expect(f.completa, isTrue);
      expect(f.etiqueta, 'completa');
    });
    test('bueno: la forma completa no deja ningún hallazgo de ninguna comprobación', () {
      expect(propios(correrB([...unidadesCompletas(), formaCompleta()])), isEmpty);
    });
    test('malo: reducida, y la etiqueta lo dice', () {
      final f = fidelidad(secciones: seccionesCompletas()..remove('l-2'));
      expect(f.completa, isFalse);
      expect(f.etiqueta, 'reducida');
    });

    group('unidades y preguntas', () {
      test('malo: una unidad de menos en una parte', () {
        final m = fidelidad(secciones: {...seccionesCompletas(), 'r-1': ['u-r1-a']}).motivos;
        expect(m, contains('la parte "r-1" tiene 1 unidad y el contrato pide 2'));
        expect(m, contains('la parte "r-1" tiene 1 pregunta y el contrato pide 2'));
      });
      test('malo: una unidad de más en una parte', () {
        final m = fidelidad(
          unidades: [...unidadesCompletas(), lectura('u-r1-c', parte: 'r-1', semilla: 30, palabras: 25)],
          secciones: {...seccionesCompletas(), 'r-1': ['u-r1-a', 'u-r1-b', 'u-r1-c']},
        ).motivos;
        expect(m, contains('la parte "r-1" tiene 3 unidades y el contrato pide 2'));
      });
      test('malo: falta una parte entera', () {
        expect(fidelidad(secciones: seccionesCompletas()..remove('l-2')).motivos, ['falta la parte "l-2"']);
      });
      test('malo: una unidad con más preguntas por unidad de las que pide el contrato', () {
        final m = fidelidad(unidades: reemplaza('u-r1-a', lectura('u-r1-a', parte: 'r-1', semilla: 1, palabras: 30, preguntas: 2))).motivos;
        expect(m, contains('la unidad "u-r1-a" tiene 2 preguntas y el contrato de "r-1" pide 1 por unidad'));
        expect(m, contains('la parte "r-1" tiene 3 preguntas y el contrato pide 2'));
      });
      test('bueno: se cuentan preguntas y estímulos, no archivos (dos archivos ninguno con 2 y 1 transformaciones)', () {
        final f = fidelidad(
          unidades: [
            for (final d in unidadesCompletas()) if (d['id'] != 'u-tr') d,
            transformaciones('u-tr-a', n: 2, semilla: 4),
            transformaciones('u-tr-b', n: 1, semilla: 40),
          ],
          secciones: {...seccionesCompletas(), 'r-tr': ['u-tr-a', 'u-tr-b']},
        );
        expect(f.motivos, isEmpty);
      });
      test('malo: un archivo ninguno con dos transformaciones es dos unidades y el contrato pide tres', () {
        final f = fidelidad(unidades: reemplaza('u-tr', transformaciones('u-tr', n: 2, semilla: 4)));
        expect(f.motivos, contains('la parte "r-tr" tiene 2 unidades y el contrato pide 3'));
        expect(f.motivos, contains('la parte "r-tr" tiene 2 preguntas y el contrato pide 3'));
      });
      test('las oraciones omitidas valen una pregunta por oración colocada y los huecos de las notas, uno cada uno', () {
        // La forma completa ya trae `omitidas` (2 colocadas y 1 sobrante) y `audioNotas` (2 huecos).
        expect(fidelidad().motivos, isEmpty);
      });
      test('bueno: un total de preguntas dado como rango acepta cualquier valor dentro', () {
        final c = contratoCon('r-1', (p) => p['preguntas_total'] = {'min': 1, 'max': 3});
        expect(fidelidad(contrato: c).motivos, isEmpty);
      });
      test('malo: el contrato no da el número de unidades de una parte que no es pendiente', () {
        final c = contratoCon('r-2', (p) => p.remove('unidades'));
        expect(fidelidad(contrato: c).motivos, ['el contrato no da el número de unidades de la parte "r-2"']);
      });
      test('malo: el contrato no da el número de preguntas', () {
        final c = contratoCon('r-2', (p) {
          p.remove('preguntas_total');
          p.remove('preguntas_por_unidad');
        });
        expect(fidelidad(contrato: c).motivos, ['el contrato no da el número de preguntas de la parte "r-2"']);
      });
    });

    group('rango de palabras', () {
      test('malo: un estímulo con 45 palabras donde el contrato pide de 20 a 40', () {
        final m = fidelidad(unidades: reemplaza('u-r1-a', lectura('u-r1-a', parte: 'r-1', semilla: 1, palabras: 45))).motivos;
        expect(m, ['la unidad "u-r1-a" tiene 45 palabras y el contrato de "r-1" pide 20 a 40']);
      });
      test('bueno: los extremos del rango valen', () {
        expect(fidelidad(unidades: reemplaza('u-r1-a', lectura('u-r1-a', parte: 'r-1', semilla: 1, palabras: 20))).motivos, isEmpty);
        expect(fidelidad(unidades: reemplaza('u-r1-a', lectura('u-r1-a', parte: 'r-1', semilla: 1, palabras: 40))).motivos, isEmpty);
      });
      test('malo: las oraciones originales de unas transformaciones fuera de rango', () {
        final m = fidelidad(unidades: reemplaza('u-tr', transformaciones('u-tr', semilla: 4, palabrasOriginal: 13))).motivos;
        expect(m, hasLength(3));
        expect(m.first, 'la oración original de "u-tr-1" tiene 13 palabras y el contrato de "r-tr" pide 5 a 12');
      });
      test('malo: el habla de un audio fuera de rango (el narrador no cuenta)', () {
        final m = fidelidad(unidades: reemplaza('u-l1-a', audio('u-l1-a', semilla: 6, palabras: 10))).motivos;
        expect(m, ['la unidad "u-l1-a" tiene 10 palabras y el contrato de "l-1" pide 15 a 40']);
      });
    });

    group('partes de escucha', () {
      test('malo: una unidad de escucha sin estímulo de audio', () {
        final m = fidelidad(unidades: reemplaza('u-l1-a', lectura('u-l1-a', parte: 'l-1', semilla: 6, palabras: 24))).motivos;
        expect(m, ['la parte "l-1" es de escucha y la unidad "u-l1-a" no tiene estímulo de audio con guion']);
      });
      test('malo: un audio que se oye una vez donde el contrato pide dos', () {
        final m = fidelidad(unidades: reemplaza('u-l1-a', audio('u-l1-a', semilla: 6, palabras: 24, reproducciones: 1))).motivos;
        expect(m, ['el audio de la unidad "u-l1-a" se oye 1 vez y el contrato de "l-1" pide 2 veces']);
      });
      test('malo: un audio sin ningún turno de habla (solo narrador)', () {
        final solo = audio('u-l1-a', semilla: 6, guion: [
          {'voz': 'N', 'texto': relleno(6, 24)},
        ]);
        expect(fidelidad(unidades: reemplaza('u-l1-a', solo)).motivos, motivo('no tiene guion con turnos de habla'));
      });
      test('una parte con reproducciones del contrato es de escucha aunque su sección no se llame así', () {
        // La sección de las partes `l-1` y `l-2` se llama `listening`; con otro nombre sigue valiendo por las reproducciones.
        final c = clonar(contratoFidelidad());
        mapa(lista(c['secciones'])[1])['id'] = 'oral';
        expect(fidelidad(contrato: c, unidades: reemplaza('u-l1-a', lectura('u-l1-a', parte: 'l-1', semilla: 6, palabras: 24))).motivos,
            motivo('es de escucha'));
      });
    });

    group('datos pendientes', () {
      test('malo: una parte pendiente en el contrato impide la fidelidad completa', () {
        final c = contratoCon('r-1', (p) => p['pendiente'] = true);
        expect(fidelidad(contrato: c).motivos, ['el contrato tiene datos pendientes en la parte "r-1"']);
      });
      test('bueno: una parte pendiente que la forma no usa no cuenta, pero la parte falta', () {
        final c = contratoCon('r-1', (p) => p['pendiente'] = true);
        final m = fidelidad(contrato: c, secciones: seccionesCompletas()..remove('r-1')).motivos;
        expect(m, ['falta la parte "r-1"']);
      });
      test('un dato pendiente no decide: no se exigen unidades ni preguntas que el contrato no da', () {
        final c = contratoCon('r-2', (p) {
          p['pendiente'] = true;
          p.remove('unidades');
          p.remove('preguntas_total');
          p.remove('preguntas_por_unidad');
        });
        expect(fidelidad(contrato: c).motivos, ['el contrato tiene datos pendientes en la parte "r-2"']);
      });
    });

    group('imagen, retiradas y unidades que no son de la parte', () {
      Doc conImagen([String? archivo]) {
        final d = lectura('u-r2', parte: 'r-2', semilla: 3, palabras: 60, preguntas: 2);
        d['estimulo'] = {'tipo': 'imagen', 'descripcion': 'A photo of a bridge.', 'archivo': ?archivo};
        return d;
      }

      test('malo: una imagen sin archivo no puede ser de fidelidad completa', () {
        expect(fidelidad(unidades: reemplaza('u-r2', conImagen())).motivos,
            ['la unidad "u-r2" tiene un estímulo de imagen sin archivo: solo se muestra su descripción']);
      });
      test('bueno: la misma imagen con su archivo', () {
        expect(fidelidad(unidades: reemplaza('u-r2', conImagen('puente.png'))).motivos, isEmpty);
      });
      test('malo: una unidad retirada', () {
        expect(fidelidad(unidades: cambia('u-r1-b', (d) => d['estado'] = 'retirado')).motivos, ['la unidad "u-r1-b" está retirada']);
      });
      test('malo: una unidad de otra parte', () {
        expect(fidelidad(unidades: cambia('u-r1-b', (d) => d['parte'] = 'r-2')).motivos,
            ['la unidad "u-r1-b" es de la parte "r-2" y la forma la usa en "r-1"']);
      });
      test('malo: una unidad de otro formato', () {
        expect(fidelidad(unidades: cambia('u-r1-b', (d) => d['formato'] = 'otro')).motivos,
            ['la unidad "u-r1-b" es del formato "otro" y la forma es de "prueba-fidelidad"']);
      });
    });

    group('lo que impide que una forma se haga pasar por completa', () {
      test('malo: listar dos veces la misma unidad para llegar al número de unidades', () {
        final m = fidelidad(secciones: {...seccionesCompletas(), 'r-1': ['u-r1-a', 'u-r1-a']}).motivos;
        expect(m, contains('la unidad "u-r1-a" está repetida en la parte "r-1"'));
        expect(m, contains('la parte "r-1" tiene 1 unidad y el contrato pide 2'));
      });
      test('malo: una unidad que no existe', () {
        final m = fidelidad(secciones: {...seccionesCompletas(), 'r-1': ['u-r1-a', 'u-nada']}).motivos;
        expect(m, contains('la unidad "u-nada" no existe'));
      });
      test('malo: un id que existe pero no es una unidad', () {
        final m = fidelidad(secciones: {...seccionesCompletas(), 'r-1': ['u-r1-a', 'prueba-fidelidad']}).motivos;
        expect(m, contains('"prueba-fidelidad" no es una unidad'));
      });
      test('malo: la misma parte en dos secciones', () {
        final f = formaDe('f-1', seccionesCompletas());
        lista(f['secciones']).add({'parte': 'r-1', 'unidades': ['u-r1-a']});
        final archivos = archivosB([...unidadesCompletas(), f]);
        final fi = calcularFidelidad(archivos.whereType<Forma>().single, Contexto(archivos));
        expect(fi.motivos, contains('la parte "r-1" aparece en 2 secciones de la forma'));
      });
      test('malo: una parte que el contrato no tiene', () {
        final m = fidelidad(secciones: {...seccionesCompletas(), 'zzz': ['u-r1-a']}).motivos;
        expect(m, ['la forma usa la parte "zzz", que no está en el contrato']);
      });
      test('los motivos se acumulan: primero lo que falta y luego, parte por parte, lo que no cuadra', () {
        final m = fidelidad(
          unidades: reemplaza('u-r1-a', lectura('u-r1-a', parte: 'r-1', semilla: 1, palabras: 45)),
          secciones: seccionesCompletas()..remove('l-2'),
        ).motivos;
        expect(m, [
          'falta la parte "l-2"',
          'la unidad "u-r1-a" tiene 45 palabras y el contrato de "r-1" pide 20 a 40',
        ]);
      });
      test('varias partes que faltan se dicen juntas', () {
        final m = fidelidad(secciones: {'r-1': ['u-r1-a', 'u-r1-b']}).motivos;
        expect(m, ['faltan 5 partes del contrato: "r-2", "r-tr", "r-oo", "l-1", "l-2"']);
      });
    });

    group('sin contrato', () {
      test('malo: la forma de un formato sin contrato es reducida y no se inventa ninguno', () {
        final f = formaDe('f-1', seccionesCompletas())..['formato'] = 'no-existe';
        final archivos = archivosB([...unidadesCompletas(), f]);
        final fi = calcularFidelidad(archivos.whereType<Forma>().single, Contexto(archivos));
        expect(fi.completa, isFalse);
        expect(fi.motivos.single, startsWith('sin contrato'));
      });
    });

    group('alcance: prácticas, mini pruebas y pruebas por unidad (formato 5 y 5.1)', () {
      test('bueno: una práctica de una sola parte es completa en esa parte y dice cuál es', () {
        final f = fidelidad(secciones: {'r-1': ['u-r1-a', 'u-r1-b']}, uso: 'practica');
        expect(f.motivos, isEmpty);
        expect(f.completa, isTrue);
        expect(f.parcial, isTrue);
        expect(f.partes, ['r-1']);
        expect(f.descripcion, 'completa solo en: r-1 (no es el examen entero)');
      });
      test('malo: una práctica se evalúa sobre las partes que incluye: la que incluye mal la hace reducida', () {
        final f = fidelidad(
          unidades: reemplaza('u-r1-a', lectura('u-r1-a', parte: 'r-1', semilla: 1, palabras: 45)),
          secciones: {'r-1': ['u-r1-a', 'u-r1-b'], 'r-2': ['u-r2']},
          uso: 'practica',
        );
        expect(f.completa, isFalse);
        expect(f.partes, ['r-1', 'r-2']);
        expect(f.motivos, ['la unidad "u-r1-a" tiene 45 palabras y el contrato de "r-1" pide 20 a 40']);
        expect(f.descripcion, startsWith('reducida solo en: r-1, r-2'));
      });
      test('malo: una práctica con las partes a medias sigue siendo reducida por lo que incluye', () {
        final f = fidelidad(secciones: {'r-1': ['u-r1-a']}, uso: 'practica');
        expect(f.motivos, ['la parte "r-1" tiene 1 unidad y el contrato pide 2', 'la parte "r-1" tiene 1 pregunta y el contrato pide 2']);
      });
      test('malo: una práctica sin ninguna parte del contrato no se da por completa', () {
        final f = fidelidad(secciones: {'zzz': ['u-r1-a']}, uso: 'practica');
        expect(f.completa, isFalse);
        expect(f.motivos, contains('la práctica no incluye ninguna parte del contrato'));
      });
      test('los usos simulacro, etapa, escalon y ubicacion exigen todas las partes', () {
        for (final uso in ['simulacro', 'etapa', 'escalon', 'ubicacion']) {
          final f = fidelidad(secciones: {'r-1': ['u-r1-a', 'u-r1-b']}, uso: uso);
          expect(f.completa, isFalse, reason: uso);
          expect(f.motivos.first, startsWith('faltan 5 partes'), reason: uso);
          expect(f.parcial, isFalse, reason: uso);
        }
      });
      test('mini y prueba_unidad: la fidelidad no aplica', () {
        for (final uso in ['mini', 'prueba_unidad']) {
          final f = fidelidad(secciones: {'r-1': ['u-r1-a']}, uso: uso);
          expect(f.aplica, isFalse, reason: uso);
          expect(f.completa, isFalse, reason: uso);
          expect(f.etiqueta, 'no aplica', reason: uso);
          expect(f.motivos, isEmpty, reason: uso);
        }
      });
      test('un dato pendiente a cualquier profundidad de la parte impide la fidelidad completa', () {
        final c = contratoCon('r-1', (p) => p['por_dia'] = {'martes': {'pendiente': true, 'nota': 'falta'}});
        expect(fidelidad(contrato: c).motivos, ['el contrato tiene datos pendientes en la parte "r-1"']);
        // ...y una parte que la forma no usa, en una práctica, no cuenta.
        expect(fidelidad(contrato: c, secciones: {'r-2': ['u-r2']}, uso: 'practica').completa, isTrue);
      });
    });
  });
}

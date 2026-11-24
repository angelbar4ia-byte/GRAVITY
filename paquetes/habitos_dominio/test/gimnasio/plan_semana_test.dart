import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('CA-G-13 plan semanal de 3, 4 y 5 días', () {
    test('por omisión: la semana reordenada del dueño (24/nov/2026)', () {
      // A lunes, C martes, B miércoles; jueves libre; R1 el viernes.
      expect(planSemanal(3).fila, [
        'A',
        'C',
        'B',
        'descanso',
        'descanso',
        'bici',
        'descanso',
      ]);
      expect(planSemanal(4).fila, [
        'A',
        'C',
        'B',
        'descanso',
        'R1',
        'bici',
        'descanso',
      ]);
      expect(planSemanal(5).fila, [
        'A',
        'C',
        'B',
        'R2',
        'R1',
        'bici',
        'descanso',
      ]);
    });

    test(
      'CASO MALO: la forma anterior (C el jueves) ya no es la de omisión',
      () {
        for (final d in [3, 4, 5]) {
          expect(planSemanal(d).dia(4), isNot('C'));
          expect(planSemanal(d).dia(5), isNot('C'));
          expect(planSemanal(d).dia(2), 'C');
          expect(
            planSemanal(d).fila,
            isNot(planSemanal(d, cEnJueves: true).fila),
          );
          expect(
            planSemanal(d).fila,
            isNot(planSemanal(d, cEnViernes: true).fila),
          );
        }
      },
    );

    test('variante «C el jueves» (la recomendación anterior, pregunta 4)', () {
      expect(planSemanal(3, cEnJueves: true).fila, [
        'A',
        'descanso',
        'B',
        'C',
        'descanso',
        'bici',
        'descanso',
      ]);
      expect(planSemanal(4, cEnJueves: true).fila, [
        'A',
        'R1',
        'B',
        'C',
        'descanso',
        'bici',
        'descanso',
      ]);
      expect(planSemanal(5, cEnJueves: true).fila, [
        'A',
        'R1',
        'B',
        'C',
        'R2',
        'bici',
        'descanso',
      ]);
    });

    test('la tabla original de 5.6 (C el viernes) sigue disponible', () {
      expect(planSemanal(3, cEnViernes: true).fila, [
        'A',
        'descanso',
        'B',
        'descanso',
        'C',
        'bici',
        'descanso',
      ]);
      expect(planSemanal(4, cEnViernes: true).fila, [
        'A',
        'R1',
        'B',
        'descanso',
        'C',
        'bici',
        'descanso',
      ]);
      expect(planSemanal(5, cEnViernes: true).fila, [
        'A',
        'R1',
        'B',
        'R2',
        'C',
        'bici',
        'descanso',
      ]);
    });

    test('CASO MALO: pedir las dos variantes a la vez falla', () {
      expect(
        () => planSemanal(4, cEnViernes: true, cEnJueves: true),
        throwsArgumentError,
      );
    });

    test('sábado bici y domingo descanso en todas las variantes y tamaños', () {
      for (final (viernes, jueves) in [
        (false, false),
        (true, false),
        (false, true),
      ]) {
        for (final d in [3, 4, 5]) {
          final p = planSemanal(d, cEnViernes: viernes, cEnJueves: jueves);
          expect(p.dia(6), 'bici', reason: 'plan de $d');
          expect(p.dia(7), 'descanso', reason: 'plan de $d');
          expect(p.sesionesDeFuerza, 3, reason: 'plan de $d');
        }
      }
    });

    test(
      'por omisión las regenerativas ya no caen en martes: R1 el viernes y R2 '
      'el jueves; el jueves queda libre en los planes de 3 y 4 días',
      () {
        for (final d in [3, 4, 5]) {
          final p = planSemanal(d);
          for (final e in p.porDia.entries) {
            if (e.value == 'R1') expect(e.key, 5, reason: 'plan de $d');
            if (e.value == 'R2') expect(e.key, 4, reason: 'plan de $d');
          }
          expect(p.dia(2), isNot(anyOf('R1', 'R2')), reason: 'plan de $d');
        }
        expect(planSemanal(3).porDia.values, isNot(contains('R1')));
        expect(planSemanal(3).dia(4), 'descanso');
        expect(planSemanal(3).dia(5), 'descanso');
        expect(planSemanal(4).dia(4), 'descanso');
        expect(planSemanal(4).dia(5), 'R1');
        expect(planSemanal(5).dia(4), 'R2');
        expect(planSemanal(5).dia(5), 'R1');
      },
    );

    test(
      'en las variantes, las regenerativas siguen donde estaban: R1 el martes; '
      'R2 el viernes (C jueves) o el jueves (C viernes)',
      () {
        for (final viernes in [false, true]) {
          for (final d in [3, 4, 5]) {
            final p = planSemanal(d, cEnViernes: viernes, cEnJueves: !viernes);
            for (final e in p.porDia.entries) {
              if (e.value == 'R1') expect(e.key, 2);
              if (e.value == 'R2') expect(e.key, viernes ? 4 : 5);
            }
          }
        }
      },
    );

    test(
      'CASO MALO: un plan de 2 o 6 días falla (también en las variantes)',
      () {
        expect(() => planSemanal(2), throwsArgumentError);
        expect(() => planSemanal(6), throwsArgumentError);
        expect(() => planSemanal(2, cEnJueves: true), throwsArgumentError);
        expect(() => planSemanal(6, cEnViernes: true), throwsArgumentError);
      },
    );
  });
}

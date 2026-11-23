import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('CA-G-13 plan semanal de 3, 4 y 5 días', () {
    test(
      'por omisión: la sesión C al jueves (pregunta 4); R2 pasa al viernes',
      () {
        expect(planSemanal(3).fila, [
          'A',
          'descanso',
          'B',
          'C',
          'descanso',
          'bici',
          'descanso',
        ]);
        expect(planSemanal(4).fila, [
          'A',
          'R1',
          'B',
          'C',
          'descanso',
          'bici',
          'descanso',
        ]);
        expect(planSemanal(5).fila, [
          'A',
          'R1',
          'B',
          'C',
          'R2',
          'bici',
          'descanso',
        ]);
      },
    );

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

    test(
      'sábado bici y domingo descanso en todos; regenerativas solo en martes y '
      'jueves/viernes',
      () {
        for (final viernes in [false, true]) {
          for (final d in [3, 4, 5]) {
            final p = planSemanal(d, cEnViernes: viernes);
            expect(p.dia(6), 'bici');
            expect(p.dia(7), 'descanso');
            expect(p.sesionesDeFuerza, 3);
            for (final e in p.porDia.entries) {
              if (e.value == 'R1') expect(e.key, 2);
              if (e.value == 'R2') expect(e.key, viernes ? 4 : 5);
            }
          }
        }
      },
    );

    test('CASO MALO: un plan de 2 o 6 días falla', () {
      expect(() => planSemanal(2), throwsArgumentError);
      expect(() => planSemanal(6), throwsArgumentError);
    });
  });
}

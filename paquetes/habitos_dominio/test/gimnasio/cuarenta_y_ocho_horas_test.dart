import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

DateTime t(int d, int h, int m, {int mes = 11}) =>
    DateTime.utc(2026, mes, d, h, m);

List<AvisoSemana> revisar(List<SesionProgramada> s) => revisarSemana(s, cat);

void main() {
  test('el 30/nov/2026 es lunes (base de los ejemplos)', () {
    expect(lunes30nov.weekday, DateTime.monday);
  });

  group('CA-G-14 48 horas (inicio a inicio, tolerancia de 60 min)', () {
    test('A el lunes 20:00 y B el miércoles 19:15: 47 h 15 min, cumple', () {
      final a = revisar([
        SesionProgramada('A', t(30, 20, 0)),
        SesionProgramada('B', t(2, 19, 15, mes: 12)),
      ]);
      expect(a, isEmpty);
    });

    test('A el lunes 20:00 y B el miércoles 18:30: 46 h 30 min, avisa; faltan 30 min', () {
      final a = revisar([
        SesionProgramada('A', t(30, 20, 0)),
        SesionProgramada('B', t(2, 18, 30, mes: 12)),
      ]);
      expect(a, hasLength(1));
      expect(a.single.intervaloMin, 46 * 60 + 30);
      expect(a.single.grupos, ['hombro']);
      expect(a.single.faltanMin, 30);
      expect(a.single.propuestas.first, AccionSemana.masTarde);
    });

    test('A el lunes y B el martes a la misma hora: 24 h, avisa', () {
      final a = revisar([
        SesionProgramada('A', t(30, 20, 0)),
        SesionProgramada('B', t(1, 20, 0, mes: 12)),
      ]);
      expect(a, hasLength(1));
      expect(a.single.intervaloMin, 24 * 60);
      expect(a.single.tipo, TipoAvisoSemana.grupoCompartido);
    });

    test('dos sesiones de fuerza el mismo día: avisa y propone otro día', () {
      final a = revisar([
        SesionProgramada('A', t(30, 18, 0)),
        SesionProgramada('C', t(30, 20, 0)),
      ]);
      expect(a.map((x) => x.tipo), contains(TipoAvisoSemana.mismoDia));
      expect(
        a.firstWhere((x) => x.tipo == TipoAvisoSemana.mismoDia).propuestas,
        [AccionSemana.otroDia],
      );
    });

    test('la bicicleta del sábado 8:00 con C el viernes 20:00: 12 h, avisa y propone '
        'mover C al jueves, C corta o dejarlo', () {
      final a = revisar([
        SesionProgramada('C', t(4, 20, 0, mes: 12)),
        SesionProgramada('bici', t(5, 8, 0, mes: 12)),
      ]);
      expect(a, hasLength(1));
      expect(a.single.intervaloMin, 12 * 60);
      expect(a.single.grupos, ['cuadriceps', 'gluteo']);
      expect(a.single.propuestas, [
        AccionSemana.moverAlJueves,
        AccionSemana.versionCorta,
        AccionSemana.dejarComoEsta,
      ]);
    });

    test(
      'NUNCA bloquea: mover la sesión siempre devuelve un resultado con avisos',
      () {
        // C el viernes 20:00 con bici el sábado: permitido, con aviso.
        final r = moverSesion(
          plan: [SesionProgramada('bici', t(5, 8, 0, mes: 12))],
          tipo: 'C',
          nuevoInicio: t(4, 20, 0, mes: 12),
          catalogo: cat,
        );
        expect(r.permitido, isTrue);
        expect(r.avisos, isNotEmpty);
      },
    );

    test(
      'las regenerativas no cuentan como grupos: R1 el martes no avisa con A',
      () {
        expect(
          revisar([
            SesionProgramada('A', t(30, 20, 0)),
            SesionProgramada('R1', t(1, 20, 0, mes: 12)),
          ]),
          isEmpty,
        );
      },
    );

    test(
      'hallazgo: con C el jueves la bicicleta del sábado sigue por debajo de 47 h '
      '(36 h 45 min); el aviso queda y la mudanza al jueves ya no se propone',
      () {
        final a = revisar([
          SesionProgramada('C', t(3, 19, 15, mes: 12)),
          SesionProgramada('bici', t(5, 8, 0, mes: 12)),
        ]);
        expect(a, hasLength(1));
        expect(a.single.intervaloMin, 36 * 60 + 45);
        expect(a.single.propuestas, [
          AccionSemana.versionCorta,
          AccionSemana.dejarComoEsta,
        ]);
      },
    );

    /// Pone un plan en el calendario de la semana del 30/nov/2026: fuerza y
    /// regenerativas a las 19:15 y la bicicleta a las 8:00 del sábado.
    List<SesionProgramada> calendario(PlanSemana plan) {
      final lunes = lunes30nov;
      return [
        for (final e in plan.porDia.entries)
          if (e.value != 'descanso')
            SesionProgramada(
              e.value,
              DateTime.utc(
                lunes.year,
                lunes.month,
                lunes.day + e.key - 1,
                e.value == 'bici' ? 8 : 19,
                e.value == 'bici' ? 0 : 15,
              ),
            ),
      ];
    }

    test(
      'la semana por omisión (C el martes, hora 19:15) no avisa de nada',
      () {
        for (final d in [3, 4, 5]) {
          final sesiones = calendario(planSemanal(d));
          // A (lunes) y B (miércoles) a las 19:15: 48 h, cumple. A→C y C→B no
          // comparten grupo. C (martes) → bici (sábado 8:00): 84 h 45 min.
          expect(revisar(sesiones), isEmpty, reason: 'plan de $d');
        }
      },
    );

    test(
      'C el martes a las 19:15 y la ruta del sábado a las 8:00: 84 h 45 min, '
      'cumple; A el lunes y B el miércoles a las 19:15: 48 h, cumple',
      () {
        final ruta = revisar([
          SesionProgramada('C', t(1, 19, 15, mes: 12)),
          SesionProgramada('bici', t(5, 8, 0, mes: 12)),
        ]);
        expect(ruta, isEmpty);
        final ab = revisar([
          SesionProgramada('A', t(30, 19, 15)),
          SesionProgramada('B', t(2, 19, 15, mes: 12)),
        ]);
        expect(ab, isEmpty);
      },
    );

    test('CASO MALO: la semana por omisión sigue avisando si B se corre una '
        'hora antes (A lunes 19:15, B miércoles 18:00: 46 h 45 min)', () {
      final sesiones = calendario(planSemanal(3))
          .map(
            (s) =>
                s.tipo == 'B' ? SesionProgramada('B', t(2, 18, 0, mes: 12)) : s,
          )
          .toList();
      final avisos = revisar(sesiones);
      expect(avisos.map((x) => '${x.a.tipo}-${x.b.tipo}'), ['A-B']);
      expect(avisos.single.faltanMin, 15);
    });

    test('las regenerativas de la semana por omisión (R2 jueves, R1 viernes) '
        'no avisan contra la bicicleta ni contra la fuerza', () {
      final sesiones = calendario(planSemanal(5));
      expect(sesiones.map((s) => s.tipo), containsAll(['R1', 'R2']));
      expect(
        revisar(sesiones).where(
          (x) =>
              ['R1', 'R2'].contains(x.a.tipo) ||
              ['R1', 'R2'].contains(x.b.tipo),
        ),
        isEmpty,
      );
    });

    test('con C el jueves (variante), el plan solo avisa de la bicicleta '
        '(36 h 45 min) y no propone mover al jueves', () {
      for (final d in [3, 4, 5]) {
        final avisos = revisar(calendario(planSemanal(d, cEnJueves: true)));
        // A→B 48 h cumple; B y C no comparten grupo. Solo C → bici.
        expect(avisos.map((x) => '${x.a.tipo}-${x.b.tipo}'), [
          'C-bici',
        ], reason: 'plan de $d');
        expect(avisos.single.intervaloMin, 36 * 60 + 45);
        expect(avisos.single.propuestas, [
          AccionSemana.versionCorta,
          AccionSemana.dejarComoEsta,
        ]);
      }
    });

    test('con C el viernes (tabla del diseño), el plan avisa de la bicicleta '
        '(12 h 45 min) y propone mover C al jueves', () {
      for (final d in [3, 4, 5]) {
        final avisos = revisar(calendario(planSemanal(d, cEnViernes: true)));
        expect(avisos.map((x) => '${x.a.tipo}-${x.b.tipo}'), [
          'C-bici',
        ], reason: 'plan de $d');
        expect(avisos.single.intervaloMin, 12 * 60 + 45);
        expect(avisos.single.propuestas, [
          AccionSemana.moverAlJueves,
          AccionSemana.versionCorta,
          AccionSemana.dejarComoEsta,
        ]);
      }
    });
  });
}

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

DateTime t(int d, int h, int m, {int mes = 12}) =>
    DateTime.utc(2026, mes, d, h, m);

void main() {
  group('CA-G-15 sesión perdida', () {
    test('saltar una sesión no cambia la carga sugerida: se compara con la última '
        'vez que se hizo', () {
      final hecho = sesionHecha(fecha: dia(2026, 12, 1)); // 12-12-12, placa 5
      // Pasan 2, 3, 4 y 5 días sin que se haga otra: la sugerencia es la misma.
      final cargas = [
        for (final d in [3, 4, 5, 6])
          generar(
            'A',
            historial: [hecho],
            hoy: dia(2026, 12, d),
          ).ejercicios.first.cargaPasos,
      ];
      expect(cargas, [6, 6, 6, 6]);
      // Con una racha anterior distinta, la última vez manda y no el calendario.
      final antes = sesionHecha(
        fecha: dia(2026, 11, 28),
        reps: const [10, 10, 10],
        carga: 4,
      );
      expect(
        generar(
          'A',
          historial: [antes, hecho],
          hoy: dia(2026, 12, 4),
        ).ejercicios.first.cargaPasos,
        6,
      );
    });

    test('CASO MALO: una sesión de otra plantilla no cuenta como «la última vez» de A', () {
      final b = sesionHecha(
        fecha: dia(2026, 12, 2),
        plantilla: 'B',
        ejercicio: 'jalon_pecho',
        variante: 'jalon_polea_alta',
        carga: 7,
      );
      final a = generar(
        'A',
        historial: [b],
        hoy: dia(2026, 12, 3),
      ).ejercicios.first;
      expect(a.motivo, MotivoProgresion.primeraVez);
      expect(a.cargaPasos, isNull);
    });

    test('mover la sesión respeta las 48 h con aviso', () {
      final plan = [
        SesionProgramada('A', t(30, 20, 0, mes: 11)),
        SesionProgramada('B', t(2, 19, 15)),
      ];
      final r = moverSesion(
        plan: plan,
        tipo: 'B',
        nuevoInicio: t(1, 20, 0),
        catalogo: cat,
      );
      expect(r.permitido, isTrue);
      expect(r.avisos, hasLength(1));
      expect(r.avisos.single.tipo, TipoAvisoSemana.grupoCompartido);
      final bien = moverSesion(
        plan: plan,
        tipo: 'B',
        nuevoInicio: t(3, 20, 0),
        catalogo: cat,
      );
      expect(bien.permitido, isTrue);
      expect(bien.avisos, isEmpty);
    });

    test('no se permiten dos sesiones de fuerza en un día', () {
      final plan = [
        SesionProgramada('A', t(30, 19, 0, mes: 11)),
        SesionProgramada('B', t(2, 19, 15)),
        SesionProgramada('C', t(3, 19, 15)),
      ];
      final r = moverSesion(
        plan: plan,
        tipo: 'C',
        nuevoInicio: t(2, 21, 0),
        catalogo: cat,
      );
      expect(r.permitido, isFalse);
      expect(r.avisos.map((a) => a.tipo), contains(TipoAvisoSemana.mismoDia));
    });

    test('una regenerativa puede compartir día con una de fuerza', () {
      final r = moverSesion(
        plan: [SesionProgramada('A', t(2, 19, 15))],
        tipo: 'R1',
        nuevoInicio: t(2, 8, 0),
        catalogo: cat,
      );
      expect(r.permitido, isTrue);
    });
  });
}

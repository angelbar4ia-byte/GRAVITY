import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Plan que empieza el lunes 30/nov/2026, ciclo 3 + 1, sin semanas de
/// adaptación (nivel intermedio).
final perfil = PerfilGimnasio(
  nivel: NivelGimnasio.intermedio,
  inicioCiclo: lunes30nov,
);

SemanaCiclo? ciclo(
  DateTime hoy, {
  int semanas = 4,
  List<DateTime> foco = const [],
}) => semanaDelCiclo(
  hoy: hoy,
  inicioCiclo: lunes30nov,
  cicloSemanas: semanas,
  lunesEnFoco: foco,
);

void main() {
  group('CA-G-18 descarga (3 + 1)', () {
    test(
      '30/nov, 7/dic y 14/dic son de carga; la del 21/dic es de descarga; la '
      'siguiente empieza el 28/dic',
      () {
        final semanas = [
          for (final d in [
            dia(2026, 11, 30),
            dia(2026, 12, 7),
            dia(2026, 12, 14),
            dia(2026, 12, 21),
            dia(2026, 12, 28),
          ])
            ciclo(d)!,
        ];
        expect([for (final s in semanas) s.numero], [1, 2, 3, 4, 1]);
        expect(
          [for (final s in semanas) s.descarga],
          [false, false, false, true, false],
        );
        // Cualquier día de la semana cuenta como esa semana.
        expect(ciclo(dia(2026, 12, 27))!.descarga, isTrue); // domingo
        expect(ciclo(dia(2026, 12, 21))!.descarga, isTrue);
      },
    );

    test('antes del inicio del plan no hay semana de ciclo', () {
      expect(ciclo(dia(2026, 11, 29)), isNull);
      expect(
        semanaDelCiclo(
          hoy: dia(2026, 12, 1),
          inicioCiclo: null,
          cicloSemanas: 4,
        ),
        isNull,
      );
    });

    test('la semana de descarga: 2 series, mínimo del rango, una placa menos y sin subir', () {
      // 18/dic: 12-12-12 con la placa 5 (sesión de la semana de carga).
      final h = [sesionHecha(fecha: dia(2026, 12, 18))];
      final s = generar(
        'A',
        historial: h,
        perfil: perfil,
        hoy: dia(2026, 12, 21),
      );
      expect(s.semanaTipo, TipoSemana.descarga);
      final e = s.ejercicios.first;
      expect(e.series, 2);
      expect(e.objetivo, e.rangoMin);
      expect(e.cargaPasos, 4);
      expect(e.motivo, MotivoProgresion.bajaUnPaso);
      for (final x in s.ejercicios) {
        expect(x.series, 2, reason: x.slotId);
      }
      // En la de carga anterior sí sube (placa 6) con 3 series.
      final c = generar(
        'A',
        historial: h,
        perfil: perfil,
        hoy: dia(2026, 12, 20),
      );
      expect(c.semanaTipo, TipoSemana.carga);
      expect(c.ejercicios.first.cargaPasos, 6);
      expect(c.ejercicios.first.series, 3);
    });

    test(
      'la sesión de descarga no baja la carga de las semanas siguientes',
      () {
        final h = [
          sesionHecha(fecha: dia(2026, 12, 18)),
          // La de descarga: placa 4, 2 series al mínimo.
          sesionHecha(
            fecha: dia(2026, 12, 22),
            reps: const [10, 10],
            carga: 4,
            tipo: TipoSemana.descarga,
            repsMax: 12,
          ),
        ];
        final s = generar(
          'A',
          historial: h,
          perfil: perfil,
          hoy: dia(2026, 12, 28),
        );
        expect(s.semanaTipo, TipoSemana.carga);
        // Se retoma desde la última semana de carga (placa 5 → sube a 6).
        expect(s.ejercicios.first.cargaPasos, 6);
      },
    );

    test('con ciclo_semanas = 0 nunca hay descarga programada', () {
      for (var i = 0; i < 30; i++) {
        final hoy = sumarDias(lunes30nov, i * 7);
        final s = semanaDelCiclo(
          hoy: hoy,
          inicioCiclo: lunes30nov,
          cicloSemanas: 0,
        )!;
        expect(s.descarga, isFalse);
      }
      final h = [sesionHecha(fecha: dia(2026, 12, 18))];
      final p = PerfilGimnasio(
        nivel: NivelGimnasio.intermedio,
        inicioCiclo: lunes30nov,
        cicloSemanas: 0,
      );
      expect(
        generar(
          'A',
          historial: h,
          perfil: p,
          hoy: dia(2026, 12, 21),
        ).semanaTipo,
        TipoSemana.carga,
      );
    });

    test('dos sesiones seguidas con esfuerzo 5 SUGIEREN una descarga y no la imponen', () {
      final h = [
        sesionHecha(fecha: dia(2026, 12, 1), esfuerzoSesion: 5),
        sesionHecha(
          fecha: dia(2026, 12, 3),
          plantilla: 'B',
          ejercicio: 'curl_biceps',
          variante: 'curl_cojin',
          esfuerzoSesion: 5,
        ),
      ];
      expect(sugerirDescarga(h), isTrue);
      final s = generar(
        'A',
        historial: h,
        perfil: perfil,
        hoy: dia(2026, 12, 4),
      );
      expect(s.tiene(CodigoAviso.descargaSugerida), isTrue);
      expect(s.semanaTipo, TipoSemana.carga); // no la impone
      expect(s.ejercicios.first.series, 3);
    });

    test('CASO MALO: un solo 5, o 5 y luego 3, no sugiere nada', () {
      expect(
        sugerirDescarga([
          sesionHecha(fecha: dia(2026, 12, 1), esfuerzoSesion: 5),
        ]),
        isFalse,
      );
      expect(
        sugerirDescarga([
          sesionHecha(fecha: dia(2026, 12, 1), esfuerzoSesion: 5),
          sesionHecha(fecha: dia(2026, 12, 3), esfuerzoSesion: 3),
        ]),
        isFalse,
      );
      expect(
        sugerirDescarga([
          sesionHecha(fecha: dia(2026, 12, 1), esfuerzoSesion: 5),
          sesionHecha(
            fecha: dia(2026, 12, 3),
            esfuerzoSesion: 5,
            estado: EstadoSesion.enCurso,
          ),
        ]),
        isFalse,
      );
    });

    test('principiante: las 2 primeras semanas son de adaptación (2 series, sin subir)', () {
      final p = PerfilGimnasio(
        inicioCiclo: lunes30nov,
      ); // principiante por omisión
      final h = [sesionHecha(fecha: dia(2026, 12, 1))];
      final s = generar('A', historial: h, perfil: p, hoy: dia(2026, 12, 3));
      expect(s.semana.adaptacion, isTrue);
      expect(s.ejercicios.first.series, 2);
      expect(s.ejercicios.first.cargaPasos, 5); // sin subir
      // La tercera semana ya es normal.
      final n = generar('A', historial: h, perfil: p, hoy: dia(2026, 12, 14));
      expect(n.semana.adaptacion, isFalse);
    });
  });
}

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

String min(SesionPlanificada s) => minutosConDecimal(s.duracionEstimadaSeg);

/// Reglas con la larga **sin extras** (las del renglón «4 series, sin extras»).
const reglasLargaSinExtras = ReglasGimnasio(
  larga: ParametrosVersion(
    series: 4,
    descansoS: 75,
    calentamientoMin: 8,
    cierreMin: 5,
    metaMin: 60,
    toleranciaDesdeMin: 48,
    toleranciaHastaMin: 65,
  ),
);

void main() {
  group('CA-G-10 tiempo estimado', () {
    test('corta: 29.3, 29.3 y 31.2 min', () {
      expect(min(generar('A', version: VersionSesion.corta)), '29.3');
      expect(min(generar('B', version: VersionSesion.corta)), '29.3');
      expect(min(generar('C', version: VersionSesion.corta)), '31.2');
    });

    test('estándar: 35.3, 35.3 y 45.8 min', () {
      expect(min(generar('A')), '35.3');
      expect(min(generar('B')), '35.3');
      expect(min(generar('C')), '45.8');
    });

    test('larga (4 series, sin extras): 48.4, 48.4 y 63.1 min', () {
      for (final (p, esperado) in [
        ('A', '48.4'),
        ('B', '48.4'),
        ('C', '63.1'),
      ]) {
        expect(
          min(
            generar(
              p,
              version: VersionSesion.larga,
              reglas: reglasLargaSinExtras,
            ),
          ),
          esperado,
          reason: p,
        );
      }
    });

    test('larga con extras: A 60.9 y B 61.3 (y 54.4 sin bandas)', () {
      expect(min(generar('A', version: VersionSesion.larga)), '60.9');
      expect(
        min(
          generar('B', version: VersionSesion.larga, inventario: conBandas()),
        ),
        '61.3',
      );
      expect(min(generar('B', version: VersionSesion.larga)), '54.4');
      expect(min(generar('C', version: VersionSesion.larga)), '63.1');
    });

    test(
      'en segundos exactos: A estándar 2118 s, corta 1758 s, larga 2904 s',
      () {
        expect(generar('A').duracionEstimadaSeg, 2118);
        expect(
          generar('A', version: VersionSesion.corta).duracionEstimadaSeg,
          1758,
        );
        expect(
          generar(
            'A',
            version: VersionSesion.larga,
            reglas: reglasLargaSinExtras,
          ).duracionEstimadaSeg,
          2904,
        );
      },
    );

    test(
      'las tolerancias se cumplen (corta 27–33, estándar 33–50, larga 48–65)',
      () {
        const r = ReglasGimnasio();
        for (final p in ['A', 'B', 'C']) {
          for (final v in VersionSesion.values) {
            final s = generar(p, version: v, inventario: conBandas());
            expect(
              r.dentroDeTolerancia(v, s.duracionEstimadaSeg),
              isTrue,
              reason: '$p ${v.name} ${min(s)}',
            );
          }
        }
      },
    );

    test('CASO MALO: un cambio de la regla de series que mueva A estándar fuera de '
        '33–50 falla', () {
      const rota = ReglasGimnasio(
        estandar: ParametrosVersion(
          series: 6,
          descansoS: 60,
          calentamientoMin: 6,
          cierreMin: 5,
          metaMin: 45,
          toleranciaDesdeMin: 33,
          toleranciaHastaMin: 50,
        ),
      );
      final s = generar('A', reglas: rota);
      expect(
        rota.dentroDeTolerancia(VersionSesion.estandar, s.duracionEstimadaSeg),
        isFalse,
      );
      expect(
        const ReglasGimnasio().dentroDeTolerancia(
          VersionSesion.estandar,
          generar('A').duracionEstimadaSeg,
        ),
        isTrue,
      );
    });

    test('las décimas se truncan como en la especificación (63.15 → 63.1)', () {
      expect(decimasDeMinuto(3789), 631);
      expect(decimasDeMinuto(1875), 312);
      expect(minutosConDecimal(2118), '35.3');
    });
  });

  group('CA-G-12 calibración', () {
    SesionRegistrada conTiempos(
      int dia0,
      int porRep,
      int cambio, {
      int? descanso = 55,
    }) => sesionHecha(
      fecha: dia(2026, 11, dia0),
      plantilla: 'C',
      ejercicio: 'plancha',
      variante: 'plancha_suelo',
      segundos: const [30, 30, 30],
      carga: null,
      descansoReal: descanso,
      tiempos: TiemposMedidos(
        segundosPorRepeticion: porRep,
        segundosCambio: cambio,
      ),
    );

    test('con menos de 3 sesiones usa los valores de 5.5', () {
      final m = calibrarModelo([conTiempos(2, 5, 40), conTiempos(5, 6, 50)]);
      expect(
        (m.segundosPorRepeticion, m.segundosCambio, m.calibrado),
        (4, 45, false),
      );
    });

    test('tras 3 sesiones usa la mediana de la persona', () {
      final h = [
        conTiempos(2, 5, 40),
        conTiempos(5, 7, 60),
        conTiempos(9, 6, 50),
      ];
      final m = calibrarModelo(h);
      expect(
        (m.segundosPorRepeticion, m.segundosCambio, m.calibrado),
        (6, 50, true),
      );
      // Con 6 s por repetición y 50 s de cambio, A estándar (sin historial
      // propio de A) dura 2417 s: 1757 de ejercicios + 660 de calentamiento y cierre.
      expect(
        generar('A', historial: h, hoy: dia(2026, 11, 12)).duracionEstimadaSeg,
        2417,
      );
      // Con las de 5.5, 2118 s.
      expect(generar('A').duracionEstimadaSeg, 2118);
    });

    test('mediana con cantidad par: promedio redondeado hacia arriba', () {
      expect(mediana([4, 6, 7, 9]), 7);
      expect(mediana([3]), 3);
      expect(mediana([5, 1, 3]), 3);
    });

    test(
      'CASO MALO: sesiones sin `descanso_real_s` o sin terminar no calibran',
      () {
        final sinDescanso = [
          conTiempos(2, 5, 40, descanso: null),
          conTiempos(5, 7, 60, descanso: null),
          conTiempos(9, 6, 50, descanso: null),
        ];
        expect(calibrarModelo(sinDescanso).calibrado, isFalse);
        final h = [conTiempos(2, 5, 40), conTiempos(5, 7, 60)];
        final enCurso = SesionRegistrada(
          fecha: dia(2026, 11, 12),
          plantilla: 'C',
          version: VersionSesion.estandar,
          estado: EstadoSesion.enCurso,
          tiempos: const TiemposMedidos(
            segundosPorRepeticion: 9,
            segundosCambio: 90,
          ),
          series: const [
            SerieRegistrada(
              ejercicioId: 'plancha',
              varianteId: 'plancha_suelo',
              n: 1,
              descansoRealS: 50,
            ),
          ],
        );
        expect(calibrarModelo([...h, enCurso]).calibrado, isFalse);
      },
    );
  });
}

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

void main() {
  group('CA-G-06 filtro por inventario', () {
    test('con Marcy, banco y caminadora: A, B y C del diseño', () {
      expect(variantesDe(generar('A')), [
        'press_pecho_estacion',
        'elevacion_lateral_polea_baja',
        'extension_triceps_polea_alta',
        'fondos_banco_piernas',
      ]);
      expect(variantesDe(generar('B')), [
        'jalon_polea_alta',
        'remo_polea_baja',
        'face_pull_polea_alta',
        'curl_cojin',
      ]);
      // Sin tobillera ni bandas, la patada cae a cuadrupedia (sin equipo).
      expect(variantesDe(generar('C')), [
        'sentadilla_banco_peso',
        'subida_banco_peso',
        'puente_banco',
        'patada_cuadrupedia',
        'plancha_suelo',
      ]);
    });

    test('C: patada en polea baja si hay tobillera; si no, con banda', () {
      final conTobillera = inventarioBase().conItem(
        'tobillera_polea',
        EstadoItem.disponible,
      );
      expect(
        variantesDe(generar('C', inventario: conTobillera)),
        contains('patada_polea'),
      );
      expect(
        variantesDe(generar('C', inventario: conBandas())),
        contains('patada_banda'),
      );
    });

    test(
      'sin estación: A usa banda (con ancla de puerta), fondos incluidos',
      () {
        final s = generar('A', inventario: sinEstacion(conBandas(ancla: true)));
        expect(variantesDe(s), [
          'press_pecho_banda_puerta',
          'elevacion_lateral_banda',
          'extension_triceps_banda_puerta',
          'fondos_banco_piernas',
        ]);
      },
    );

    test('sin estación y sin ancla de puerta: flexiones inclinadas; tríceps se omite', () {
      final s = generar('A', inventario: sinEstacion(conBandas()));
      expect(variantesDe(s), [
        'flexion_inclinada_banco',
        'elevacion_lateral_banda',
        'fondos_banco_piernas',
      ]);
      expect(s.omitidos.map((o) => o.slotId), ['A3']);
      expect(
        s.avisos.where((a) => a.codigo == CodigoAviso.slotOmitido).single.razon,
        RazonOmision.sinEquipo,
      );
    });

    test('sin Marcy y sin bandas: en la larga A queda con flexiones, fondos y plancha', () {
      final inv = sinMarcy(inventarioBase());
      final s = generar('A', version: VersionSesion.larga, inventario: inv);
      // El slot A1 toma las flexiones; el extra A5 repetiría la misma variante
      // y se omite (nada se usa dos veces).
      expect(variantesDe(s), [
        'flexion_inclinada_banco',
        'fondos_banco_piernas',
        'plancha_suelo',
      ]);
      expect(variantesDe(s).toSet(), {
        'flexion_inclinada_banco',
        'fondos_banco_piernas',
        'plancha_suelo',
      });
      expect(s.ejercicios, hasLength(3));
      expect(s.tiene(CodigoAviso.sinEquipoSuficiente), isFalse);
    });

    test('CASO MALO: con menos de 3 ejercicios, sin_equipo_suficiente y no se inventa ninguno', () {
      final inv = sinMarcy(inventarioBase());
      final s = generar('A', inventario: inv);
      expect(variantesDe(s), [
        'flexion_inclinada_banco',
        'fondos_banco_piernas',
      ]);
      expect(s.tiene(CodigoAviso.sinEquipoSuficiente), isTrue);
      expect(s.tiene(CodigoAviso.ofrecerRegenerativa), isTrue);
      // Todo lo planeado es del catálogo y salió de las candidatas del slot.
      for (final e in s.ejercicios) {
        final slot = cat
            .plantilla('A')!
            .slots
            .firstWhere((x) => x.id == e.slotId);
        expect(slot.candidatas, contains(e.varianteId));
      }
      // Sin nada de equipo, ni el banco: solo la plancha (larga).
      final nada = Inventario(items: const {});
      final vacia = generar(
        'A',
        version: VersionSesion.larga,
        inventario: nada,
      );
      expect(variantesDe(vacia), ['plancha_suelo']);
      expect(vacia.tiene(CodigoAviso.sinEquipoSuficiente), isTrue);
    });
  });

  group('CA-G-08 el Marcy gana', () {
    test(
      'con el Marcy disponible, ni A ni B usan banda aunque haya bandas',
      () {
        for (final p in ['A', 'B']) {
          final s = generar(p, inventario: conBandas(ancla: true));
          for (final e in s.ejercicios) {
            expect(
              cat.variante(e.varianteId)!.esDeBanda,
              isFalse,
              reason: '$p ${e.varianteId}',
            );
          }
        }
      },
    );

    test(
      'con un puesto no disponible, solo cambian los slots de ese puesto',
      () {
        final base = conBandas(ancla: true);
        final sin = base.conItem('marcy.polea_alta', EstadoItem.noDisponible);
        final antes = generar('A', inventario: base);
        final despues = generar('A', inventario: sin);
        expect(variantesDe(despues)[0], variantesDe(antes)[0]);
        expect(variantesDe(despues)[1], variantesDe(antes)[1]);
        expect(variantesDe(despues)[2], 'extension_triceps_banda_puerta');
        expect(variantesDe(despues)[3], variantesDe(antes)[3]);

        final bAntes = generar('B', inventario: base);
        final bDespues = generar('B', inventario: sin);
        final cambian = [
          for (var i = 0; i < 4; i++)
            if (variantesDe(bAntes)[i] != variantesDe(bDespues)[i])
              bAntes.ejercicios[i].slotId,
        ];
        expect(cambian, ['B1', 'B3']);
        expect(variantesDe(bDespues)[0], 'jalon_banda_puerta');
        expect(variantesDe(bDespues)[2], 'face_pull_banda_puerta');
      },
    );

    test(
      'la estación entera cae sobre el padre: un puesto exige su aparato',
      () {
        final inv = inventarioBase().conItem(
          'marcy_mwm7119',
          EstadoItem.noDisponible,
        );
        expect(inv.disponible('marcy.press', cat), isFalse);
      },
    );
  });

  group('generador determinista', () {
    test('mismas entradas, mismas salidas', () {
      final h = [sesionHecha(fecha: dia(2026, 12, 1))];
      String huella(SesionPlanificada s) => [
        s.duracionEstimadaSeg,
        for (final e in s.ejercicios)
          '${e.varianteId}/${e.series}/${e.rangoMin}-${e.rangoMax}/${e.cargaPasos}/${e.objetivo}',
        s.avisos.join(','),
      ].join('|');
      expect(
        huella(generar('A', historial: h)),
        huella(generar('A', historial: h)),
      );
    });

    test('plantilla inexistente o regenerativa lanza un error claro', () {
      expect(() => generar('Z'), throwsArgumentError);
      expect(() => generar('R1'), throwsArgumentError);
    });

    test('calentamiento y cierre: sin caminadora, marcha suave', () {
      final con = generar('A');
      expect(con.calentamiento, ['caminata_suave', 'movilidad_hombros']);
      final sin = generar(
        'A',
        inventario: inventarioBase().conItem(
          'caminadora',
          EstadoItem.noDisponible,
        ),
      );
      expect(sin.calentamiento, ['marcha_suave', 'movilidad_hombros']);
      expect(generar('C').calentamiento, [
        'caminata_suave',
        'movilidad_cadera',
      ]);
      expect(con.cierre, ['estiramiento_cierre']);
    });

    test(
      'serie de aproximación en el primer ejercicio, con la mitad de la carga',
      () {
        final h = [
          sesionHecha(fecha: dia(2026, 12, 1), carga: 5, reps: [10, 10, 10]),
        ];
        final s = generar('A', historial: h);
        expect(s.ejercicios.first.aproximacion!.reps, 8);
        expect(
          s.ejercicios.first.aproximacion!.cargaPasos,
          3,
        ); // mitad de 5, hacia arriba
        expect(s.ejercicios[1].aproximacion, isNull);
      },
    );

    test('cambiar ejercicio: alternativas sin la actual y con su motivo', () {
      final s = generar('A', inventario: conBandas(ancla: true));
      final a1 = s.ejercicios.first;
      expect(
        a1.alternativas.map((a) => a.varianteId),
        isNot(contains(a1.varianteId)),
      );
      expect(
        a1.alternativas.map((a) => a.varianteId),
        contains('press_pecho_banda_puerta'),
      );
      expect(
        a1.alternativas
            .firstWhere((a) => a.varianteId == 'press_pecho_banda_puerta')
            .motivo,
        MotivoAlternativa.masFacil,
      );
    });

    test('perfil: objetivo de fuerza baja el rango 2 y sube el descanso', () {
      final s = generar(
        'A',
        perfil: const PerfilGimnasio(objetivo: ObjetivoGimnasio.fuerza),
      );
      final press = s.ejercicios.first;
      expect((press.rangoMin, press.rangoMax), (8, 10));
      expect(press.descansoS, 75);
      final g = generar(
        'A',
        perfil: const PerfilGimnasio(objetivo: ObjetivoGimnasio.perdidaGrasa),
      );
      expect(g.ejercicios.first.descansoS, 45);
      expect(generar('A').ejercicios.first.descansoS, 60);
    });

    test('perfil: descanso propio de 30 a 120', () {
      final s = generar('A', perfil: const PerfilGimnasio(descansoS: 200));
      expect(s.ejercicios.first.descansoS, 120);
    });
  });
}

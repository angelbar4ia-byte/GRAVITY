// G6 · Revisión de cierre del gimnasio (docs/revisiones/fase-8-gimnasio.md).
//
// Recálculo INDEPENDIENTE de la especificación: las cifras de este archivo salen
// de un script aparte que aplica las fórmulas de la sección 5.5 y las reglas de
// 5.6, 5.8 y 5.9 sin leer el código del dominio, y se contrastan con él. Además
// un barrido de invariantes (equipo, molestias, series) sobre todas las
// combinaciones de inventario.
import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

DateTime d(int y, int m, int dd, [int h = 0, int mi = 0]) =>
    DateTime.utc(y, m, dd, h, mi);

void main() {
  final cat = catalogoGimnasio;
  final conBandas = Inventario.inicial().conBandas(const [
    BandaInventario(id: 'b1', nombre: 'v', orden: 1, cantidad: 2),
  ]);

  group('G6 · tiempos de 5.5 recalculados a mano (en segundos)', () {
    // calentamiento + cierre + Σ (45 + series × (trabajo + descanso)), con
    // trabajo = media de repeticiones × 4 s (por pierna ×2; plancha = segundos).
    const esperado = <String, int>{
      'A corta': 1758, // 29.3
      'A estandar': 2118, // 35.3
      'A larga': 3654, // 60.9 (con extras: flexiones y plancha)
      'B corta': 1758, // 29.3
      'B estandar': 2118, // 35.3
      'B larga': 3678, // 61.3 (con remo con banda y plancha)
      'C corta': 1875, // 31.2 (sin patada)
      'C estandar': 2748, // 45.8
      'C larga': 3789, // 63.1
    };
    for (final e in esperado.entries) {
      test(e.key, () {
        final p = e.key.split(' ');
        final s = generarSesion(
          catalogo: cat,
          plantillaId: p[0],
          version: VersionSesion.deId(p[1])!,
          inventario: conBandas,
          hoy: d(2026, 12, 3),
        );
        expect(s.duracionEstimadaSeg, e.value);
      });
    }

    test('B larga sin bandas pierde el remo con banda: 54.4 min', () {
      final s = generarSesion(
        catalogo: cat,
        plantillaId: 'B',
        version: VersionSesion.larga,
        inventario: Inventario.inicial(),
        hoy: d(2026, 12, 3),
      );
      expect(minutosConDecimal(s.duracionEstimadaSeg), '54.4');
    });

    test('A estándar no llega a 45 min (H-08): 35.3, dentro de 33 a 50', () {
      final s = generarSesion(
        catalogo: cat,
        plantillaId: 'A',
        version: VersionSesion.estandar,
        inventario: conBandas,
        hoy: d(2026, 12, 3),
      );
      expect(s.duracionEstimadaSeg / 60, closeTo(35.3, 0.05));
      expect(const ReglasGimnasio().dentroDeTolerancia(
        VersionSesion.estandar,
        s.duracionEstimadaSeg,
      ), isTrue);
    });
  });

  group('G6 · semana, 48 horas y bicicleta (con la semana reordenada)', () {
    List<AvisoSemana> rev(List<SesionProgramada> s) => revisarSemana(s, cat);

    test('plan por omisión: A lunes, C martes, B miércoles, R2 jueves, R1 viernes', () {
      expect(planSemanal(3).fila,
          ['A', 'C', 'B', 'descanso', 'descanso', 'bici', 'descanso']);
      expect(planSemanal(4).fila,
          ['A', 'C', 'B', 'descanso', 'R1', 'bici', 'descanso']);
      expect(planSemanal(5).fila, ['A', 'C', 'B', 'R2', 'R1', 'bici', 'descanso']);
    });

    test('A lunes 19:15 → B miércoles 19:15 = 48 h exactas: cumple', () {
      final a = SesionProgramada('A', d(2026, 11, 30, 19, 15));
      final b = SesionProgramada('B', d(2026, 12, 2, 19, 15));
      expect(b.inicio.difference(a.inicio).inMinutes, 48 * 60);
      expect(rev([a, b]), isEmpty);
    });

    test('C martes 19:15 → ruta del sábado 8:00 = 84 h 45 min: sin aviso', () {
      final c = SesionProgramada('C', d(2026, 12, 1, 19, 15));
      final bici = SesionProgramada('bici', d(2026, 12, 5, 8));
      expect(bici.inicio.difference(c.inicio).inMinutes, 84 * 60 + 45);
      expect(rev([c, bici]), isEmpty);
    });

    test('la semana completa por omisión no avisa nada', () {
      expect(
        rev([
          SesionProgramada('A', d(2026, 11, 30, 19, 15)),
          SesionProgramada('C', d(2026, 12, 1, 19, 15)),
          SesionProgramada('B', d(2026, 12, 2, 19, 15)),
          SesionProgramada('bici', d(2026, 12, 5, 8)),
        ]),
        isEmpty,
      );
    });

    test('el borde: 47 h cumple y 46 h 59 min avisa (tolerancia de 60 min)', () {
      final a = SesionProgramada('A', d(2026, 11, 30, 20));
      expect(
        rev([a, SesionProgramada('B', d(2026, 12, 2, 19))]),
        isEmpty,
      ); // 47 h
      expect(
        rev([a, SesionProgramada('B', d(2026, 12, 2, 18, 59))]),
        hasLength(1),
      ); // 46 h 59 min
    });

    test('C el jueves (36 h 45 min) y C el viernes (12 h) avisan; no bloquean', () {
      final bici = SesionProgramada('bici', d(2026, 12, 5, 8));
      final jue = rev([SesionProgramada('C', d(2026, 12, 3, 19, 15)), bici]);
      expect(jue.single.intervaloMin, 36 * 60 + 45);
      final vie = rev([SesionProgramada('C', d(2026, 12, 4, 20)), bici]);
      expect(vie.single.intervaloMin, 12 * 60);
      expect(vie.single.propuestas.first, AccionSemana.moverAlJueves);
    });
  });

  group('G6 · ciclo, descarga, reentrada y progresión', () {
    final inicio = d(2026, 11, 30);

    test('3 + 1 desde el lunes 30/nov: descarga el 21/dic y el ciclo nuevo el 28/dic', () {
      final esperado = {
        d(2026, 11, 30): (1, false),
        d(2026, 12, 7): (2, false),
        d(2026, 12, 14): (3, false),
        d(2026, 12, 21): (4, true),
        d(2026, 12, 28): (1, false),
      };
      esperado.forEach((fecha, v) {
        final c = semanaDelCiclo(hoy: fecha, inicioCiclo: inicio, cicloSemanas: 4)!;
        expect((c.numero, c.descarga), v, reason: '$fecha');
      });
      // Cualquier día de esa semana cuenta igual.
      expect(
        semanaDelCiclo(hoy: d(2026, 12, 27), inicioCiclo: inicio, cicloSemanas: 4)!
            .descarga,
        isTrue,
      );
      expect(
        semanaDelCiclo(hoy: d(2026, 12, 21), inicioCiclo: inicio, cicloSemanas: 0)!
            .descarga,
        isFalse,
      );
    });

    test('reentrada: 6 normal, 7 y 13 repite, 14 reentrada, 55 reentrada, 56 desde cero', () {
      final perfil = PerfilGimnasio(
        inicioCiclo: inicio,
        nivel: NivelGimnasio.intermedio,
      );
      ParametrosSemana sem(int? dias) => calcularSemana(
        hoy: d(2026, 12, 10),
        perfil: perfil,
        modoFoco: false,
        diasSinSesion: dias,
      );
      expect(sem(6).tipo, TipoSemana.carga);
      expect(sem(6).incrementos, isTrue);
      expect(sem(7).repiteCargas, isTrue);
      expect(sem(13).repiteCargas, isTrue);
      expect(sem(14).tipo, TipoSemana.reentrada);
      expect(sem(14).series, 2);
      expect(sem(14).bajarUnPaso, isTrue);
      expect(sem(55).bajarUnPaso, isTrue);
      expect(sem(56).cargasDePrueba, isTrue);
      expect(sem(null).cargasDePrueba, isTrue);
    });

    test('descarga: 2 series, mínimo del rango, una placa menos, sin subir', () {
      final perfil = PerfilGimnasio(
        inicioCiclo: inicio,
        nivel: NivelGimnasio.intermedio,
      );
      final s = calcularSemana(
        hoy: d(2026, 12, 22),
        perfil: perfil,
        modoFoco: false,
        diasSinSesion: 3,
      );
      expect(s.tipo, TipoSemana.descarga);
      expect(s.series, 2);
      expect(s.repsAlMinimo, isTrue);
      expect(s.bajarUnPaso, isTrue);
      expect(s.incrementos, isFalse);
    });

    test('doble progresión: 12-12-12 con esfuerzo 3 sube a placa 6 con objetivo 10', () {
      SesionRegistrada hecha(DateTime f, List<int> reps, int esfuerzo) =>
          SesionRegistrada(
            fecha: f,
            plantilla: 'A',
            version: VersionSesion.estandar,
            semanaTipo: TipoSemana.carga,
            estado: EstadoSesion.completa,
            plan: const [
              PlanEjercicioGuardado(
                ejercicioId: 'press_pecho',
                varianteId: 'press_pecho_estacion',
                series: 3,
                repsMin: 10,
                repsMax: 12,
              ),
            ],
            series: [
              for (var i = 0; i < reps.length; i++)
                SerieRegistrada(
                  ejercicioId: 'press_pecho',
                  varianteId: 'press_pecho_estacion',
                  n: i + 1,
                  reps: reps[i],
                  cargaPasos: 5,
                  esfuerzo: i == reps.length - 1 ? esfuerzo : null,
                ),
            ],
          );
      EjercicioPlanificado pedir(List<int> reps, int esfuerzo) => generarSesion(
        catalogo: cat,
        plantillaId: 'A',
        version: VersionSesion.estandar,
        inventario: Inventario.inicial(),
        hoy: d(2026, 12, 3),
        historial: [hecha(d(2026, 11, 30), reps, esfuerzo)],
        perfil: PerfilGimnasio(nivel: NivelGimnasio.intermedio),
      ).ejercicios.first;

      final sube = pedir([12, 12, 12], 3);
      expect(sube.cargaPasos, 6);
      expect(sube.objetivo, 10);
      expect(pedir([12, 12, 11], 3).cargaPasos, 5);
      expect(pedir([12, 12, 12], 5).cargaPasos, 5);
    });
  });

  group('G6 · invariantes sobre todas las combinaciones de inventario', () {
    test('ninguna sesión usa equipo ausente o futuro ni una zona con molestia moderada', () {
      final marcy = [
        'marcy.press',
        'marcy.polea_alta',
        'marcy.polea_baja',
        'marcy.cojin_curl',
      ];
      final otros = [
        'banco_inclinado',
        'caminadora',
        'ancla_puerta',
        'tobillera_polea',
        'colchoneta',
      ];
      final hoy = d(2026, 12, 3);
      var casos = 0;
      for (var mask = 0; mask < (1 << 10); mask++) {
        var inv = Inventario.inicial();
        var bit = 0;
        for (final p in marcy) {
          inv = inv.conItem(
            p,
            (mask >> bit++) & 1 == 1
                ? EstadoItem.disponible
                : EstadoItem.noDisponible,
          );
        }
        for (final o in otros) {
          inv = inv.conItem(
            o,
            (mask >> bit++) & 1 == 1
                ? EstadoItem.disponible
                : EstadoItem.noDisponible,
          );
        }
        if ((mask >> bit++) & 1 == 1) {
          inv = inv.conBandas(const [
            BandaInventario(id: 'b1', nombre: 'v', orden: 1),
          ]);
        }
        inv = inv.conItem('mancuernas', EstadoItem.futuro);
        for (final pl in ['A', 'B', 'C']) {
          for (final zona in [null, ...Zonas.todas]) {
            for (final inten in zona == null ? [0] : [1, 2, 3]) {
              final mol = zona == null
                  ? <Molestia>[]
                  : [
                      Molestia(
                        id: 'm',
                        zona: zona,
                        intensidad: inten,
                        desde: hoy,
                      ),
                    ];
              final s = generarSesion(
                catalogo: cat,
                plantillaId: pl,
                version: VersionSesion.estandar,
                inventario: inv,
                hoy: hoy,
                molestias: mol,
              );
              casos++;
              for (final e in s.ejercicios) {
                final v = cat.variante(e.varianteId)!;
                expect(inv.varianteDisponible(v, cat), isTrue,
                    reason: '${e.varianteId} con máscara $mask');
                expect(v.requiere, isNot(contains('mancuernas')));
                final i = intensidadQueAfecta(mol, cat.zonasDe(e.varianteId));
                expect(i, lessThan(2),
                    reason: '${e.varianteId} carga $zona con intensidad $inten');
                expect(e.conPrecaucion, i == 1);
                expect(e.series, allOf(greaterThanOrEqualTo(1), lessThanOrEqualTo(5)));
              }
              if (s.ejercicios.length < 3) {
                expect(s.tiene(CodigoAviso.sinEquipoSuficiente), isTrue,
                    reason: '$pl con máscara $mask y $zona');
              }
            }
          }
        }
      }
      expect(casos, greaterThan(90000));
    });
  });

  group('G6 · contenido: palabras de diagnóstico o tratamiento (por raíz)', () {
    // La prueba de G1 compara palabras enteras; aquí se buscan raíces para
    // atrapar derivados («lesionarte», «tendones», «tratarse»).
    const raices = [
      'lesion',
      'diagnos',
      'tratam',
      'terap',
      'medicam',
      'medicin',
      'dosis',
      'tendin',
      'tendon',
      'cartilag',
      'ligament',
      'menisc',
      'inflam',
      'desgarr',
      'esguinc',
      'hernia',
      'lumbalg',
      'ciatic',
      'artros',
      'artrit',
      'fractur',
      'luxac',
      'cirug',
      'pastill',
      'analges',
      'pomada',
      'garantiz',
      'promet',
      'adelgaz',
      'quemar',
    ];
    test('ningún texto del catálogo ni de los mensajes contiene esas raíces', () {
      final textos = textosDelModulo(cat);
      final malos = <String>[];
      for (final t in textos) {
        final s = t.toLowerCase();
        for (final r in raices) {
          // «diagnostica» sola está permitida: «Esta guía no diagnostica.»
          if (s.contains(r) && !(r == 'diagnos' && s.contains('no diagnostica'))) {
            malos.add('"$t" → $r');
          }
        }
      }
      expect(malos, isEmpty);
    });

    test('todo mensaje que habla de molestias termina en un profesional, un médico o un entrenador, o dice que no diagnostica', () {
      final habla = MensajesGimnasio.todos.where(
        (t) => t.toLowerCase().contains('molest') || t.toLowerCase().contains('zona'),
      );
      for (final t in habla) {
        final s = t.toLowerCase();
        final remite = s.contains('profesional') ||
            s.contains('médico') ||
            s.contains('entrenador') ||
            s.contains('no diagnostica') ||
            s.contains('solo en tu teléfono') ||
            s.contains('¿sigue');
        expect(remite, isTrue, reason: t);
      }
    });
  });
}

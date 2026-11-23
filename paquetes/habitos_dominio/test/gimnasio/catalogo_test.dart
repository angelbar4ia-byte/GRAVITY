import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

void main() {
  group('CA-G-01 integridad del catálogo', () {
    test('el catálogo inicial es íntegro', () {
      expect(validarCatalogo(cat), isEmpty);
    });

    test('ids únicos y en minúsculas sin acentos', () {
      final ids = [
        for (final e in cat.ejercicios) ...[
          e.id,
          for (final v in e.variantes) v.id,
        ],
        for (final i in cat.items) i.id,
      ];
      expect(ids.toSet().length, ids.length);
      final ok = RegExp(r'^[a-z0-9_.]+$');
      for (final id in ids) {
        expect(ok.hasMatch(id), isTrue, reason: id);
      }
    });

    test('cada ejercicio tiene variantes, cada slot candidatas y cada requiere existe', () {
      for (final e in cat.ejercicios) {
        expect(e.variantes, isNotEmpty, reason: e.id);
        for (final v in e.variantes) {
          for (final r in v.requiere) {
            expect(cat.item(r), isNotNull, reason: '${v.id} → $r');
          }
        }
      }
      for (final p in cat.plantillas) {
        for (final s in p.slots) {
          expect(s.candidatas, isNotEmpty, reason: s.id);
          for (final c in s.candidatas) {
            expect(cat.variante(c), isNotNull, reason: c);
          }
        }
      }
    });

    test('grupos y zonas son del catálogo y reps_min < reps_max', () {
      for (final e in cat.ejercicios) {
        expect(e.gruposPrimarios.every(Grupos.todos.contains), isTrue);
        expect(e.zonas.every(Zonas.todas.contains), isTrue);
        if (e.repsMin != null) {
          expect(e.repsMin! < e.repsMax!, isTrue, reason: e.id);
        }
      }
      for (final p in cat.plantillas) {
        for (final s in p.slots) {
          if (s.repsMin != null) {
            expect(s.repsMin! < s.repsMax!, isTrue, reason: s.id);
          }
        }
      }
    });

    test('CASO MALO: una variante con un requiere inexistente falla', () {
      final malo = Catalogo(
        version: 1,
        items: cat.items,
        datosAparato: const [],
        ejercicios: const [
          Ejercicio(
            id: 'x',
            nombre: 'X',
            patron: 'p',
            gruposPrimarios: [Grupos.pecho],
            zonas: [Zonas.hombro],
            explicacion: 'Texto.',
            repsMin: 8,
            repsMax: 12,
            variantes: [
              Variante(
                id: 'x_a',
                nombre: 'X',
                requiere: ['aparato_que_no_existe'],
                revision: RevisionContenido.borrador,
              ),
            ],
            revision: RevisionContenido.borrador,
          ),
        ],
        plantillas: const [],
        regenerativas: const [],
        bloques: const [],
      );
      final e = validarCatalogo(malo);
      expect(e.map((x) => x.codigo), contains('requiere_inexistente'));
    });

    test('CASO MALO: reps_min >= reps_max, id con acento, '
        'slot sin candidatas, zona y grupo inválidos', () {
      Catalogo con({
        int min = 8,
        int max = 12,
        String id = 'x',
        List<String> candidatas = const ['x_a'],
        List<String> zonas = const [Zonas.hombro],
        List<String> grupos = const [Grupos.pecho],
      }) => Catalogo(
        version: 1,
        items: cat.items,
        datosAparato: const [],
        ejercicios: [
          Ejercicio(
            id: id,
            nombre: 'X',
            patron: 'p',
            gruposPrimarios: grupos,
            zonas: zonas,
            explicacion: 'Texto.',
            repsMin: min,
            repsMax: max,
            variantes: const [
              Variante(
                id: 'x_a',
                nombre: 'X',
                revision: RevisionContenido.borrador,
              ),
            ],
            revision: RevisionContenido.borrador,
          ),
        ],
        plantillas: [
          PlantillaSesion(
            id: 'A',
            nombre: 'A',
            slots: [
              Slot(
                id: 'A1',
                nombre: 'a',
                candidatas: candidatas,
                repsMin: 8,
                repsMax: 12,
              ),
            ],
            revision: RevisionContenido.borrador,
          ),
        ],
        regenerativas: const [],
        bloques: const [],
      );
      List<String> codigos(Catalogo c) =>
          validarCatalogo(c).map((e) => e.codigo).toList();
      expect(codigos(con()), isEmpty);
      expect(codigos(con(min: 12, max: 12)), contains('rango_reps'));
      expect(codigos(con(min: 14, max: 10)), contains('rango_reps'));
      expect(codigos(con(id: 'presión')), contains('id_invalido'));
      expect(
        codigos(con(candidatas: const [])),
        contains('slot_sin_candidatas'),
      );
      expect(codigos(con(zonas: const ['dedo'])), contains('zona_invalida'));
      expect(codigos(con(grupos: const ['ala'])), contains('grupo_invalido'));
    });

    test(
      'un aparato `futuro` (solo dato) no puede ser requerido por una variante',
      () {
        final c = miniCatalogo(requiereSegunda: const ['mancuernas']);
        expect(
          validarCatalogo(c).map((e) => e.codigo),
          contains('requiere_equipo_futuro'),
        );
      },
    );
  });

  group('CA-G-02 las sesiones del diseño están (primera opción de cada slot)', () {
    ({int series, int? min, int? max, int? segMin, int? segMax}) primera(
      String plantilla,
      String slot,
    ) {
      final s = cat.plantilla(plantilla)!.slots.firstWhere((x) => x.id == slot);
      return (
        series: s.series,
        min: s.repsMin,
        max: s.repsMax,
        segMin: s.segundosMin,
        segMax: s.segundosMax,
      );
    }

    String variante0(String plantilla, String slot) => cat
        .plantilla(plantilla)!
        .slots
        .firstWhere((x) => x.id == slot)
        .candidatas
        .first;

    test(
      'A: press 3×10–12, laterales 3×12–15, tríceps 3×12, fondos 3×8–12',
      () {
        expect(variante0('A', 'A1'), 'press_pecho_estacion');
        expect(variante0('A', 'A2'), 'elevacion_lateral_polea_baja');
        expect(variante0('A', 'A3'), 'extension_triceps_polea_alta');
        expect(variante0('A', 'A4'), 'fondos_banco_piernas');
        expect(primera('A', 'A1'), (
          series: 3,
          min: 10,
          max: 12,
          segMin: null,
          segMax: null,
        ));
        expect(primera('A', 'A2'), (
          series: 3,
          min: 12,
          max: 15,
          segMin: null,
          segMax: null,
        ));
        // «3×12» se codifica como 10–14 (media 12): reps_min < reps_max.
        final a3 = primera('A', 'A3');
        expect(a3.series, 3);
        expect((a3.min! + a3.max!) / 2, 12);
        expect(primera('A', 'A4'), (
          series: 3,
          min: 8,
          max: 12,
          segMin: null,
          segMax: null,
        ));
      },
    );

    test('B: jalón, remo, face pull y curl en el cojín', () {
      expect(variante0('B', 'B1'), 'jalon_polea_alta');
      expect(variante0('B', 'B2'), 'remo_polea_baja');
      expect(variante0('B', 'B3'), 'face_pull_polea_alta');
      expect(variante0('B', 'B4'), 'curl_cojin');
      expect(primera('B', 'B1').min, 10);
      expect(primera('B', 'B3').max, 15);
    });

    test('C: sentadilla, subidas, puente, patada y plancha de 30 a 45 s', () {
      expect(variante0('C', 'C1'), 'sentadilla_banco_peso');
      expect(variante0('C', 'C2'), 'subida_banco_peso');
      expect(variante0('C', 'C3'), 'puente_banco');
      expect(variante0('C', 'C4'), 'patada_polea');
      expect(variante0('C', 'C5'), 'plancha_suelo');
      final c5 = primera('C', 'C5');
      expect((c5.segMin, c5.segMax), (30, 45));
      expect(primera('C', 'C1').min, 12);
      expect(primera('C', 'C1').max, 15);
    });

    test(
      'CASO MALO: las plantillas tienen los slots del diseño y ninguno de más',
      () {
        expect(
          [
            for (final s in cat.plantilla('A')!.slots.where((s) => !s.extra))
              s.id,
          ],
          ['A1', 'A2', 'A3', 'A4'],
        );
        expect(
          [for (final s in cat.plantilla('C')!.slots) s.id],
          ['C1', 'C2', 'C3', 'C4', 'C5'],
        );
        expect(
          cat
              .plantilla('C')!
              .slots
              .where((s) => s.omitirEnCorta)
              .map((s) => s.id),
          ['C4'],
        );
      },
    );

    test('grupos de cada plantilla (5.6)', () {
      expect(cat.gruposDePlantilla('A'), {
        Grupos.pecho,
        Grupos.hombro,
        Grupos.triceps,
      });
      expect(cat.gruposDePlantilla('B'), {
        Grupos.espalda,
        Grupos.hombro,
        Grupos.biceps,
      });
      expect(cat.gruposDePlantilla('C'), {
        Grupos.cuadriceps,
        Grupos.gluteo,
        Grupos.core,
      });
    });
  });

  group('CA-G-05 revisión', () {
    test('todo el contenido inicial nace borrador y la sesión lo dice', () {
      for (final e in cat.ejercicios) {
        expect(e.revision, RevisionContenido.borrador, reason: e.id);
        for (final v in e.variantes) {
          expect(v.revision, RevisionContenido.borrador, reason: v.id);
        }
      }
      for (final p in cat.plantillas) {
        expect(p.revision, RevisionContenido.borrador);
      }
      expect(cat.hayBorrador, isTrue);
      final s = generar('A');
      expect(s.contenidoEnRevision, isTrue);
      expect(s.tiene(CodigoAviso.contenidoEnRevision), isTrue);
      expect(MensajesGimnasio.contenidoEnRevision, 'Contenido en revisión');
    });

    test('con todo revisado desaparece', () {
      final s = generar(
        'A',
        catalogo: miniCatalogo(),
        inventario: inventarioBase(),
      );
      expect(s.contenidoEnRevision, isFalse);
      expect(s.tiene(CodigoAviso.contenidoEnRevision), isFalse);
    });

    test('un ejercicio, una variante o una plantilla borrador lo activa', () {
      for (final c in [
        miniCatalogo(ejercicio: RevisionContenido.borrador),
        miniCatalogo(variante: RevisionContenido.borrador),
        miniCatalogo(plantilla: RevisionContenido.borrador),
      ]) {
        expect(generar('A', catalogo: c).contenidoEnRevision, isTrue);
      }
    });

    test('CASO MALO: una variante nueva sin campo revision falla', () {
      final c = miniCatalogo(variante: null);
      expect(validarCatalogo(c).map((e) => e.codigo), contains('sin_revision'));
      expect(generar('A', catalogo: c).contenidoEnRevision, isTrue);
    });
  });
}

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

Map<String, RecordsVariante> calc(
  List<SesionRegistrada> h, {
  List<BandaInventario> bandas = const [],
}) => calcularRecords(h, cat, bandas: bandas);

void main() {
  group('CA-G-21 récords (calculados)', () {
    test('mejor carga: la más alta con al menos el mínimo del rango (10)', () {
      final h = [
        sesionHecha(
          fecha: dia(2026, 12, 1),
          reps: const [12, 12, 12],
          carga: 5,
        ),
        sesionHecha(
          fecha: dia(2026, 12, 4),
          reps: const [10, 10, 10],
          carga: 6,
        ),
        // La placa 8 con 6 repeticiones no cuenta (menos del mínimo).
        sesionHecha(fecha: dia(2026, 12, 7), reps: const [6, 6, 6], carga: 8),
      ];
      expect(calc(h)['press_pecho_estacion']!.mejorCargaPasos, 6);
    });

    test('mejores repeticiones: más repeticiones a una carga igual o mayor a la mejor', () {
      final h = [
        sesionHecha(
          fecha: dia(2026, 12, 1),
          reps: const [12, 12, 12],
          carga: 5,
        ),
        sesionHecha(
          fecha: dia(2026, 12, 4),
          reps: const [10, 11, 10],
          carga: 6,
        ),
      ];
      final r = calc(h)['press_pecho_estacion']!;
      expect(r.mejorCargaPasos, 6);
      expect(r.mejoresReps, 11); // las 12 fueron a la placa 5, menor que la 6
    });

    test('mejor tiempo: la plancha, más segundos en una serie', () {
      final h = [
        sesionHecha(
          fecha: dia(2026, 12, 1),
          plantilla: 'C',
          ejercicio: 'plancha',
          variante: 'plancha_suelo',
          segundos: const [30, 35, 32],
          carga: null,
        ),
        sesionHecha(
          fecha: dia(2026, 12, 4),
          plantilla: 'C',
          ejercicio: 'plancha',
          variante: 'plancha_suelo',
          segundos: const [40, 28, 30],
          carga: null,
        ),
      ];
      expect(calc(h)['plancha_suelo']!.mejorSegundos, 40);
    });

    test('mejor banda: la de mayor orden con el mínimo del rango', () {
      const bandas = [banda1, banda2];
      final h = [
        sesionHecha(
          fecha: dia(2026, 12, 1),
          ejercicio: 'curl_biceps',
          plantilla: 'B',
          variante: 'curl_banda',
          carga: null,
          bandaId: 'b1',
          reps: const [12, 12, 12],
        ),
        sesionHecha(
          fecha: dia(2026, 12, 4),
          ejercicio: 'curl_biceps',
          plantilla: 'B',
          variante: 'curl_banda',
          carga: null,
          bandaId: 'b2',
          reps: const [10, 10, 10],
        ),
        // La banda 2 con 4 repeticiones no cuenta.
        sesionHecha(
          fecha: dia(2026, 12, 8),
          ejercicio: 'curl_biceps',
          plantilla: 'B',
          variante: 'curl_banda',
          carga: null,
          bandaId: 'b2',
          reps: const [4, 4, 4],
        ),
      ];
      expect(calc(h, bandas: bandas)['curl_banda']!.mejorBandaOrden, 2);
      expect(
        calc(h.sublist(0, 1), bandas: bandas)['curl_banda']!.mejorBandaOrden,
        1,
      );
    });

    test('un día más flojo no quita un récord', () {
      final h = [
        sesionHecha(
          fecha: dia(2026, 12, 1),
          reps: const [12, 12, 12],
          carga: 6,
        ),
        sesionHecha(
          fecha: dia(2026, 12, 4),
          reps: const [10, 10, 10],
          carga: 4,
        ),
      ];
      expect(calc(h)['press_pecho_estacion']!.mejorCargaPasos, 6);
    });

    test('corregir o deshacer una serie recalcula', () {
      final buena = sesionHecha(
        fecha: dia(2026, 12, 4),
        reps: const [10, 10, 10],
        carga: 7,
      );
      final previa = sesionHecha(fecha: dia(2026, 12, 1), carga: 5);
      expect(calc([previa, buena])['press_pecho_estacion']!.mejorCargaPasos, 7);
      // Se deshace la sesión de la placa 7: vuelve a 5.
      expect(calc([previa])['press_pecho_estacion']!.mejorCargaPasos, 5);
      // Se corrige: la placa 7 solo se hizo con 8 repeticiones.
      final corregida = sesionHecha(
        fecha: dia(2026, 12, 4),
        reps: const [8, 8, 8],
        carga: 7,
      );
      expect(
        calc([previa, corregida])['press_pecho_estacion']!.mejorCargaPasos,
        5,
      );
    });

    test('polea y cojín no se mezclan', () {
      final h = [
        sesionHecha(
          fecha: dia(2026, 12, 1),
          plantilla: 'B',
          ejercicio: 'curl_biceps',
          variante: 'curl_cojin',
          carga: 4,
        ),
        sesionHecha(
          fecha: dia(2026, 12, 2),
          plantilla: 'B',
          ejercicio: 'curl_biceps',
          variante: 'curl_polea_baja',
          carga: 9,
        ),
      ];
      final r = calc(h);
      expect(r['curl_cojin']!.mejorCargaPasos, 4);
      expect(r['curl_polea_baja']!.mejorCargaPasos, 9);
    });

    test('CASO MALO: una regenerativa no produce récords ni series', () {
      final regen = SesionRegistrada(
        fecha: dia(2026, 12, 2),
        plantilla: 'R1',
        version: VersionSesion.estandar,
        series: const [
          SerieRegistrada(
            ejercicioId: 'press_pecho',
            varianteId: 'press_pecho_estacion',
            n: 1,
            reps: 50,
            cargaPasos: 50,
          ),
        ],
      );
      expect(calc([regen]), isEmpty);
    });

    test('récords nuevos: solo lo que supera el historial', () {
      final antes = [sesionHecha(fecha: dia(2026, 12, 1), carga: 5)];
      final nueva = sesionHecha(
        fecha: dia(2026, 12, 4),
        reps: const [10, 10, 10],
        carga: 6,
      );
      final r = recordsNuevos(antes, nueva, cat);
      expect(r.single.tipo, 'carga');
      expect(r.single.valor, 6);
      expect(
        MensajesGimnasio.recordPersonal(
          'press de pecho',
          'placa ${r.single.valor}',
        ),
        'Nuevo récord personal en press de pecho: placa 6.',
      );
      final igual = sesionHecha(
        fecha: dia(2026, 12, 4),
        reps: const [10, 10, 10],
        carga: 5,
      );
      expect(recordsNuevos(antes, igual, cat), isEmpty);
    });
  });
}

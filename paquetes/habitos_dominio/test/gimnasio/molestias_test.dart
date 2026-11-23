import 'dart:convert';

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

Molestia m(String zona, int intensidad, {DateTime? desde}) => Molestia(
  id: 'm_$zona$intensidad',
  zona: zona,
  intensidad: intensidad,
  desde: desde ?? dia(2026, 11, 1),
);

void main() {
  group('CA-G-22 filtro por molestia (sin diagnosticar)', () {
    test(
      'hombro leve: el press de A queda «con precaución»; la persona decide',
      () {
        final s = generar(
          'A',
          molestias: [m(Zonas.hombro, 1)],
          inventario: conBandas(ancla: true),
        );
        final press = s.ejercicios.first;
        expect(press.varianteId, 'press_pecho_estacion');
        expect(press.conPrecaucion, isTrue);
        expect(s.tiene(CodigoAviso.conPrecaucion), isTrue);
        // Todas las alternativas del slot cargan el hombro: se ofrecen, pero
        // marcadas «con precaución» (no existe una alternativa sin esa zona).
        expect(press.alternativas, isNotEmpty);
        expect(
          press.alternativas.every(
            (a) => a.motivo == MotivoAlternativa.conPrecaucion,
          ),
          isTrue,
        );
      },
    );

    test('leve con alternativa sin esa zona: se ofrece (catálogo chico)', () {
      final c = miniCatalogo();
      final s = generar('A', catalogo: c, molestias: [m(Zonas.rodilla, 1)]);
      final x1 = s.ejercicios.first;
      expect(x1.varianteId, 'x1_a'); // se mantiene: la persona decide
      expect(x1.conPrecaucion, isTrue);
      final alt = x1.alternativas.single;
      expect(alt.varianteId, 'x1_b');
      expect(alt.motivo, isNot(MotivoAlternativa.conPrecaucion));
    });

    test('moderada: se sustituye por la siguiente variante sin esa zona', () {
      final c = miniCatalogo();
      final s = generar('A', catalogo: c, molestias: [m(Zonas.rodilla, 2)]);
      final x1 = s.ejercicios.first;
      expect(x1.varianteId, 'x1_b');
      expect(x1.conPrecaucion, isFalse);
      expect(s.omitidos, isEmpty);
    });

    test('moderada sin variante alternativa: se omite el slot y se ofrece con precaución', () {
      final s = generar('A', molestias: [m(Zonas.hombro, 2)]);
      // Todo lo de A carga el hombro: ningún slot se ocupa solo.
      expect(s.ejercicios, isEmpty);
      expect(s.omitidos.map((o) => o.slotId), ['A1', 'A2', 'A3', 'A4']);
      expect(
        s.omitidos.every((o) => o.razon == RazonOmision.precaucion),
        isTrue,
      );
      expect(
        s.omitidos.first.opcionesConPrecaucion,
        contains('press_pecho_estacion'),
      );
      expect(s.tiene(CodigoAviso.sinEquipoSuficiente), isTrue);
    });

    test('moderada en cuello: solo se omite el slot que lo carga', () {
      final s = generar('A', molestias: [m(Zonas.cuello, 2)]);
      expect(s.omitidos.map((o) => o.slotId), ['A2']);
      expect(s.ejercicios.map((e) => e.slotId), ['A1', 'A3', 'A4']);
    });

    test(
      'fuerte: además el aviso de consultar a un profesional y la regenerativa',
      () {
        final s = generar('A', molestias: [m(Zonas.hombro, 3)]);
        expect(s.tiene(CodigoAviso.molestiaFuerte), isTrue);
        expect(s.tiene(CodigoAviso.ofrecerRegenerativa), isTrue);
        for (final palabra in ['profesional', 'médico', 'entrenador']) {
          expect(MensajesGimnasio.molestiaFuerte, contains(palabra));
        }
        // Una molestia en otra zona no dispara el aviso en esta sesión.
        expect(
          generar(
            'C',
            molestias: [m(Zonas.hombro, 3)],
          ).tiene(CodigoAviso.molestiaFuerte),
          isTrue,
        ); // la plancha carga el hombro
        expect(
          generar(
            'B',
            molestias: [m(Zonas.rodilla, 3)],
          ).tiene(CodigoAviso.molestiaFuerte),
          isFalse,
        );
      },
    );

    test('ninguna salida nombra una lesión ni un tratamiento', () {
      final s = generar('A', molestias: [m(Zonas.hombro, 3), m(Zonas.codo, 2)]);
      // La sesión no lleva texto: solo códigos.
      expect(s.avisos.map((a) => a.codigo.name).join(' '), isNotEmpty);
      for (final a in s.avisos) {
        expect(palabrasMedicasEn(a.toString()), isEmpty);
      }
      for (final t in [
        MensajesGimnasio.molestiaFuerte,
        MensajesGimnasio.molestiaCambio,
        MensajesGimnasio.molestiaConPrecaucion,
        MensajesGimnasio.sigueLaMolestia,
      ]) {
        expect(palabrasMedicasEn(t), isEmpty, reason: t);
      }
    });

    test(
      'CASO MALO: una molestia cerrada o una zona inválida no filtra nada',
      () {
        final cerrada = m(Zonas.hombro, 3).yaNo(dia(2026, 11, 20));
        expect(generar('A', molestias: [cerrada]).omitidos, isEmpty);
        final rara = Molestia(
          id: 'x',
          zona: 'dedo',
          intensidad: 3,
          desde: dia(2026, 11, 1),
        );
        expect(rara.valida, isFalse);
        expect(generar('A', molestias: [rara]).omitidos, isEmpty);
      },
    );

    test('la escalera nunca empuja a una zona con molestia, y el filtro usa las zonas '
        'propias de la variante', () {
      expect(cat.zonasDe('patada_cuadrupedia'), contains(Zonas.rodilla));
      expect(cat.zonasDe('patada_polea'), isNot(contains(Zonas.rodilla)));
      expect(
        intensidadQueAfecta([m(Zonas.rodilla, 2)], cat.zonasDe('patada_polea')),
        0,
      );
      expect(
        intensidadQueAfecta([
          m(Zonas.rodilla, 2),
        ], cat.zonasDe('patada_cuadrupedia')),
        2,
      );
    });

    test('cada 14 días sin cambios se pregunta «¿Sigue esta molestia?»', () {
      final x = m(Zonas.hombro, 1, desde: dia(2026, 11, 1));
      expect(x.debePreguntarSigue(dia(2026, 11, 14)), isFalse);
      expect(x.debePreguntarSigue(dia(2026, 11, 15)), isTrue);
      final sigue = x.sigue(dia(2026, 11, 15));
      expect(sigue.activa, isTrue);
      expect(sigue.debePreguntarSigue(dia(2026, 11, 20)), isFalse);
      expect(sigue.debePreguntarSigue(dia(2026, 11, 29)), isTrue);
      expect(
        x.yaNo(dia(2026, 11, 16)).debePreguntarSigue(dia(2026, 12, 30)),
        isFalse,
      );
    });
  });

  group('PG-19 y PG-03: las molestias no salen del dispositivo', () {
    test('el motivo de cambio que viaja nunca es «molestia»', () {
      expect(MotivoCambio.values.map((v) => v.id), [
        'no_disponible',
        'preferencia',
        'otra',
      ]);
      expect(MotivoCambioLocal.molestia.paraServidor, MotivoCambio.otra);
      expect(MotivoCambioLocal.noDisponible.paraServidor.id, 'no_disponible');
      for (final v in MotivoCambioLocal.values) {
        expect(v.paraServidor.id, isNot('molestia'));
      }
    });

    test(
      'las filas del servidor no tienen campo de molestia, zona ni dolor',
      () {
        const columnasSerie = {
          'id',
          'sesion_id',
          'ejercicio_id',
          'variante_id',
          'n',
          'lado',
          'reps',
          'segundos',
          'carga_pasos',
          'banda_id',
          'esfuerzo',
          'descanso_real_s',
          'sustituye_a',
          'motivo_cambio',
        };
        const columnasSesion = {
          'id',
          'fecha',
          'plantilla',
          'version',
          'semana_tipo',
          'ventana',
          'bloque_id',
          'inicio',
          'fin',
          'estado',
          'esfuerzo',
          'energia',
          'plan',
          'catalogo_version',
        };
        final s = sesionHecha(fecha: dia(2026, 12, 1));
        expect(s.aJsonServidor(id: 'i').keys.toSet(), columnasSesion);
        expect(
          s.series.first.aJsonServidor(id: 'i', sesionId: 's').keys.toSet(),
          columnasSerie,
        );
        final serie = SerieRegistrada(
          ejercicioId: 'press_pecho',
          varianteId: 'press_pecho_estacion',
          n: 1,
          sustituyeA: 'press_pecho_banda_puerta',
          motivoCambio: MotivoCambioLocal.molestia.paraServidor,
        ).aJsonServidor(id: 'i', sesionId: 's');
        expect(serie['motivo_cambio'], 'otra');
      },
    );

    test(
      'CASO MALO: aunque haya molestias, nada de lo que se guarda las menciona',
      () {
        final molestias = [m(Zonas.hombro, 2), m(Zonas.codo, 3)];
        final s = generar(
          'A',
          molestias: molestias,
          inventario: conBandas(ancla: true),
        );
        final plan = s.aResumenPlan();
        final registrada = SesionRegistrada(
          fecha: dia(2026, 12, 3),
          plantilla: 'A',
          version: VersionSesion.estandar,
          plan: plan,
          series: [
            SerieRegistrada(
              ejercicioId: 'extension_triceps',
              varianteId: 'extension_triceps_banda_puerta',
              n: 1,
              reps: 12,
              sustituyeA: 'extension_triceps_polea_alta',
              motivoCambio: MotivoCambioLocal.molestia.paraServidor,
            ),
          ],
        );
        final texto = jsonEncode({
          'sesion': registrada.aJsonServidor(id: 'i'),
          'serie': registrada.series.first.aJsonServidor(
            id: 'j',
            sesionId: 'i',
          ),
        }).toLowerCase();
        for (final prohibida in [
          'molestia',
          'zona',
          'dolor',
          'precaucion',
          'hombro',
          'codo',
          'intensidad',
        ]) {
          expect(texto.contains(prohibida), isFalse, reason: prohibida);
        }
      },
    );

    test(
      'la molestia solo se convierte a un mapa LOCAL (sin formatos de nube)',
      () {
        final x = m(Zonas.hombro, 2);
        final mapa = x.aMapaLocal();
        expect(mapa['zona'], 'hombro');
        final volver = Molestia.deMapaLocal(x.id, mapa);
        expect(
          (volver.zona, volver.intensidad, volver.activa),
          ('hombro', 2, true),
        );
      },
    );
  });
}

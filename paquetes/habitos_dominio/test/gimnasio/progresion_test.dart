import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

EjercicioPlanificado press(
  List<int> reps,
  int? esfuerzo, {
  int? seriesPlan,
  int carga = 5,
  int dias = 2,
}) {
  final h = [
    sesionHecha(
      fecha: dia(2026, 12, 1),
      reps: reps,
      esfuerzoUltima: esfuerzo,
      carga: carga,
      seriesPlan: seriesPlan,
    ),
  ];
  return generar(
    'A',
    historial: h,
    hoy: dia(2026, 12, 1 + dias),
  ).ejercicios.first;
}

/// Simula sesiones consecutivas de [plantilla] en las que la persona
/// **siempre** cumple lo planeado (todas las series al máximo del rango).
/// Devuelve el primer ejercicio de cada sesión.
List<EjercicioPlanificado> simular(
  String plantilla,
  Inventario inv, {
  int sesiones = 8,
  int cargaInicial = 10,
  VersionSesion version = VersionSesion.estandar,
  List<Molestia> molestias = const [],
}) {
  final historial = <SesionRegistrada>[];
  final primeros = <EjercicioPlanificado>[];
  var fecha = dia(2026, 12, 1);
  for (var i = 0; i < sesiones; i++) {
    final s = generar(
      plantilla,
      version: version,
      inventario: inv,
      historial: historial,
      hoy: fecha,
      molestias: molestias,
    );
    primeros.add(s.ejercicios.first);
    final series = <SerieRegistrada>[];
    for (final e in s.ejercicios) {
      final v = cat.variante(e.varianteId)!;
      for (var n = 1; n <= e.series; n++) {
        series.add(
          SerieRegistrada(
            ejercicioId: e.ejercicioId,
            varianteId: e.varianteId,
            n: n,
            reps: e.porTiempo ? null : e.rangoMax,
            segundos: e.porTiempo ? e.rangoMax : null,
            cargaPasos: v.carga == TipoCarga.pila
                ? (e.cargaPasos ?? cargaInicial)
                : null,
            bandaId: v.carga == TipoCarga.banda ? (e.bandaId ?? 'b1') : null,
            bandaDoble: e.bandaDoble,
          ),
        );
      }
    }
    historial.add(
      SesionRegistrada(
        fecha: fecha,
        plantilla: plantilla,
        version: version,
        plan: s.aResumenPlan(),
        series: series,
      ),
    );
    fecha = sumarDias(fecha, 3);
  }
  return primeros;
}

void main() {
  group('CA-G-16 doble progresión (5.8)', () {
    test('12-12-12 con esfuerzo 3 sube a la placa 6 con objetivo de 10', () {
      final e = press([12, 12, 12], 3);
      expect(e.cargaPasos, 6);
      expect(e.objetivo, 10);
      expect(e.motivo, MotivoProgresion.subeCarga);
      expect(e.series, 3);
    });

    test(
      '12-12-11 mantiene la placa 5; el objetivo es completar 12 en todas',
      () {
        final e = press([12, 12, 11], 3);
        expect(e.cargaPasos, 5);
        expect(e.objetivo, 12);
        expect(e.motivo, MotivoProgresion.mantiene);
      },
    );

    test('12-12-12 con esfuerzo 5 en la última mantiene la placa 5', () {
      final e = press([12, 12, 12], 5);
      expect(e.cargaPasos, 5);
      expect(e.objetivo, 12);
    });

    test(
      'sin esfuerzo registrado se asume 3 (sube); con 4 sube y con 5 no',
      () {
        expect(press([12, 12, 12], null).cargaPasos, 6);
        expect(press([12, 12, 12], 4).cargaPasos, 6);
        expect(press([12, 12, 12], 5).cargaPasos, 5);
      },
    );

    test('sesión saltada: sin cambio (se compara con la última vez)', () {
      for (final dias in [1, 2, 4, 6]) {
        expect(
          press([12, 12, 12], 3, dias: dias).cargaPasos,
          6,
          reason: '$dias días',
        );
      }
    });

    test('CASO MALO: se hicieron menos series de las planeadas, no sube', () {
      final e = press([12, 12], 3, seriesPlan: 3);
      expect(e.cargaPasos, 5);
      expect(e.motivo, MotivoProgresion.mantiene);
    });

    test('primera vez: sin carga sugerida (la primera serie fija el punto de partida)', () {
      final e = generar('A').ejercicios.first;
      expect(e.cargaPasos, isNull);
      expect(e.motivo, MotivoProgresion.primeraVez);
      expect(e.objetivo, 10);
    });

    test('la carga se compara por variante: polea y cojín no se mezclan', () {
      final h = [
        sesionHecha(
          fecha: dia(2026, 12, 1),
          plantilla: 'B',
          ejercicio: 'curl_biceps',
          variante: 'curl_polea_baja',
          reps: const [12, 12, 12],
          carga: 8,
        ),
      ];
      // B4 usa el cojín: sin historial en el cojín, es primera vez.
      final curl = generar('B', historial: h).ejercicios.last;
      expect(curl.varianteId, 'curl_cojin');
      expect(curl.motivo, MotivoProgresion.primeraVez);
      expect(curl.cargaPasos, isNull);
    });
  });

  group('CA-G-17 escalera sin carga', () {
    test('con el tope confirmado: los peldaños se aplican en orden y ninguno se salta', () {
      final inv = inventarioBase().confirmando(CamposAparato.pasosMax, 10);
      final m = simular('A', inv, sesiones: 8).map((e) => e.motivo).toList();
      expect(m, [
        MotivoProgresion.primeraVez,
        MotivoProgresion.escaleraRepeticiones,
        MotivoProgresion.escaleraSeries,
        MotivoProgresion.escaleraTempo,
        MotivoProgresion.escaleraDescanso,
        MotivoProgresion.escaleraAgotada,
        MotivoProgresion.escaleraAgotada,
        MotivoProgresion.escaleraAgotada,
      ]);
    });

    test('cada peldaño cambia solo lo suyo', () {
      final inv = inventarioBase().confirmando(CamposAparato.pasosMax, 10);
      final e = simular('A', inv, sesiones: 5);
      // 0 primera vez: rango 10–12, 3 series, tempo 2-1-1, 60 s.
      expect(
        (e[0].rangoMax, e[0].series, e[0].tempo, e[0].descansoS),
        (12, 3, '2-1-1', 60),
      );
      // 1 más repeticiones: techo +3 (10–15), el objetivo vuelve al mínimo.
      expect(
        (e[1].rangoMin, e[1].rangoMax, e[1].objetivo, e[1].series),
        (10, 15, 10, 3),
      );
      // 2 más series: de 3 a 4 (tope 4 fuera de la larga).
      expect((e[2].series, e[2].rangoMax, e[2].tempo), (4, 15, '2-1-1'));
      // 3 tempo más lento: 3-1-1.
      expect((e[3].tempo, e[3].series, e[3].descansoS), ('3-1-1', 4, 60));
      // 4 menos descanso: de 60 a 45 s.
      expect((e[4].descansoS, e[4].tempo), (45, '3-1-1'));
      // La carga no pasa de la última placa.
      for (final x in e.skip(1)) {
        expect(x.cargaPasos, 10);
        expect(x.cargaPasos! <= 10, isTrue);
      }
      expect(e[1].topeDePila, isTrue);
    });

    test('en la versión larga las series llegan a 5', () {
      final inv = inventarioBase().confirmando(CamposAparato.pasosMax, 10);
      final e = simular('A', inv, sesiones: 4, version: VersionSesion.larga);
      expect(e[0].series, 4);
      expect(e[2].series, 5);
    });

    test('peso corporal y banda: seis peldaños, con la variante más difícil y las bandas', () {
      final inv = conBandas();
      final m = simular('C', inv, sesiones: 20);
      final orden = <MotivoProgresion>[];
      for (final e in m) {
        if (orden.isEmpty || orden.last != e.motivo) orden.add(e.motivo);
      }
      // Sentadilla con peso corporal: repeticiones, series, tempo, descanso y
      // luego la variante de banda (nunca antes).
      final i = orden.indexOf(MotivoProgresion.escaleraVariante);
      expect(orden.sublist(0, i + 1), [
        MotivoProgresion.primeraVez,
        MotivoProgresion.escaleraRepeticiones,
        MotivoProgresion.escaleraSeries,
        MotivoProgresion.escaleraTempo,
        MotivoProgresion.escaleraDescanso,
        MotivoProgresion.escaleraVariante,
      ]);
      expect(m[i].varianteId, 'sentadilla_banco_banda');
      // Con la banda: los mismos peldaños y al final, la banda siguiente.
      final banda = [
        for (final e in m)
          if (e.varianteId == 'sentadilla_banco_banda') e,
      ];
      expect(
        banda.map((e) => e.motivo),
        contains(MotivoProgresion.escaleraBanda),
      );
      final pasos = [
        for (final e in banda)
          if (e.motivo == MotivoProgresion.escaleraBanda)
            (e.bandaId, e.bandaDoble),
      ];
      // b1 → dos b1 juntas → b2.
      expect(pasos.first, ('b1', true));
      expect(pasos, contains(('b2', false)));
      final ultimo = banda.last;
      expect(ultimo.motivo, MotivoProgresion.escaleraAgotada);
    });

    test('sin confirmar el tope NO se ofrece la escalera: sube de placa', () {
      final e = simular('A', inventarioBase(), sesiones: 4);
      expect(e.map((x) => x.motivo), [
        MotivoProgresion.primeraVez,
        MotivoProgresion.subeCarga,
        MotivoProgresion.subeCarga,
        MotivoProgresion.subeCarga,
      ]);
      expect([for (final x in e.skip(1)) x.cargaPasos], [11, 12, 13]);
    });

    test('...salvo que la persona marque «ya estoy en la última placa»', () {
      final h = [sesionHecha(fecha: dia(2026, 12, 1), carga: 10)];
      final sin = generar('A', historial: h).ejercicios.first;
      expect(sin.motivo, MotivoProgresion.subeCarga);
      final con = generar(
        'A',
        historial: h,
        ultimaPlaca: {'press_pecho_estacion'},
      ).ejercicios.first;
      expect(con.motivo, MotivoProgresion.escaleraRepeticiones);
      expect(con.cargaPasos, 10);
      expect(con.topeDePila, isTrue);
      expect(
        generar(
          'A',
          historial: h,
          ultimaPlaca: {'press_pecho_estacion'},
        ).tiene(CodigoAviso.topeDePila),
        isTrue,
      );
    });

    test('CASO MALO: subir una placa más allá de pasos_max falla', () {
      final inv = inventarioBase().confirmando(CamposAparato.pasosMax, 10);
      expect(inv.cargaValida(11), isFalse);
      // Aun con el esfuerzo bajo y todas las series al máximo, la carga
      // sugerida nunca pasa de la última placa.
      final h = [
        sesionHecha(fecha: dia(2026, 12, 1), carga: 10, esfuerzoUltima: 1),
      ];
      final e = generar('A', historial: h, inventario: inv).ejercicios.first;
      expect(e.cargaPasos, 10);
      expect(e.motivo, isNot(MotivoProgresion.subeCarga));
    });

    test(
      'el peldaño de la variante más difícil no empuja a una zona con molestia',
      () {
        final rodilla = Molestia(
          id: 'm',
          zona: Zonas.rodilla,
          intensidad: 1,
          desde: dia(2026, 11, 1),
        );
        final m = simular('C', conBandas(), sesiones: 12, molestias: [rodilla]);
        expect(m.map((e) => e.varianteId).toSet(), {'sentadilla_banco_peso'});
        expect(
          m.map((e) => e.motivo),
          isNot(contains(MotivoProgresion.escaleraVariante)),
        );
        expect(m.last.motivo, MotivoProgresion.escaleraAgotada);
      },
    );
  });
}

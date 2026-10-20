import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  final festivos2026 = CalendarioFijo.deDias(festivosOficialesMexico(2026));

  group('Fin de semana y festivos (5.1; decisiones 44 y 55)', () {
    test('IN2: la quincena del sábado 31/oct/2026 se paga el lunes 2/nov', () {
      expect(
        ajustarADiaHabil(
          Fecha(2026, 10, 31),
          ReglaDiaInhabil.siguienteDiaHabil,
          festivos2026,
        ),
        Fecha(2026, 11, 2),
      );
    });

    test('domingo pasa al lunes; día hábil no se mueve', () {
      final cal = CalendarioFijo.vacio;
      expect(
        ajustarADiaHabil(
          Fecha(2026, 11, 1),
          ReglaDiaInhabil.siguienteDiaHabil,
          cal,
        ),
        Fecha(2026, 11, 2),
      );
      expect(
        ajustarADiaHabil(
          Fecha(2026, 10, 29),
          ReglaDiaInhabil.siguienteDiaHabil,
          cal,
        ),
        Fecha(2026, 10, 29),
      );
    });

    test(
      '15/nov/2026 (domingo): lunes 16 sin festivos; martes 17 con ellos',
      () {
        // El diseño (5.6 bis, punto 5) dice "se paga el lunes 16/nov", pero el
        // lunes 16/nov/2026 es el tercer lunes de noviembre (Día de la
        // Revolución, LFT art. 74): con el calendario oficial pasa al martes.
        expect(
          ajustarADiaHabil(
            Fecha(2026, 11, 15),
            ReglaDiaInhabil.siguienteDiaHabil,
            CalendarioFijo.vacio,
          ),
          Fecha(2026, 11, 16),
        );
        expect(
          ajustarADiaHabil(
            Fecha(2026, 11, 15),
            ReglaDiaInhabil.siguienteDiaHabil,
            festivos2026,
          ),
          Fecha(2026, 11, 17),
        );
      },
    );

    test('regla del día hábil anterior y sin cambio', () {
      expect(
        ajustarADiaHabil(
          Fecha(2026, 11, 16),
          ReglaDiaInhabil.diaHabilAnterior,
          festivos2026,
        ),
        Fecha(2026, 11, 13), // viernes
      );
      expect(
        ajustarADiaHabil(
          Fecha(2026, 11, 1),
          ReglaDiaInhabil.sinCambio,
          festivos2026,
        ),
        Fecha(2026, 11, 1),
      );
    });

    test('festivo inyectado por el hogar', () {
      final cal = CalendarioFijo([Fecha(2026, 11, 2)]); // p. ej., día personal
      expect(
        ajustarADiaHabil(
          Fecha(2026, 10, 31),
          ReglaDiaInhabil.siguienteDiaHabil,
          cal,
        ),
        Fecha(2026, 11, 3),
      );
      expect(esDiaHabil(Fecha(2026, 11, 2), cal), isFalse);
      expect(esDiaHabil(Fecha(2026, 11, 2), CalendarioFijo.vacio), isTrue);
    });

    test('un calendario imposible avisa en lugar de ciclar', () {
      final todo = _TodoInhabil();
      expect(
        () => ajustarADiaHabil(
          Fecha(2026, 1, 1),
          ReglaDiaInhabil.siguienteDiaHabil,
          todo,
        ),
        throwsStateError,
      );
    });
  });

  group('Precarga de festivos oficiales (LFT art. 74)', () {
    test('2026', () {
      final fechas = festivosOficialesMexico(2026).map((d) => d.fecha).toList();
      expect(fechas, [
        Fecha(2026, 1, 1),
        Fecha(2026, 2, 2), // primer lunes de febrero
        Fecha(2026, 3, 16), // tercer lunes de marzo
        Fecha(2026, 5, 1),
        Fecha(2026, 9, 16),
        Fecha(2026, 11, 16), // tercer lunes de noviembre
        Fecha(2026, 12, 25),
      ]);
      expect(
        festivosOficialesMexico(2026).first.fuente,
        contains('LFT art. 74'),
      );
    });

    test('1 de octubre solo en años de transmisión del Ejecutivo', () {
      bool tieneOctubre(int anio) =>
          festivosOficialesMexico(anio)
              .any((d) => d.fecha == Fecha(anio, 10, 1));
      expect(tieneOctubre(2030), isTrue);
      expect(tieneOctubre(2026), isFalse);
      expect(tieneOctubre(2029), isFalse);
    });

    test('n-ésimo lunes', () {
      expect(nEsimoLunes(2026, 11, 1), Fecha(2026, 11, 2));
      expect(nEsimoLunes(2026, 11, 3), Fecha(2026, 11, 16));
      expect(nEsimoLunes(2027, 2, 1), Fecha(2027, 2, 1));
    });
  });

  group('Fechas de pago por forma de ingreso (5.1)', () {
    final oct26 = Fecha(2026, 10, 26);
    final nov22 = Fecha(2026, 11, 22);

    test('quincenal 15 y último, con la regla de fin de semana', () {
      final pagos = CalendarioPago.quincenal().fechasDePago(
        Fecha(2026, 10, 1),
        Fecha(2026, 11, 30),
        festivos2026,
      );
      expect(pagos.map((p) => p.ajustada), [
        Fecha(2026, 10, 15),
        Fecha(2026, 11, 2), // sábado 31/oct
        Fecha(2026, 11, 17), // domingo 15/nov → lunes festivo → martes
        Fecha(2026, 11, 30),
      ]);
      expect(pagos[1].programada, Fecha(2026, 10, 31));
      expect(pagos[1].seMovio, isTrue);
    });

    test('un pago del sábado anterior al rango cae dentro ya ajustado', () {
      final pagos = CalendarioPago.mensual(DiaDelMes.ultimo)
          .fechasDePago(Fecha(2026, 11, 2), Fecha(2026, 11, 8), festivos2026);
      expect(pagos, [FechaPago(Fecha(2026, 10, 31), Fecha(2026, 11, 2))]);
    });

    test('mensual con día 31 en meses cortos se toma el último día', () {
      final pagos = CalendarioPago.mensual(
        const DiaDelMes(31),
        regla: ReglaDiaInhabil.sinCambio,
      ).fechasNominales(Fecha(2026, 1, 1), Fecha(2026, 4, 30));
      expect(pagos, [
        Fecha(2026, 1, 31),
        Fecha(2026, 2, 28),
        Fecha(2026, 3, 31),
        Fecha(2026, 4, 30),
      ]);
    });

    test('semanal y catorcenal', () {
      final viernes = CalendarioPago.semanal(DateTime.friday)
          .fechasDePago(oct26, nov22, festivos2026)
          .map((p) => p.ajustada);
      expect(viernes, [
        Fecha(2026, 10, 30),
        Fecha(2026, 11, 6),
        Fecha(2026, 11, 13),
        Fecha(2026, 11, 20),
      ]);

      final catorcena = CalendarioPago.catorcenal(Fecha(2026, 10, 2))
          .fechasDePago(oct26, nov22, festivos2026)
          .map((p) => p.ajustada);
      expect(catorcena, [Fecha(2026, 10, 30), Fecha(2026, 11, 13)]);
    });

    test(
      'mes con tres catorcenas: aparecen las tres (el flujo las muestra)',
      () {
        final pagos = CalendarioPago.catorcenal(
          Fecha(2026, 1, 2),
          regla: ReglaDiaInhabil.sinCambio,
        ).fechasNominales(Fecha(2026, 1, 1), Fecha(2026, 1, 31));
        expect(pagos, [
          Fecha(2026, 1, 2),
          Fecha(2026, 1, 16),
          Fecha(2026, 1, 30),
        ]);
      },
    );

    test('cada N meses: luz bimestral y predial anual', () {
      final luz = CalendarioPago.cadaMeses(
        Fecha(2026, 9, 20),
        2,
        regla: ReglaDiaInhabil.sinCambio,
      ).fechasNominales(Fecha(2026, 1, 1), Fecha(2026, 12, 31));
      expect(luz, [
        Fecha(2026, 1, 20),
        Fecha(2026, 3, 20),
        Fecha(2026, 5, 20),
        Fecha(2026, 7, 20),
        Fecha(2026, 9, 20),
        Fecha(2026, 11, 20),
      ]);
      final predial = CalendarioPago.cadaMeses(
        Fecha(2026, 1, 31),
        12,
      ).fechasDePago(Fecha(2027, 1, 1), Fecha(2028, 12, 31), festivos2026);
      // 31/ene/2027 es domingo → lunes 1/feb/2027 (sin festivos de 2027
      // cargados; el primer lunes de febrero de 2027 lo es, por eso el hogar
      // carga el calendario de cada año).
      expect(predial.map((p) => p.ajustada), [
        Fecha(2027, 2, 1),
        Fecha(2028, 1, 31),
      ]);
      expect(
        () => CalendarioPago.cadaMeses(Fecha(2026, 1, 1), 0),
        throwsArgumentError,
      );
    });

    test('validaciones', () {
      expect(() => CalendarioPago.semanal(0), throwsArgumentError);
    });
  });
}

class _TodoInhabil implements CalendarioDiasInhabiles {
  @override
  bool esInhabil(Fecha fecha) => true;
}

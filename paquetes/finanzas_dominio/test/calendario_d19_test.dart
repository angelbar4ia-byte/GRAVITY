// Calendarios que pidió el dueño (P13, P15; reglas 5 y 6 de 4.5).
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'hogar_ejemplo.dart';

void main() {
  final festivos = CalendarioFijo.deDias(festivosOficialesMexico(2026));
  final festivos2027 = CalendarioFijo.deDias(festivosOficialesMexico(2027));

  group('Pensión los días 1 y 11 con el siguiente día hábil (P15)', () {
    const pension = CalendarioConfig.mensual([1, 11]);

    test('fechas de octubre a diciembre de 2026', () {
      final pagos = pension.pagosEntre(
        Fecha(2026, 10, 1),
        Fecha(2026, 12, 31),
        festivos,
      );
      expect(pagos.map((p) => '${p.programada}→${p.ajustada}'), [
        '2026-10-01→2026-10-01', // jueves
        '2026-10-11→2026-10-12', // domingo → lunes
        '2026-11-01→2026-11-02', // domingo → lunes
        '2026-11-11→2026-11-11', // miércoles
        '2026-12-01→2026-12-01', // martes
        '2026-12-11→2026-12-11', // viernes
      ]);
    });

    test('un festivo oficial también pasa al siguiente día hábil', () {
      // 1/ene/2027 es viernes y festivo: se paga el lunes 4.
      final pagos = pension.pagosEntre(
        Fecha(2027, 1, 1),
        Fecha(2027, 1, 31),
        festivos2027,
      );
      expect(pagos.first.ajustada, Fecha(2027, 1, 4));
    });

    test('dos días al mes equivalen a 24 pagos al año', () {
      expect(pension.calendario.vecesAlAnio, 24);
      expect(pension.frecuencia, Frecuencia.quincenal);
      // $2,500 × 24 ÷ 52 = $1,153.85 por semana.
      expect(Equivalente.de(250000, pension.frecuencia).semanal, 115385);
    });

    test('solo se admiten 1 o 2 días fijos', () {
      expect(
        () => const CalendarioConfig.mensual([1, 11, 21]).calendario,
        throwsArgumentError,
      );
    });
  });

  group('Dos días fijos que coinciden en un mes corto (M4)', () {
    final treintaYUltimo = CalendarioPago.diasFijos([
      const DiaDelMes(30),
      DiaDelMes.ultimo,
    ], regla: ReglaDiaInhabil.sinCambio);

    test('en febrero el 30 y el último día son el 28: se pagan los dos', () {
      final febrero = treintaYUltimo.fechasNominales(
        Fecha(2026, 2, 1),
        Fecha(2026, 2, 28),
      );
      expect(febrero, [Fecha(2026, 2, 28), Fecha(2026, 2, 28)]);
    });

    test(
      'el año completo tiene 24 pagos, como cuenta el equivalente semanal',
      () {
        final anio = treintaYUltimo.fechasNominales(
          Fecha(2026, 1, 1),
          Fecha(2026, 12, 31),
        );
        expect(anio, hasLength(24));
        expect(treintaYUltimo.vecesAlAnio, 24);
        expect(anio.where((f) => f.mes == 2), hasLength(2));
        expect(
          anio.where((f) => f.mes == 1),
          hasLength(2),
          reason: 'enero: el 30 y el 31',
        );
      },
    );

    test('fechasDePago los deja pasar los dos y respeta el orden', () {
      final pagos = treintaYUltimo.fechasDePago(
        Fecha(2026, 2, 1),
        Fecha(2026, 3, 31),
        festivos,
      );
      expect(pagos.map((p) => p.ajustada.toString()), [
        '2026-02-28',
        '2026-02-28',
        '2026-03-30',
        '2026-03-31',
      ]);
    });

    test('un ingreso con esos dos días cuenta los dos pagos de febrero', () {
      final ingreso = Ingreso(
        id: 'ing-dos-dias',
        libroId: casa,
        nombre: 'Pago (ejemplo)',
        cuentaOrigenId: 'sueldo-ana',
        cuentaDestinoId: 'banco-casa',
        vigencias: [
          VigenciaIngreso(
            id: 'v-dos-dias',
            ingresoId: 'ing-dos-dias',
            montoNeto: 100000,
            calendario: const CalendarioConfig.mensual([
              30,
              0,
            ], regla: ReglaDiaInhabil.sinCambio),
            desde: Fecha(2026, 1, 1),
          ),
        ],
      );
      final pagos = ingreso.pagosEntre(
        Fecha(2026, 2, 1),
        Fecha(2026, 2, 28),
        festivos,
      );
      expect(pagos, hasLength(2));
      expect(pagos.fold(0, (t, p) => t + p.$2), 200000);
      final datos = hogarEjemplo().copiar(ingresos: [ingreso]);
      final vence = vencimientosEntre(
        datos,
        casa,
        Fecha(2026, 2, 23),
        Fecha(2026, 3, 1),
      ).where((v) => v.origenId == 'ing-dos-dias');
      expect(vence, hasLength(2), reason: 'la semana ve los dos');
    });

    test('un solo día, o dos que no coinciden, no cambian', () {
      expect(
        const CalendarioConfig.mensual([1, 11]).calendario
            .fechasNominales(Fecha(2026, 2, 1), Fecha(2026, 2, 28)),
        [Fecha(2026, 2, 1), Fecha(2026, 2, 11)],
      );
      expect(
        CalendarioPago.mensual(const DiaDelMes(31))
            .fechasNominales(Fecha(2026, 2, 1), Fecha(2026, 2, 28)),
        [Fecha(2026, 2, 28)],
      );
    });
  });

  group('Apoyo 60+ cada bimestre (cada_meses, intervalo 2)', () {
    final apoyo = CalendarioConfig.cadaMeses(Fecha(2026, 9, 1), 2);

    test('cada dos meses desde el pago conocido, ajustado al día hábil', () {
      final pagos = apoyo.pagosEntre(
        Fecha(2026, 9, 1),
        Fecha(2027, 3, 31),
        festivos,
      );
      expect(pagos.map((p) => p.ajustada.toString()), [
        '2026-09-01',
        '2026-11-02', // 1/nov/2026 es domingo
        '2027-01-01', // calendario 2026: el 1/ene/2027 no está cargado
        '2027-03-01',
      ]);
      expect(apoyo.frecuencia, Frecuencia.bimestral);
    });

    test('solo intervalos de 1, 2, 3, 6 o 12 meses', () {
      expect(
        () => CalendarioConfig.cadaMeses(Fecha(2026, 1, 1), 5).calendario,
        throwsArgumentError,
      );
    });

    test('el libro de papá cuenta la pensión y el apoyo probable', () {
      final d = hogarEjemplo();
      final plan = armarPlanDelLibro(
        d,
        libroPapa,
        Semana.de(Fecha(2026, 11, 2)),
      );
      // Pensión: 250000 × 24 / 52; apoyo: 620000 × 6 / 52.
      expect(
        plan.plan.ingreso,
        dividirRedondeando(250000 * 24 + 620000 * 6, 52),
      );
      expect(plan.plan.ingresoPotencial, 0, reason: 'probable sí cuenta');
      final vence = vencimientosEntre(
        d,
        libroPapa,
        Fecha(2026, 11, 2),
        Fecha(2026, 11, 8),
      );
      expect(vence.map((v) => v.concepto), ['Apoyo 60+', 'Pensión']);
    });
  });

  group('Día inhábil por compromiso y deuda (P13; regla 5 de 4.5)', () {
    test('por defecto los pagos que salen se quedan en su fecha', () {
      final renta = compromisosEjemplo.firstWhere((c) => c.id == 'renta');
      final pagos = renta.pagosEntre(
        Fecha(2026, 10, 26),
        Fecha(2026, 11, 8),
        festivos,
      );
      expect(pagos.single.ajustada, Fecha(2026, 11, 1), reason: 'domingo');
    });

    test('solo la caja pasa al siguiente día hábil', () {
      const caja = Deuda(
        id: 'caja',
        libroId: casa,
        nombre: 'Crédito de la caja',
        tipo: TipoDeuda.conCosto,
        abono: 200000,
        frecuencia: Frecuencia.mensual,
        tasaAnualPuntosBase: 1800,
        calendario: CalendarioConfig.mensual([
          1,
        ], regla: ReglaDiaInhabil.siguienteDiaHabil),
      );
      final otra = Deuda(
        id: 'otra',
        libroId: casa,
        nombre: 'Tarjeta',
        tipo: TipoDeuda.conCosto,
        abono: 200000,
        frecuencia: Frecuencia.mensual,
        tasaAnualPuntosBase: 4800,
        calendario: const CalendarioConfig.mensual([
          1,
        ], regla: ReglaDiaInhabil.sinCambio),
      );
      final desde = Fecha(2026, 11, 1);
      final hasta = Fecha(2026, 11, 3);
      expect(
        caja.pagosEntre(desde, hasta, festivos).single.ajustada,
        Fecha(2026, 11, 2),
      );
      expect(
        otra.pagosEntre(desde, hasta, festivos).single.ajustada,
        Fecha(2026, 11, 1),
      );
    });

    test('sin regla elegida, un compromiso y una deuda se quedan en su fecha '
        'y un ingreso pasa al siguiente día hábil (default del servidor)', () {
      // 1/nov/2026 es domingo.
      const delUno = CalendarioConfig.mensual([1]);
      expect(delUno.reglaElegida, isNull);
      final compromiso = Compromiso(
        id: 'renta-sin-regla',
        libroId: casa,
        nombre: 'Renta',
        cuentaGastoId: 'g-vivienda',
        monto: 800000,
        frecuencia: Frecuencia.mensual,
        calendario: delUno,
      );
      const deuda = Deuda(
        id: 'deuda-sin-regla',
        libroId: casa,
        nombre: 'Tarjeta',
        tipo: TipoDeuda.conCosto,
        abono: 100000,
        frecuencia: Frecuencia.mensual,
        tasaAnualPuntosBase: 4800,
        calendario: delUno,
      );
      final ingreso = Ingreso(
        id: 'ing-sin-regla',
        libroId: casa,
        nombre: 'Sueldo',
        cuentaOrigenId: 'sueldo-ana',
        cuentaDestinoId: 'banco-casa',
        vigencias: [
          VigenciaIngreso(
            id: 'v',
            ingresoId: 'ing-sin-regla',
            montoNeto: 100000,
            calendario: delUno,
            desde: Fecha(2026, 1, 1),
          ),
        ],
      );
      final desde = Fecha(2026, 10, 26);
      final hasta = Fecha(2026, 11, 8);
      expect(compromiso.reglaInhabil, ReglaDiaInhabil.sinCambio);
      expect(deuda.reglaInhabil, ReglaDiaInhabil.sinCambio);
      expect(
        compromiso.pagosEntre(desde, hasta, festivos).single.ajustada,
        Fecha(2026, 11, 1),
      );
      expect(
        deuda.pagosEntre(desde, hasta, festivos).single.ajustada,
        Fecha(2026, 11, 1),
      );
      expect(
        ingreso.pagosEntre(desde, hasta, festivos).single.$1.ajustada,
        Fecha(2026, 11, 2),
      );
      // La regla elegida manda (la caja).
      const caja = CalendarioConfig.mensual([
        1,
      ], regla: ReglaDiaInhabil.siguienteDiaHabil);
      final conCaja = Deuda(
        id: 'caja',
        libroId: casa,
        nombre: 'Caja',
        tipo: TipoDeuda.conCosto,
        abono: 100000,
        frecuencia: Frecuencia.mensual,
        tasaAnualPuntosBase: 1800,
        calendario: caja,
      );
      expect(conCaja.reglaInhabil, ReglaDiaInhabil.siguienteDiaHabil);
      expect(
        conCaja.pagosEntre(desde, hasta, festivos).single.ajustada,
        Fecha(2026, 11, 2),
      );
      expect(
        delUno.conRegla(ReglaDiaInhabil.diaHabilAnterior).regla,
        ReglaDiaInhabil.diaHabilAnterior,
      );
    });

    test('la frecuencia debe coincidir con el calendario', () {
      final mal = Compromiso(
        id: 'x',
        libroId: casa,
        nombre: 'X',
        cuentaGastoId: 'g-vivienda',
        monto: 100,
        frecuencia: Frecuencia.mensual,
        calendario: CalendarioConfig.cadaMeses(Fecha(2026, 1, 1), 2),
      );
      expect(mal.validar, throwsArgumentError);
    });
  });

  group('Vigencias de un ingreso (5.1 bis, punto 2)', () {
    test('un cambio de neto crea una vigencia nueva y cierra la anterior', () {
      final ana = ingresosEjemplo.first;
      final nuevo = ana.conNuevaVigencia(
        id: 'vig-ana-2',
        montoNeto: 950000,
        calendario: const CalendarioConfig.quincenal(),
        desde: Fecha(2026, 11, 1),
      );
      expect(nuevo.vigencias, hasLength(2));
      expect(nuevo.vigencias.first.hasta, Fecha(2026, 10, 31));
      expect(
        nuevo.vigenciaEn(Semana.de(Fecha(2026, 10, 19)))!.montoNeto,
        900000,
      );
      expect(
        nuevo.vigenciaEn(Semana.de(Fecha(2026, 11, 9)))!.montoNeto,
        950000,
      );
      expect(
        () => nuevo.conNuevaVigencia(
          id: 'vig-ana-3',
          montoNeto: 1,
          calendario: const CalendarioConfig.quincenal(),
          desde: Fecha(2026, 10, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}

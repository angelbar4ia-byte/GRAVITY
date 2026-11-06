import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  final festivos = CalendarioFijo.deDias(festivosOficialesMexico(2026));

  group('IN10: calendario de flujo con peor caso (5.1 bis, punto 9)', () {
    // Saldo del jueves 29/oct: $2,600. Mínimo de tarjeta el viernes 30.
    // La quincena del sábado 31 y la renta del domingo 1/nov pasan al lunes 2
    // (en este ejemplo del diseño la renta también se mueve).
    List<EventoFlujo> eventos() {
      final sueldo = CalendarioPago.quincenal().fechasDePago(
        Fecha(2026, 10, 29),
        Fecha(2026, 11, 2),
        festivos,
      );
      final renta = CalendarioPago.mensual(const DiaDelMes(1))
          .fechasDePago(Fecha(2026, 10, 29), Fecha(2026, 11, 2), festivos);
      return [
        EventoFlujo(Fecha(2026, 10, 30), -45000, 'Mínimo de tarjeta'),
        for (final p in sueldo) EventoFlujo(p.ajustada, 600000, 'Sueldo'),
        for (final p in renta) EventoFlujo(p.ajustada, -350000, 'Renta'),
      ];
    }

    test('saldos del ejemplo', () {
      final proyeccion = proyectarFlujo(
        saldoInicial: 260000,
        desde: Fecha(2026, 10, 29),
        hasta: Fecha(2026, 11, 2),
        eventos: eventos(),
      );
      expect(proyeccion.dia(Fecha(2026, 10, 29)).saldoCierre, 260000);
      expect(proyeccion.dia(Fecha(2026, 10, 30)).saldoPeorCaso, 215000);
      expect(proyeccion.dia(Fecha(2026, 10, 30)).saldoCierre, 215000);
      expect(proyeccion.dia(Fecha(2026, 11, 1)).saldoCierre, 215000);
      final lunes = proyeccion.dia(Fecha(2026, 11, 2));
      expect(lunes.saldoPeorCaso, -135000); // −$1,350
      expect(lunes.saldoCierre, 465000); // $4,650
    });

    test('avisa con anticipación del peor caso negativo', () {
      final proyeccion = proyectarFlujo(
        saldoInicial: 260000,
        desde: Fecha(2026, 10, 29),
        hasta: Fecha(2026, 11, 2),
        eventos: eventos(),
      );
      expect(proyeccion.hayAlerta, isTrue);
      expect(proyeccion.primerDiaEnRiesgo!.fecha, Fecha(2026, 11, 2));
    });

    test('saldo mínimo configurable', () {
      final proyeccion = proyectarFlujo(
        saldoInicial: 260000,
        desde: Fecha(2026, 10, 29),
        hasta: Fecha(2026, 10, 30),
        eventos: eventos(),
        saldoMinimo: 250000,
      );
      expect(proyeccion.primerDiaEnRiesgo!.fecha, Fecha(2026, 10, 30));
    });
  });

  group('5.6 bis, prueba 3: flujo semanal del hogar de Ana y Alex', () {
    test('la semana del 26/oct entra \$0 y sale \$8,000', () {
      final desde = Fecha(2026, 10, 26);
      final hasta = Fecha(2026, 11, 8);
      final ana = CalendarioPago.quincenal().fechasDePago(
        desde,
        hasta,
        festivos,
      );
      final alex = CalendarioPago.mensual(DiaDelMes.ultimo)
          .fechasDePago(desde, hasta, festivos);
      // Pagos que salen: por defecto se quedan en su fecha (interpretación).
      final renta = CalendarioPago.mensual(
        const DiaDelMes(1),
        regla: ReglaDiaInhabil.sinCambio,
      ).fechasDePago(desde, hasta, festivos);

      expect(ana.single, FechaPago(Fecha(2026, 10, 31), Fecha(2026, 11, 2)));
      expect(alex.single, FechaPago(Fecha(2026, 10, 31), Fecha(2026, 11, 2)));
      expect(renta.single.ajustada, Fecha(2026, 11, 1));

      final semanas = flujoPorSemana(
        [
          for (final p in ana)
            EventoFlujo(p.ajustada, 900000, 'Quincena de Ana'),
          for (final p in alex)
            EventoFlujo(p.ajustada, 1400000, 'Sueldo de Alex'),
          for (final p in renta) EventoFlujo(p.ajustada, -800000, 'Renta'),
        ],
        desde: desde,
        hasta: hasta,
      );
      expect(semanas.length, 2);
      expect(semanas[0].semana.inicio, Fecha(2026, 10, 26));
      expect(semanas[0].entradas, 0);
      expect(semanas[0].salidas, 800000);
      expect(semanas[0].neto, -800000);
      expect(semanas[1].entradas, 2300000);
      expect(semanas[1].salidas, 0);

      // Alerta de flujo: con $5,000 en cuentas la semana no alcanza.
      final proyeccion = proyectarFlujo(
        saldoInicial: 500000,
        desde: desde,
        hasta: hasta,
        eventos: [
          for (final p in renta) EventoFlujo(p.ajustada, -800000, 'Renta'),
        ],
      );
      expect(proyeccion.primerDiaEnRiesgo!.fecha, Fecha(2026, 11, 1));
    });
  });

  test('un evento de flujo no puede ser cero', () {
    expect(() => EventoFlujo(Fecha(2026, 1, 1), 0, 'x'), throwsArgumentError);
  });
}

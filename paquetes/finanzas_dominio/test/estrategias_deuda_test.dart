import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  // Datos de ejemplo inventados.
  const chica = DeudaSimulable(
    id: 'a',
    nombre: 'Tienda',
    saldo: 300000,
    tasaAnualPuntosBase: 3000,
    minimoMensual: 30000,
    diasParaVencer: 20,
  );
  const cara = DeudaSimulable(
    id: 'b',
    nombre: 'Tarjeta cara',
    saldo: 1200000,
    tasaAnualPuntosBase: 6000,
    minimoMensual: 60000,
    diasParaVencer: 10,
  );
  const grande = DeudaSimulable(
    id: 'c',
    nombre: 'Préstamo',
    saldo: 2500000,
    tasaAnualPuntosBase: 2000,
    minimoMensual: 90000,
    diasParaVencer: 3,
  );
  const deudas = [chica, cara, grande];

  test('las tres liquidan el mismo capital', () {
    final r = simularTodas(deudas, extraMensual: 50000);
    for (final x in r) {
      expect(x.calculada, isTrue);
      expect(x.liquidada, isTrue);
      expect(x.capitalPagado, 4000000);
      expect(x.totalPagado, 4000000 + x.interesesTotales);
    }
  });

  test('la avalancha paga menos intereses cuando las tasas difieren', () {
    final r = simularTodas(deudas, extraMensual: 50000);
    final nieve = r[0], aval = r[1];
    expect(aval.interesesTotales, lessThan(nieve.interesesTotales));
    expect(recomendar(r)!.estrategia, EstrategiaPago.avalancha);
  });

  test('el orden de pago sigue el criterio de cada estrategia', () {
    final r = simularTodas(deudas, extraMensual: 200000);
    expect(r[0].orden.first.deudaId, 'a');
    expect(r[1].orden.first.deudaId, anyOf('a', 'b'));
    int mes(ResultadoEstrategia r, String id) =>
        r.orden.firstWhere((p) => p.deudaId == id).mesDeLiquidacion!;
    final v = simularEstrategia(
      EstrategiaPago.porVencimiento,
      deudas,
      extraMensual: 300000,
    );
    // La que vence primero (c) se liquida antes que con bola de nieve.
    final nieve = simularEstrategia(
      EstrategiaPago.bolaDeNieve,
      deudas,
      extraMensual: 300000,
    );
    expect(mes(v, 'c'), lessThan(mes(nieve, 'c')));
  });

  test('falta fecha límite: solo bloquea la estrategia por vencimiento', () {
    const sinFecha = DeudaSimulable(
      id: 'd',
      nombre: 'Sin fecha',
      saldo: 100000,
      tasaAnualPuntosBase: 4000,
      minimoMensual: 10000,
    );
    final r = simularTodas([...deudas, sinFecha]);
    expect(r[0].calculada, isTrue);
    expect(r[1].calculada, isTrue);
    expect(r[2].estado, EstadoEstrategia.faltaDato);
    expect(r[2].faltantes, ['fecha límite']);
    expect(r[2].interesesTotales, 0);
    expect(recomendar(r), isNotNull);
  });

  test('falta saldo o tasa bloquea sin estimar', () {
    const sinTasa = DeudaSimulable(
      id: 'e',
      nombre: 'X',
      saldo: 100000,
      minimoMensual: 10000,
      diasParaVencer: 5,
    );
    final r = simularTodas([chica, sinTasa]);
    expect(r.every((x) => !x.calculada), isTrue);
    expect(recomendar(r), isNull);
    expect(interesesConPagoMinimo([chica, sinTasa]).calculado, isFalse);
  });

  test('el mínimo solo cuesta más intereses que cualquier estrategia', () {
    final minimo = interesesConPagoMinimo(deudas);
    expect(minimo.calculado, isTrue);
    for (final x in simularTodas(deudas)) {
      expect(x.interesesTotales, lessThanOrEqualTo(minimo.interesesTotales));
    }
  });

  test('mínimo que no cubre el interés no liquida y se avisa', () {
    const trampa = DeudaSimulable(
      id: 't',
      nombre: 'T',
      saldo: 1000000,
      tasaAnualPuntosBase: 6000,
      minimoMensual: 1000,
    );
    final m = interesesConPagoMinimo([trampa], horizonteMeses: 24);
    expect(m.liquidada, isFalse);
    expect(m.interesesTotales, greaterThan(0));
  });

  test('redondeo del interés al centavo: 1,000.00 al 24 % = 20.00 al mes', () {
    const d = DeudaSimulable(
      id: 'r',
      nombre: 'R',
      saldo: 100000,
      tasaAnualPuntosBase: 2400,
      minimoMensual: 102000,
    );
    final r = simularEstrategia(EstrategiaPago.avalancha, [d]);
    expect(r.interesesTotales, 2000);
    expect(r.meses, 1);
  });

  test('deuda sin costo (tasa cero) no genera intereses', () {
    const f = DeudaSimulable(
      id: 'f',
      nombre: 'Familiar',
      saldo: 500000,
      tasaAnualPuntosBase: 0,
      minimoMensual: 100000,
      diasParaVencer: 30,
    );
    for (final r in simularTodas([f])) {
      expect(r.interesesTotales, 0);
      expect(r.meses, 5);
    }
  });

  test('vencimiento proyecta ciclos futuros', () {
    expect(diasProyectadosDeVencimiento(25, 1), 25);
    expect(diasProyectadosDeVencimiento(25, 2), 55);
    expect(diasProyectadosDeVencimiento(40, 2), 40);
    expect(diasProyectadosDeVencimiento(-5, 1), -5);
    expect(diasProyectadosDeVencimiento(-5, 2), 55);
  });

  test('presupuesto pedido: menor que los mínimos no alcanza', () {
    final minimos = sumaDeMinimos(deudas)!;
    expect(minimos, 180000);
    final r = simularTodas(deudas, presupuestoMensual: minimos - 1);
    expect(r.every((x) => x.estado == EstadoEstrategia.noAlcanza), isTrue);
    expect(r.every((x) => x.orden.isEmpty && x.interesesTotales == 0), isTrue);
    final igual = simularTodas(deudas, presupuestoMensual: minimos);
    final omision = simularTodas(deudas);
    expect(igual[0].interesesTotales, omision[0].interesesTotales);
  });
}

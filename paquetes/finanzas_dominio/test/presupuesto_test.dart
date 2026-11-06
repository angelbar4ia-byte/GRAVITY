import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'ejemplo_ana_alex.dart';

void main() {
  group('5.6 bis, prueba 1: plan del ejemplo de Ana y Alex', () {
    final plan = planEjemplo();

    test('cascada: ingreso, presupuesto, deuda y remanente', () {
      expect(plan.ingreso, 738462); // $7,384.62
      expect(plan.presupuesto, 547231); // $5,472.31
      expect(plan.deudaPlaneada, 39231); // $392.31
      expect(plan.remanente, 152000); // $1,520.00
      expect(plan.tasaRemanentePuntosBase, 2058); // 20.58 %
    });

    test('meta de 20 %, techo y resultado del periodo', () {
      expect(plan.metaRemanente, 147692); // $1,476.92
      expect(plan.diferenciaContraMeta, 4308); // supera la meta por $43.08
      expect(plan.techo, 551539); // $5,515.39
      expect(plan.dentroDelTecho, isTrue);
      expect(plan.resultado, 191231); // $1,912.31
      expect(plan.tasaResultadoPuntosBase, 2590); // 25.9 %
      expect(plan.enDeficit, isFalse);
    });

    test('renglones que suman exactamente sus totales (regla R2)', () {
      expect(plan.ingresos.map((r) => r.semanal), [415385, 323077]);
      expect(plan.partidas.map((r) => r.semanal), [
        184615, // renta $1,846.15
        10385, // luz $103.85
        6923, // agua $69.23
        9231, // internet $92.31
        8077, // celular $80.77
        3000, // placas y predial $30.00
        150000, 70000, 30000, 15000, 15000, 25000, 20000, // $3,250.00
      ]);
      // El diseño muestra $276.92 y $115.38, que suman $392.30 y no los
      // $392.31 del total. Con el reparto por mayor resto el centavo va al
      // préstamo familiar: $276.92 + $115.39 = $392.31.
      expect(plan.abonoPlaneadoA('tarjeta'), 27692);
      expect(plan.abonoPlaneadoA('familiar'), 11539);
      expect(plan.asignadoA('alimentacion'), 150000);
    });

    test('el remanente se propone como abono extra a la tarjeta', () {
      expect(plan.destino.abonosExtra.single.deuda.id, 'tarjeta');
      expect(plan.destino.totalAbonoExtra, 152000);
      expect(plan.destino.ahorro, 0);
    });

    test('T1: semáforos del remanente y de la carga de deuda en verde', () {
      expect(plan.semaforoDelRemanente, Semaforo.verde);
      expect(plan.cargaDeudaPuntosBase, 531); // 5.31 %
      expect(plan.semaforoDeLaCarga, Semaforo.verde);
    });
  });

  group('5.6 bis, prueba 2: regla de sobregasto', () {
    final plan = planEjemplo();

    CierreSemanal conSobregasto(int monto) => cerrarSemana(
      plan,
      ingresoReal: plan.ingreso,
      gastadoPorPartida: gastoSegunPlan(plan, {'alimentacion': monto}),
    );

    test('sin sobregasto se cumple el plan', () {
      final c = conSobregasto(0);
      expect(c.remanenteReal, 152000);
      expect(c.abonoReal, 39231);
      expect(c.abonoDiferido, 0);
      expect(c.deficit, 0);
    });

    test(
      '\$300 → remanente \$1,220.00 (16.52 %, ámbar) y aviso de la partida',
      () {
        final c = conSobregasto(30000);
        expect(c.remanenteReal, 122000);
        expect(c.abonoReal, 39231);
        expect(c.deficit, 0);
        expect(c.sobregasto, 30000);
        expect(c.tasaRemanentePuntosBase, 1652);
        expect(c.semaforoDelRemanente, Semaforo.ambar); // T2
        expect(c.partidasPasadas.single.partida.id, 'alimentacion');
        expect(c.partidasPasadas.single.sobregasto, 30000);
        expect(c.partidasPasadas.single.semaforo, Semaforo.rojo);
      },
    );

    test(
      '\$1,800 → remanente \$0, abono \$112.31 y abono diferido \$280.00',
      () {
        final c = conSobregasto(180000);
        expect(c.remanenteReal, 0);
        expect(c.abonoReal, 11231);
        expect(c.abonoDiferido, 28000);
        expect(c.deficit, 0);
        expect(c.destino.ahorro, 0);
        // Se reduce primero el préstamo familiar y después la tarjeta.
        final familiar = c.abonos.firstWhere((a) => a.deuda.id == 'familiar');
        final tarjeta = c.abonos.firstWhere((a) => a.deuda.id == 'tarjeta');
        expect(familiar.real, 0);
        expect(familiar.diferido, 11539);
        expect(tarjeta.real, 11231);
      },
    );

    test('\$2,000 → remanente \$0, abono \$0 y déficit \$87.69', () {
      final c = conSobregasto(200000);
      expect(c.remanenteReal, 0);
      expect(c.abonoReal, 0);
      expect(c.abonoDiferido, 39231);
      expect(c.deficit, 8769);
    });

    test('un ingreso que no llegó se absorbe con la misma regla', () {
      // Faltan $540 de un ingreso variable (5.1 bis, punto 3).
      final c = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso - 54000,
        gastadoPorPartida: gastoSegunPlan(plan),
      );
      expect(c.remanenteReal, 98000);
    });
  });

  group('5.6 bis, prueba 6: alerta de pago mínimo', () {
    test('un abono a tarjeta bajo el mínimo exigible se marca', () {
      final tarjeta = DeudaPlan(
        id: 'tarjeta',
        nombre: 'Tarjeta',
        tipo: TipoDeuda.conCosto,
        abono: 120000,
        minimo: 60000, // mínimo mensual
        frecuencia: Frecuencia.mensual,
        tasaAnualPuntosBase: 4800,
        saldo: 600000,
      );
      final plan = planEjemplo(deudas: [tarjeta, prestamoFamiliarEjemplo]);
      final c = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan, {'alimentacion': 180000}),
      );
      final abono = c.abonos.firstWhere((a) => a.deuda.id == 'tarjeta');
      expect(abono.minimo, 13846); // $600 al mes ≈ $138.46 por semana
      expect(abono.real, 11231);
      expect(abono.bajoMinimo, isTrue);
      expect(c.abonosBajoMinimo.single.deuda.id, 'tarjeta');

      // Con sobregasto de $300 no se toca ningún abono.
      final bien = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan, {'alimentacion': 30000}),
      );
      expect(bien.abonosBajoMinimo, isEmpty);
    });

    test('los mínimos se protegen hasta el final', () {
      final barata = DeudaPlan(
        id: 'barata',
        nombre: 'Crédito barato',
        tipo: TipoDeuda.conCosto,
        abono: 52000,
        minimo: 26000,
        frecuencia: Frecuencia.semanal,
        tasaAnualPuntosBase: 1200,
      );
      final cara = DeudaPlan(
        id: 'cara',
        nombre: 'Tarjeta cara',
        tipo: TipoDeuda.conCosto,
        abono: 52000,
        minimo: 26000,
        frecuencia: Frecuencia.semanal,
        tasaAnualPuntosBase: 6000,
      );
      final msi = DeudaPlan(
        id: 'msi',
        nombre: 'Compra a MSI',
        tipo: TipoDeuda.msi,
        abono: 10000,
        frecuencia: Frecuencia.semanal,
      );
      final plan = planEjemplo(deudas: [barata, cara, msi]);
      final remanente = plan.remanente;
      // Sobregasto que se come el remanente y $600 de abonos: primero lo que
      // pasa del mínimo en la barata ($260), luego en la cara ($260), y $80
      // del mínimo de la barata.
      final c = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan, {
          'alimentacion': remanente + 60000,
        }),
      );
      int real(String id) => c.abonos.firstWhere((a) => a.deuda.id == id).real;
      expect(real('barata'), 18000);
      expect(real('cara'), 26000);
      expect(real('msi'), 10000); // la mensualidad MSI se toca al último
      expect(c.abonoDiferido, 60000);
    });
  });

  group('5.6 bis, pruebas 4 y 5: periodos e ingreso incierto', () {
    test('el presupuesto por periodo usa los factores de la sección 4', () {
      final plan = planEjemplo();
      final quincena = plan.enPeriodo(TipoPeriodo.quincena);
      expect(quincena.presupuesto, 1185667); // $11,856.67 = semanal × 52 ÷ 24
      expect(quincena.ingreso, 1600000); // $16,000.00
      expect(plan.enPeriodo(TipoPeriodo.catorcena).presupuesto, 1094462);
      expect(plan.enPeriodo(TipoPeriodo.catorcena).ingreso, 1476923);
      // El diseño da $23,713.34 porque parte del semanal ya redondeado
      // (5,472.31 × 52 ÷ 12); con la suma exacta (regla R2) es $23,713.33.
      expect(plan.enPeriodo(TipoPeriodo.mes).presupuesto, 2371333);
      expect(plan.enPeriodo(TipoPeriodo.mes).ingreso, 3200000);
      expect(plan.enPeriodo(TipoPeriodo.semana).remanente, 152000);
    });

    test(
      'un ingreso incierto no cambia el cálculo y aparece como potencial',
      () {
        final plan = planEjemplo(
          ingresos: [
            ...ingresosEjemplo,
            const IngresoPlan(
              id: 'ventas',
              nombre: 'Ventas',
              monto: 200000,
              frecuencia: Frecuencia.mensual,
              certeza: Certeza.incierta,
            ),
          ],
        );
        expect(plan.ingreso, 738462);
        expect(plan.remanente, 152000);
        expect(plan.ingresoPotencial, 46154);
      },
    );

    test('un ingreso probable sí cuenta', () {
      final plan = planEjemplo(
        ingresos: [
          ...ingresosEjemplo,
          const IngresoPlan(
            id: 'comision',
            nombre: 'Comisión',
            monto: 52000,
            frecuencia: Frecuencia.anual,
            certeza: Certeza.probable,
          ),
        ],
      );
      expect(plan.ingreso, 739462);
    });
  });

  group('5.6 bis, prueba 7: propuestas de recorte', () {
    final plan = planEjemplo();
    final estado = [
      for (final r in plan.partidas)
        (partida: r.origen, disponible: r.semanal, gastado: 0),
    ];

    test('primero lo discrecional; nunca lo protegido', () {
      final p = proponerRecortes(50000, estado);
      expect(p.recortes.map((r) => (r.partida.id, r.monto)), [
        ('entretenimiento', 25000),
        ('vestimenta', 20000),
        ('salud', 5000),
      ]);
      expect(p.faltante, 0);
    });

    test('aunque falte, los protegidos no aparecen', () {
      final p = proponerRecortes(100000000, estado);
      expect(p.recortes.any((r) => r.partida.protegida), isFalse);
      expect(p.recortes.map((r) => r.partida.id), isNot(contains('renta')));
      expect(p.faltante, greaterThan(0));
      expect(p.total + p.faltante, 100000000);
    });

    test('respeta lo ya gastado y el piso mínimo', () {
      const ocio = PartidaPlan.variable(
        id: 'ocio',
        nombre: 'Ocio',
        montoSemanal: 30000,
        prioridad: Prioridad.discrecional,
        pisoMinimo: 10000,
      );
      final p = proponerRecortes(50000, [
        (partida: ocio, disponible: 30000, gastado: 5000),
      ]);
      expect(p.recortes.single.monto, 20000); // deja el piso de $100
      final gastada = proponerRecortes(50000, [
        (partida: ocio, disponible: 30000, gastado: 25000),
      ]);
      expect(gastada.recortes.single.monto, 5000);
    });
  });

  group('5.6 bis, prueba 8: destino del remanente', () {
    test(
      'al cerrar, abono extra a la tarjeta (mayor costo) y familiares al final',
      () {
        final tarjetaChica = DeudaPlan(
          id: 'tarjeta',
          nombre: 'Tarjeta',
          tipo: TipoDeuda.conCosto,
          abono: 120000,
          frecuencia: Frecuencia.mensual,
          tasaAnualPuntosBase: 4800,
          saldo: 50000,
        );
        final plan = planEjemplo(
          deudas: [prestamoFamiliarEjemplo, tarjetaChica],
        );
        final c = cerrarSemana(
          plan,
          ingresoReal: plan.ingreso,
          gastadoPorPartida: gastoSegunPlan(plan),
        );
        expect(c.remanenteReal, 152000);
        expect(c.destino.abonosExtra.map((a) => (a.deuda.id, a.monto)), [
          ('tarjeta', 50000 - 27692), // hasta liquidarla
          ('familiar', 152000 - (50000 - 27692)),
        ]);
        expect(c.destino.ahorro, 0);
      },
    );

    test('las compras a MSI no reciben extra', () {
      final msi = DeudaPlan(
        id: 'msi',
        nombre: 'Refrigerador a 12 MSI',
        tipo: TipoDeuda.msi,
        abono: 100000,
        frecuencia: Frecuencia.mensual,
        saldo: 1200000,
      );
      expect(msi.minimo, 100000); // la mensualidad completa es el mínimo
      final plan = planEjemplo(deudas: [msi]);
      expect(plan.destino.extraPara('msi'), 0);
      expect(plan.destino.ahorro, plan.remanente); // MSI no bloquea el ahorro
    });

    test('sin deudas todo el remanente va a ahorro (caso límite 9)', () {
      final plan = planEjemplo(deudas: []);
      expect(plan.deudaPlaneada, 0);
      expect(plan.remanente, 191231);
      expect(plan.destino.ahorro, 191231);
      expect(plan.destino.abonosExtra, isEmpty);
    });

    test('ahorro mínimo con deuda (por defecto 0 %)', () {
      final plan = planEjemplo(
        parametros: const ParametrosPlan(ahorroMinimoConDeudaPuntosBase: 1000),
      );
      expect(plan.destino.ahorro, 15200);
      expect(plan.destino.totalAbonoExtra, 136800);
    });

    test('la prioridad manual pasa por encima del costo', () {
      final familiarPrimero = DeudaPlan(
        id: 'familiar',
        nombre: 'Préstamo familiar (acuerdo)',
        tipo: TipoDeuda.familiar,
        abono: 50000,
        frecuencia: Frecuencia.mensual,
        saldo: 300000,
        prioridadManual: 1,
      );
      expect(
        ordenDeAbonoExtra([tarjetaEjemplo, familiarPrimero]).map((d) => d.id),
        ['familiar', 'tarjeta'],
      );
    });

    test('mayor tasa primero; con la misma tasa, más interés en pesos', () {
      DeudaPlan d(String id, int tasa, int saldo) => DeudaPlan(
        id: id,
        nombre: id,
        tipo: TipoDeuda.conCosto,
        abono: 1000,
        frecuencia: Frecuencia.mensual,
        tasaAnualPuntosBase: tasa,
        saldo: saldo,
      );
      // Ejemplo de 5.3: A 45 %, B 60 %, C 38 %, D 30 % → B, A, C, D.
      final orden = ordenDeAbonoExtra([
        d('A', 4500, 2000000),
        d('B', 6000, 500000),
        d('C', 3800, 1200000),
        d('D', 3000, 800000),
        d('E', 3000, 900000),
      ]);
      expect(orden.map((x) => x.id), ['B', 'A', 'C', 'E', 'D']);
    });
  });

  group('Arrastre de sobrantes (5.6 bis, punto 8; decisión 49)', () {
    final plan = planEjemplo();

    test('lo que sobra pasa a la semana siguiente y no sube el remanente', () {
      final c = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan, {'alimentacion': -50000}),
      );
      final alimentacion = c.partidas.firstWhere(
        (p) => p.partida.id == 'alimentacion',
      );
      expect(alimentacion.arrastreSiguiente, 50000);
      expect(alimentacion.alRemanente, 0);
      expect(c.remanenteReal, 152000);
    });

    test('tope de 2 semanas de su monto; el exceso va al remanente', () {
      final c = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan, {'alimentacion': -150000}),
        arrastreRecibido: {'alimentacion': 250000},
      );
      final alimentacion = c.partidas.firstWhere(
        (p) => p.partida.id == 'alimentacion',
      );
      expect(alimentacion.disponible, 400000);
      expect(alimentacion.arrastreSiguiente, 300000); // 2 × $1,500
      expect(alimentacion.alRemanente, 100000);
      expect(c.remanenteReal, 252000);
    });

    test('gastar lo arrastrado no es sobregasto', () {
      final c = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan, {'alimentacion': 40000}),
        arrastreRecibido: {'alimentacion': 50000},
      );
      final alimentacion = c.partidas.firstWhere(
        (p) => p.partida.id == 'alimentacion',
      );
      expect(alimentacion.dentro, isTrue);
      expect(alimentacion.arrastreSiguiente, 10000);
      expect(c.remanenteReal, 152000);
    });

    test('partida en modo "al remanente" y partidas fijas no arrastran', () {
      final c = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan, {'luz': -2000}),
      );
      final luz = c.partidas.firstWhere((p) => p.partida.id == 'luz');
      expect(luz.arrastreSiguiente, 0);
      expect(luz.alRemanente, 2000);
      expect(c.remanenteReal, 154000);
    });

    test('el tope se puede configurar', () {
      final unaSemana = planEjemplo(
        parametros: const ParametrosPlan(topeArrastreSemanas: 1),
      );
      final c = cerrarSemana(
        unaSemana,
        ingresoReal: unaSemana.ingreso,
        gastadoPorPartida: gastoSegunPlan(unaSemana, {'salud': -30000}),
        arrastreRecibido: {'salud': 30000},
      );
      final salud = c.partidas.firstWhere((p) => p.partida.id == 'salud');
      expect(salud.arrastreSiguiente, 30000);
      expect(salud.alRemanente, 30000);
    });
  });

  group('Vista devengada de fijos y reservas', () {
    test('una renta mensual pagada completa no es sobregasto; una luz más '
        'cara sí', () {
      expect(gastoDevengado(184615, [(800000, 800000)]), 184615);
      expect(gastoDevengado(10385, [(90000, 110000)]), 30385);
      expect(gastoDevengado(10385, const []), 10385);
    });
  });

  group('Validaciones y casos límite', () {
    test('plan en déficit', () {
      final plan = planEjemplo(
        partidas: [
          ...partidasEjemplo,
          const PartidaPlan.variable(
            id: 'extra',
            nombre: 'Extra',
            montoSemanal: 200000,
          ),
        ],
      );
      expect(plan.remanente, -48000);
      expect(plan.enDeficit, isTrue);
      expect(plan.destino.abonosExtra, isEmpty);
      expect(plan.destino.ahorro, 0);
      expect(plan.dentroDelTecho, isFalse);
    });

    test(
      'una deuda con costo necesita su tasa; familiares y MSI no llevan',
      () {
        expect(
          () => DeudaPlan(
            id: 'x',
            nombre: 'x',
            tipo: TipoDeuda.conCosto,
            abono: 100,
            frecuencia: Frecuencia.mensual,
          ),
          throwsArgumentError,
        );
        expect(
          () => DeudaPlan(
            id: 'y',
            nombre: 'y',
            tipo: TipoDeuda.familiar,
            abono: 100,
            frecuencia: Frecuencia.mensual,
            tasaAnualPuntosBase: 100,
          ),
          throwsArgumentError,
        );
      },
    );

    test('ids repetidos y partidas fuera del plan', () {
      expect(
        () => planEjemplo(
          partidas: [partidasEjemplo.first, partidasEjemplo.first],
        ),
        throwsArgumentError,
      );
      final plan = planEjemplo();
      expect(
        () =>
            cerrarSemana(plan, ingresoReal: 0, gastadoPorPartida: {'nada': 1}),
        throwsArgumentError,
      );
    });

    test('cumplimiento del presupuesto', () {
      final plan = planEjemplo();
      final c = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan, {
          'alimentacion': 1,
          'salud': 1,
        }),
      );
      // 11 de 13 partidas dentro = 84.6 % → ámbar.
      expect(c.semaforoDelCumplimiento, Semaforo.ambar);
    });
  });

  group('Semáforos (5.6 bis, punto 10; 5.9 bis, punto 3)', () {
    test('partida: verde hasta 80 %, ámbar hasta 100 %, rojo arriba', () {
      expect(semaforoPartida(80000, 100000), Semaforo.verde);
      expect(semaforoPartida(80001, 100000), Semaforo.ambar);
      expect(semaforoPartida(100000, 100000), Semaforo.ambar);
      expect(semaforoPartida(100001, 100000), Semaforo.rojo);
      expect(semaforoPartida(0, 0), Semaforo.verde);
      expect(semaforoPartida(1, 0), Semaforo.rojo);
    });

    test('remanente: ≥ 20 % verde, 10 a 20 % ámbar, < 10 % rojo', () {
      expect(semaforoRemanente(2000, 10000), Semaforo.verde);
      expect(semaforoRemanente(1999, 10000), Semaforo.ambar);
      expect(semaforoRemanente(1000, 10000), Semaforo.ambar);
      expect(semaforoRemanente(999, 10000), Semaforo.rojo);
      expect(semaforoRemanente(0, 0), Semaforo.rojo);
    });

    test('carga de deuda: < 20 % verde, 20 a 35 % ámbar, > 35 % rojo', () {
      expect(semaforoCargaDeuda(1999, 10000), Semaforo.verde);
      expect(semaforoCargaDeuda(2000, 10000), Semaforo.ambar);
      expect(semaforoCargaDeuda(3500, 10000), Semaforo.ambar);
      expect(semaforoCargaDeuda(3501, 10000), Semaforo.rojo);
    });

    test('cumplimiento: ≥ 90 % verde, 70 a 90 % ámbar, < 70 % rojo', () {
      expect(semaforoCumplimiento(9, 10), Semaforo.verde);
      expect(semaforoCumplimiento(7, 10), Semaforo.ambar);
      expect(semaforoCumplimiento(6, 10), Semaforo.rojo);
    });

    test('umbrales editables', () {
      const propios = Umbrales(remanenteVerdeDesde: 1500);
      expect(semaforoRemanente(1600, 10000, umbrales: propios), Semaforo.verde);
    });
  });
}

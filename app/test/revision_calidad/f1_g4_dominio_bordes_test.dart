// Guardia de la revisión de calidad de la Fase 1: casos borde del dominio
// (`finanzas_dominio`) que la revisión probó a mano: medio centavo y signos,
// repartos por mayor resto, semanas (ISO, fin de año), años bisiestos, día 31,
// fines de semana y festivos de 2026 y 2027, la pensión de los días 1 y 11,
// pagos "cada N meses", cambios de horario y los límites exactos de los
// semáforos. Hoy PASAN y deben seguir pasando.
import 'dart:math';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dinero: redondeo R1 y reparto R2', () {
    test('los medios centavos se alejan de cero, con cualquier signo', () {
      expect(dividirRedondeando(1, 2), 1);
      expect(dividirRedondeando(-1, 2), -1);
      expect(dividirRedondeando(3, 2), 2);
      expect(dividirRedondeando(5, 2), 3);
      expect(dividirRedondeando(1, -2), -1);
      expect(dividirRedondeando(-1, -2), 1);
      expect(dividirRedondeando(0, 7), 0);
      expect(() => dividirRedondeando(1, 0), throwsArgumentError);
    });

    test('porcentajes con monto cero, negativo o de un centavo', () {
      expect(aplicarPorcentaje(0, 2000), 0);
      expect(aplicarPorcentaje(1, 5000), 1);
      expect(aplicarPorcentaje(-100, 2000), -20);
      expect(proporcionEnPuntosBase(5, 0), 0);
      expect(proporcionEnPuntosBase(5, -10), 0);
    });

    test('el equivalente semanal de medio centavo sube un centavo', () {
      // $0.13 semestral = 26 centavos al año = 0.5 centavo por semana.
      expect(Equivalente.de(13, Frecuencia.semestral).semanal, 1);
      expect(Equivalente.de(0, Frecuencia.mensual).semanal, 0);
      expect(
        () => semanalesQueSuman([Equivalente.de(-1, Frecuencia.mensual)]),
        throwsArgumentError,
      );
    });

    test('el reparto por mayor resto siempre suma el total redondeado', () {
      final azar = Random(2026);
      for (var vuelta = 0; vuelta < 500; vuelta++) {
        final n = 1 + azar.nextInt(12);
        final numeradores = [for (var i = 0; i < n; i++) azar.nextInt(5000000)];
        final partes = repartirConMayorResto(numeradores, 52);
        final total = dividirRedondeando(
          numeradores.fold<int>(0, (a, b) => a + b),
          52,
        );
        expect(partes.fold<int>(0, (a, b) => a + b), total, reason: '$numeradores');
        for (var i = 0; i < n; i++) {
          expect((partes[i] - numeradores[i] / 52).abs(), lessThan(1.0));
        }
      }
      expect(repartirConMayorResto(const [], 52), isEmpty);
      expect(repartirConMayorResto(const [0, 0], 52), [0, 0]);
      expect(() => repartirConMayorResto(const [-1], 52), throwsArgumentError);
    });
  });

  group('Fechas y semanas', () {
    test('la semana va de lunes a domingo, también al cruzar el año', () {
      for (final dia in [
        Fecha(2026, 10, 25),
        Fecha(2026, 10, 26),
        Fecha(2026, 1, 1),
        Fecha(2024, 2, 29),
        Fecha(2026, 12, 31),
        Fecha(2027, 1, 1),
      ]) {
        final s = Semana.de(dia);
        expect(s.inicio.diaSemana, DateTime.monday, reason: '$dia');
        expect(s.contiene(dia), isTrue);
        expect(s.fin.diaSemana, DateTime.sunday);
      }
      expect(Semana.de(Fecha(2026, 12, 31)).inicio, Fecha(2026, 12, 28));
      expect(Semana.de(Fecha(2027, 1, 1)).inicio, Fecha(2026, 12, 28));
      expect(Semana.de(Fecha(2026, 12, 31)).numeroIso, 53);
      expect(Semana.semanasIsoDelAnio(2026), 53);
    });

    test('bisiestos, día 31 y la aritmética no depende del horario', () {
      expect(Fecha.enMes(2024, 2, 31), Fecha(2024, 2, 29));
      expect(Fecha.enMes(2026, 2, 31), Fecha(2026, 2, 28));
      expect(Fecha.enMes(2026, 4, 31), Fecha(2026, 4, 30));
      expect(() => Fecha(2026, 2, 29), throwsArgumentError);
      expect(Fecha(2024, 2, 29).sumarDias(365), Fecha(2025, 2, 28));
      // Cambios de horario de otros países: la diferencia es de un día exacto.
      expect(Fecha(2026, 3, 8).diasHasta(Fecha(2026, 3, 9)), 1);
      expect(Fecha(2026, 10, 25).diasHasta(Fecha(2026, 10, 26)), 1);
      expect(Fecha(2026, 11, 1).diasHasta(Fecha(2026, 11, 2)), 1);
    });
  });

  group('Calendario de pagos', () {
    final festivos = CalendarioFijo.deDias([
      ...festivosOficialesMexico(2026),
      ...festivosOficialesMexico(2027),
    ]);

    test('festivos oficiales de 2026 y 2027 (LFT art. 74)', () {
      expect(
        [for (final d in festivosOficialesMexico(2026)) d.fecha.toString()],
        [
          '2026-01-01',
          '2026-02-02',
          '2026-03-16',
          '2026-05-01',
          '2026-09-16',
          '2026-11-16',
          '2026-12-25',
        ],
      );
      expect(
        [for (final d in festivosOficialesMexico(2027)) d.fecha.toString()],
        [
          '2027-01-01',
          '2027-02-01',
          '2027-03-15',
          '2027-05-01',
          '2027-09-16',
          '2027-11-15',
          '2027-12-25',
        ],
      );
    });

    test('la pensión de los días 1 y 11 pasa al siguiente día hábil', () {
      final pension = CalendarioPago.diasFijos([DiaDelMes(1), DiaDelMes(11)]);
      final pagos = pension.fechasDePago(
        Fecha(2026, 10, 1),
        Fecha(2027, 3, 31),
        festivos,
      );
      expect(
        [for (final p in pagos) p.ajustada.toString()],
        [
          '2026-10-01',
          '2026-10-12', // 11/oct es domingo
          '2026-11-02', // 1/nov es domingo
          '2026-11-11',
          '2026-12-01',
          '2026-12-11',
          '2027-01-04', // 1/ene/2027 es festivo (viernes); sábado y domingo
          '2027-01-11',
          '2027-02-02', // 1/feb/2027 es festivo (lunes)
          '2027-02-11',
          '2027-03-01',
          '2027-03-11',
        ],
      );
      expect(pension.vecesAlAnio, 24);
      expect(Equivalente.de(320000, pension.frecuencia).semanal, 147692);
    });

    test('quincenal del 15 y último día, también en febrero', () {
      final q = CalendarioPago.quincenal();
      expect(
        q.fechasNominales(Fecha(2026, 2, 1), Fecha(2026, 2, 28)),
        [Fecha(2026, 2, 15), Fecha(2026, 2, 28)],
      );
      expect(
        q.fechasNominales(Fecha(2028, 2, 1), Fecha(2028, 2, 29)),
        [Fecha(2028, 2, 15), Fecha(2028, 2, 29)],
      );
    });

    test('cada N meses: ancla en día 31, en febrero y catorcenal con ancla futura', () {
      expect(
        CalendarioPago.cadaMeses(Fecha(2026, 1, 31), 2)
            .fechasNominales(Fecha(2026, 1, 1), Fecha(2026, 12, 31))
            .map((f) => f.toString()),
        [
          '2026-01-31',
          '2026-03-31',
          '2026-05-31',
          '2026-07-31',
          '2026-09-30',
          '2026-11-30',
        ],
      );
      expect(
        CalendarioPago.cadaMeses(Fecha(2026, 12, 31), 2)
            .fechasNominales(Fecha(2026, 12, 1), Fecha(2027, 6, 30))
            .map((f) => f.toString()),
        ['2026-12-31', '2027-02-28', '2027-04-30', '2027-06-30'],
      );
      expect(
        CalendarioPago.catorcenal(Fecha(2026, 11, 6))
            .fechasNominales(Fecha(2026, 10, 1), Fecha(2026, 11, 30))
            .map((f) => f.toString()),
        ['2026-10-09', '2026-10-23', '2026-11-06', '2026-11-20'],
      );
    });

    test('regla por origen: la salida se queda en su fecha; "sin cambio" y "anterior"', () {
      expect(
        ajustarADiaHabil(Fecha(2026, 12, 26), ReglaDiaInhabil.siguienteDiaHabil, festivos),
        Fecha(2026, 12, 28),
      );
      expect(
        ajustarADiaHabil(Fecha(2027, 1, 1), ReglaDiaInhabil.diaHabilAnterior, festivos),
        Fecha(2026, 12, 31),
      );
      expect(
        ajustarADiaHabil(Fecha(2026, 11, 1), ReglaDiaInhabil.sinCambio, festivos),
        Fecha(2026, 11, 1),
      );
    });
  });

  group('Semáforos: los límites exactos', () {
    test('partida: 80 % verde, 100 % ámbar, más de 100 % rojo', () {
      expect(semaforoPartida(8000, 10000), Semaforo.verde);
      expect(semaforoPartida(8001, 10000), Semaforo.ambar);
      expect(semaforoPartida(10000, 10000), Semaforo.ambar);
      expect(semaforoPartida(10001, 10000), Semaforo.rojo);
      expect(semaforoPartida(0, 0), Semaforo.verde);
      expect(semaforoPartida(1, 0), Semaforo.rojo);
    });

    test('remanente y carga de deuda con ingreso cero o negativo no fallan', () {
      expect(semaforoRemanente(2000, 10000), Semaforo.verde);
      expect(semaforoRemanente(1999, 10000), Semaforo.ambar);
      expect(semaforoRemanente(999, 10000), Semaforo.rojo);
      expect(semaforoRemanente(-5, 10000), Semaforo.rojo);
      expect(semaforoRemanente(100, 0), Semaforo.rojo);
      expect(semaforoCargaDeuda(0, 0), Semaforo.verde);
      expect(semaforoCargaDeuda(1, 0), Semaforo.rojo);
      expect(semaforoCumplimiento(0, 0), Semaforo.verde);
    });
  });

  group('Grupo de deudas prioritarias: bordes', () {
    DeudaPlan deuda(
      String id, {
      int? saldo,
      bool grupo = true,
      int? orden,
      TipoDeuda tipo = TipoDeuda.conCosto,
    }) => DeudaPlan(
      id: id,
      nombre: id,
      tipo: tipo,
      abono: 100000,
      frecuencia: Frecuencia.mensual,
      tasaAnualPuntosBase: tipo == TipoDeuda.conCosto ? 3000 : 0,
      saldo: saldo,
      grupoPrioritario: grupo,
      ordenGrupo: orden,
    );

    test('una deuda ya liquidada (saldo 0) no recibe extra y pasa a la siguiente', () {
      final a = deuda('a', saldo: 0, orden: 1);
      final b = deuda('b', saldo: 500000, orden: 2);
      final destino = repartirRemanente(300000, {a: 0, b: 0});
      expect([for (final x in destino.abonosExtra) (x.deuda.id, x.monto)], [('b', 300000)]);
      expect(destino.ahorro, 0);
    });

    test('remanente cero o negativo no reparte nada ni inventa ahorro', () {
      final a = deuda('a', saldo: 500000, orden: 1);
      expect(repartirRemanente(0, {a: 0}).abonosExtra, isEmpty);
      expect(repartirRemanente(0, {a: 0}).ahorro, 0);
      expect(repartirRemanente(-500, {a: 0}).abonosExtra, isEmpty);
      expect(repartirRemanente(-500, {a: 0}).ahorro, 0);
    });

    test('ahorro mínimo del 100 % manda todo el remanente a ahorro', () {
      final a = deuda('a', saldo: 500000, orden: 1);
      final destino = repartirRemanente(
        100000,
        {a: 0},
        parametros: const ParametrosPlan(ahorroMinimoConDeudaPuntosBase: 10000),
      );
      expect(destino.abonosExtra, isEmpty);
      expect(destino.ahorro, 100000);
    });

    test('mismo orden: desempata por id; sin orden va al final', () {
      final x1 = deuda('x1', saldo: 100000, orden: 1);
      final x2 = deuda('x2', saldo: 100000, orden: 1);
      final destino = repartirRemanente(150000, {x2: 0, x1: 0});
      expect([for (final e in destino.abonosExtra) (e.deuda.id, e.monto)], [
        ('x1', 100000),
        ('x2', 50000),
      ]);
      final sin = deuda('y1', saldo: 100000);
      final con = deuda('y2', saldo: 100000, orden: 1);
      expect(
        [for (final d in ordenDeAbonoExtra([sin, con])) d.id],
        ['y2', 'y1'],
      );
    });

    test('con el grupo pagado el abono liberado va a ahorro', () {
      final a = deuda('a', saldo: 0, orden: 1);
      final destino = repartirRemanente(0, {a: 0}, liberado: 70000);
      expect(destino.abonosExtra, isEmpty);
      expect(destino.ahorro, 70000);
    });
  });
}

// Ahorro automático al cierre (Fase 4, E16): extras, sobre, sobrante y
// redondeo, en ese orden, sin apartar dos veces y sin dejar la semana en
// negativo. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'hogar_ejemplo.dart';

BolsaAhorro bolsa(
  String id,
  List<MetodoAhorro> metodos, {
  TipoBolsaAhorro tipo = TipoBolsaAhorro.metaLibre,
  int? aportePb,
  int multiplo = 1000,
  int prioridad = 1,
  bool activa = true,
}) => BolsaAhorro(
  id: id,
  libroId: 'l',
  nombre: id,
  tipo: tipo,
  cuentaId: 'c-$id',
  metodos: metodos,
  aportePb: aportePb,
  redondeoMultiplo: multiplo,
  prioridad: prioridad,
  activa: activa,
);

void main() {
  group('Orden del cierre: extras, sobre, sobrante y redondeo', () {
    test('cada método toma su parte y el sobrante se lleva lo que queda', () {
      final plan = planearAhorroDeCierre(
        remanente: 100000,
        extras: 50000,
        sobre: 8000,
        gastos: [4700, 12350],
        bolsas: [
          bolsa('a', [
            MetodoAhorro.porcentajeDeExtras,
            MetodoAhorro.sobrePorCategoria,
            MetodoAhorro.redondeo,
          ], aportePb: 2000),
          bolsa('b', [MetodoAhorro.sobranteSemanal], prioridad: 2),
        ],
      );
      expect(plan.aportes.map((a) => a.origen), [
        OrigenAporte.extras,
        OrigenAporte.sobre,
        OrigenAporte.sobrante,
      ], reason: 'el redondeo va al final y ya no queda nada');
      expect(plan.deOrigen(OrigenAporte.extras), 10000, reason: '20 % de 500');
      expect(plan.deOrigen(OrigenAporte.sobre), 8000);
      expect(plan.deOrigen(OrigenAporte.sobrante), 82000);
      expect(plan.total, 100000);
      expect(plan.disponibleFinal, 0);
    });

    test('el redondeo sale al final si hay otros métodos y queda disponible', () {
      final plan = planearAhorroDeCierre(
        remanente: 20000,
        gastos: [4700, 12350, 8000], // faltan 300 + 650 + 0
        bolsas: [bolsa('a', [MetodoAhorro.redondeo])],
      );
      expect(plan.aportes.single.origen, OrigenAporte.redondeo);
      expect(plan.total, 950);
      expect(plan.disponibleFinal, 19050);
    });

    test('el redondeo nunca deja la semana en negativo', () {
      final plan = planearAhorroDeCierre(
        remanente: 500,
        gastos: [4700, 12350], // pediría 950
        bolsas: [bolsa('a', [MetodoAhorro.redondeo])],
      );
      expect(plan.total, 500);
      expect(plan.disponibleFinal, 0);
    });

    test('sin remanente no se aparta nada', () {
      for (final r in [0, -1000]) {
        final plan = planearAhorroDeCierre(
          remanente: r,
          extras: 100000,
          gastos: [4700],
          bolsas: [
            bolsa('a', [
              MetodoAhorro.porcentajeDeExtras,
              MetodoAhorro.redondeo,
            ], aportePb: 1000),
          ],
        );
        expect(plan.aportes, isEmpty);
        expect(plan.total, 0);
      }
    });

    test('un método que no está en la bolsa no se aplica; una inactiva tampoco', () {
      final plan = planearAhorroDeCierre(
        remanente: 100000,
        extras: 50000,
        gastos: [4700],
        bolsas: [
          bolsa('a', [MetodoAhorro.montoFijo]),
          bolsa('b', [MetodoAhorro.redondeo], activa: false),
        ],
      );
      expect(plan.aportes, isEmpty);
    });

    test('extras sin porcentaje configurado no aparta nada (no se inventa)', () {
      final plan = planearAhorroDeCierre(
        remanente: 100000,
        extras: 50000,
        bolsas: [bolsa('a', [MetodoAhorro.porcentajeDeExtras])],
      );
      expect(plan.aportes, isEmpty);
    });

    test('con varias bolsas el sobre y el sobrante no se cuentan dos veces', () {
      final plan = planearAhorroDeCierre(
        remanente: 30000,
        sobre: 5000,
        bolsas: [
          bolsa('a', [MetodoAhorro.sobrePorCategoria], prioridad: 1),
          bolsa('b', [MetodoAhorro.sobrePorCategoria], prioridad: 2),
        ],
      );
      expect(plan.aportadoA('a'), 5000);
      expect(plan.aportadoA('b'), 0);
    });

    test('es determinista: mismos datos, mismo plan', () {
      List<AporteDeCierre> corre() => planearAhorroDeCierre(
        remanente: 77777,
        extras: 12345,
        sobre: 999,
        gastos: [101, 1999, 5000],
        bolsas: [
          bolsa('x', [
            MetodoAhorro.porcentajeDeExtras,
            MetodoAhorro.redondeo,
          ], aportePb: 1500),
        ],
      ).aportes;
      expect(corre().toString(), corre().toString());
    });
  });

  group('Con deuda que recibe abono extra (regla 16)', () {
    test('solo el mínimo del remanente y solo al fondo de emergencia', () {
      final plan = planearAhorroDeCierre(
        remanente: 100000,
        gastos: [4700],
        hayDeudaConExtra: true,
        ahorroMinimoConDeudaPuntosBase: 1000, // 10 %
        bolsas: [
          bolsa('meta', [MetodoAhorro.sobranteSemanal]),
          bolsa(
            'fondo',
            [MetodoAhorro.sobranteSemanal],
            tipo: TipoBolsaAhorro.fondoEmergencia,
          ),
        ],
      );
      expect(plan.aportes.single.bolsaId, 'fondo');
      expect(plan.total, 10000);
      expect(plan.disponibleFinal, 0);
    });
  });

  group('Datos de la semana', () {
    final semana = Semana.de(Fecha(2026, 10, 26));

    test('los gastos de la semana son los confirmados de esa semana', () {
      final d = hogarEjemplo(
        movimientos: [
          gasto('g1', Fecha(2026, 10, 27), 180000, 'g-alimentacion'),
          gasto('g2', Fecha(2026, 10, 28), 4700, 'g-alimentacion'),
          gasto('fuera', Fecha(2026, 10, 20), 9900, 'g-alimentacion'),
        ],
      );
      expect(gastosDeLaSemana(d, casa, semana), unorderedEquals([180000, 4700]));
    });

    test('el esencial real sale de las partidas protegidas de los cierres', () {
      var d = hogarEjemplo(
        movimientos: [gasto('g1', Fecha(2026, 10, 27), 180000, 'g-alimentacion')],
      );
      expect(esencialesPorSemanaCerrada(d, casa), isEmpty);
      final plan = armarPlanDelLibro(d, casa, semana);
      final foto = fotoDelPlan(
        plan,
        id: 'sem-1',
        libroId: casa,
        arrastrePorOrigen: const {},
        activadaPor: ana,
        activadaEn: DateTime(2026, 10, 26, 8),
        generarId: (() {
          var n = 0;
          return () => 'p-${n++}';
        })(),
      );
      d = d.copiar(semanas: [foto]);
      final v = vistaSemana(d, casa, semana, hoy: Fecha(2026, 11, 2));
      final cierre = cierreDeLaVista(
        v,
        d,
        id: 'c1',
        accion: AccionCierre.sinAplicar,
        cerradoPor: ana,
        cerradoEn: DateTime(2026, 11, 2, 9),
      );
      d = d.copiar(
        cierres: [cierre],
        semanas: [foto.conEstado(EstadoSemana.cerrada)],
      );
      final protegidas = {
        for (final p in foto.partidas)
          if (p.protegida) p.id,
      };
      expect(protegidas, isNotEmpty);
      final esperado = cierre.partidas
          .where((r) => protegidas.contains(r.partidaId))
          .fold<int>(0, (t, r) => t + r.gastado);
      expect(esperado, greaterThan(0));
      expect(esencialesPorSemanaCerrada(d, casa), [esperado]);
      // Con el historial, el gasto esencial deja de decir "según tu plan".
      final g = gastoEsencialSemanal(
        esencialesPorSemanaCerrada: esencialesPorSemanaCerrada(d, casa),
        presupuestoEsencial: 1,
      );
      expect(g.origen, OrigenEsencial.historial);
      expect(g.rotulo, isNull);
      expect(g.semanal, esperado);
    });
  });
}

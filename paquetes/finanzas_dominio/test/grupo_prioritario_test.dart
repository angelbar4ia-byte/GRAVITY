// Grupo de deudas prioritarias (P12 y P19; regla 4 de 4.5).
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'ejemplo_ana_alex.dart';

DeudaPlan deuda(
  String id, {
  TipoDeuda tipo = TipoDeuda.conCosto,
  int abono = 100000,
  int tasa = 3000,
  int? saldo,
  bool grupo = false,
  int? orden,
}) => DeudaPlan(
  id: id,
  nombre: id,
  tipo: tipo,
  abono: abono,
  frecuencia: Frecuencia.mensual,
  tasaAnualPuntosBase: tipo == TipoDeuda.conCosto ? tasa : 0,
  saldo: saldo,
  grupoPrioritario: grupo,
  ordenGrupo: orden,
);

void main() {
  group('Orden de abono extra con grupo', () {
    final cara = deuda('cara', tasa: 6000, saldo: 500000);
    final barata = deuda(
      'barata',
      tasa: 2000,
      saldo: 500000,
      grupo: true,
      orden: 1,
    );
    final familiar = deuda(
      'familiar',
      tipo: TipoDeuda.familiar,
      saldo: 300000,
      grupo: true,
      orden: 2,
    );
    final msi = deuda('msi', tipo: TipoDeuda.msi, saldo: 120000);

    test('sin grupo: por costo y los familiares al final (decisión 51)', () {
      final sinGrupo = [
        deuda('cara', tasa: 6000),
        deuda('barata', tasa: 2000),
        deuda('familiar', tipo: TipoDeuda.familiar),
        deuda('msi', tipo: TipoDeuda.msi),
      ];
      expect(ordenDeAbonoExtra(sinGrupo).map((d) => d.id), [
        'cara',
        'barata',
        'familiar',
      ]);
    });

    test(
      'con grupo: solo las del grupo, en el orden que eligió el titular',
      () {
        expect(hayGrupoPrioritario([cara, barata, familiar, msi]), isTrue);
        expect(
          ordenDeAbonoExtra([cara, barata, familiar, msi]).map((d) => d.id),
          ['barata', 'familiar'],
        );
      },
    );

    test(
      'el remanente va a la primera del grupo y lo que sobra a la siguiente',
      () {
        final destino = repartirRemanente(700000, {
          cara: 0,
          barata: 0,
          familiar: 0,
          msi: 0,
        });
        expect(
          [for (final a in destino.abonosExtra) (a.deuda.id, a.monto)],
          [('barata', 500000), ('familiar', 200000)],
        );
        expect(destino.ahorro, 0);
      },
    );

    test(
      'cuando el grupo queda pagado, el dinero va a ahorro (no a las demás)',
      () {
        final destino = repartirRemanente(900000, {
          cara: 0,
          barata: 0,
          familiar: 0,
        });
        expect(destino.totalAbonoExtra, 800000);
        expect(destino.extraPara('cara'), 0);
        expect(destino.ahorro, 100000);
      },
    );

    test('el ahorro mínimo sale del remanente, no del abono liberado', () {
      final destino = repartirRemanente(
        100000,
        {barata: 0},
        parametros: const ParametrosPlan(ahorroMinimoConDeudaPuntosBase: 1000),
        liberado: 50000,
      );
      expect(destino.ahorro, 10000);
      expect(destino.extraPara('barata'), 140000);
    });
  });

  group('Proyección con grupo (P19)', () {
    test('sin grupo se conserva el ejemplo del diseño (prueba 10)', () {
      final plan = planEjemplo(
        deudas: [tarjetaEjemplo, prestamoFamiliarEjemplo],
      );
      final p = proyectarSalidaDeDeuda(
        abonos: plan.abonos,
        remanenteSemanal: plan.remanente,
        semanas: 8,
      );
      expect(p.semanaDeLiquidacion('tarjeta'), 4);
      expect(p.semanaDeLiquidacion('familiar'), 5);
      // Desde la semana 6, solo el remanente ($1,520.00) va a ahorro.
      expect(p.semanas[5].ahorro, 152000);
    });

    test('con grupo, el abono liberado pasa a la siguiente deuda y luego a '
        'ahorro', () {
      // Grupo: primero el préstamo familiar, después la tarjeta.
      final tarjeta = DeudaPlan(
        id: 'tarjeta',
        nombre: 'Tarjeta',
        tipo: TipoDeuda.conCosto,
        abono: 120000,
        frecuencia: Frecuencia.mensual,
        tasaAnualPuntosBase: 4800,
        saldo: 600000,
        grupoPrioritario: true,
        ordenGrupo: 2,
      );
      final familiar = DeudaPlan(
        id: 'familiar',
        nombre: 'Préstamo familiar',
        tipo: TipoDeuda.familiar,
        abono: 50000,
        frecuencia: Frecuencia.mensual,
        saldo: 300000,
        grupoPrioritario: true,
        ordenGrupo: 1,
      );
      final plan = planEjemplo(deudas: [tarjeta, familiar]);
      final p = proyectarSalidaDeDeuda(
        abonos: plan.abonos,
        remanenteSemanal: plan.remanente,
        semanas: 10,
      );
      // El familiar (primero del grupo) se liquida en la semana 2:
      // 300000 − (11538 + 152000) = 136462; semana 2 lo termina.
      expect(p.semanaDeLiquidacion('familiar'), 2);
      expect(p.semanaDeLiquidacion('tarjeta'), lessThanOrEqualTo(5));
      final libre = p.semanaLibreDeDeuda!;
      // Desde la semana siguiente a quedar libre, todo va a ahorro:
      // remanente + los dos abonos liberados.
      expect(p.semanas[libre].ahorro, plan.remanente + plan.deudaPlaneada);
      // Sin grupo, el ahorro de esa misma semana sería solo el remanente.
      final sinGrupo = proyectarSalidaDeDeuda(
        abonos: planEjemplo().abonos,
        remanenteSemanal: plan.remanente,
        semanas: 10,
      );
      expect(sinGrupo.semanas[9].ahorro, plan.remanente);
    });
  });

  group('Cierre con grupo', () {
    test('el remanente real del cierre va al grupo', () {
      final familiar = DeudaPlan(
        id: 'familiar',
        nombre: 'Préstamo familiar',
        tipo: TipoDeuda.familiar,
        abono: 50000,
        frecuencia: Frecuencia.mensual,
        saldo: 300000,
        grupoPrioritario: true,
        ordenGrupo: 1,
      );
      final plan = planEjemplo(deudas: [tarjetaEjemplo, familiar]);
      final cierre = cerrarSemana(
        plan,
        ingresoReal: plan.ingreso,
        gastadoPorPartida: gastoSegunPlan(plan),
      );
      expect(cierre.destino.extraPara('familiar'), 152000);
      expect(cierre.destino.extraPara('tarjeta'), 0);
    });
  });
}

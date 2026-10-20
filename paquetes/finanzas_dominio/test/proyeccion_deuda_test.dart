import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'ejemplo_ana_alex.dart';

/// Tabla "Salida de deuda del ejemplo" de 5.6 bis, punto 5:
/// (semana, saldo de la tarjeta, saldo del préstamo familiar, ahorro).
const tablaDelDiseno = [
  (1, 425846, 288462, 0),
  (2, 250085, 276924, 0),
  (3, 72702, 265386, 0),
  (4, 0, 147529, 0),
  (5, 0, 0, 16009),
  (6, 0, 0, 152000),
];

void verificar(ProyeccionDeuda p, int tolerancia) {
  for (final (semana, tarjeta, familiar, ahorro) in tablaDelDiseno) {
    final s = p.semanas[semana - 1];
    expect(
      s.saldos['tarjeta'],
      closeTo(tarjeta, tolerancia),
      reason: 'tarjeta, semana $semana',
    );
    expect(
      s.saldos['familiar'],
      closeTo(familiar, tolerancia),
      reason: 'familiar, semana $semana',
    );
    expect(
      s.ahorro,
      closeTo(ahorro, tolerancia),
      reason: 'ahorro, semana $semana',
    );
  }
}

void main() {
  group('5.6 bis, prueba 10: salida de deuda del ejemplo', () {
    test('con el plan del motor (tolerancia de centavos por redondeo)', () {
      final plan = planEjemplo();
      final p = proyectarSalidaDeDeuda(
        abonos: plan.abonos,
        remanenteSemanal: plan.remanente,
        semanas: 8,
      );
      expect(p.semanaDeLiquidacion('tarjeta'), 4);
      expect(p.semanaDeLiquidacion('familiar'), 5);
      expect(p.semanaLibreDeDeuda, 5);
      expect(p.semanas[5].ahorro, 152000); // desde la semana 6: $1,520.00
      expect(p.semanas[7].ahorro, 152000);
      expect(p.interesesTotales, closeTo(12449, 10)); // unos $124.49
      // El préstamo familiar lleva $115.39 por semana (el diseño usa $115.38),
      // así que la diferencia crece un centavo por semana: máximo 6 centavos.
      verificar(p, 10);
    });

    test(
      'con los abonos literales del diseño la diferencia es de un centavo',
      () {
        final p = proyectarSalidaDeDeuda(
          abonos: [
            Renglon(tarjetaEjemplo, 27692),
            Renglon(prestamoFamiliarEjemplo, 11538),
          ],
          remanenteSemanal: 152000,
          semanas: 6,
        );
        verificar(p, 1);
        expect(p.interesesTotales, closeTo(12449, 1));
      },
    );
  });

  test('la deuda familiar no crece al diferir; la de costo sí', () {
    final p = proyectarSalidaDeDeuda(
      abonos: [Renglon(tarjetaEjemplo, 0), Renglon(prestamoFamiliarEjemplo, 0)],
      remanenteSemanal: 0,
      semanas: 3,
    );
    expect(p.semanas.last.saldos['familiar'], 300000);
    expect(p.semanas.first.saldos['tarjeta'], 605538); // + interés semanal
    expect(p.semanas.last.saldos['tarjeta'], greaterThan(605538));
  });

  test('necesita el saldo de cada deuda', () {
    final sinSaldo = DeudaPlan(
      id: 'x',
      nombre: 'x',
      tipo: TipoDeuda.familiar,
      abono: 100,
      frecuencia: Frecuencia.semanal,
    );
    expect(
      () => proyectarSalidaDeDeuda(
        abonos: [Renglon(sinSaldo, 100)],
        remanenteSemanal: 0,
      ),
      throwsArgumentError,
    );
  });
}

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('Equivalentes semanales (sección 4)', () {
    test('cada frecuencia', () {
      int semanal(int monto, Frecuencia f, {int? dias}) =>
          Equivalente.de(monto, f, diasActivosPorSemana: dias).semanal;

      expect(semanal(100000, Frecuencia.semanal), 100000);
      expect(semanal(500000, Frecuencia.catorcenal), 250000); // monto ÷ 2
      expect(semanal(600000, Frecuencia.quincenal), 276923); // × 24 / 52
      expect(semanal(800000, Frecuencia.mensual), 184615); // × 12 / 52
      expect(semanal(90000, Frecuencia.bimestral), 10385); // × 6 / 52
      expect(semanal(52000, Frecuencia.trimestral), 4000); // × 4 / 52
      expect(semanal(52000, Frecuencia.semestral), 2000); // × 2 / 52
      expect(semanal(156000, Frecuencia.anual), 3000); // ÷ 52
      expect(semanal(3000, Frecuencia.diaria, dias: 5), 15000); // pasaje L-V
    });

    test('IN1: quincenal \$6,000, catorcenal \$5,000 y mensual \$2,000', () {
      expect(Equivalente.de(600000, Frecuencia.quincenal).semanal, 276923);
      expect(Equivalente.de(500000, Frecuencia.catorcenal).semanal, 250000);
      expect(Equivalente.de(200000, Frecuencia.mensual).semanal, 46154);
    });

    test('renta de \$8,000 al mes ≈ \$1,846 por semana (sección 4)', () {
      expect(Equivalente.de(800000, Frecuencia.mensual).semanal, 184615);
    });

    test('la frecuencia diaria exige días activos válidos', () {
      expect(
        () => Equivalente.de(3000, Frecuencia.diaria),
        throwsArgumentError,
      );
      expect(
        () => Equivalente.de(3000, Frecuencia.diaria, diasActivosPorSemana: 8),
        throwsArgumentError,
      );
      expect(
        () => Equivalente.de(3000, Frecuencia.mensual, diasActivosPorSemana: 5),
        throwsArgumentError,
      );
    });

    test('medio centavo semanal se redondea hacia arriba (R1)', () {
      // 13 centavos trimestrales = 52 al año → 1 por semana exacto.
      expect(Equivalente.de(13, Frecuencia.trimestral).semanal, 1);
      // 26 centavos al año → 0.5 por semana → 1.
      expect(Equivalente.de(26, Frecuencia.anual).semanal, 1);
      // 25 centavos al año → 0.48 por semana → 0.
      expect(Equivalente.de(25, Frecuencia.anual).semanal, 0);
    });
  });

  group('Sumas exactas (R2) con el ejemplo de 5.6 bis', () {
    final ana = Equivalente.de(900000, Frecuencia.quincenal);
    final alex = Equivalente.de(1400000, Frecuencia.mensual);

    test('se suma exacto y se redondea una vez', () {
      expect(ana.semanal, 415385); // $4,153.85
      expect(alex.semanal, 323077); // $3,230.77
      expect((ana + alex).semanal, 738462); // $7,384.62
    });

    test('equivalencias por periodo del ingreso', () {
      final ingreso = ana + alex;
      expect(ingreso.enPeriodo(TipoPeriodo.semana), 738462);
      expect(ingreso.enPeriodo(TipoPeriodo.quincena), 1600000); // $16,000.00
      expect(ingreso.enPeriodo(TipoPeriodo.catorcena), 1476923); // $14,769.23
      expect(ingreso.enPeriodo(TipoPeriodo.mes), 3200000); // $32,000.00
    });

    test('los renglones suman exactamente el total semanal', () {
      final renglones = [
        Equivalente.de(800000, Frecuencia.mensual), // renta
        Equivalente.de(90000, Frecuencia.bimestral), // luz
        Equivalente.de(30000, Frecuencia.mensual), // agua
        Equivalente.de(40000, Frecuencia.mensual), // internet
        Equivalente.de(35000, Frecuencia.mensual), // celular
        Equivalente.de(156000, Frecuencia.anual), // reserva placas y predial
        Equivalente.de(325000, Frecuencia.semanal), // variables
      ];
      final semanales = semanalesQueSuman(renglones);
      expect(semanales, [184615, 10385, 6923, 9231, 8077, 3000, 325000]);
      expect(semanales.reduce((a, b) => a + b), 547231);
      expect(Equivalente.suma(renglones).semanal, 547231);
    });
  });
}

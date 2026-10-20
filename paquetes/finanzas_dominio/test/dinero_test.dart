import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Regla de redondeo R1 (al centavo más cercano, medios lejos de cero)',
    () {
      test('redondea al más cercano', () {
        expect(dividirRedondeando(10, 3), 3); // 3.33
        expect(dividirRedondeando(20, 3), 7); // 6.67
        expect(dividirRedondeando(21600000, 52), 415385); // 415,384.62
      });

      test('los medios se alejan de cero', () {
        expect(dividirRedondeando(1, 2), 1); // 0.5
        expect(dividirRedondeando(3, 2), 2); // 1.5
        expect(dividirRedondeando(5, 2), 3); // 2.5 (no es redondeo bancario)
        expect(dividirRedondeando(26, 52), 1); // medio centavo semanal
        expect(dividirRedondeando(-1, 2), -1);
        expect(dividirRedondeando(-5, 2), -3);
        expect(dividirRedondeando(5, -2), -3);
      });

      test('justo debajo del medio baja', () {
        expect(dividirRedondeando(25, 52), 0); // 0.48
        expect(dividirRedondeando(-25, 52), 0);
      });

      test('no divide entre cero', () {
        expect(() => dividirRedondeando(1, 0), throwsArgumentError);
      });
    },
  );

  group('Porcentajes en puntos base', () {
    test('aplicar 20 % al ingreso del ejemplo', () {
      expect(aplicarPorcentaje(738462, 2000), 147692); // $1,476.92
    });

    test('proporción redondeada', () {
      expect(proporcionEnPuntosBase(152000, 738462), 2058); // 20.58 %
      expect(proporcionEnPuntosBase(39231, 738462), 531); // 5.31 %
      expect(proporcionEnPuntosBase(1, 0), 0);
    });

    test('comparación exacta contra un umbral', () {
      expect(compararProporcion(20, 100, 2000), 0);
      expect(compararProporcion(19999, 100000, 2000), lessThan(0));
      expect(compararProporcion(20001, 100000, 2000), greaterThan(0));
    });
  });

  group('Regla R2: reparto con mayor resto', () {
    test('los renglones suman el total redondeado', () {
      // 0.4 + 0.4 + 0.4 = 1.2 → 1; el centavo va al primero (empate).
      expect(repartirConMayorResto([4, 4, 4], 10), [1, 0, 0]);
      // 0.6 + 0.6 = 1.2 → 1; ambos tienen resto 6: gana el primero.
      expect(repartirConMayorResto([6, 6], 10), [1, 0]);
      // 0.3 + 0.8 = 1.1 → 1: el de mayor resto se lleva el centavo.
      expect(repartirConMayorResto([3, 8], 10), [0, 1]);
    });

    test('lista vacía', () {
      expect(repartirConMayorResto([], 52), isEmpty);
    });

    test('rechaza negativos', () {
      expect(() => repartirConMayorResto([-1], 52), throwsArgumentError);
    });
  });

  test('formato de apoyo', () {
    expect(formatearCentavos(152000), '1,520.00');
    expect(formatearCentavos(738462), '7,384.62');
    expect(formatearCentavos(-135000), '-1,350.00');
    expect(formatearCentavos(5), '0.05');
    expect(formatearCentavos(123456789), '1,234,567.89');
  });
}

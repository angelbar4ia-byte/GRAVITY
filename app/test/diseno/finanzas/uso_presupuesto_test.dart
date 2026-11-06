import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

UsoPresupuesto _uso(int asignado, int gastado) =>
    UsoPresupuesto(asignadoCentavos: asignado, gastadoCentavos: gastado);

void main() {
  group('UsoPresupuesto: porcentaje', () {
    test('exacto', () {
      expect(_uso(180000, 111600).porcentaje, 62);
      expect(_uso(180000, 111600).textoPorcentaje, '62 %');
      expect(_uso(100000, 0).porcentaje, 0);
      expect(_uso(90000, 90000).porcentaje, 100);
    });

    test('redondea hacia arriba: nunca se ve bajo un umbral ya cruzado', () {
      // 80.01 % → 81 % (y ya es ámbar).
      expect(_uso(1000000, 800100).porcentaje, 81);
      // 100.01 % → 101 % (y ya es rojo).
      expect(_uso(1000000, 1000100).porcentaje, 101);
      // Un peso de $1,800 → 1 %, no 0 %.
      expect(_uso(180000, 100).porcentaje, 1);
      // Excedido: $340 de $300 → 113.33 % → 114 %.
      expect(_uso(30000, 34000).porcentaje, 114);
    });

    test('sin presupuesto no hay porcentaje', () {
      expect(_uso(0, 0).porcentaje, isNull);
      expect(_uso(0, 5000).porcentaje, isNull);
      expect(_uso(0, 0).textoPorcentaje, 'Sin presupuesto');
    });

    test('un reembolso mayor que el gasto cuenta como 0 %', () {
      expect(_uso(50000, -2000).porcentaje, 0);
      expect(_uso(50000, -2000).fraccion, 0);
      expect(_uso(50000, -2000).restanteCentavos, 52000);
    });
  });

  group('UsoPresupuesto: semáforo con la fracción exacta', () {
    test('verde hasta 80 % (incluido)', () {
      expect(_uso(100000, 80000).estado, EstadoSemaforo.verde);
      expect(_uso(100000, 80000).textoEstado, 'Bien');
    });

    test('ámbar arriba de 80 % y hasta 100 % (incluido)', () {
      expect(_uso(100000, 80001).estado, EstadoSemaforo.ambar);
      expect(_uso(100000, 80001).textoEstado, 'Cerca del límite');
      expect(_uso(100000, 100000).estado, EstadoSemaforo.ambar);
      expect(_uso(100000, 100000).textoEstado, 'Al límite');
    });

    test('rojo arriba de 100 %', () {
      expect(_uso(100000, 100001).estado, EstadoSemaforo.rojo);
      expect(_uso(100000, 100001).textoEstado, 'Excedido');
      expect(_uso(100000, 100001).excedido, isTrue);
      expect(_uso(100000, 100001).restanteCentavos, -1);
    });

    test(
      '80.004 % se ve "81 %" y es ámbar: el porcentaje no esconde el cruce',
      () {
        final uso = _uso(2500000, 2000100);
        expect(uso.estado, EstadoSemaforo.ambar);
        expect(uso.porcentaje, greaterThan(80));
      },
    );

    test('sin presupuesto: rojo si hubo gasto, verde si no', () {
      expect(_uso(0, 1).estado, EstadoSemaforo.rojo);
      expect(_uso(0, 1).textoEstado, 'Excedido');
      expect(_uso(0, 1).fraccion, 1);
      expect(_uso(0, 0).estado, EstadoSemaforo.verde);
      expect(_uso(0, 0).textoEstado, 'Sin gasto');
      expect(_uso(0, 0).fraccion, 0);
    });

    test('umbrales editados por el dueño', () {
      const uso = UsoPresupuesto(
        asignadoCentavos: 100000,
        gastadoCentavos: 75000,
        ambarDesdePuntosBase: 7000,
        rojoArribaDePuntosBase: 9000,
      );
      expect(uso.estado, EstadoSemaforo.ambar);
      const rojo = UsoPresupuesto(
        asignadoCentavos: 100000,
        gastadoCentavos: 90001,
        ambarDesdePuntosBase: 7000,
        rojoArribaDePuntosBase: 9000,
      );
      expect(rojo.estado, EstadoSemaforo.rojo);
    });
  });

  group('formatearPuntosBase', () {
    test('dos decimales por defecto', () {
      expect(formatearPuntosBase(2058), '20.58 %');
      expect(formatearPuntosBase(531), '5.31 %');
      expect(formatearPuntosBase(2000), '20.00 %');
      expect(formatearPuntosBase(5), '0.05 %');
      expect(formatearPuntosBase(0), '0.00 %');
      expect(formatearPuntosBase(-1652), '-16.52 %');
    });

    test('uno o cero decimales, medios lejos de cero (R1)', () {
      expect(formatearPuntosBase(2055, decimales: 1), '20.6 %');
      expect(formatearPuntosBase(2054, decimales: 1), '20.5 %');
      expect(formatearPuntosBase(2050, decimales: 0), '21 %');
      expect(formatearPuntosBase(2049, decimales: 0), '20 %');
      expect(formatearPuntosBase(-2050, decimales: 0), '-21 %');
      expect(formatearPuntosBase(-4, decimales: 0), '0 %');
      expect(formatearPuntosBase(4800, decimales: 0), '48 %');
    });
  });

  group('formatearCentavos (montos de la cascada)', () {
    test('ejemplo 5.6 bis-1', () {
      expect(formatearCentavos(738462), r'$7,384.62');
      expect(formatearCentavos(547231), r'$5,472.31');
      expect(formatearCentavos(39231), r'$392.31');
      expect(formatearCentavos(152000), r'$1,520.00');
      expect(formatearCentavos(-8769), r'-$87.69');
    });
  });
}

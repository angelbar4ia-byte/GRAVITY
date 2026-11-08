// Cuadre por libro con aportaciones entre libros (D19; contrato del servidor:
// "una aportación cambia el patrimonio de cada libro sin pasar por el
// resultado"). Datos del hogar de ejemplo de Ana y Alex, ilustrativos.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'hogar_ejemplo.dart';

void main() {
  final dia = Fecha(2026, 10, 20);
  Movimiento mov(
    String id,
    TipoMovimiento tipo,
    String origen,
    String destino,
    int monto, {
    int hora = 10,
  }) => Movimiento(
    id: id,
    tipo: tipo,
    fecha: dia,
    registradoEn: DateTime(2026, 10, 20, hora),
    cuentaOrigenId: origen,
    cuentaDestinoId: destino,
    monto: monto,
    realizadoPor: ana,
  );

  // Ana aporta $2,000 al banco de la casa y paga $500 de la tarjeta
  // compartida desde su banco; la casa recibe el sueldo y gasta en súper.
  final aportacion = mov(
    'aportacion',
    TipoMovimiento.transferencia,
    'banco-ana',
    'banco-casa',
    200000,
  );
  final pagoTarjeta = mov(
    'pago-tarjeta',
    TipoMovimiento.pagoDeuda,
    'banco-ana',
    'tarjeta',
    50000,
    hora: 11,
  );
  final movimientos = [
    aportacion,
    pagoTarjeta,
    mov('sueldo', TipoMovimiento.ingreso, 'sueldo-ana', 'banco-casa', 900000),
    gasto('super-casa', dia, 150000, 'g-alimentacion'),
    gasto('super-ana', dia, 30000, 'g-alimentacion', origen: 'banco-ana'),
  ];
  final datos = hogarEjemplo(movimientos: movimientos);

  group('Aportaciones recibidas y entregadas (cuadre por libro)', () {
    test(
      'el libro que aporta: patrimonio = inicial + resultado − entregadas',
      () {
        final b = datos.vista(libroAna).balance();
        expect(b.patrimonioInicial, 1000000);
        expect(b.resultadoAcumulado, -30000, reason: 'solo su gasto');
        expect(b.aportacionesEntregadas, 200000 + 50000);
        expect(b.aportacionesRecibidas, 0);
        expect(b.patrimonio, 1000000 - 30000 - 250000);
        expect(
          b.patrimonio,
          b.patrimonioInicial +
              b.resultadoAcumulado +
              b.aportacionesRecibidas -
              b.aportacionesEntregadas,
        );
        expect(b.cuadra, isTrue);
      },
    );

    test(
      'el libro que recibe: patrimonio = inicial + resultado + recibidas',
      () {
        final b = datos.vista(casa).balance();
        // Inicial: banco $5,000 − tarjeta $6,000 − préstamo $3,000.
        expect(b.patrimonioInicial, 500000 - 600000 - 300000);
        expect(b.resultadoAcumulado, 900000 - 150000);
        expect(b.aportacionesRecibidas, 250000);
        expect(b.aportacionesEntregadas, 0);
        // Activos: 5,000 + 2,000 + 9,000 − 1,500; pasivos: 6,000 − 500 + 3,000.
        expect(b.activos, 1450000);
        expect(b.pasivos, 850000);
        expect(b.patrimonio, 600000);
        expect(b.patrimonioEsperado, b.patrimonio);
        expect(b.cuadra, isTrue);
      },
    );

    test('la aportación no pasa por el resultado de ningún libro', () {
      final periodo = Periodo.semana(dia);
      final deAna = datos.vista(libroAna).estadoResultados(periodo);
      final deCasa = datos.vista(casa).estadoResultados(periodo);
      expect(deAna.ingresos, 0);
      expect(deAna.gastos, 30000, reason: 'no es gasto de Ana');
      expect(deCasa.ingresos, 900000, reason: 'no es ingreso de la casa');
      expect(deCasa.gastos, 150000);
    });

    test('lo entregado por un libro es lo recibido por el otro', () {
      final entregadas = datos.vista(libroAna).balance().aportacionesEntregadas;
      final recibidas = datos.vista(casa).balance().aportacionesRecibidas;
      expect(entregadas, recibidas);
    });

    test('al anular una aportación se descuenta de su mismo lado', () {
      final libro = datos.nuevoLibroHogar();
      final contra = libro.anular(
        'aportacion',
        nuevoId: 'anula-aportacion',
        motivo: 'Se capturó dos veces',
        registradoPor: ana,
        registradoEn: DateTime(2026, 10, 20, 12),
      );
      final conAnulacion = hogarEjemplo(movimientos: [...movimientos, contra]);
      final deAna = conAnulacion.vista(libroAna).balance();
      final deCasa = conAnulacion.vista(casa).balance();
      expect(deAna.aportacionesEntregadas, 50000);
      expect(deAna.aportacionesRecibidas, 0, reason: 'no es una recibida');
      expect(deCasa.aportacionesRecibidas, 50000);
      expect(deCasa.aportacionesEntregadas, 0);
      expect(deAna.cuadra, isTrue);
      expect(deCasa.cuadra, isTrue);
    });

    test(
      'el balance a una fecha solo cuenta las aportaciones hasta ese día',
      () {
        final antes = datos.vista(casa).balance(al: Fecha(2026, 10, 19));
        expect(antes.aportacionesRecibidas, 0);
        expect(antes.cuadra, isTrue);
        final (recibidas, entregadas) = datos
            .vista(libroAna)
            .aportaciones(desde: dia, hasta: dia);
        expect((recibidas, entregadas), (0, 250000));
      },
    );
  });

  group('Solo transferencia y pago de deuda cruzan de libro (regla 5)', () {
    test(
      'un ingreso, una apertura o un ajuste no cruzan de un libro a otro',
      () {
        for (final m in [
          mov('i', TipoMovimiento.ingreso, 'sueldo-ana', 'banco-ana', 100),
          mov('a', TipoMovimiento.apertura, 'apertura-casa', 'banco-papa', 100),
          Movimiento(
            id: 'aj',
            tipo: TipoMovimiento.ajuste,
            fecha: dia,
            registradoEn: DateTime(2026, 10, 20),
            cuentaOrigenId: 'ajustes-casa',
            cuentaDestinoId: 'banco-ana',
            monto: 100,
            realizadoPor: ana,
            motivo: 'Diferencia',
          ),
        ]) {
          expect(
            () => hogarEjemplo().nuevoLibroHogar().agregar(m),
            throwsA(isA<ErrorLibro>()),
            reason: m.tipo.name,
          );
        }
      },
    );

    test('la transferencia, el pago de deuda y su anulación sí cruzan', () {
      final libro = hogarEjemplo().nuevoLibroHogar()
        ..agregar(aportacion)
        ..agregar(pagoTarjeta);
      final contra = libro.anular(
        'pago-tarjeta',
        nuevoId: 'anula-pago',
        motivo: 'Error',
        registradoPor: ana,
        registradoEn: DateTime(2026, 10, 20, 13),
      );
      expect(contra.cuentaOrigenId, 'tarjeta');
      expect(libro.estaAnulado('pago-tarjeta'), isTrue);
    });

    test('un gasto a una cuenta de gasto del hogar no es un cruce', () {
      expect(
        () => hogarEjemplo().nuevoLibroHogar().agregar(
          gasto('g', dia, 100, 'g-salud', origen: 'banco-papa'),
        ),
        returnsNormally,
      );
    });
  });
}

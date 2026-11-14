// Reportes puros del libro (Fase 8, bloque 4): gasto por categoría y por mes.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'hogar_ejemplo.dart';

void main() {
  final octubre = RangoReporte.mes(2026, 10);

  Movimiento anula(Movimiento m) => Movimiento(
    id: 'anula-${m.id}',
    tipo: TipoMovimiento.anulacion,
    fecha: m.fecha,
    registradoEn: DateTime(2026, 10, 21),
    cuentaOrigenId: m.cuentaDestinoId,
    cuentaDestinoId: m.cuentaOrigenId,
    monto: m.monto,
    realizadoPor: ana,
    motivo: 'Error al capturar',
    anulaA: m.id,
  );

  final luz = gasto(
    'g1',
    Fecha(2026, 10, 5),
    80000,
    'g-vivienda',
    categoria: 'c-luz',
  );
  final agua = gasto(
    'g2',
    Fecha(2026, 10, 6),
    20000,
    'g-vivienda',
    categoria: 'c-agua',
  );
  final super1 = gasto(
    'g3',
    Fecha(2026, 10, 7),
    100000,
    'g-alimentacion',
    categoria: 'c-super',
  );
  final sinCat = gasto('g4', Fecha(2026, 10, 8), 5000, 'g-vivienda');
  final deAna = gasto(
    'g5',
    Fecha(2026, 10, 9),
    70000,
    'g-alimentacion',
    origen: 'banco-ana',
    categoria: 'c-super',
    por: ana,
  );
  final septiembre = gasto('g6', Fecha(2026, 9, 30), 30000, 'g-salud');

  test('agrupa por categoría de nivel 1, mayor primero, y suma el total', () {
    final d = hogarEjemplo(
      movimientos: [luz, agua, super1, sinCat, septiembre],
    );
    final r = gastoPorCategoria(d, casa, octubre);
    expect(r.totalCentavos, 205000);
    expect(r.lineas.map((l) => l.nombre), [
      'Alimentación',
      'Vivienda y servicios',
      nombreSinCategoria,
    ]);
    expect(r.lineas.map((l) => l.centavos), [100000, 100000, 5000]);
    // 100000 / 205000 = 48.78% -> 4878 pb (hacia abajo).
    expect(r.lineas.first.partePb, 4878);
  });

  test('solo cuenta el libro pedido', () {
    final d = hogarEjemplo(movimientos: [super1, deAna]);
    expect(gastoPorCategoria(d, casa, octubre).totalCentavos, 100000);
    expect(gastoPorCategoria(d, libroAna, octubre).totalCentavos, 70000);
    expect(gastoPorCategoria(d, libroPapa, octubre).totalCentavos, 0);
  });

  test('un gasto anulado y su contraasiento no cuentan', () {
    final d = hogarEjemplo(movimientos: [luz, super1, anula(luz)]);
    final r = gastoPorCategoria(d, casa, octubre);
    expect(r.totalCentavos, 100000);
    expect(r.lineas.single.nombre, 'Alimentación');
  });

  test('periodo configurable: los extremos cuentan', () {
    final d = hogarEjemplo(movimientos: [luz, septiembre]);
    final r = gastoPorCategoria(
      d,
      casa,
      RangoReporte(Fecha(2026, 9, 30), Fecha(2026, 10, 5)),
    );
    expect(r.totalCentavos, 110000);
  });

  test('sin gastos: total cero y sin líneas', () {
    final r = gastoPorCategoria(hogarEjemplo(), casa, octubre);
    expect(r.totalCentavos, 0);
    expect(r.lineas, isEmpty);
  });

  test('un periodo al revés es un error', () {
    expect(
      () => RangoReporte(Fecha(2026, 10, 5), Fecha(2026, 10, 1)),
      throwsArgumentError,
    );
  });

  test('gasto por mes: del más antiguo al más reciente, cruzando el año', () {
    final d = hogarEjemplo(
      movimientos: [
        luz,
        septiembre,
        gasto('g7', Fecha(2026, 1, 15), 1000, 'g-salud'),
      ],
    );
    final m = gastoPorMes(d, casa, Fecha(2026, 10, 20), meses: 3);
    expect(m.map((x) => (x.anio, x.mes, x.centavos)), [
      (2026, 8, 0),
      (2026, 9, 30000),
      (2026, 10, 80000),
    ]);
    final ene = gastoPorMes(d, casa, Fecha(2026, 1, 20), meses: 2);
    expect(ene.map((x) => (x.anio, x.mes)), [(2025, 12), (2026, 1)]);
    expect(ene.last.centavos, 1000);
  });
}

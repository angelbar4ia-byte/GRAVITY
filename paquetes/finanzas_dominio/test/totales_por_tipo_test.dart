// Totales por tipo de movimiento de un periodo (Fase 8, movimientos y pagos).
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

const _yo = 'persona-yo';

Cuenta _c(String id, TipoCuenta t) => Cuenta(id: id, nombre: id, tipo: t);

Movimiento _m(
  String id,
  TipoMovimiento tipo,
  Fecha f,
  String origen,
  String destino,
  int monto, {
  EstadoMovimiento estado = EstadoMovimiento.confirmado,
}) => Movimiento(
  id: id,
  tipo: tipo,
  fecha: f,
  registradoEn: DateTime(f.anio, f.mes, f.dia, 12),
  cuentaOrigenId: origen,
  cuentaDestinoId: destino,
  monto: monto,
  realizadoPor: _yo,
  estadoInicial: estado,
);

LibroMovimientos _libro(List<Movimiento> movs) => LibroMovimientos.restaurar(
  cuentas: [
    _c('banco', TipoCuenta.banco),
    _c('efectivo', TipoCuenta.efectivo),
    _c('ahorro', TipoCuenta.ahorro),
    _c('tarjeta', TipoCuenta.tarjeta),
    _c('sueldo', TipoCuenta.origenIngreso),
    _c('g-comida', TipoCuenta.deGasto),
    _c('g-intereses', TipoCuenta.gastoFinanciero),
    _c('apertura', TipoCuenta.apertura),
  ],
  movimientos: movs,
);

void main() {
  // Semana del lunes 2026-11-16 al domingo 2026-11-22.
  final semana = Periodo.semana(Fecha(2026, 11, 18));
  final lunes = Fecha(2026, 11, 16);
  final domingo = Fecha(2026, 11, 22);

  final base = [
    _m(
      'ap',
      TipoMovimiento.apertura,
      Fecha(2026, 11, 1),
      'apertura',
      'banco',
      500000,
    ),
    _m('i1', TipoMovimiento.ingreso, lunes, 'sueldo', 'banco', 900000),
    _m(
      'g1',
      TipoMovimiento.gasto,
      Fecha(2026, 11, 17),
      'banco',
      'g-comida',
      120000,
    ),
    _m('g2', TipoMovimiento.gasto, domingo, 'tarjeta', 'g-comida', 30000),
    _m(
      'int',
      TipoMovimiento.gasto,
      Fecha(2026, 11, 18),
      'banco',
      'g-intereses',
      4500,
    ),
    _m(
      'pd',
      TipoMovimiento.pagoDeuda,
      Fecha(2026, 11, 19),
      'banco',
      'tarjeta',
      200000,
    ),
    _m(
      't1',
      TipoMovimiento.transferencia,
      Fecha(2026, 11, 19),
      'banco',
      'efectivo',
      50000,
    ),
    _m(
      'a1',
      TipoMovimiento.transferencia,
      Fecha(2026, 11, 20),
      'banco',
      'ahorro',
      80000,
    ),
    _m(
      'r1',
      TipoMovimiento.reembolso,
      Fecha(2026, 11, 20),
      'g-comida',
      'banco',
      10000,
    ),
    // Fuera del periodo (domingo anterior y lunes siguiente).
    _m(
      'f1',
      TipoMovimiento.gasto,
      Fecha(2026, 11, 15),
      'banco',
      'g-comida',
      7777,
    ),
    _m('f2', TipoMovimiento.ingreso, Fecha(2026, 11, 23), 'sueldo', 'banco', 1),
  ];

  test('suma cada tipo en centavos y excluye saldos iniciales', () {
    final t = totalesPorTipo(_libro(base), semana);
    expect(t.ingresos, 900000);
    expect(t.gastos, 150000);
    expect(t.interesesYCargos, 4500);
    expect(t.pagosDeuda, 200000);
    expect(t.transferencias, 50000);
    expect(t.ahorro, 80000);
    expect(t.reembolsos, 10000);
    expect(t.cantidadDe(TipoResumen.gastos), 2);
    expect(t.cantidadTotal, 8);
  });

  test('el pago de deuda no es gasto y no entra al neto', () {
    final t = totalesPorTipo(_libro(base), semana);
    expect(t.gastos, 150000);
    // 900000 + 10000 - 150000 - 4500
    expect(t.neto, 755500);
  });

  test('los bordes lunes y domingo entran; lo de afuera no', () {
    final t = totalesPorTipo(_libro(base), semana);
    expect(t.ingresos, 900000); // lunes sí, el lunes siguiente no
    expect(t.gastos, 150000); // domingo sí, el domingo anterior no
  });

  test('un movimiento anulado y su contraasiento no cuentan', () {
    final libro = _libro(base);
    libro.anular(
      'g1',
      nuevoId: 'x-g1',
      motivo: 'Error al capturar',
      registradoPor: _yo,
      registradoEn: DateTime(2026, 11, 19),
    );
    final t = totalesPorTipo(libro, semana);
    expect(t.gastos, 30000);
    expect(t.cantidadDe(TipoResumen.gastos), 1);
  });

  test('un contraasiento pendiente no anula todavía', () {
    final libro = _libro(base);
    libro.anular(
      'g1',
      nuevoId: 'x-g1',
      motivo: 'Error al capturar',
      registradoPor: _yo,
      registradoEn: DateTime(2026, 11, 19),
      estado: EstadoMovimiento.pendiente,
    );
    expect(totalesPorTipo(libro, semana).gastos, 150000);
  });

  test('un movimiento pendiente no cuenta hasta confirmarse', () {
    final t = totalesPorTipo(
      _libro([
        ...base,
        _m(
          'p',
          TipoMovimiento.ingreso,
          lunes,
          'sueldo',
          'banco',
          5000,
          estado: EstadoMovimiento.pendiente,
        ),
      ]),
      semana,
    );
    expect(t.ingresos, 900000);
  });

  test('sin periodo cuenta todas las fechas', () {
    final t = totalesPorTipo(_libro(base), null);
    expect(t.ingresos, 900001);
    expect(t.gastos, 157777);
  });

  test('periodo de mes y acotar con incluir', () {
    final mes = Periodo.mes(Fecha(2026, 11, 3));
    final libro = _libro(base);
    expect(totalesPorTipo(libro, mes).ingresos, 900001);
    final soloTarjeta = totalesPorTipo(
      libro,
      mes,
      incluir: (m) => m.cuentaOrigenId == 'tarjeta',
    );
    expect(soloTarjeta.gastos, 30000);
    expect(soloTarjeta.ingresos, 0);
  });

  test('un periodo vacío da ceros', () {
    final t = totalesPorTipo(_libro(base), Periodo.semana(Fecha(2027, 1, 6)));
    expect(t.neto, 0);
    expect(t.cantidadTotal, 0);
  });

  test('retirar de ahorro cuenta como transferencia, no como ahorro', () {
    final libro = _libro([
      ...base,
      _m('ret', TipoMovimiento.transferencia, lunes, 'ahorro', 'banco', 1000),
    ]);
    final t = totalesPorTipo(libro, semana);
    expect(t.ahorro, 80000);
    expect(t.transferencias, 51000);
  });

  test('coincide con el estado de resultados del libro', () {
    final libro = _libro(base);
    final r = libro.estadoResultados(semana);
    final t = totalesPorTipo(libro, semana);
    expect(t.neto, r.resultado);
  });
}

// Fase 8, bloque 6 (F8-6.10): el movimiento lleva el comercio y la marca de
// cargo automático que la persona llenó al registrar el gasto; las fugas los
// toman de ahí (D3: son datos del libro, solo se usan en el dispositivo).
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

Movimiento _gasto(
  String id, {
  String? comercio,
  bool auto = false,
  ViaCaptura via = ViaCaptura.manual,
  TipoMovimiento tipo = TipoMovimiento.gasto,
  String? anulaA,
}) => Movimiento(
  id: id,
  tipo: tipo,
  fecha: Fecha(2026, 10, 5),
  registradoEn: DateTime.utc(2026, 10, 5, 12),
  cuentaOrigenId: 'banco',
  cuentaDestinoId: 'gasto',
  monto: 8900,
  realizadoPor: 'p',
  via: via,
  comercio: comercio,
  cobroAutomatico: auto,
  anulaA: anulaA,
  motivo: anulaA == null ? null : 'Lo registré dos veces',
);

void main() {
  test('sin comercio ni marca: nulo y falso, igual que antes', () {
    final m = _gasto('a');
    expect(m.comercio, isNull);
    expect(m.cobroAutomatico, isFalse);
  });

  test('conCuentas y mismoContenido conservan el comercio y la marca', () {
    final m = _gasto('a', comercio: 'Streamix', auto: true);
    final c = m.conCuentas('x', 'y');
    expect(c.comercio, 'Streamix');
    expect(c.cobroAutomatico, isTrue);
    expect(
      m.mismoContenido(_gasto('a', comercio: 'Streamix', auto: true)),
      isTrue,
    );
    expect(
      m.mismoContenido(_gasto('a', comercio: 'Otro', auto: true)),
      isFalse,
    );
    expect(m.mismoContenido(_gasto('a', comercio: 'Streamix')), isFalse);
  });

  test('gastosVigentesParaFugas toma el comercio y la marca del propio '
      'movimiento, y un gasto anulado no cuenta', () {
    final gastos = gastosVigentesParaFugas([
      _gasto('a', comercio: 'Streamix', auto: true),
      _gasto('b', comercio: 'Cafetería'),
      _gasto('c', comercio: 'Fuera'),
      _gasto('anula-c', tipo: TipoMovimiento.anulacion, anulaA: 'c'),
      _gasto('d', via: ViaCaptura.importacion),
    ]);
    expect([for (final g in gastos) g.id], ['a', 'b', 'd']);
    expect(gastos[0].comercio, 'Streamix');
    expect(gastos[0].cobroAutomatico, isTrue);
    expect(gastos[1].cobroAutomatico, isFalse);
    expect(gastos[2].cobroAutomatico, isTrue, reason: 'una importación');
    // Los mapas por id siguen completando.
    final con = gastosVigentesParaFugas(
      [_gasto('e')],
      comercios: {'e': 'Aparte'},
      automaticos: {'e'},
    );
    expect(con.single.comercio, 'Aparte');
    expect(con.single.cobroAutomatico, isTrue);
  });
}

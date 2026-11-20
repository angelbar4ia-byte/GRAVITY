// Fase 8, bloque 6 (F8-6.10), punto 4: el movimiento con `comercio` y
// `cobro_automatico` sube por la ruta de escritura de siempre (la cola, con
// `insert ... on conflict do nothing`), y la migración 20261146 ya da INSERT
// sobre esas dos columnas: no hace falta ninguna migración nueva. La prueba lo
// comprueba contra las migraciones (los grants se suman).
import 'dart:io';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/filas.dart';

Directory _migraciones() => [
  Directory('../supabase/migrations'),
  Directory('supabase/migrations'),
].firstWhere((d) => d.existsSync());

void main() {
  test('la fila de un gasto con comercio y cargo automático cabe en el INSERT '
      'de fin_movimientos y la de uno sin ellos no los manda', () {
    final archivos =
        _migraciones()
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final sql = archivos
        .map((f) => f.readAsStringSync())
        .join('\n')
        .replaceAll(RegExp(r'--[^\n]*'), '');
    final permitidas = <String>{};
    for (final m in RegExp(
      r'grant insert \(([^)]*)\)([^;]*?)on public\.fin_movimientos\b',
      dotAll: true,
    ).allMatches(sql)) {
      permitidas.addAll({
        for (final c in m[1]!.split(',')) c.trim().replaceAll('"', ''),
      });
    }
    expect(permitidas, containsAll(['comercio', 'cobro_automatico']));

    Movimiento gasto({String? comercio, bool auto = false}) => Movimiento(
      id: 'm1',
      tipo: TipoMovimiento.gasto,
      fecha: Fecha(2026, 10, 5),
      registradoEn: DateTime.utc(2026, 10, 5, 12),
      cuentaOrigenId: 'a',
      cuentaDestinoId: 'b',
      monto: 8900,
      realizadoPor: 'p',
      comercio: comercio,
      cobroAutomatico: auto,
    );
    final con = filaMovimiento(
      gasto(comercio: 'Streamix', auto: true),
      hogarId: 'h',
    );
    expect(con.keys.toSet().difference(permitidas), isEmpty);
    final sin = filaMovimiento(gasto(), hogarId: 'h');
    expect(sin.keys.toSet().difference(permitidas), isEmpty);
    expect(sin.keys, isNot(contains('comercio')));
    expect(sin.keys, isNot(contains('cobro_automatico')));
  });
}

// La cola sabe dos cosas del servidor de Finanzas (lib/nucleo/cola/
// contrato_servidor.dart) y esta prueba las compara con las migraciones, para
// que un cambio del servidor obligue a actualizar la app:
//
// - columnas que PONE EL SERVIDOR (sin permiso de INSERT para la app): la
//   carga de la cola nunca las lleva (recibido_en, libro_origen_id,
//   libro_destino_id, las generadas…);
// - orden de subida: cada tabla sube después de aquellas a las que apunta una
//   llave foránea.
//
// Y que las filas reales de Finanzas (filas.dart) no las llevan.
import 'dart:io';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/filas.dart';
import 'package:gravity/nucleo/cola/contrato_servidor.dart';

Directory _migraciones() => [
  Directory('../supabase/migrations'),
  Directory('supabase/migrations'),
].firstWhere((d) => d.existsSync());

String _sqlDeFinanzas() {
  final archivos =
      _migraciones()
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  // Sin comentarios de línea (llevan texto con comas y paréntesis).
  return archivos
      .map((f) => f.readAsStringSync())
      .join('\n')
      .replaceAll(RegExp(r'--[^\n]*'), '');
}

/// Cuerpo de cada `create table public.fin_*`.
Map<String, String> _cuerposDeTablas(String sql) => {
  for (final m in RegExp(
    r'create table public\.(fin_\w+)\s*\((.*?)\n\);',
    dotAll: true,
  ).allMatches(sql))
    m[1]!: m[2]!,
};

/// Nombres de las columnas de un cuerpo de tabla.
List<String> _columnas(String cuerpo) {
  final definiciones = <String>[];
  var profundidad = 0;
  final actual = StringBuffer();
  for (final c in cuerpo.split('')) {
    if (c == '(') profundidad++;
    if (c == ')') profundidad--;
    if (c == ',' && profundidad == 0) {
      definiciones.add(actual.toString());
      actual.clear();
    } else {
      actual.write(c);
    }
  }
  definiciones.add(actual.toString());
  const noEsColumna = {
    'constraint',
    'primary',
    'unique',
    'check',
    'foreign',
    'exclude',
  };
  return [
    for (final d in definiciones)
      if (d.trim().isNotEmpty &&
          !noEsColumna.contains(d.trim().split(RegExp(r'\s+')).first))
        d.trim().split(RegExp(r'\s+')).first.replaceAll('"', ''),
  ];
}

/// Columnas con permiso de INSERT para la app (`grant insert (…) on tabla`).
Map<String, Set<String>> _conInsert(String sql) => {
  for (final m in RegExp(
    r'grant insert \(([^)]*)\)(.*?)on public\.(fin_\w+)',
    dotAll: true,
  ).allMatches(sql))
    m[3]!: {for (final c in m[1]!.split(',')) c.trim().replaceAll('"', '')},
};

void main() {
  final sql = _sqlDeFinanzas();
  final tablas = _cuerposDeTablas(sql);
  final conInsert = _conInsert(sql);

  test('se leyeron las 21 tablas de Finanzas y sus permisos de INSERT', () {
    expect(tablas, hasLength(21));
    expect(conInsert.keys.toSet(), tablas.keys.toSet());
  });

  group('columnas que pone el servidor', () {
    test('columnasQuePoneElServidor coincide con las migraciones', () {
      final delServidor = <String, Set<String>>{};
      for (final MapEntry(key: tabla, value: cuerpo) in tablas.entries) {
        final fuera = {
          for (final c in _columnas(cuerpo))
            if (!conInsert[tabla]!.contains(c)) c,
        };
        if (fuera.isNotEmpty) delServidor[tabla] = fuera;
      }
      expect(columnasQuePoneElServidor, delServidor);
    });

    test('incluye las que dice el contrato', () {
      expect(columnasQuePoneElServidor['fin_movimientos'], {
        'recibido_en',
        'libro_origen_id',
        'libro_destino_id',
      });
      // Generadas.
      expect(
        columnasQuePoneElServidor['fin_cuentas'],
        containsAll(['clase', 'liquida']),
      );
      expect(
        columnasQuePoneElServidor['fin_conciliaciones'],
        contains('diferencia'),
      );
      expect(
        columnasQuePoneElServidor['fin_cierre_abonos'],
        contains('diferido'),
      );
      // Las que la app puede mandar y el servidor sobrescribe, sí van.
      expect(
        columnasQuePoneElServidor['fin_cuentas'],
        isNot(contains('creada_por')),
      );
      expect(
        columnasQuePoneElServidor['fin_semanas'],
        isNot(contains('activada_por')),
      );
      expect(columnasQuePoneElServidor['fin_dias_inhabiles'], isNull);
    });

    test('sinColumnasDelServidor quita solo esas y no cambia la carga', () {
      final carga = <String, Object?>{
        'id': 'm1',
        'monto_centavos': 100,
        'recibido_en': '2026-10-22T00:00:00Z',
        'libro_origen_id': 'l1',
        'libro_destino_id': 'l2',
      };
      expect(sinColumnasDelServidor('fin_movimientos', carga), {
        'id': 'm1',
        'monto_centavos': 100,
      });
      expect(carga, hasLength(5));
      // Una tabla sin columnas del servidor queda igual.
      expect(sinColumnasDelServidor('fin_ingresos', carga), carga);
    });
  });

  group('filas reales de Finanzas', () {
    final fecha = Fecha(2026, 10, 22);
    final hora = DateTime.utc(2026, 10, 22, 14);

    void sinColumnasDelServidorEn(String tabla, Map<String, Object?> fila) {
      final prohibidas = columnasQuePoneElServidor[tabla] ?? const <String>{};
      expect(
        fila.keys.where(prohibidas.contains),
        isEmpty,
        reason: 'La fila de $tabla lleva columnas del servidor',
      );
      // Y solo columnas con permiso de INSERT.
      expect(
        fila.keys.where((c) => !conInsert[tabla]!.contains(c)),
        isEmpty,
        reason: 'La fila de $tabla lleva columnas sin permiso de INSERT',
      );
    }

    test('movimiento', () {
      sinColumnasDelServidorEn(
        'fin_movimientos',
        filaMovimiento(
          Movimiento(
            id: 'm1',
            tipo: TipoMovimiento.gasto,
            fecha: fecha,
            registradoEn: hora,
            cuentaOrigenId: 'c1',
            cuentaDestinoId: 'c2',
            monto: 18500,
            realizadoPor: 'p1',
          ),
          hogarId: 'h1',
        ),
      );
    });

    test('conciliación', () {
      sinColumnasDelServidorEn(
        'fin_conciliaciones',
        filaConciliacion(
          ConciliacionGuardada(
            id: 'k1',
            libroId: 'l1',
            cuentaId: 'c1',
            fecha: fecha,
            saldoDeclarado: 1000,
            saldoCalculado: 900,
            personaId: 'p1',
            creadoEn: hora,
          ),
          hogarId: 'h1',
        ),
      );
    });

    test('importación', () {
      sinColumnasDelServidorEn(
        'fin_importaciones',
        filaImportacion(
          ImportacionGuardada(
            id: 'i1',
            archivo: 'presupuesto.xlsx',
            hoja: 'Hoja 1',
            filasLeidas: 10,
            filasCreadas: 9,
            filasOmitidas: 1,
            personaId: 'p1',
            creadoEn: hora,
          ),
          hogarId: 'h1',
        ),
      );
    });

    test('cierre, sus partidas y sus abonos', () {
      final cierre = CierreGuardado(
        id: 'z1',
        semanaId: 's1',
        version: 1,
        ingresoReal: 1,
        gastoReal: 1,
        abonoReal: 1,
        abonoDiferido: 0,
        abonoExtraReal: 0,
        ahorroReal: 0,
        deficit: 0,
        arrastreSiguiente: 0,
        accionElegida: AccionCierre.sinAplicar,
        activos: 1,
        pasivos: 1,
        patrimonio: 0,
        cerradoEn: hora,
      );
      sinColumnasDelServidorEn(
        'fin_cierres',
        filaCierre(cierre, hogarId: 'h1', libroId: 'l1'),
      );
      sinColumnasDelServidorEn(
        'fin_cierre_partidas',
        filaCierrePartida(
          'z1',
          const CierrePartidaGuardada(
            partidaId: 'pt1',
            gastado: 1,
            arrastreSiguiente: 0,
            alRemanente: 0,
          ),
          hogarId: 'h1',
          libroId: 'l1',
          id: 'zp1',
        ),
      );
      sinColumnasDelServidorEn(
        'fin_cierre_abonos',
        filaCierreAbono(
          'z1',
          const CierreAbonoGuardado(
            deudaId: 'd1',
            planeado: 100,
            real: 100,
            minimo: 50,
          ),
          hogarId: 'h1',
          libroId: 'l1',
          id: 'za1',
        ),
      );
    });

    test('cuenta', () {
      sinColumnasDelServidorEn(
        'fin_cuentas',
        filaCuenta(
          const Cuenta(
            id: 'c1',
            nombre: 'Banco',
            tipo: TipoCuenta.banco,
            libroId: 'l1',
          ),
          hogarId: 'h1',
        ),
      );
    });
  });

  group('orden de subida', () {
    /// Tablas a las que apunta cada tabla con una llave foránea.
    final apuntaA = {
      for (final MapEntry(key: tabla, value: cuerpo) in tablas.entries)
        tabla: {
          for (final m in RegExp(
            r'references public\.(fin_\w+)',
          ).allMatches(cuerpo))
            if (m[1] != tabla) m[1]!,
        },
    };

    test('hay un nivel para cada tabla de Finanzas', () {
      expect(
        nivelesDeSubidaFinanzas.keys.where((k) => !k.contains('#')).toSet(),
        tablas.keys.toSet(),
      );
    });

    test('cada tabla sube después de aquellas a las que apunta', () {
      final mal = <String>[];
      for (final MapEntry(key: tabla, value: padres) in apuntaA.entries) {
        for (final padre in padres) {
          if (nivelesDeSubidaFinanzas[tabla]! <=
              nivelesDeSubidaFinanzas[padre]!) {
            mal.add(
              '$tabla (${nivelesDeSubidaFinanzas[tabla]}) apunta a $padre '
              '(${nivelesDeSubidaFinanzas[padre]})',
            );
          }
        }
      }
      expect(mal, isEmpty, reason: mal.join('\n'));
    });

    test('el orden del contrato', () {
      int n(String tabla) => nivelesDeSubidaFinanzas[tabla]!;
      // Cuentas → movimientos.
      expect(n('fin_cuentas'), lessThan(n('fin_movimientos')));
      // El ajuste (un movimiento) → su conciliación.
      expect(n('fin_movimientos'), lessThan(n('fin_conciliaciones')));
      // El cierre → sus partidas y abonos → la semana cerrada.
      expect(n('fin_cierres'), lessThan(n('fin_cierre_partidas')));
      expect(n('fin_cierres'), lessThan(n('fin_cierre_abonos')));
      final cerrar =
          nivelesDeSubidaFinanzas[claveDeActualizacion('fin_semanas')]!;
      expect(n('fin_cierre_partidas'), lessThan(cerrar));
      expect(n('fin_cierre_abonos'), lessThan(cerrar));
      expect(n('fin_semanas'), lessThan(cerrar));
    });

    test('la única llave circular es categoría → cuenta de gasto', () {
      // fin_categorias.cuenta_gasto_id (alter table) apunta a las cuentas, y
      // las cuentas apuntan a su categoría. Se rompe porque es opcional: se
      // crea la categoría y después se le asigna la cuenta con un cambio.
      expect(
        RegExp(
          r'alter table public\.fin_categorias\s+add constraint \w+ foreign key \(hogar_id, cuenta_gasto_id\)\s+references public\.fin_cuentas',
        ).hasMatch(sql),
        isTrue,
      );
      expect(apuntaA['fin_categorias'], isEmpty);
    });
  });
}

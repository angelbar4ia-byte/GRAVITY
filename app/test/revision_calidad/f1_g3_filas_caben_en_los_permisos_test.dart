// Guardia de la revisión de calidad de la Fase 1: TODAS las filas que arma la
// app (`filas.dart`) usan solo columnas con permiso de INSERT para
// `authenticated` según las migraciones (`grant insert (...)`). La prueba de la
// cola (`cola/contrato_servidor_test.dart`) lo revisa para 6 tablas; las demás
// (libros, miembros, categorías, ingresos, vigencias, compromisos, sobres,
// deudas, días inhábiles, semanas, partidas, abonos, ocurrencias y parámetros)
// se guardan por `upsert` directo y una columna de más da 42501 en el
// proyecto real sin que ninguna prueba lo vea. Hoy PASA.
import 'dart:io';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/filas.dart';

Directory _migraciones() => [
  Directory('../supabase/migrations'),
  Directory('supabase/migrations'),
].firstWhere((d) => d.existsSync());

Map<String, Set<String>> _conInsert(String sql) => {
  for (final m in RegExp(
    r'grant insert \(([^)]*)\)(.*?)on public\.(fin_\w+)',
    dotAll: true,
  ).allMatches(sql))
    m[3]!: {for (final c in m[1]!.split(',')) c.trim().replaceAll('"', '')},
};

void main() {
  test('cada fila de la app cabe en los permisos de INSERT de su tabla', () {
    final archivos = _migraciones()
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final sql = archivos
        .map((f) => f.readAsStringSync())
        .join('\n')
        .replaceAll(RegExp(r'--[^\n]*'), '');
    final permisos = _conInsert(sql);
    expect(permisos.length, greaterThanOrEqualTo(21));

    final d = datosDeDemostracion(hoy: Fecha(2026, 10, 20));
    const h = 'hogar';
    final filas = <String, List<Map<String, Object?>>>{
      'fin_libros': [for (final l in d.libros) filaLibro(l, hogarId: h)],
      'fin_libro_miembros': [
        for (final l in d.libros)
          for (final m in l.miembros) filaMiembro(l.id, m, hogarId: h, id: 'x'),
      ],
      'fin_categorias': [for (final c in d.categorias) filaCategoria(c, hogarId: h)],
      'fin_cuentas': [for (final c in d.cuentas) filaCuenta(c, hogarId: h)],
      'fin_parametros': [for (final p in d.parametros) filaParametros(p, hogarId: h)],
      'fin_movimientos': [for (final m in d.movimientos) filaMovimiento(m, hogarId: h)],
      'fin_ingresos': [for (final i in d.ingresos) filaIngreso(i, hogarId: h)],
      'fin_vigencias_ingreso': [
        for (final i in d.ingresos)
          for (final v in i.vigencias) filaVigencia(v, hogarId: h, libroId: i.libroId),
      ],
      'fin_compromisos': [for (final c in d.compromisos) filaCompromiso(c, hogarId: h)],
      'fin_sobres': [for (final s in d.sobres) filaSobre(s, hogarId: h)],
      'fin_deudas': [for (final x in d.deudas) filaDeuda(x, hogarId: h)],
      'fin_dias_inhabiles': [
        for (final x in festivosOficialesMexico(2026))
          filaDiaInhabil(x, hogarId: h, id: 'x'),
      ],
      'fin_semanas': [for (final s in d.semanas) filaSemana(s, hogarId: h)],
      'fin_partidas_semana': [
        for (final s in d.semanas)
          for (final p in s.partidas) filaPartidaSemana(p, hogarId: h, libroId: s.libroId),
      ],
      'fin_abonos_semana': [
        for (final s in d.semanas)
          for (final p in s.abonos) filaAbonoSemana(p, hogarId: h, libroId: s.libroId),
      ],
      'fin_ocurrencias': [
        filaOcurrencia(
          Ocurrencia(
            id: 'o1',
            libroId: 'l1',
            origen: OrigenOcurrencia.ingreso,
            origenId: 'i1',
            fechaProgramada: Fecha(2026, 11, 1),
            fechaAjustada: Fecha(2026, 11, 2),
            montoEsperado: 320000,
            estado: EstadoOcurrencia.esperada,
            movimientoId: null,
          ),
          hogarId: h,
        ),
      ],
    };

    final problemas = <String>[];
    for (final MapEntry(key: tabla, value: lista) in filas.entries) {
      final permitidas = permisos[tabla];
      if (permitidas == null) {
        problemas.add('$tabla: sin "grant insert" en las migraciones');
        continue;
      }
      expect(lista, isNotEmpty, reason: 'sin filas de prueba para $tabla');
      for (final fila in lista) {
        final demas = fila.keys.toSet().difference(permitidas);
        if (demas.isNotEmpty) problemas.add('$tabla manda $demas');
      }
    }
    expect(problemas, isEmpty);
  });
}

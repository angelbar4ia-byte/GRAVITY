// La cola conoce el servidor de «Mi gimnasio» (lib/nucleo/cola/
// contrato_gimnasio.dart) y esta prueba lo compara con la migración
// supabase/migrations/20261152000000_habitos_gimnasio.sql, para que un cambio
// del servidor obligue a actualizar la app:
//
// - columnas que la app puede mandar = las del `grant insert` de cada tabla;
// - columnas que pone el servidor = las que no están en ese grant;
// - `on_conflict` = una llave única de la tabla;
// - orden de subida: cada tabla sube después de aquellas a las que apunta una
//   llave foránea;
// - ninguna columna habla de molestias, zonas ni dolor.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/contrato_gimnasio.dart';

String _migracion() {
  final candidatos = [
    File('../supabase/migrations/20261152000000_habitos_gimnasio.sql'),
    File('supabase/migrations/20261152000000_habitos_gimnasio.sql'),
  ];
  return candidatos
      .firstWhere((f) => f.existsSync())
      .readAsStringSync()
      // Sin comentarios de línea (llevan texto con comas y paréntesis).
      .replaceAll(RegExp(r'--[^\n]*'), '');
}

Map<String, String> _cuerposDeTablas(String sql) => {
  for (final m in RegExp(
    r'create table public\.(hab_ent_\w+)\s*\((.*?)\n\);',
    dotAll: true,
  ).allMatches(sql))
    m[1]!: m[2]!,
};

/// Columnas del `grant insert (...) on public.<tabla>`.
Set<String> _columnasDelGrant(String sql, String tabla) {
  final m = RegExp(
    'grant insert \\(([^)]*)\\)[^;]*?on public\\.$tabla to authenticated',
    dotAll: true,
  ).firstMatch(sql);
  expect(m, isNotNull, reason: 'no hay grant insert para $tabla');
  return {for (final c in m!.group(1)!.split(',')) c.trim()};
}

List<String> _columnasDeTabla(String cuerpo) {
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
  const noEsColumna = {'constraint', 'primary', 'unique', 'check', 'foreign'};
  return [
    for (final d in definiciones)
      if (d.trim().isNotEmpty &&
          !noEsColumna.contains(d.trim().split(RegExp(r'\s+')).first))
        d.trim().split(RegExp(r'\s+')).first,
  ];
}

void main() {
  final sql = _migracion();
  final tablas = _cuerposDeTablas(sql);

  test('la migración trae las seis tablas hab_ent_*', () {
    expect(tablas.keys.toSet(), {
      'hab_ent_perfil',
      'hab_ent_plan_dias',
      'hab_ent_inventario',
      'hab_ent_bandas',
      'hab_ent_sesiones',
      'hab_ent_series',
    });
    expect({
      for (final d in destinosUpsertGimnasio.values) d.tabla,
    }, tablas.keys.toSet());
  });

  group('columnas', () {
    for (final tabla in tablas.keys) {
      test('$tabla: lo que se manda = el grant insert', () {
        expect(
          columnasQueSeMandanGimnasio[tabla],
          _columnasDelGrant(sql, tabla),
        );
      });

      test('$tabla: lo que pone el servidor = lo que no está en el grant', () {
        final todas = _columnasDeTabla(tablas[tabla]!).toSet();
        final grant = _columnasDelGrant(sql, tabla);
        expect(
          todas.difference(grant),
          columnasQuePoneElServidorGimnasio[tabla],
        );
        // Nada se manda y se pone a la vez.
        expect(
          columnasQueSeMandanGimnasio[tabla]!.intersection(
            columnasQuePoneElServidorGimnasio[tabla]!,
          ),
          isEmpty,
        );
      });

      test('$tabla: ninguna columna habla de molestias, zonas ni dolor', () {
        for (final c in _columnasDeTabla(tablas[tabla]!)) {
          expect(
            raicesProhibidasEnCarga.any(c.contains),
            isFalse,
            reason: 'la columna $c de $tabla habla de salud',
          );
        }
      });
    }
  });

  group('on_conflict', () {
    final llavesUnicas = <String, Set<String>>{
      for (final e in tablas.entries) e.key: _llaves(e.value),
    };

    for (final d in destinosUpsertGimnasio.entries) {
      test('${d.key} usa una llave única de ${d.value.tabla}', () {
        final columnas = d.value.onConflict.split(',').toSet();
        expect(
          llavesUnicas[d.value.tabla],
          contains(columnas.join(',')),
          reason:
              'ON CONFLICT (${d.value.onConflict}) debe ser una llave única',
        );
      });
    }

    test('llevaId solo en las tablas cuya llave es id', () {
      for (final d in destinosUpsertGimnasio.values) {
        expect(d.llevaId, d.onConflict == 'id');
      }
    });
  });

  group('orden de subida', () {
    // tabla → tablas hab_ent_* a las que apunta una llave foránea.
    final apunta = <String, Set<String>>{
      for (final e in tablas.entries)
        e.key: {
          for (final m in RegExp(
            r'references public\.(hab_ent_\w+)',
          ).allMatches(e.value))
            m[1]!,
        },
    };

    test('cada tabla sube después de aquellas a las que apunta', () {
      expect(
        apunta['hab_ent_series'],
        containsAll(['hab_ent_sesiones', 'hab_ent_bandas']),
      );
      for (final e in apunta.entries) {
        for (final destino in e.value) {
          expect(
            nivelesDeSubidaGimnasio[e.key]!,
            greaterThan(nivelesDeSubidaGimnasio[destino]!),
            reason: '${e.key} apunta a $destino y debe subir después',
          );
        }
      }
    });

    test('perfil, inventario, bandas y plan; luego sesiones; luego series', () {
      final n = nivelesDeSubidaGimnasio;
      for (final t in [
        'hab_ent_perfil',
        'hab_ent_inventario',
        'hab_ent_bandas',
        'hab_ent_plan_dias',
      ]) {
        expect(n[t], 0);
      }
      expect(n['hab_ent_sesiones'], greaterThan(n['hab_ent_plan_dias']!));
      expect(n['hab_ent_series'], greaterThan(n['hab_ent_sesiones']!));
    });

    test('los borrados suben después de las altas', () {
      final maximoAltas = [
        for (final d in destinosUpsertGimnasio.values)
          nivelesDeSubidaGimnasio[d.tabla]!,
      ].reduce((a, b) => a > b ? a : b);
      for (final tabla in borradosGimnasio.values) {
        expect(
          nivelesDeSubidaGimnasio[claveDeBorrado(tabla)],
          greaterThan(maximoAltas),
        );
      }
    });
  });

  group('tipos', () {
    test('todos llevan el prefijo habitos.gim_ y son personales', () {
      for (final tipo in TipoColaGimnasio.todos) {
        expect(tipo, startsWith(TipoColaGimnasio.prefijo));
        expect(esTipoPersonal(tipo), isTrue);
      }
    });

    test('cada tipo tiene destino: seis altas y tres borrados', () {
      expect(destinosUpsertGimnasio.keys.toSet(), TipoColaGimnasio.altas);
      expect(borradosGimnasio.keys.toSet(), TipoColaGimnasio.borrados);
      expect(TipoColaGimnasio.altas, hasLength(6));
    });

    test('ningún tipo habla de molestias', () {
      for (final tipo in TipoColaGimnasio.todos) {
        expect(raicesProhibidasEnCarga.any(tipo.contains), isFalse);
      }
    });
  });

  group('sobres que solo viven en el equipo', () {
    test('salud_local se reconoce en una carga de sobres', () {
      expect(
        cargaLlevaSobreSoloLocal({
          'p_sobres': [
            {'tipo': 'habitos_sensibles'},
            {'tipo': 'salud_local'},
          ],
        }),
        isTrue,
      );
    });

    test('los de la nube y las cargas sin sobres no', () {
      expect(
        cargaLlevaSobreSoloLocal({
          'p_sobres': [
            {'tipo': 'habitos_sensibles'},
            {'tipo': 'diario_oracion'},
          ],
        }),
        isFalse,
      );
      expect(cargaLlevaSobreSoloLocal({'p_alcance': 'todo'}), isFalse);
      expect(cargaLlevaSobreSoloLocal({'p_sobres': 'x'}), isFalse);
    });
  });
}

/// Llaves únicas o primarias de una tabla, como «col1,col2».
Set<String> _llaves(String cuerpo) {
  final r = <String>{};
  // `persona_id uuid primary key` o `id uuid primary key` en la columna.
  for (final m in RegExp(r'(\w+)\s+uuid primary key').allMatches(cuerpo)) {
    r.add(m[1]!);
  }
  for (final m in RegExp(r'primary key\s*\(([^)]*)\)').allMatches(cuerpo)) {
    r.add(m[1]!.split(',').map((c) => c.trim()).join(','));
  }
  for (final m in RegExp(r'unique\s*\(([^)]*)\)').allMatches(cuerpo)) {
    r.add(m[1]!.split(',').map((c) => c.trim()).join(','));
  }
  return r;
}

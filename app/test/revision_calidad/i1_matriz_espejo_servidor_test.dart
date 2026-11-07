// HALLAZGO I1 (IMPORTANTE) · docs/revisiones/fase-0.md
//
// Prueba de regresión: el hallazgo se resolvió el 20/oct/2026 (docs/revisiones/fase-0.md, sección 11).
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// El espejo de la app (lib/nucleo/permisos/permisos.dart) debe dar **las mismas
// filas** que la matriz del servidor (permisos_rol en supabase/migrations/):
// por cada rol × módulo × acción, la misma acción y el mismo alcance (total,
// propio o restringido, D17). La matriz del servidor se arma como la deja la
// base: los `insert` de cada migración, en orden, y luego sus `update` y
// `delete` (la de Finanzas cambia el alcance de varias filas con `update`).
//
// Esta prueba queda como guardia permanente: cuando una migración cambie la
// matriz, obliga a actualizar el espejo (y al revés).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

typedef Fila = (Rol, Modulo, Accion);

Directory _migraciones() => [
  Directory('../supabase/migrations'),
  Directory('supabase/migrations'),
].firstWhere((d) => d.existsSync());

/// Archivos de migración en el orden en que se aplican.
List<File> _archivos() =>
    _migraciones()
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Fin de la sentencia que empieza en [inicio]: el primer `;` fuera de
/// comillas simples y de comentarios `--` (las notas llevan `;` dentro).
int _finDeSentencia(String sql, int inicio) {
  var enTexto = false;
  for (var i = inicio; i < sql.length; i++) {
    final c = sql[i];
    if (enTexto) {
      if (c == "'") enTexto = false; // '' (comilla escapada) vuelve a abrir.
    } else if (c == "'") {
      enTexto = true;
    } else if (c == '-' && i + 1 < sql.length && sql[i + 1] == '-') {
      final salto = sql.indexOf('\n', i);
      if (salto < 0) return sql.length;
      i = salto;
    } else if (c == ';') {
      return i + 1;
    }
  }
  throw StateError('Sentencia sin ";" desde la posición $inicio');
}

/// Condiciones `rol = '…' and modulo = '…' [and accion = '…']` de un `where`.
/// Falla si el `where` lleva algo que esta prueba no sabe leer.
Map<String, String> _condiciones(String where, String sentencia) {
  final partes = where.trim().split(RegExp(r'\s+and\s+', caseSensitive: false));
  final condiciones = <String, String>{};
  for (final parte in partes) {
    final m = RegExp(r"^(rol|modulo|accion)\s*=\s*'(\w+)'$")
        .firstMatch(parte.trim());
    if (m == null) {
      fail(
        'No sé leer la condición "$parte" de:\n$sentencia\n'
        'Amplía esta prueba (o escribe la migración con rol, modulo y accion).',
      );
    }
    condiciones[m[1]!] = m[2]!;
  }
  return condiciones;
}

bool _cumple(Fila fila, Map<String, String> condiciones) =>
    (condiciones['rol'] == null || condiciones['rol'] == fila.$1.name) &&
    (condiciones['modulo'] == null || condiciones['modulo'] == fila.$2.name) &&
    (condiciones['accion'] == null || condiciones['accion'] == fila.$3.name);

/// Matriz del servidor tal como queda tras todas las migraciones:
/// rol × módulo × acción → alcance.
Map<Fila, String> matrizDelServidor() {
  final matriz = <Fila, String>{};
  final sentencia = RegExp(
    r'(insert\s+into|update|delete\s+from)\s+public\.permisos_rol\b',
    caseSensitive: false,
  );
  final fila = RegExp(
    r"\(\s*'(\w+)'\s*,\s*'(\w+)'\s*,\s*'(\w+)'\s*,\s*'(\w+)'",
  );
  for (final archivo in _archivos()) {
    final sql = archivo.readAsStringSync();
    for (final m in sentencia.allMatches(sql)) {
      // Lo que esté en un comentario no cuenta.
      final inicioLinea = sql.lastIndexOf('\n', m.start) + 1;
      if (sql.substring(inicioLinea, m.start).contains('--')) continue;
      final texto = sql.substring(m.start, _finDeSentencia(sql, m.start));
      final tipo = m[1]!.toLowerCase().split(RegExp(r'\s+')).first;
      switch (tipo) {
        case 'insert':
          if (texto.toLowerCase().contains('on conflict')) {
            fail('Esta prueba no sabe leer "on conflict" en:\n$texto');
          }
          final cuerpo = texto.substring(texto.toLowerCase().indexOf('values'));
          for (final f in fila.allMatches(cuerpo)) {
            final clave = (
              Rol.values.byName(f[1]!),
              Modulo.values.byName(f[2]!),
              Accion.values.byName(f[3]!),
            );
            if (matriz.containsKey(clave)) {
              fail('Fila repetida en ${archivo.path}: $clave');
            }
            matriz[clave] = f[4]!;
          }
        case 'update':
          final set = RegExp(
            r'\bset\b(.*?)\bwhere\b(.*);',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(texto);
          if (set == null) fail('Esta prueba no sabe leer:\n$texto');
          final asignaciones = set[1]!;
          if (RegExp(r'\b(rol|modulo|accion)\s*=').hasMatch(asignaciones)) {
            fail(
              'Un update que cambia rol, módulo o acción no se sabe leer:\n$texto',
            );
          }
          final alcance = RegExp(r"\balcance\s*=\s*'(\w+)'")
              .firstMatch(asignaciones)?[1];
          final condiciones = _condiciones(set[2]!, texto);
          final afectadas = [
            for (final f in matriz.keys)
              if (_cumple(f, condiciones)) f,
          ];
          if (afectadas.isEmpty) {
            fail('El update no cambia ninguna fila:\n$texto');
          }
          if (alcance != null) {
            for (final f in afectadas) {
              matriz[f] = alcance;
            }
          }
        case 'delete':
          final where = RegExp(
            r'\bwhere\b(.*);',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(texto);
          if (where == null) {
            fail('Un delete sin where borra toda la matriz:\n$texto');
          }
          final condiciones = _condiciones(where[1]!, texto);
          matriz.removeWhere((f, _) => _cumple(f, condiciones));
      }
    }
  }
  return matriz;
}

/// Valores que acepta el servidor para `alcance` (dominio `alcance_permiso`).
Set<String> alcancesDelServidor() {
  for (final archivo in _archivos()) {
    final m = RegExp(
      r"create\s+domain\s+public\.alcance_permiso\s+as\s+text\s+check\s*\(\s*value\s+in\s*\(([^)]*)\)",
      caseSensitive: false,
    ).firstMatch(archivo.readAsStringSync());
    if (m != null) {
      return {for (final v in RegExp(r"'(\w+)'").allMatches(m[1]!)) v[1]!};
    }
  }
  fail('No encontré el dominio alcance_permiso en las migraciones.');
}

/// Filas del espejo de la app: rol × módulo × acción → alcance del servidor.
Map<Fila, String> matrizDeLaApp() => {
  for (final modulo in Modulo.values)
    for (final rol in Rol.values)
      for (final accion in permisoDe(rol, modulo).acciones)
        (rol, modulo, accion):
            permisoDe(rol, modulo).alcance.enServidor ?? '(sin alcance)',
};

String _texto(Fila f, String alcance) =>
    '${f.$1.name} × ${f.$2.name} × ${f.$3.name}: $alcance';

void main() {
  final servidor = matrizDelServidor();
  final app = matrizDeLaApp();

  // Ajuste de plataforma (revisión de la Fase 0, I1): la alineación acordada
  // quitó las 2 filas de cuidador × gravity, y el servidor quedó con 55 filas.
  // D18 y D19 (21/oct/2026, migración de Finanzas MVP 1) agregan 4: la pareja
  // escribe y administra su libro de Finanzas, y la cuidadora lee y confirma
  // sus solicitudes de GRAVITY (restringido). Total: 59.
  test('se leyó la matriz del servidor (61 filas)', () {
    expect(servidor, hasLength(61));
  });

  test('D17: el servidor solo acepta total, propio y restringido', () {
    expect(alcancesDelServidor(), {'total', 'propio', 'restringido'});
    expect(servidor.values.toSet().difference(alcancesDelServidor()), isEmpty);
    // Y la app no manda ni compara otro alcance.
    final deLaApp = {
      for (final a in Alcance.values)
        if (a.enServidor != null) a.enServidor!,
    };
    expect(deLaApp, alcancesDelServidor());
  });

  test('el espejo de la app tiene las mismas filas que el servidor, '
      'con el mismo alcance', () {
    final soloServidor = [
      for (final MapEntry(key: f, value: a) in servidor.entries)
        if (!app.containsKey(f)) _texto(f, a),
    ]..sort();
    final soloApp = [
      for (final MapEntry(key: f, value: a) in app.entries)
        if (!servidor.containsKey(f)) _texto(f, a),
    ]..sort();
    final otroAlcance = [
      for (final MapEntry(key: f, value: a) in servidor.entries)
        if (app.containsKey(f) && app[f] != a)
          '${_texto(f, a)} (la app dice ${app[f]})',
    ]..sort();
    expect(
      [...soloServidor, ...soloApp, ...otroAlcance],
      isEmpty,
      reason: [
        if (soloServidor.isNotEmpty)
          'Faltan en la app:\n  ${soloServidor.join('\n  ')}',
        if (soloApp.isNotEmpty) 'Sobran en la app:\n  ${soloApp.join('\n  ')}',
        if (otroAlcance.isNotEmpty)
          'Otro alcance:\n  ${otroAlcance.join('\n  ')}',
      ].join('\n'),
    );
  });

  test('D19: dueño y pareja, Finanzas y GRAVITY con alcance propio', () {
    for (final rol in [Rol.dueno, Rol.coadministrador]) {
      for (final accion in Accion.values) {
        expect(
          servidor[(rol, Modulo.finanzas, accion)],
          'propio',
          reason: '$rol $accion',
        );
      }
    }
    for (final accion in Accion.values) {
      expect(servidor[(Rol.dueno, Modulo.gravity, accion)], 'propio');
    }
  });

  test('D5: en el espejo la cuidadora tampoco lee Finanzas', () {
    expect(servidor[(Rol.cuidador, Modulo.finanzas, Accion.leer)], isNull);
    expect(
      servidor[(Rol.cuidador, Modulo.finanzas, Accion.escribir)],
      'restringido',
    );
    expect(puede(Rol.cuidador, Modulo.finanzas, Accion.leer), isFalse);
  });

  test('D18: la cuidadora no abre GRAVITY; solo su bandeja de solicitudes', () {
    // Por rol: cuidador × gravity × restringido (D17), sin un alcance nuevo.
    expect(
      servidor[(Rol.cuidador, Modulo.gravity, Accion.leer)],
      'restringido',
    );
    expect(
      servidor[(Rol.cuidador, Modulo.gravity, Accion.escribir)],
      'restringido',
    );
    expect(
      servidor[(Rol.cuidador, Modulo.gravity, Accion.administrar)],
      isNull,
    );
    expect(
      permisoDe(Rol.cuidador, Modulo.gravity).alcance,
      Alcance.restringido,
    );
    expect(soloBandejaDeSolicitudes(Rol.cuidador), isTrue);
    expect(puedeAbrir(Rol.cuidador, Modulo.gravity), isFalse);
    expect(modulosNavegables(Rol.cuidador), [Modulo.cuidados]);
  });
}

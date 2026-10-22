// HALLAZGO I1 (IMPORTANTE) · docs/revisiones/fase-0.md
//
// Prueba de regresión: el hallazgo se resolvió el 20/oct/2026 (docs/revisiones/fase-0.md, sección 11).
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// El espejo de la app (lib/nucleo/permisos/permisos.dart) debe dar las mismas
// acciones por rol y módulo que la matriz del servidor (permisos_rol en
// supabase/migrations/20261020000000_base.sql). Hoy difieren en 3 celdas; la
// más delicada: el espejo dice que la cuidadora LEE Finanzas (Alcance
// registroPropio = leer + escribir) y el servidor dice "nunca lee Finanzas".
//
// Esta prueba queda como guardia permanente: cuando una migración cambie la
// matriz, obliga a actualizar el espejo (y al revés).
@Tags(['hallazgo'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

/// Acciones por (rol, módulo) según las migraciones del servidor.
Map<(Rol, Modulo), Set<Accion>> matrizDelServidor() {
  final carpeta = [
    Directory('../supabase/migrations'),
    Directory('supabase/migrations'),
  ].firstWhere((d) => d.existsSync());
  final fila = RegExp(
    r"\(\s*'(\w+)'\s*,\s*'(\w+)'\s*,\s*'(leer|escribir|administrar)'\s*,\s*'(total|propio|restringido)'",
  );
  final matriz = <(Rol, Modulo), Set<Accion>>{};
  final archivos = carpeta.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final archivo in archivos) {
    final sql = archivo.readAsStringSync();
    final inicio = sql.indexOf('insert into public.permisos_rol');
    if (inicio < 0) continue;
    // Hasta el fin de la sentencia (las notas pueden llevar ';' dentro).
    final fin = RegExp(r'\)\s*;\s*$', multiLine: true)
        .allMatches(sql, inicio)
        .first
        .end;
    for (final m in fila.allMatches(sql.substring(inicio, fin))) {
      final clave = (Rol.values.byName(m[1]!), Modulo.values.byName(m[2]!));
      (matriz[clave] ??= {}).add(Accion.values.byName(m[3]!));
    }
  }
  return matriz;
}

void main() {
  final servidor = matrizDelServidor();

  // Ajuste de plataforma (revisión de la Fase 0, I1): la alineación acordada
  // quitó las 2 filas de cuidador × gravity, y el servidor quedó con 55 filas.
  // D18 y D19 (21/oct/2026, migración de Finanzas MVP 1) agregan 4: la pareja
  // escribe y administra su libro de Finanzas, y la cuidadora lee y confirma
  // sus solicitudes de GRAVITY (restringido). Total: 59.
  test('se leyó la matriz del servidor (59 filas)', () {
    final filas = servidor.values.fold<int>(0, (n, s) => n + s.length);
    expect(filas, 59);
  });

  test('el espejo de la app da las mismas acciones que el servidor', () {
    final diferencias = <String>[];
    for (final modulo in Modulo.values) {
      for (final rol in Rol.values) {
        final app = permisoDe(rol, modulo).acciones;
        final srv = servidor[(rol, modulo)] ?? const <Accion>{};
        if (app.length != srv.length || !app.containsAll(srv)) {
          diferencias.add(
            '${rol.name} × ${modulo.name}: app ${app.map((a) => a.name).toList()} '
            '≠ servidor ${srv.map((a) => a.name).toList()}',
          );
        }
      }
    }
    expect(diferencias, isEmpty, reason: diferencias.join('\n'));
  });

  test('D5: en el espejo la cuidadora tampoco lee Finanzas', () {
    expect(puede(Rol.cuidador, Modulo.finanzas, Accion.leer), isFalse);
  });

  test('D18: la cuidadora no abre GRAVITY; solo su bandeja de solicitudes', () {
    expect(servidor[(Rol.cuidador, Modulo.gravity)], {
      Accion.leer,
      Accion.escribir,
    });
    expect(puedeAbrir(Rol.cuidador, Modulo.gravity), isFalse);
    expect(modulosNavegables(Rol.cuidador), [Modulo.cuidados]);
  });
}

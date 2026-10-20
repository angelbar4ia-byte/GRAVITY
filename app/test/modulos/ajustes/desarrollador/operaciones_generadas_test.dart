import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/ajustes/desarrollador/operacion_api.dart';
import 'package:gravity/modulos/ajustes/desarrollador/operaciones.g.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

const _comoRegenerar =
    'operaciones.g.dart no coincide con api/openapi.yaml. '
    'Corre en api/: npm install && npm run generar';

/// Raíz del repositorio: la primera carpeta hacia arriba con api/openapi.yaml.
Directory _raiz() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/api/openapi.yaml').existsSync()) return dir;
    final padre = dir.parent;
    if (padre.path == dir.path) {
      throw StateError(
        'No encontré api/openapi.yaml desde ${Directory.current.path}',
      );
    }
    dir = padre;
  }
}

/// La misma huella que api/generar_dart.mjs: FNV-1a de 32 bits sobre UTF-8,
/// con saltos de línea \n.
String _huella(String texto) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(texto.replaceAll('\r\n', '\n'))) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return 'fnv1a32:${h.toRadixString(16).padLeft(8, '0')}';
}

void main() {
  final raiz = _raiz();
  final yaml = File('${raiz.path}/api/openapi.yaml').readAsStringSync();
  final operaciones = [for (final g in gruposOperaciones) ...g.operaciones];

  test('la huella del archivo generado coincide con openapi.yaml', () {
    expect(_huella('abc'), 'fnv1a32:1a47e90b', reason: 'FNV-1a de referencia');
    expect(huellaEspecificacion, _huella(yaml), reason: _comoRegenerar);
  });

  test('la copia para Swagger UI (especificacion.js) también está al día', () {
    final js = File('${raiz.path}/api/swagger/especificacion.js')
        .readAsStringSync();
    final huellaJs = RegExp(r'// huella: (fnv1a32:[0-9a-f]{8})')
        .firstMatch(js)
        ?.group(1);
    expect(huellaJs, _huella(yaml), reason: _comoRegenerar);
  });

  test('las operaciones generadas son las de openapi.yaml', () {
    final ids = RegExp(
      r'^\s+operationId:\s*(\S+)\s*$',
      multiLine: true,
    ).allMatches(yaml).map((m) => m.group(1)).toList();
    expect(operaciones.map((o) => o.id).toList()..sort(), ids..sort());
    for (final o in operaciones) {
      expect(yaml, contains('\n  ${o.ruta}:\n'), reason: o.ruta);
      expect(o.roles, isNotEmpty, reason: o.id);
      expect(o.resumen, isNotEmpty, reason: o.id);
    }
    expect(gruposOperaciones.map((g) => g.nombre), [
      'Herramientas de GRAVITY',
      'Base de datos',
      'Funciones del servidor',
      'Puente de casa',
    ]);
  });

  test('cada herramienta registrada está documentada igual (D1, D16)', () {
    final porRuta = {for (final o in operaciones) o.ruta: o};
    final registradas = registroFase0().todas;
    for (final h in registradas) {
      final o = porRuta['/herramientas/${h.nombre}'];
      expect(o, isNotNull, reason: '${h.nombre} no está en openapi.yaml');
      expect(o!.metodo, MetodoHttp.post, reason: h.nombre);
      expect(o.roles, h.roles, reason: '${h.nombre}: x-roles');
      expect(o.escribe, h.escribe, reason: '${h.nombre}: x-escribe');
      expect(o.soloLocal, h.soloLocal, reason: '${h.nombre}: x-solo-local');
    }
    final documentadas = operaciones
        .where(
          (o) => o.ruta.startsWith('/herramientas/') && !o.ruta.contains('{'),
        )
        .map((o) => o.ruta.substring('/herramientas/'.length));
    expect(
      documentadas.toSet(),
      registradas.map((h) => h.nombre).toSet(),
      reason: 'openapi.yaml documenta una herramienta que no existe',
    );
  });

  test(
    'en la base de datos todo escribe con confirmación y nada va a la IA',
    () {
      final base = gruposOperaciones.firstWhere(
        (g) => g.nombre == 'Base de datos',
      );
      for (final o in base.operaciones) {
        expect(o.soloLocal, isTrue, reason: o.id);
        final esLectura =
            o.metodo == MetodoHttp.get ||
            o.id == 'misPermisos'; // RPC de solo lectura
        expect(o.escribe, !esLectura, reason: o.id);
      }
    },
  );
}

import 'dart:io';

import 'package:test/test.dart';

/// El dominio del gimnasio es Dart puro: sin Flutter, sin I/O, sin reloj
/// propio, sin red y sin IA (CA-G-39 en la parte de dominio).
void main() {
  final archivos = Directory('lib/src/gimnasio')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('hay archivos del gimnasio que revisar', () {
    expect(archivos.length, greaterThan(10));
  });

  test('sin Flutter, I/O, red, reloj ni IA', () {
    final prohibidos = <String, Pattern>{
      'dart:io': RegExp(r"import\s+'dart:io'"),
      'dart:ui': RegExp(r"import\s+'dart:ui'"),
      'dart:html': RegExp(r"import\s+'dart:html'"),
      'dart:isolate': RegExp(r"import\s+'dart:isolate'"),
      'paquete externo': RegExp(r"import\s+'package:(?!habitos_dominio)"),
      'flutter': 'package:flutter',
      'http': RegExp(r'package:(http|dio)'),
      'reloj': RegExp(r'DateTime\.now\(|Stopwatch|Timer\(|Future\.delayed'),
      'azar': RegExp(r'\bRandom\b'),
      'IA': RegExp(
        r'gravity-asistente|asistente\.dart|Gemini|OpenAI',
        caseSensitive: false,
      ),
      'Health Connect': RegExp(
        r'health_connect|HealthConnect',
        caseSensitive: false,
      ),
    };
    for (final f in archivos) {
      final src = f.readAsStringSync();
      for (final e in prohibidos.entries) {
        expect(
          src.contains(e.value),
          isFalse,
          reason: '${f.path} usa ${e.key}',
        );
      }
    }
  });

  test('no hay doubles: la carga y el tiempo son enteros (R5)', () {
    for (final f in archivos) {
      final src = f.readAsStringSync();
      expect(RegExp(r'\bdouble\b').hasMatch(src), isFalse, reason: f.path);
    }
  });

  test('el pubspec del paquete sigue sin dependencias', () {
    final y = File('pubspec.yaml').readAsStringSync();
    final deps = RegExp(
      r'^dependencies:\s*\n((?:  .*\n|\n)*)',
      multiLine: true,
    ).firstMatch(y)!.group(1)!.trim();
    expect(deps, isEmpty);
  });

  test('las molestias no se serializan a nada de nube: solo un mapa local', () {
    final m = File('lib/src/gimnasio/molestias.dart').readAsStringSync();
    expect(m.contains('aJson'), isFalse);
    expect(m.contains('ElementoDoc'), isFalse);
    expect(m.contains('DocumentoSensible'), isFalse);
    final r = File('lib/src/gimnasio/registro.dart').readAsStringSync();
    expect(
      RegExp('molestia', caseSensitive: false)
          .allMatches(
            r
                .split('\n')
                .where(
                  (l) =>
                      !l.trimLeft().startsWith('///') &&
                      !l.trimLeft().startsWith('//'),
                )
                .join('\n'),
          )
          .length,
      lessThanOrEqualTo(3),
    ); // solo el enum local y su conversión a `otra`
  });
}

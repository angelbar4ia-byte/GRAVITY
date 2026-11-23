// Revisión del código fuente de «Mi gimnasio» (plataforma, G3):
//
// - CA-G-32 (caso malo): ningún código escribe directo a las tablas hab_ent_*
//   con upsert, insert, update o delete (el patrón de H-12): todo va por la
//   cola; solo el enviador de la cola lo hace.
// - CA-G-39: ningún archivo de plataforma de «Mi gimnasio» llama a una IA ni al
//   asistente ni usa Health Connect.
// - R6: ningún registro (debugPrint/print) ni mensaje de error habla de
//   molestias.
// - Sin dependencias nuevas: lo que usa «Mi gimnasio» ya estaba en pubspec.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _lib() =>
    [Directory('lib'), Directory('app/lib')].firstWhere((d) => d.existsSync());

List<File> _fuentes(Directory d) => [
  for (final e in d.listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart')) e,
];

String _sinComentarios(String fuente) => fuente
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  final lib = _lib();
  final todas = _fuentes(lib);

  /// Archivos propios de «Mi gimnasio» en plataforma.
  final propios = [
    ..._fuentes(Directory('${lib.path}/nucleo/gimnasio')),
    ..._fuentes(Directory('${lib.path}/app/gimnasio')),
    File('${lib.path}/nucleo/cola/contrato_gimnasio.dart'),
    File('${lib.path}/nucleo/avisos/aviso_descanso.dart'),
    File('${lib.path}/nucleo/tablet/retencion_sesion_gimnasio.dart'),
  ];

  test('hay archivos propios que revisar', () {
    expect(propios.length, greaterThan(8));
    for (final f in propios) {
      expect(f.existsSync(), isTrue, reason: f.path);
    }
  });

  test('CA-G-32: nadie escribe directo (upsert, insert, update, delete) a hab_ent_*', () {
    final directo = RegExp(
      r'''from\(\s*['"]hab_ent_\w+['"]\s*\)\s*\.\s*(upsert|insert|update|delete)\b''',
    );
    for (final f in todas) {
      final texto = _sinComentarios(f.readAsStringSync());
      expect(
        directo.hasMatch(texto),
        isFalse,
        reason: '${f.path} escribe directo a hab_ent_*: debe ir por la cola',
      );
    }
  });

  test(
    'CA-G-39: sin IA, sin asistente y sin Health Connect en lo de plataforma',
    () {
      final prohibido = RegExp(
        r'conversacion|cliente_asistente|ClienteAsistente|gravity-asistente|'
        r'health_connect|HealthConnect|package:health',
        caseSensitive: false,
      );
      for (final f in propios) {
        final texto = _sinComentarios(f.readAsStringSync());
        expect(prohibido.hasMatch(texto), isFalse, reason: f.path);
      }
    },
  );

  test(
    'R6: ningún registro ni error de plataforma de gimnasio lleva molestias',
    () {
      final logs = RegExp(
        r'(debugPrint|print|developer\.log)\s*\(([^;]*)\)\s*;',
        dotAll: true,
      );
      for (final f in propios) {
        final texto = _sinComentarios(f.readAsStringSync());
        for (final m in logs.allMatches(texto)) {
          expect(
            m.group(2)!.toLowerCase(),
            isNot(contains('molest')),
            reason: '${f.path}: un registro habla de molestias',
          );
        }
        // Ni mensajes de error armados con datos de una molestia.
        expect(
          RegExp(
            r"throw\s+\w+\([^)]*\$\{?(nota|zona|molestia)",
            dotAll: true,
          ).hasMatch(texto),
          isFalse,
          reason: f.path,
        );
      }
    },
  );

  test('sin dependencias nuevas: pubspec no nombra nada de gimnasio, salud ni pantalla encendida', () {
    final pubspec = File('pubspec.yaml').existsSync()
        ? File('pubspec.yaml')
        : File('app/pubspec.yaml');
    final texto = pubspec.readAsStringSync().toLowerCase();
    for (final p in [
      'wakelock',
      'health',
      'screen_brightness',
      'keep_screen_on',
    ]) {
      expect(texto, isNot(contains(p)), reason: 'pubspec no debe traer $p');
    }
  });
}

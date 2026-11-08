// REVISIÓN DE CALIDAD · FASE 4 (docs/revisiones/fase-4.md) · D3/D13 en el
// diseño y fuentes con licencia (criterios 12 y 50 de la spec del pulido).
//
//  - `app/lib/diseno` no importa red, IA, analítica ni lo que lee datos de los
//    módulos (el tema es solo apariencia, convención 3);
//  - no hay paquetes de analítica, reporte de fallas ni `google_fonts`;
//  - cada familia declarada en `pubspec.yaml` existe en `assets/fonts/`, trae su
//    OFL.txt (SIL Open Font License) y está en `licencias.dart`;
//  - ninguna fuente de Swagger (Anton) ni de estilos que no se ofrecen;
//  - las fuentes del proyecto pesan menos de 3 MB.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/licencias.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('lib/diseno no importa red, IA, analítica ni datos de los módulos', () {
    final prohibido = RegExp(
      r"^import '(package:(http|dio|firebase_[a-z_]+|supabase_flutter|"
      r"url_launcher|sentry[a-z_]*|google_fonts|share_plus|drift[a-z_]*)/|"
      r"[./]*/?(modulos|nucleo/(sesion|cola|herramientas|sensibles|avisos|"
      r"seguridad/(montos|bloqueo|pin))))",
      multiLine: true,
    );
    final infractores = <String>[];
    for (final f in Directory('lib/diseno').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final texto = f.readAsStringSync();
      for (final m in prohibido.allMatches(texto)) {
        final linea = m.group(0)!;
        // Los módulos que reciben gadgets "futuros" (ejemplo) no se importan.
        infractores.add('${f.path}: $linea');
      }
    }
    expect(infractores, isEmpty);
  });

  test('sin paquetes de analítica, de fallas ni de fuentes por red', () {
    for (final p in [
      'google_fonts',
      'firebase_analytics',
      'firebase_crashlytics',
      'sentry',
      'sentry_flutter',
      'mixpanel',
      'amplitude',
      'posthog',
    ]) {
      expect(
        pubspec.contains(RegExp('^\\s+$p:', multiLine: true)),
        isFalse,
        reason: p,
      );
    }
  });

  test(
    'cada familia del pubspec existe, trae OFL.txt y está en licencias.dart',
    () {
      final familias = RegExp(r'- family: (\w+)')
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toList();
      expect(familias, isNotEmpty);
      final rutasLicencia = licenciasFuentes.values.toSet();
      for (final familia in familias) {
        final carpeta = Directory('assets/fonts/$familia');
        expect(carpeta.existsSync(), isTrue, reason: familia);
        final ofl = File('assets/fonts/$familia/OFL.txt');
        expect(ofl.existsSync(), isTrue, reason: '$familia sin OFL.txt');
        expect(
          ofl.readAsStringSync(),
          contains('SIL Open Font License'),
          reason: familia,
        );
        expect(
          rutasLicencia,
          contains('assets/fonts/$familia/OFL.txt'),
          reason: '$familia no está en licencias.dart',
        );
        // Todo archivo declarado en el pubspec existe.
        for (final m in RegExp(
          'asset: (assets/fonts/$familia/[^\\s]+\\.ttf)',
        ).allMatches(pubspec)) {
          expect(File(m.group(1)!).existsSync(), isTrue, reason: m.group(1));
        }
      }
      // Y al revés: ninguna carpeta de fuentes sin declarar (ni Anton).
      final enDisco = Directory('assets/fonts')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split('/').last)
          .toSet();
      expect(enDisco, familias.toSet());
      expect(enDisco, isNot(contains('Anton')));
    },
  );

  test('las fuentes del proyecto pesan menos de 3 MB', () {
    var bytes = 0;
    for (final f in Directory('assets/fonts').listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.ttf')) bytes += f.lengthSync();
    }
    expect(bytes, lessThan(3 * 1024 * 1024), reason: '$bytes bytes');
  });
}

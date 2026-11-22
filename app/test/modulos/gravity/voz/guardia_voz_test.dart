// Guardia de código fuente del motor de voz (spec fase-8-motor-de-voz,
// criterios 11, 12 y 13; reglas R1, R3, R5 y R8): lee los archivos de
// `app/lib/modulos/gravity/voz/` y de la pantalla de Ajustes y comprueba lo que
// no deben importar ni usar. Mismo patrón que
// `test/diseno/guardia_sin_colores_fijos_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> archivosDart(String carpeta) =>
    Directory(carpeta)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Quita los comentarios (los de documentación explican justo lo prohibido).
String sinComentarios(String fuente) => fuente
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final motor = archivosDart('lib/modulos/gravity/voz');
  final ajustes = archivosDart('lib/modulos/ajustes/voz');

  test('hay archivos que vigilar', () {
    expect(motor.length, greaterThanOrEqualTo(8));
    expect(ajustes, isNotEmpty);
  });

  test('ningún archivo del motor usa la red (criterio 11, R8)', () {
    // Solo el gestor de descargas (carpeta `descarga/`, que llega con
    // P3.2a-2) podrá hablar con la red.
    final prohibidos = RegExp(
      r"package:http/|dart:io'\s+show\s+[^;]*(HttpClient|Socket|WebSocket)|"
      r'\bHttpClient\b|\bSocket\b|\bWebSocket\b|\bRawSocket\b|dart:html|package:dio',
    );
    for (final f in [...motor, ...ajustes]) {
      if (f.path.contains('/descarga/')) continue;
      expect(
        prohibidos.hasMatch(sinComentarios(f.readAsStringSync())),
        isFalse,
        reason: '${f.path} no debe usar la red',
      );
    }
  });

  test('el motor no importa las herramientas ni la casa (criterios 11, 12 y 13)', () {
    for (final f in motor) {
      final fuente = sinComentarios(f.readAsStringSync());
      expect(
        fuente.contains('nucleo/herramientas'),
        isFalse,
        reason: '${f.path}: la voz no tiene ruta hacia las herramientas (R3)',
      );
      expect(
        fuente.contains('modulos/casa'),
        isFalse,
        reason: '${f.path}: sin bocinas mientras D6 sea propuesta (R4)',
      );
      expect(fuente.contains('puente_casa'), isFalse, reason: f.path);
    }
  });

  test('el motor no importa dinero, salud ni la sesión (R1, R2)', () {
    for (final f in motor) {
      final fuente = sinComentarios(f.readAsStringSync());
      for (final modulo in [
        'modulos/finanzas',
        'modulos/cuidados',
        'modulos/alimentacion',
        'modulos/habitos',
        'sesion_efectiva',
        'nucleo/sesion',
        'nucleo/sensibles',
      ]) {
        expect(
          fuente.contains(modulo),
          isFalse,
          reason: '${f.path} no debe conocer $modulo',
        );
      }
    }
  });

  test('UsoVoz no tiene valor para bocinas (criterio 12)', () {
    final tipos = File('lib/modulos/gravity/voz/tipos.dart').readAsStringSync();
    final m = RegExp(r'enum UsoVoz \{([^}]*)\}').firstMatch(tipos)!;
    final valores = m.group(1)!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    expect(valores, ['curso', 'asistente']);
  });

  test('PuenteCasa.hablar sigue recibiendo solo un MensajeBocina (criterio 12)', () {
    final puente = File('lib/modulos/casa/puente/puente_casa.dart').readAsStringSync();
    expect(
      puente,
      contains('Future<void> hablar({required String bocina, required MensajeBocina mensaje});'),
    );
  });

  test('la voz del motor no recibe identidad: ningún tipo guarda persona o rol', () {
    for (final f in motor) {
      final fuente = sinComentarios(f.readAsStringSync());
      expect(
        RegExp(r'\b(personaId|idPersona|Rol\b|sesion)\b').hasMatch(fuente),
        isFalse,
        reason: '${f.path}: la voz no identifica ni autoriza (R2)',
      );
    }
  });

  test('flutter_tts solo se usa en la puerta de la fuente A', () {
    for (final f in motor) {
      final usa = f.readAsStringSync().contains('package:flutter_tts/');
      expect(
        usa,
        f.path.endsWith('fuentes/dispositivo/puerto_tts.dart'),
        reason: f.path,
      );
    }
  });
}

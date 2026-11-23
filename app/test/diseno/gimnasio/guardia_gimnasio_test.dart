// Guardias de «Mi gimnasio» (G4): sin colores fijos, sin dependencias de
// dominio, de red ni de sonido, tono sin culpa y sin contenido médico, y
// contraste de las superficies propias de los componentes en cada estilo.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_gimnasio.dart';

List<File> _fuentes() =>
    Directory('lib/diseno/gimnasio')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

String _sinComentarios(File f) =>
    f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

void main() {
  test('hay componentes que revisar', () {
    expect(_fuentes().length, greaterThanOrEqualTo(10));
  });

  test('ningún componente usa Color(0x…) ni Colors.*: todo sale del tema', () {
    final patron = RegExp(r'Color\(0x|Colors\.(?!transparent)[a-zA-Z]');
    final fallas = <String>[];
    for (final f in _fuentes()) {
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final l = lineas[i].trimLeft();
        if (l.startsWith('//')) continue;
        if (patron.hasMatch(l)) fallas.add('${f.path}:${i + 1}: $l');
      }
    }
    expect(fallas, isEmpty, reason: fallas.join('\n'));
  });

  test('los componentes no importan el dominio, los módulos, la red ni el '
      'sonido', () {
    final prohibido = RegExp(
      r"^import '(package:(habitos_dominio|finanzas_dominio|http|dio|"
      r"supabase_flutter|audioplayers|just_audio|flutter_tts|share_plus)/|"
      r"[./]*/?(modulos|nucleo/(sesion|cola|herramientas|sensibles|avisos|"
      r"seguridad)))",
      multiLine: true,
    );
    for (final f in _fuentes()) {
      expect(prohibido.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('sin Timer.periodic ni sonidos en ningún componente', () {
    for (final f in _fuentes()) {
      final codigo = _sinComentarios(f);
      expect(codigo.contains('Timer.periodic'), isFalse, reason: f.path);
      expect(codigo.contains('SystemSound'), isFalse, reason: f.path);
    }
  });

  test('ningún texto escrito en los componentes lleva signos de exclamación '
      'ni palabras que culpan', () {
    final cadenas = RegExp(r"'([^'\n]*)'");
    for (final f in _fuentes()) {
      for (final linea in _sinComentarios(f).split('\n')) {
        for (final m in cadenas.allMatches(linea)) {
          final texto = m.group(1)!;
          expect(
            texto.contains('!') && !texto.contains('!='),
            isFalse,
            reason: '${f.path}: $texto',
          );
          for (final p in palabrasProhibidas) {
            expect(
              texto.toLowerCase().contains(p),
              isFalse,
              reason: '${f.path}: $texto',
            );
          }
        }
      }
    }
  });

  test('los textos fijos no tienen contenido médico y los avisos de molestia '
      'nombran a un profesional, un médico o un entrenador', () {
    final fuente = File('lib/diseno/gimnasio/textos_gimnasio.dart')
        .readAsStringSync();
    final constantes = RegExp(
      r"static const (\w+) =\s*((?:'[^']*'\s*)+);",
      multiLine: true,
    ).allMatches(fuente);
    expect(constantes.length, greaterThanOrEqualTo(38));
    for (final m in constantes) {
      final nombre = m.group(1)!;
      final texto = RegExp(r"'([^']*)'")
          .allMatches(m.group(2)!)
          .map((x) => x.group(1)!)
          .join();
      expect(patronMedico.hasMatch(texto), isFalse, reason: '$nombre: $texto');
      if (nombre.startsWith('molestia') &&
          const [
            'molestiaLeve',
            'molestiaModerada',
            'molestiaFuerte',
          ].contains(nombre)) {
        expect(
          RegExp('profesional|médico|entrenador').hasMatch(texto),
          isTrue,
          reason: nombre,
        );
      }
    }
  });

  group('contraste de las superficies de los componentes', () {
    for (final estilo in todosLosEstilos) {
      for (final brillo in Brightness.values) {
        for (final p in [
          PersonalidadModulo.igualAlEstilo,
          PersonalidadModulo.sport,
        ]) {
          test('${estilo.id} ${brillo.name} · ${p.id}', () {
            final v = valoresPara(
              estilo: estilo,
              brillo: p.brilloEfectivo(brillo),
              personalidad: p,
            );
            // Superficies teñidas que usan los componentes (marcas con relleno,
            // avisos, día de hoy, serie actual, celdas de fuerza).
            final tintes = <String, Color>{
              'panel': v.panel,
              'chipSeleccionado': v.chipSeleccionado,
              for (final (nombre, color) in [
                ('alerta', v.alerta),
                ('exito', v.exito),
                ('acento', v.acento),
              ])
                for (final a in [0.06, 0.08, 0.10, 0.12, 0.14])
                  '$nombre $a': Color.alphaBlend(
                    color.withValues(alpha: a),
                    v.panel,
                  ),
            };
            for (final MapEntry(key: nombre, value: fondo) in tintes.entries) {
              expect(
                razonContraste(v.textoFuerte, fondo),
                greaterThanOrEqualTo(contrasteMinimoTexto),
                reason: 'textoFuerte sobre $nombre',
              );
              expect(
                razonContraste(v.texto, fondo),
                greaterThanOrEqualTo(contrasteMinimoTexto),
                reason: 'texto sobre $nombre',
              );
            }
            // Texto tenue sobre las superficies planas y la del día de hoy.
            for (final fondo in [v.fondo, v.panel, v.chipSeleccionado]) {
              expect(
                razonContraste(v.textoTenue, fondo),
                greaterThanOrEqualTo(contrasteMinimoTexto),
                reason: 'textoTenue',
              );
            }
            // Iconos, bordes y barras: 3:1 contra el panel y el avance contra
            // su pista.
            for (final (nombre, color) in [
              ('acento', v.acento),
              ('exito', v.exito),
              ('alerta', v.alerta),
              ('textoTenue', v.textoTenue),
            ]) {
              expect(
                razonContraste(color, v.panel),
                greaterThanOrEqualTo(contrasteMinimoGrande),
                reason: '$nombre sobre el panel',
              );
            }
            expect(
              razonContraste(v.acento, v.pista),
              greaterThanOrEqualTo(contrasteMinimoGrande),
              reason: 'avance de las barras y del aro contra su pista',
            );
            if (p == PersonalidadModulo.sport) {
              expect(v.altoContraste, isTrue);
              expect(
                razonContraste(v.sobreAcento, v.acento),
                greaterThanOrEqualTo(contrasteMinimoAlto),
                reason: 'texto del botón ✓ sobre el acento (Sport)',
              );
            } else {
              expect(
                razonContraste(v.sobreAcento, v.acento),
                greaterThanOrEqualTo(contrasteMinimoTexto),
                reason: 'texto de Empezar sobre el acento',
              );
            }
          });
        }
      }
    }
  });
}

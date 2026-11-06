import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Criterio 4 de la Fase 4: las pantallas y los componentes no usan colores
/// fijos; todo sale del tema (`ValoresDiseno`). Así, un estilo nuevo no obliga
/// a tocar pantallas.
void main() {
  test('ningún archivo fuera de los estilos usa Color(0x…) ni Colors.*', () {
    final carpetas = [
      'lib/modulos',
      'lib/diseno/componentes',
      'lib/diseno/gadgets',
      'lib/diseno/habitos',
      'lib/diseno/ajustes',
    ];
    final patron = RegExp(r'Color\(0x|Colors\.(?!transparent)[a-zA-Z]');
    final fallas = <String>[];
    for (final carpeta in carpetas) {
      for (final f in Directory(carpeta).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lineas = f.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final l = lineas[i].trimLeft();
          if (l.startsWith('//') || l.startsWith('///')) continue;
          if (patron.hasMatch(l)) fallas.add('${f.path}:${i + 1}: $l');
        }
      }
    }
    expect(fallas, isEmpty, reason: fallas.join('\n'));
  });

  test('los estilos son los únicos que declaran paletas', () {
    final estilos = Directory('lib/diseno/estilos')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split('/').last)
        .toSet();
    expect(
      estilos,
      containsAll({
        'catalogo.dart',
        'futurista.dart',
        'bento.dart',
        'swagger.dart',
      }),
    );
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

void _minimo(Color texto, Color fondo, double minimo, String que) {
  final razon = razonContraste(texto, fondo);
  expect(
    razon,
    greaterThanOrEqualTo(minimo),
    reason:
        '$que: ${_hex(texto)} sobre ${_hex(fondo)} da '
        '${razon.toStringAsFixed(2)}:1 (mínimo $minimo:1)',
  );
}

/// Todos los juegos de valores que pueden dibujar los componentes: cada estilo
/// incluido, de día y de noche, con cada personalidad de la sección 5.
Iterable<(String, ValoresDiseno)> _todos() sync* {
  for (final estilo in [...estilosIncluidos, ...estilosEnPausa]) {
    for (final brillo in Brightness.values) {
      for (final p in PersonalidadModulo.todas) {
        yield (
          '${estilo.nombre} ${brillo.name} ${p.nombre}',
          valoresPara(estilo: estilo, brillo: brillo, personalidad: p),
        );
      }
    }
  }
}

void main() {
  group('Contraste de las superficies de Finanzas (4.5:1 en texto)', () {
    for (final (nombre, v) in _todos()) {
      test(nombre, () {
        v.superficiesConTexto.forEach((superficie, fondo) {
          // Texto de celdas, teclas, chips y encabezados.
          _minimo(v.texto, fondo, 4.5, '$nombre texto/$superficie');
          _minimo(v.textoFuerte, fondo, 4.5, '$nombre fuerte/$superficie');
          _minimo(v.textoTenue, fondo, 4.5, '$nombre tenue/$superficie');
          _minimo(v.etiqueta, fondo, 4.5, '$nombre etiqueta/$superficie');
          // Texto de acento ajustado (icono de la marca del libro).
          _minimo(
            v.acentoParaTextoSobre(fondo),
            fondo,
            4.5,
            '$nombre acento ajustado/$superficie',
          );
        });
        // Semáforo con texto y montos negativos en rojo: solo donde se dibujan.
        v.superficiesConSemaforo.forEach((superficie, fondo) {
          _minimo(v.exito, fondo, 4.5, '$nombre exito/$superficie');
          _minimo(v.alerta, fondo, 4.5, '$nombre alerta/$superficie');
          _minimo(v.peligro, fondo, 4.5, '$nombre peligro/$superficie');
        });
      });
    }
  });

  group('Barras y medidores se distinguen de su pista (3:1)', () {
    for (final (nombre, v) in _todos()) {
      test(nombre, () {
        for (final (que, color) in [
          ('acento', v.acento),
          ('exito', v.exito),
          ('alerta', v.alerta),
          ('peligro', v.peligro),
        ]) {
          _minimo(color, v.pista, 3, '$nombre $que/pista');
          _minimo(color, v.panel, 3, '$nombre $que/panel');
          // Lo real (sólido) se distingue de lo planeado (relleno suave).
          _minimo(color, v.rellenoPlaneado(color), 3, '$nombre $que/planeado');
        }
      });
    }
  });

  test('aviso con deshacer: el tema lo dibuja con contraste', () {
    for (final (nombre, v) in _todos()) {
      final tema = construirTema(v);
      _minimo(
        tema.snackBarTheme.contentTextStyle!.color!,
        tema.snackBarTheme.backgroundColor!,
        4.5,
        '$nombre aviso',
      );
      _minimo(
        tema.snackBarTheme.actionTextColor!,
        tema.snackBarTheme.backgroundColor!,
        4.5,
        '$nombre Deshacer',
      );
    }
  });

  test('los gadgets y componentes de Finanzas no usan colores fijos', () {
    final archivos = [
      ...Directory('lib/diseno/gadgets').listSync().whereType<File>(),
      for (final nombre in [
        'aviso_deshacer',
        'selector_libro',
        'tabla_densa',
        'tarjeta_indicador',
      ])
        File('lib/diseno/componentes/$nombre.dart'),
      File('lib/diseno/superficies.dart'),
    ];
    expect(archivos.length, greaterThanOrEqualTo(9));
    final fijo = RegExp(r'Color\(0x|Colors\.(?!transparent\b)');
    for (final archivo in archivos) {
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        expect(
          fijo.hasMatch(lineas[i]),
          isFalse,
          reason: '${archivo.path}:${i + 1}: ${lineas[i].trim()}',
        );
      }
    }
  });
}

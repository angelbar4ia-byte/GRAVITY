import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

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

/// Revisa los colores de texto de un juego de valores de diseño.
void _revisarTextos(ValoresDiseno v, String nombre) {
  for (final (superficie, color) in [('fondo', v.fondo), ('panel', v.panel)]) {
    _minimo(v.texto, color, 4.5, '$nombre texto/$superficie');
    _minimo(v.textoTenue, color, 4.5, '$nombre textoTenue/$superficie');
    _minimo(v.textoFuerte, color, 4.5, '$nombre textoFuerte/$superficie');
    _minimo(v.etiqueta, color, 4.5, '$nombre etiqueta/$superficie');
  }
}

void main() {
  group('Luminancia relativa (WCAG)', () {
    test('negro y blanco', () {
      expect(luminanciaRelativa(const Color(0xFF000000)), 0);
      expect(luminanciaRelativa(const Color(0xFFFFFFFF)), closeTo(1, 1e-9));
      expect(
        razonContraste(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 1e-9),
      );
    });

    test('valores conocidos', () {
      // #777777 sobre blanco ≈ 4.48:1 (no pasa AA).
      expect(
        razonContraste(const Color(0xFF777777), const Color(0xFFFFFFFF)),
        closeTo(4.48, 0.01),
      );
      // El contraste es simétrico.
      expect(
        razonContraste(const Color(0xFF0A7F99), const Color(0xFFFFFFFF)),
        razonContraste(const Color(0xFFFFFFFF), const Color(0xFF0A7F99)),
      );
    });
  });

  group('Futurista cumple 4.5:1 en texto', () {
    test('noche: texto y textoTenue sobre fondo y panel', () {
      _revisarTextos(futuristaNoche, 'Futurista noche');
    });

    test('día: texto y textoTenue sobre fondo y panel', () {
      _revisarTextos(futuristaDia, 'Futurista día');
    });

    test('colores de la sección 18 sin cambios', () {
      expect(futuristaNoche.fondo, const Color(0xFF04070C));
      expect(futuristaNoche.acento, const Color(0xFF35D4F0));
      expect(futuristaDia.fondo, const Color(0xFFEEF4F7));
      expect(futuristaDia.acento, const Color(0xFF0A7F99));
    });
  });

  group('Todos los estilos incluidos', () {
    for (final estilo in estilosIncluidos) {
      for (final brillo in Brightness.values) {
        final v = estilo.valores(brillo);
        final nombre = '${estilo.nombre} ${brillo.name}';

        test('$nombre: textos', () => _revisarTextos(v, nombre));

        test('$nombre: semáforo legible como texto', () {
          for (final (que, color) in [
            ('exito', v.exito),
            ('alerta', v.alerta),
            ('peligro', v.peligro),
          ]) {
            _minimo(color, v.panel, 4.5, '$nombre $que/panel');
            _minimo(color, v.fondo, 4.5, '$nombre $que/fondo');
          }
        });

        test('$nombre: acento y texto sobre el acento', () {
          _minimo(v.sobreAcento, v.acento, 4.5, '$nombre sobreAcento/acento');
          _minimo(v.acento, v.panel, 4.5, '$nombre acento/panel');
          // Sobre el fondo, el acento solo se usa en texto grande o como
          // adorno (anillos, bordes): basta 3:1.
          _minimo(v.acento, v.fondo, 3, '$nombre acento/fondo');
        });
      }
    }
  });

  group('Personalidades de la sección 5', () {
    for (final p in PersonalidadModulo.todas) {
      for (final brillo in Brightness.values) {
        final v = valoresPara(
          estilo: estiloFuturista,
          brillo: brillo,
          personalidad: p,
        );
        final nombre = '${p.nombre} (${brillo.name})';

        test('$nombre: textos y acento con contraste suficiente', () {
          _revisarTextos(v, nombre);
          _minimo(v.sobreAcento, v.acento, 4.5, '$nombre sobreAcento/acento');
          _minimo(v.acento, v.panel, 4.5, '$nombre acento/panel');
          _minimo(v.acento, v.fondo, 3, '$nombre acento/fondo');
        });
      }
    }

    test('alto contraste llega a 7:1 en el texto (Cuidados y bici)', () {
      for (final brillo in Brightness.values) {
        for (final p in [
          PersonalidadModulo.claraCalida,
          PersonalidadModulo.sport,
        ]) {
          final v = valoresPara(
            estilo: estiloFuturista,
            brillo: brillo,
            personalidad: p,
          );
          expect(v.altoContraste, isTrue);
          _minimo(v.texto, v.fondo, 7, '${p.nombre} texto/fondo');
          _minimo(v.textoTenue, v.fondo, 7, '${p.nombre} textoTenue/fondo');
          _minimo(v.acento, v.fondo, 4.5, '${p.nombre} acento/fondo');
        }
      }
    });

    test('ningún módulo baja el contraste mínimo', () {
      for (final modulo in Modulo.values) {
        for (final brillo in Brightness.values) {
          final v = valoresPara(
            estilo: estiloFuturista,
            brillo: brillo,
            personalidad: PersonalidadModulo.automatica(modulo),
          );
          _revisarTextos(v, '${modulo.name} ${brillo.name}');
        }
      }
    });
  });
}

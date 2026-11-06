import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_estilos.dart';

/// Modo alto (P6): 7:1 en todo estilo, versión y personalidad.
void main() {
  test('el umbral del modo alto es 7:1', () {
    expect(contrasteMinimoAlto, 7.0);
  });

  for (final estilo in estilosIncluidos) {
    for (final brillo in Brightness.values) {
      test('${estilo.id} ${brillo.name}: todas las personalidades llegan a '
          '7:1 y van sin adornos', () {
        for (final p in PersonalidadModulo.todas) {
          final v = valoresPara(
            estilo: estilo,
            brillo: p.brilloEfectivo(brillo),
            personalidad: p,
            altoContrasteGlobal: true,
          );
          expect(v.altoContraste, isTrue, reason: p.nombre);
          expect(v.decoracion, isFalse, reason: p.nombre);
          for (final fondo in [v.fondo, v.panel]) {
            for (final (que, color) in [
              ('texto', v.texto),
              ('textoFuerte', v.textoFuerte),
              ('textoTenue', v.textoTenue),
              ('etiqueta', v.etiqueta),
              ('acento', v.acento),
              ('exito', v.exito),
              ('alerta', v.alerta),
              ('peligro', v.peligro),
            ]) {
              expect(
                razonContraste(color, fondo),
                greaterThanOrEqualTo(contrasteMinimoAlto),
                reason:
                    '${estilo.id} ${p.nombre} $que ${hex(color)}/${hex(fondo)}',
              );
            }
          }
          expect(
            razonContraste(v.sobreAcento, v.acento),
            greaterThanOrEqualTo(contrasteMinimoAlto),
            reason: '${estilo.id} ${p.nombre} sobreAcento',
          );
        }
      });
    }
  }
}

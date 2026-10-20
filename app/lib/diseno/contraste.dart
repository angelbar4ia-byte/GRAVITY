/// Cálculo de contraste según WCAG 2.x.
///
/// Se usa en las pruebas de los valores de diseño y para elegir el color del
/// texto que va sobre un acento (por ejemplo, el texto de un botón).
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Luminancia relativa de un color sRGB (WCAG 2.x): 0 es negro y 1 es blanco.
double luminanciaRelativa(Color color) {
  double canal(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(color.r) +
      0.7152 * canal(color.g) +
      0.0722 * canal(color.b);
}

/// Razón de contraste entre dos colores opacos: de 1:1 a 21:1.
double razonContraste(Color a, Color b) {
  final la = luminanciaRelativa(a);
  final lb = luminanciaRelativa(b);
  final claro = math.max(la, lb);
  final oscuro = math.min(la, lb);
  return (claro + 0.05) / (oscuro + 0.05);
}

/// De las opciones, la que tiene más contraste sobre [fondo].
Color masLegibleSobre(Color fondo, List<Color> opciones) {
  assert(opciones.isNotEmpty);
  var mejor = opciones.first;
  var mejorRazon = razonContraste(mejor, fondo);
  for (final opcion in opciones.skip(1)) {
    final razon = razonContraste(opcion, fondo);
    if (razon > mejorRazon) {
      mejor = opcion;
      mejorRazon = razon;
    }
  }
  return mejor;
}

/// Contraste mínimo para texto normal (WCAG AA).
const double contrasteMinimoTexto = 4.5;

/// Contraste mínimo para texto grande (24 px, o 18.7 px en negritas) y para
/// componentes de la interfaz (WCAG AA).
const double contrasteMinimoGrande = 3.0;

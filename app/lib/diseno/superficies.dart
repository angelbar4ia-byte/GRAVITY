/// Superficies derivadas de los valores de diseño: se calculan a partir del
/// panel, el borde, el fondo y el acento, así que cambian solas con el estilo,
/// la personalidad y el claro u oscuro (nunca son colores fijos).
///
/// Están aquí, y no dentro de cada componente, para que las pruebas de
/// contraste revisen exactamente los mismos colores que se dibujan.
library;

import 'package:flutter/painting.dart';

import 'valores_diseno.dart';

extension SuperficiesDiseno on ValoresDiseno {
  /// Pista de barras, medidores y anillos (la parte "vacía").
  Color get pista => Color.lerp(panel, borde, 0.45)!;

  /// Fondo de las teclas del teclado numérico.
  Color get superficieTecla => Color.lerp(panel, borde, 0.18)!;

  /// Fila de tabla bajo el puntero (laptop).
  Color get filaResaltada =>
      Color.alphaBlend(acento.withValues(alpha: 0.06), panel);

  /// Fila de tabla seleccionada (su detalle está abierto en el panel lateral).
  Color get filaSeleccionada =>
      Color.alphaBlend(acento.withValues(alpha: 0.12), panel);

  /// Fondo del encabezado de las tablas.
  Color get encabezadoTabla => Color.lerp(panel, fondo, 0.5)!;

  /// Relleno translúcido de lo planeado cuando se compara con lo real
  /// (cascada): el color del tono sobre el panel.
  Color rellenoPlaneado(Color tono) =>
      Color.alphaBlend(tono.withValues(alpha: 0.22), panel);

  /// Todas las superficies sobre las que los componentes ponen texto.
  /// Las pruebas de contraste las recorren.
  Map<String, Color> get superficiesConTexto => {
    'fondo': fondo,
    'panel': panel,
    'superficieTecla': superficieTecla,
    'filaResaltada': filaResaltada,
    'filaSeleccionada': filaSeleccionada,
    'encabezadoTabla': encabezadoTabla,
  };
}

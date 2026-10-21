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
  /// Pista de barras, medidores y anillos (la parte "vacía"). En alto
  /// contraste el borde es muy marcado, así que la pista se aclara para que el
  /// avance se distinga de ella (3:1 o más).
  Color get pista => Color.lerp(panel, borde, altoContraste ? 0.25 : 0.45)!;

  /// Fondo de las teclas del teclado numérico.
  Color get superficieTecla => Color.lerp(panel, borde, 0.18)!;

  /// Fila de tabla bajo el puntero (laptop).
  Color get filaResaltada =>
      Color.alphaBlend(acento.withValues(alpha: 0.06), panel);

  /// Fila de tabla seleccionada (su detalle está abierto en el panel lateral).
  Color get filaSeleccionada =>
      Color.alphaBlend(acento.withValues(alpha: 0.12), panel);

  /// Chip elegido (selector de libro) y fondo de las marcas "Solo lectura" y
  /// "En nombre de".
  Color get chipSeleccionado =>
      Color.alphaBlend(acento.withValues(alpha: 0.16), panel);

  /// Fondo del encabezado de las tablas.
  Color get encabezadoTabla => Color.lerp(panel, fondo, 0.5)!;

  /// Relleno translúcido de lo planeado cuando se compara con lo real
  /// (cascada): el color del tono sobre el panel.
  Color rellenoPlaneado(Color tono) =>
      Color.alphaBlend(tono.withValues(alpha: 0.22), panel);

  /// Superficies que llevan texto con los colores del semáforo (estado de una
  /// partida, montos negativos en rojo): las de tablas, tarjetas y gadgets.
  /// Las pruebas de contraste revisan ahí texto **y** semáforo a 4.5:1.
  Map<String, Color> get superficiesConSemaforo => {
    'fondo': fondo,
    'panel': panel,
    'filaResaltada': filaResaltada,
    'filaSeleccionada': filaSeleccionada,
    'encabezadoTabla': encabezadoTabla,
  };

  /// Todas las superficies sobre las que los componentes ponen texto (las de
  /// arriba más teclas, chips y marcas, que nunca llevan semáforo). Las
  /// pruebas de contraste revisan ahí el texto a 4.5:1.
  Map<String, Color> get superficiesConTexto => {
    ...superficiesConSemaforo,
    'superficieTecla': superficieTecla,
    'chipSeleccionado': chipSeleccionado,
  };
}

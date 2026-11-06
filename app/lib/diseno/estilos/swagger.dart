/// Estilo F · Swagger (DISENO_UX_UI, secciones 4 y 18): con actitud.
///
/// Letra grande y condensada (Anton) en títulos y cifras, negro y blanco con un
/// color neón, bordes gruesos y etiquetas tipo sticker. Lectura en Inter.
/// Noche: negro con neón magenta. Día: blanco con trazo negro y magenta oscuro.
///
/// Es también la base de la personalidad *sport* y del aspecto de
/// Ajustes › Desarrollador (D16).
library;

import 'package:flutter/material.dart';

import '../estilo.dart';
import '../valores_diseno.dart';

/// Familias de Swagger (incluidas en `assets/fonts/`, licencia OFL).
abstract final class FuentesSwagger {
  /// Anton: títulos y cifras grandes, condensada.
  static const titulos = 'Anton';

  /// Inter: lectura y números de ancho fijo (con cifras tabulares).
  static const lectura = 'Inter';
}

const swaggerNoche = ValoresDiseno(
  brillo: Brightness.dark,
  fondo: Color(0xFF000000),
  panel: Color(0xFF111111),
  borde: Color(0xFFEDEDED),
  texto: Color(0xFFF2F2F2),
  textoFuerte: Color(0xFFFFFFFF),
  textoTenue: Color(0xFFBDBDBD),
  etiqueta: Color(0xFFFF6FD8),
  acento: Color(0xFFFF3DCB),
  sobreAcento: Color(0xFF000000),
  exito: Color(0xFF3DFF8F),
  alerta: Color(0xFFFFE03D),
  peligro: Color(0xFFFF7A7A),
  fuenteTitulos: FuentesSwagger.titulos,
  fuenteNumeros: FuentesSwagger.lectura,
  fuenteLectura: FuentesSwagger.lectura,
  radioChico: 2,
  radioMediano: 2,
  radioGrande: 4,
  duracionAnimacion: Duration(milliseconds: 180),
  grosorBorde: 2,
  etiquetaSticker: true,
  marcasEsquina: false,
  nucleo: VarianteNucleo.pulso,
);

const swaggerDia = ValoresDiseno(
  brillo: Brightness.light,
  fondo: Color(0xFFFFFFFF),
  panel: Color(0xFFF4F4F4),
  borde: Color(0xFF000000),
  texto: Color(0xFF111111),
  textoFuerte: Color(0xFF000000),
  textoTenue: Color(0xFF474747),
  etiqueta: Color(0xFF8A0066),
  acento: Color(0xFFB0007F),
  sobreAcento: Color(0xFFFFFFFF),
  exito: Color(0xFF0B6B3A),
  alerta: Color(0xFF7A5200),
  peligro: Color(0xFFB3261E),
  fuenteTitulos: FuentesSwagger.titulos,
  fuenteNumeros: FuentesSwagger.lectura,
  fuenteLectura: FuentesSwagger.lectura,
  radioChico: 2,
  radioMediano: 2,
  radioGrande: 4,
  duracionAnimacion: Duration(milliseconds: 180),
  grosorBorde: 2,
  etiquetaSticker: true,
  marcasEsquina: false,
  nucleo: VarianteNucleo.pulso,
);

const estiloSwagger = Estilo(
  id: 'swagger',
  nombre: 'Swagger',
  descripcion: 'Negro y blanco con un neón, letra condensada y stickers.',
  dia: swaggerDia,
  noche: swaggerNoche,
);

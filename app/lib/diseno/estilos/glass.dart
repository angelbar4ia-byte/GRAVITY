/// Estilo E · Glass (DISENO_UX_UI, secciones 4 y 18; D27): paneles translúcidos
/// y esmerilados sobre un fondo de color difuminado, de noche y de día.
///
/// - **Laptop y tablet:** los paneles se esmerilan (`esmerilado` > 0) con un
///   máximo de 3 capas a la vez y un apagado automático si la app va lenta
///   ([GestorEsmerilado]).
/// - **Teléfono:** sin esmerilar. El panel es [ValoresDiseno.panel], la versión
///   translúcida **sólida** (un color opaco parecido al vidrio sobre el fondo).
/// - El texto cumple 4.5:1 contra el **peor fondo posible** (el fondo, su
///   segundo color y la mancha de color; ver `fondosExtremos`), no solo contra
///   un panel liso.
///
/// Lectura y títulos en Plus Jakarta Sans; cifras en Inter (cifras tabulares).
library;

import 'package:flutter/material.dart';

import '../estilo.dart';
import '../valores_diseno.dart';

/// Familias de Glass (incluidas en `assets/fonts/`, licencia OFL).
abstract final class FuentesGlass {
  /// Plus Jakarta Sans: títulos y lectura.
  static const texto = 'PlusJakartaSans';

  /// Inter: cifras de ancho fijo (con cifras tabulares).
  static const numeros = 'Inter';
}

const glassNoche = ValoresDiseno(
  brillo: Brightness.dark,
  fondo: Color(0xFF0B1020),
  fondoFin: Color(0xFF241646),
  panel: Color(0xFF161C34),
  panelTranslucido: Color(0xB3141A30),
  borde: Color(0xFF3E4A75),
  texto: Color(0xFFF1F4FF),
  textoFuerte: Color(0xFFFFFFFF),
  textoTenue: Color(0xFFB8C0DC),
  etiqueta: Color(0xFFA9C7FF),
  acento: Color(0xFF7CE0FF),
  sobreAcento: Color(0xFF0B1020),
  exito: Color(0xFF4ADE9A),
  alerta: Color(0xFFFFD166),
  peligro: Color(0xFFFF9C9C),
  fuenteTitulos: FuentesGlass.texto,
  fuenteNumeros: FuentesGlass.numeros,
  fuenteLectura: FuentesGlass.texto,
  radioChico: 14,
  radioMediano: 20,
  radioGrande: 28,
  duracionAnimacion: Duration(milliseconds: 320),
  marcasEsquina: false,
  nucleo: VarianteNucleo.cristal,
  esmerilado: 18,
);

const glassDia = ValoresDiseno(
  brillo: Brightness.light,
  fondo: Color(0xFFE8EEFF),
  fondoFin: Color(0xFFFAF0FF),
  panel: Color(0xFFF8FAFF),
  panelTranslucido: Color(0xB3FFFFFF),
  borde: Color(0xFFB4C0E6),
  texto: Color(0xFF14182B),
  textoFuerte: Color(0xFF0A0D1C),
  textoTenue: Color(0xFF4B5470),
  etiqueta: Color(0xFF3D4C8F),
  acento: Color(0xFF4338CA),
  sobreAcento: Color(0xFFFFFFFF),
  exito: Color(0xFF0B5D36),
  alerta: Color(0xFF6B4700),
  peligro: Color(0xFF9B1C14),
  fuenteTitulos: FuentesGlass.texto,
  fuenteNumeros: FuentesGlass.numeros,
  fuenteLectura: FuentesGlass.texto,
  radioChico: 14,
  radioMediano: 20,
  radioGrande: 28,
  duracionAnimacion: Duration(milliseconds: 320),
  marcasEsquina: false,
  nucleo: VarianteNucleo.cristal,
  esmerilado: 18,
);

const estiloGlass = Estilo(
  id: 'glass',
  nombre: 'Glass',
  descripcion: 'Paneles de vidrio sobre un fondo de color difuminado.',
  dia: glassDia,
  noche: glassNoche,
);

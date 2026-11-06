/// Estilo A · Futurista (HUD), el estilo por defecto (DISENO_UX_UI, secciones 4 y 18).
///
/// Noche: fondo casi negro, líneas finas cian y letra técnica.
/// Día: fondo claro con líneas azul petróleo.
library;

import 'package:flutter/material.dart';

import '../estilo.dart';
import '../valores_diseno.dart';

const futuristaNoche = ValoresDiseno(
  brillo: Brightness.dark,
  fondo: Color(0xFF04070C),
  panel: Color(0xFF07131B),
  borde: Color(0xFF16394A),
  texto: Color(0xFFD3ECF4),
  textoFuerte: Color(0xFFE8F7FB),
  textoTenue: Color(0xFF8FB3C1),
  etiqueta: Color(0xFF7FB6C7),
  acento: Color(0xFF35D4F0),
  sobreAcento: Color(0xFF04070C),
  exito: Color(0xFF3DDC97),
  alerta: Color(0xFFF2C14E),
  peligro: Color(0xFFFF8A80),
  fuenteTitulos: FuentesGravity.titulos,
  fuenteNumeros: FuentesGravity.mono,
  fuenteLectura: FuentesGravity.lectura,
  radioChico: 4,
  radioMediano: 6,
  radioGrande: 12,
);

/// Versión de día. El semáforo se oscurece para que el texto tenga al menos
/// 4.5:1 sobre el fondo y los paneles.
const futuristaDia = ValoresDiseno(
  brillo: Brightness.light,
  fondo: Color(0xFFEEF4F7),
  panel: Color(0xFFFFFFFF),
  borde: Color(0xFFB9D3DD),
  texto: Color(0xFF0D2430),
  textoFuerte: Color(0xFF06141B),
  textoTenue: Color(0xFF46606B),
  etiqueta: Color(0xFF3F6170),
  acento: Color(0xFF0A7F99),
  sobreAcento: Color(0xFFFFFFFF),
  exito: Color(0xFF17784A),
  alerta: Color(0xFF875C00),
  peligro: Color(0xFFB3261E),
  fuenteTitulos: FuentesGravity.titulos,
  fuenteNumeros: FuentesGravity.mono,
  fuenteLectura: FuentesGravity.lectura,
  radioChico: 4,
  radioMediano: 6,
  radioGrande: 12,
);

const estiloFuturista = Estilo(
  id: 'futurista',
  nombre: 'Futurista',
  descripcion: 'Líneas finas, anillos que giran y letra técnica.',
  dia: futuristaDia,
  noche: futuristaNoche,
);

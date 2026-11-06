/// Estilo Bento (D26, 6/nov/2026): tarjetas en cuadrícula tipo bento, esquinas
/// muy redondeadas, fondo suave, **un solo color de acento** y letra limpia
/// (Inter). Sin marcas de esquina ni stickers: la forma lo dice todo.
///
/// Día: fondo hueso y tarjetas blancas. Noche: fondo grafito y tarjetas un tono
/// más claras. La cuadrícula la dibuja [CuadriculaBento] (componentes).
library;

import 'package:flutter/material.dart';

import '../estilo.dart';
import '../valores_diseno.dart';

/// Familia de Bento: Inter, incluida en `assets/fonts/` (licencia OFL).
abstract final class FuentesBento {
  static const familia = 'Inter';
}

const bentoNoche = ValoresDiseno(
  brillo: Brightness.dark,
  fondo: Color(0xFF0F1115),
  panel: Color(0xFF181B22),
  borde: Color(0xFF2B303A),
  texto: Color(0xFFE7E9EE),
  textoFuerte: Color(0xFFFFFFFF),
  textoTenue: Color(0xFFA7ADBA),
  etiqueta: Color(0xFFA7ADBA),
  acento: Color(0xFF8FA8FF),
  sobreAcento: Color(0xFF0F1115),
  exito: Color(0xFF4ADE9A),
  alerta: Color(0xFFF2C14E),
  peligro: Color(0xFFFF8A80),
  fuenteTitulos: FuentesBento.familia,
  fuenteNumeros: FuentesBento.familia,
  fuenteLectura: FuentesBento.familia,
  radioChico: 12,
  radioMediano: 20,
  radioGrande: 28,
  duracionAnimacion: Duration(milliseconds: 300),
  marcasEsquina: false,
  nucleo: VarianteNucleo.orbe,
  cuadricula: true,
);

const bentoDia = ValoresDiseno(
  brillo: Brightness.light,
  fondo: Color(0xFFF2F1EE),
  panel: Color(0xFFFFFFFF),
  borde: Color(0xFFDAD7CF),
  texto: Color(0xFF1B1D22),
  textoFuerte: Color(0xFF0E0F12),
  textoTenue: Color(0xFF565B66),
  etiqueta: Color(0xFF4C5160),
  acento: Color(0xFF3451C7),
  sobreAcento: Color(0xFFFFFFFF),
  exito: Color(0xFF17784A),
  alerta: Color(0xFF875C00),
  peligro: Color(0xFFB3261E),
  fuenteTitulos: FuentesBento.familia,
  fuenteNumeros: FuentesBento.familia,
  fuenteLectura: FuentesBento.familia,
  radioChico: 12,
  radioMediano: 20,
  radioGrande: 28,
  duracionAnimacion: Duration(milliseconds: 300),
  marcasEsquina: false,
  nucleo: VarianteNucleo.orbe,
  cuadricula: true,
);

const estiloBento = Estilo(
  id: 'bento',
  nombre: 'Bento',
  descripcion: 'Tarjetas en cuadrícula, esquinas redondeadas y un solo acento.',
  dia: bentoDia,
  noche: bentoNoche,
);

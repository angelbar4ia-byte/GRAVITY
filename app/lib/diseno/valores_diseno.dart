/// Valores de diseño: el juego de colores, tipografías, formas, densidad y
/// animación que cada pantalla lee del tema central (DISENO_UX_UI, sección 4).
///
/// Las pantallas **nunca** usan colores fijos: siempre `ValoresDiseno.de(context)`.
/// Así, agregar un estilo nuevo no obliga a tocar pantallas.
library;

import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';

import '../nucleo/contratos/dispositivo.dart';
import 'contraste.dart';

/// Familias tipográficas incluidas en el proyecto (licencia OFL, en
/// `assets/fonts/`). Los nombres coinciden con la sección `fonts:` de
/// `pubspec.yaml`.
abstract final class FuentesGravity {
  /// Chakra Petch: títulos y cifras grandes del estilo Futurista.
  static const titulos = 'ChakraPetch';

  /// IBM Plex Sans: texto de lectura.
  static const lectura = 'IBMPlexSans';

  /// IBM Plex Mono: etiquetas, horas y montos (ancho fijo).
  static const mono = 'IBMPlexMono';
}

/// Variante del núcleo animado de GRAVITY; cada estilo trae la suya (P14).
enum VarianteNucleo {
  /// Futurista: anillos punteados que giran.
  anillos,

  /// Swagger: círculos gruesos que laten como un pulso.
  pulso,

  /// Glass: orbes translúcidos que flotan.
  cristal,

  /// Bento: orbes suaves que respiran.
  orbe,
}

/// Densidad de la interfaz. La laptop es compacta, el teléfono cómodo y la
/// tablet grande (sección 18); algunas personalidades la fijan (Cuidados, bici).
enum Densidad {
  compacta(4),
  comoda(8),
  grande(12);

  const Densidad(this.espacio);

  /// Unidad base de espaciado en píxeles lógicos.
  final double espacio;

  /// Densidad visual de Material. Las zonas táctiles siguen siendo de 48 dp
  /// porque el tema usa `MaterialTapTargetSize.padded`.
  VisualDensity get densidadVisual => switch (this) {
    Densidad.compacta => VisualDensity.compact,
    Densidad.comoda => VisualDensity.standard,
    Densidad.grande => const VisualDensity(horizontal: 1, vertical: 1),
  };

  /// Alto de una fila de tabla **de solo lectura**. Las filas que se tocan
  /// nunca bajan de 48 dp (sección 20).
  double get altoFilaTabla => switch (this) {
    Densidad.compacta => 40,
    Densidad.comoda => 48,
    Densidad.grande => 56,
  };

  /// Alto del encabezado de una tabla (48 dp si se puede ordenar).
  double get altoEncabezadoTabla => switch (this) {
    Densidad.compacta => 36,
    Densidad.comoda => 40,
    Densidad.grande => 48,
  };

  /// Tamaño de la letra en las celdas de una tabla.
  double get textoTabla => switch (this) {
    Densidad.compacta => 13,
    Densidad.comoda => 14,
    Densidad.grande => 16,
  };
}

/// Densidad por defecto según el dispositivo (sección 18).
Densidad densidadPara(TipoDispositivo dispositivo) => switch (dispositivo) {
  TipoDispositivo.laptop => Densidad.compacta,
  TipoDispositivo.telefono => Densidad.comoda,
  TipoDispositivo.tablet => Densidad.grande,
};

/// Juego completo de valores de diseño de un estilo en una versión (día o noche),
/// ya con la personalidad del módulo aplicada.
@immutable
class ValoresDiseno extends ThemeExtension<ValoresDiseno> {
  const ValoresDiseno({
    required this.brillo,
    required this.fondo,
    required this.panel,
    required this.borde,
    required this.texto,
    required this.textoFuerte,
    required this.textoTenue,
    required this.etiqueta,
    required this.acento,
    required this.sobreAcento,
    required this.exito,
    required this.alerta,
    required this.peligro,
    this.fuenteTitulos = FuentesGravity.titulos,
    this.fuenteNumeros = FuentesGravity.mono,
    this.fuenteLectura = FuentesGravity.lectura,
    this.radioChico = 4,
    this.radioMediano = 6,
    this.radioGrande = 12,
    this.densidad = Densidad.comoda,
    this.duracionAnimacion = const Duration(milliseconds: 250),
    this.escalaLectura = 1,
    this.decoracion = true,
    this.altoContraste = false,
    this.grosorBorde = 1,
    this.etiquetaSticker = false,
    this.marcasEsquina = true,
    this.nucleo = VarianteNucleo.anillos,
    this.cuadricula = false,
  });

  /// Claro u oscuro.
  final Brightness brillo;

  /// Fondo de la pantalla.
  final Color fondo;

  /// Superficie de tarjetas y paneles.
  final Color panel;

  /// Líneas y bordes de los paneles.
  final Color borde;

  /// Texto normal.
  final Color texto;

  /// Texto destacado: cifras grandes, títulos y saludo.
  final Color textoFuerte;

  /// Texto secundario.
  final Color textoTenue;

  /// Etiquetas en mayúsculas de los paneles ("HOY · AGENDA").
  final Color etiqueta;

  /// Color de acento del estilo o de la personalidad del módulo.
  final Color acento;

  /// Texto e iconos que van sobre el acento.
  final Color sobreAcento;

  /// Semáforo: verde.
  final Color exito;

  /// Semáforo: ámbar.
  final Color alerta;

  /// Semáforo: rojo (solo para alertas reales).
  final Color peligro;

  /// Tipografía de títulos (capa 2: estilo).
  final String fuenteTitulos;

  /// Tipografía de números y etiquetas, de ancho fijo.
  final String fuenteNumeros;

  /// Tipografía de lectura (capa 1: base común).
  final String fuenteLectura;

  /// Radio de esquinas de botones y chips.
  final double radioChico;

  /// Radio de esquinas de paneles y tarjetas.
  final double radioMediano;

  /// Radio de esquinas de hojas y diálogos.
  final double radioGrande;

  /// Densidad de la interfaz.
  final Densidad densidad;

  /// Ritmo de animación. `Duration.zero` significa sin animación.
  final Duration duracionAnimacion;

  /// Multiplicador del tamaño de la letra de lectura (Espiritual y Cuidados la agrandan).
  final double escalaLectura;

  /// Si se dibujan los adornos del estilo (marcas de esquina, retículas).
  /// Cuidados va sin decoración.
  final bool decoracion;

  /// Si es una variante de alto contraste (Cuidados y bici).
  final bool altoContraste;

  /// Grosor de los bordes de paneles y tarjetas (Swagger los dibuja gruesos).
  final double grosorBorde;

  /// Si las etiquetas de panel se dibujan como "sticker" (relleno de acento).
  final bool etiquetaSticker;

  /// Si las tarjetas dibujan las marcas de esquina del HUD (solo Futurista).
  final bool marcasEsquina;

  /// Variante del núcleo animado de GRAVITY.
  final VarianteNucleo nucleo;

  /// Si las pantallas de resumen acomodan sus tarjetas en cuadrícula tipo
  /// bento ([CuadriculaBento]) en lugar de una sola columna.
  final bool cuadricula;

  /// Los valores de diseño del tema más cercano.
  ///
  /// Si el tema no los trae (por ejemplo, en una prueba aislada), regresa los
  /// del brillo del tema con valores neutros, para no fallar.
  static ValoresDiseno de(BuildContext context) {
    final tema = Theme.of(context);
    return tema.extension<ValoresDiseno>() ??
        (tema.brightness == Brightness.dark ? _respaldoNoche : _respaldoDia);
  }

  /// Si las animaciones del módulo están activas (sin contar la opción de
  /// "reducir movimiento" del sistema, que se revisa con `MediaQuery`).
  bool get animado => duracionAnimacion > Duration.zero;

  /// Unidad de espaciado según la densidad.
  double get espacio => densidad.espacio;

  /// El acento, ajustado para texto normal (4.5:1) sobre [superficie].
  ///
  /// El acento cumple 4.5:1 sobre el panel, pero sobre el fondo solo 3:1 (texto
  /// grande y adornos). Úsalo cuando texto chico de acento va sobre otra
  /// superficie (p. ej. una mezcla de fondo y panel).
  Color acentoParaTextoSobre(Color superficie) =>
      conContrasteMinimo(acento, superficie);

  /// Estilo para títulos (GRAVITY, encabezados, cifras grandes).
  TextStyle titulo({
    double tamano = 22,
    FontWeight peso = FontWeight.w600,
    Color? color,
    double espaciadoLetras = 0,
  }) => TextStyle(
    fontFamily: fuenteTitulos,
    fontSize: tamano,
    fontWeight: peso,
    color: color ?? textoFuerte,
    letterSpacing: espaciadoLetras,
    height: 1.2,
  );

  /// Estilo para etiquetas de panel en mayúsculas.
  TextStyle etiquetaPanel({double tamano = 12, Color? color}) => TextStyle(
    fontFamily: fuenteNumeros,
    fontSize: tamano,
    fontWeight: FontWeight.w500,
    letterSpacing: tamano * 0.14,
    color: color ?? etiqueta,
    height: 1.3,
  );

  /// Estilo para números, horas y montos: ancho fijo y cifras tabulares.
  TextStyle numero({
    double tamano = 14,
    FontWeight peso = FontWeight.w500,
    Color? color,
  }) => TextStyle(
    fontFamily: fuenteNumeros,
    fontSize: tamano,
    fontWeight: peso,
    color: color ?? texto,
    fontFeatures: const [FontFeature.tabularFigures()],
    height: 1.3,
  );

  /// Estilo para texto de lectura, con la escala de la personalidad.
  TextStyle lectura({
    double tamano = 15,
    FontWeight peso = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontFamily: fuenteLectura,
    fontSize: tamano * escalaLectura,
    fontWeight: peso,
    color: color ?? texto,
    height: 1.4,
  );

  @override
  ValoresDiseno copyWith({
    Brightness? brillo,
    Color? fondo,
    Color? panel,
    Color? borde,
    Color? texto,
    Color? textoFuerte,
    Color? textoTenue,
    Color? etiqueta,
    Color? acento,
    Color? sobreAcento,
    Color? exito,
    Color? alerta,
    Color? peligro,
    String? fuenteTitulos,
    String? fuenteNumeros,
    String? fuenteLectura,
    double? radioChico,
    double? radioMediano,
    double? radioGrande,
    Densidad? densidad,
    Duration? duracionAnimacion,
    double? escalaLectura,
    bool? decoracion,
    bool? altoContraste,
    double? grosorBorde,
    bool? etiquetaSticker,
    bool? marcasEsquina,
    VarianteNucleo? nucleo,
    bool? cuadricula,
  }) {
    return ValoresDiseno(
      brillo: brillo ?? this.brillo,
      fondo: fondo ?? this.fondo,
      panel: panel ?? this.panel,
      borde: borde ?? this.borde,
      texto: texto ?? this.texto,
      textoFuerte: textoFuerte ?? this.textoFuerte,
      textoTenue: textoTenue ?? this.textoTenue,
      etiqueta: etiqueta ?? this.etiqueta,
      acento: acento ?? this.acento,
      sobreAcento: sobreAcento ?? this.sobreAcento,
      exito: exito ?? this.exito,
      alerta: alerta ?? this.alerta,
      peligro: peligro ?? this.peligro,
      fuenteTitulos: fuenteTitulos ?? this.fuenteTitulos,
      fuenteNumeros: fuenteNumeros ?? this.fuenteNumeros,
      fuenteLectura: fuenteLectura ?? this.fuenteLectura,
      radioChico: radioChico ?? this.radioChico,
      radioMediano: radioMediano ?? this.radioMediano,
      radioGrande: radioGrande ?? this.radioGrande,
      densidad: densidad ?? this.densidad,
      duracionAnimacion: duracionAnimacion ?? this.duracionAnimacion,
      escalaLectura: escalaLectura ?? this.escalaLectura,
      decoracion: decoracion ?? this.decoracion,
      altoContraste: altoContraste ?? this.altoContraste,
      grosorBorde: grosorBorde ?? this.grosorBorde,
      etiquetaSticker: etiquetaSticker ?? this.etiquetaSticker,
      marcasEsquina: marcasEsquina ?? this.marcasEsquina,
      nucleo: nucleo ?? this.nucleo,
      cuadricula: cuadricula ?? this.cuadricula,
    );
  }

  /// Transición suave entre dos juegos de valores (cambio de día a noche o de
  /// estilo): los colores y medidas se mezclan; lo demás cambia a la mitad.
  @override
  ValoresDiseno lerp(covariant ValoresDiseno? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    T mitad<T>(T a, T b) => t < 0.5 ? a : b;
    return ValoresDiseno(
      brillo: mitad(brillo, other.brillo),
      fondo: c(fondo, other.fondo),
      panel: c(panel, other.panel),
      borde: c(borde, other.borde),
      texto: c(texto, other.texto),
      textoFuerte: c(textoFuerte, other.textoFuerte),
      textoTenue: c(textoTenue, other.textoTenue),
      etiqueta: c(etiqueta, other.etiqueta),
      acento: c(acento, other.acento),
      sobreAcento: c(sobreAcento, other.sobreAcento),
      exito: c(exito, other.exito),
      alerta: c(alerta, other.alerta),
      peligro: c(peligro, other.peligro),
      fuenteTitulos: mitad(fuenteTitulos, other.fuenteTitulos),
      fuenteNumeros: mitad(fuenteNumeros, other.fuenteNumeros),
      fuenteLectura: mitad(fuenteLectura, other.fuenteLectura),
      radioChico: d(radioChico, other.radioChico),
      radioMediano: d(radioMediano, other.radioMediano),
      radioGrande: d(radioGrande, other.radioGrande),
      densidad: mitad(densidad, other.densidad),
      duracionAnimacion: mitad(duracionAnimacion, other.duracionAnimacion),
      escalaLectura: d(escalaLectura, other.escalaLectura),
      decoracion: mitad(decoracion, other.decoracion),
      altoContraste: mitad(altoContraste, other.altoContraste),
      grosorBorde: d(grosorBorde, other.grosorBorde),
      etiquetaSticker: mitad(etiquetaSticker, other.etiquetaSticker),
      marcasEsquina: mitad(marcasEsquina, other.marcasEsquina),
      nucleo: mitad(nucleo, other.nucleo),
      cuadricula: mitad(cuadricula, other.cuadricula),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValoresDiseno &&
          other.brillo == brillo &&
          other.fondo == fondo &&
          other.panel == panel &&
          other.borde == borde &&
          other.texto == texto &&
          other.textoFuerte == textoFuerte &&
          other.textoTenue == textoTenue &&
          other.etiqueta == etiqueta &&
          other.acento == acento &&
          other.sobreAcento == sobreAcento &&
          other.exito == exito &&
          other.alerta == alerta &&
          other.peligro == peligro &&
          other.fuenteTitulos == fuenteTitulos &&
          other.fuenteNumeros == fuenteNumeros &&
          other.fuenteLectura == fuenteLectura &&
          other.radioChico == radioChico &&
          other.radioMediano == radioMediano &&
          other.radioGrande == radioGrande &&
          other.densidad == densidad &&
          other.duracionAnimacion == duracionAnimacion &&
          other.escalaLectura == escalaLectura &&
          other.decoracion == decoracion &&
          other.altoContraste == altoContraste &&
          other.grosorBorde == grosorBorde &&
          other.etiquetaSticker == etiquetaSticker &&
          other.marcasEsquina == marcasEsquina &&
          other.nucleo == nucleo &&
          other.cuadricula == cuadricula;

  @override
  int get hashCode => Object.hashAll([
    brillo,
    fondo,
    panel,
    borde,
    texto,
    textoFuerte,
    textoTenue,
    etiqueta,
    acento,
    sobreAcento,
    exito,
    alerta,
    peligro,
    fuenteTitulos,
    fuenteNumeros,
    fuenteLectura,
    radioChico,
    radioMediano,
    radioGrande,
    densidad,
    duracionAnimacion,
    escalaLectura,
    decoracion,
    altoContraste,
    grosorBorde,
    etiquetaSticker,
    marcasEsquina,
    nucleo,
    cuadricula,
  ]);
}

// Valores neutros de respaldo, solo si una pantalla se dibuja sin el tema de
// GRAVITY (no deberían verse en la app).
const _respaldoDia = ValoresDiseno(
  brillo: Brightness.light,
  fondo: Color(0xFFFFFFFF),
  panel: Color(0xFFFFFFFF),
  borde: Color(0xFF8A8A8A),
  texto: Color(0xFF1A1A1A),
  textoFuerte: Color(0xFF000000),
  textoTenue: Color(0xFF4A4A4A),
  etiqueta: Color(0xFF3A3A3A),
  acento: Color(0xFF0A7F99),
  sobreAcento: Color(0xFFFFFFFF),
  exito: Color(0xFF17784A),
  alerta: Color(0xFF875C00),
  peligro: Color(0xFFB3261E),
);

const _respaldoNoche = ValoresDiseno(
  brillo: Brightness.dark,
  fondo: Color(0xFF000000),
  panel: Color(0xFF111111),
  borde: Color(0xFF5A5A5A),
  texto: Color(0xFFEDEDED),
  textoFuerte: Color(0xFFFFFFFF),
  textoTenue: Color(0xFFBDBDBD),
  etiqueta: Color(0xFFCFCFCF),
  acento: Color(0xFF35D4F0),
  sobreAcento: Color(0xFF000000),
  exito: Color(0xFF3DDC97),
  alerta: Color(0xFFF2C14E),
  peligro: Color(0xFFFF8A80),
);

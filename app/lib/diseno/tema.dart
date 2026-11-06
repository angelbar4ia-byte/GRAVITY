/// Une las cuatro capas y genera el `ThemeData` de Material 3 con la extensión
/// [ValoresDiseno] (DISENO_UX_UI, sección 4).
///
/// Capa 1 (base común, fija): Material 3, zonas táctiles de 48 dp, tipografía
/// de lectura, comportamiento de botones y campos. Capa 2: [Estilo]. Capa 3:
/// [PersonalidadModulo]. Capa 4: el brillo (claro u oscuro).
library;

import 'package:flutter/material.dart';

import 'contraste.dart';
import 'estilo.dart';
import 'personalidad_modulo.dart';
import 'superficies.dart';
import 'valores_diseno.dart';

/// Duración del cambio suave entre claro y oscuro o entre estilos.
/// Se pasa a `MaterialApp.themeAnimationDuration`.
const Duration duracionCambioTema = Duration(milliseconds: 600);

/// Tamaño mínimo de las zonas táctiles (sección 20).
const double zonaTactilMinima = 48;

/// Los valores de diseño finales para un estilo, un brillo y una personalidad.
ValoresDiseno valoresPara({
  required Estilo estilo,
  required Brightness brillo,
  PersonalidadModulo personalidad = PersonalidadModulo.asistente,
  Densidad? densidadBase,
  bool altoContrasteGlobal = false,
}) {
  final efectivo = personalidad.brilloEfectivo(brillo);
  var base = estilo.valores(efectivo);
  if (densidadBase != null) base = base.copyWith(densidad: densidadBase);
  final valores = personalidad.aplicar(base);
  // Modo alto (P6): 7:1 en todo, sin adornos; después de la personalidad, para
  // que su acento tampoco baje el contraste.
  return altoContrasteGlobal
      ? valoresAltoContraste(valores).copyWith(decoracion: false)
      : valores;
}

/// Atajo: valores + tema en un paso.
ThemeData temaPara({
  required Estilo estilo,
  required Brightness brillo,
  PersonalidadModulo personalidad = PersonalidadModulo.asistente,
  Densidad? densidadBase,
  bool altoContrasteGlobal = false,
}) => construirTema(
  valoresPara(
    estilo: estilo,
    brillo: brillo,
    personalidad: personalidad,
    densidadBase: densidadBase,
    altoContrasteGlobal: altoContrasteGlobal,
  ),
);

/// Genera el `ThemeData` de Material 3 a partir de los valores de diseño.
ThemeData construirTema(ValoresDiseno v) {
  final sobreEtiqueta = masLegibleSobre(v.etiqueta, [v.fondo, v.textoFuerte]);
  final sobreExito = masLegibleSobre(v.exito, [v.fondo, v.textoFuerte]);
  final sobrePeligro = masLegibleSobre(v.peligro, [v.fondo, v.textoFuerte]);
  final contenedorAcento = Color.alphaBlend(
    v.acento.withValues(alpha: 0.16),
    v.panel,
  );
  final pista = v.pista;

  final esquema = ColorScheme(
    brightness: v.brillo,
    primary: v.acento,
    onPrimary: v.sobreAcento,
    primaryContainer: contenedorAcento,
    onPrimaryContainer: v.textoFuerte,
    secondary: v.etiqueta,
    onSecondary: sobreEtiqueta,
    secondaryContainer: Color.alphaBlend(
      v.etiqueta.withValues(alpha: 0.14),
      v.panel,
    ),
    onSecondaryContainer: v.textoFuerte,
    tertiary: v.exito,
    onTertiary: sobreExito,
    error: v.peligro,
    onError: sobrePeligro,
    errorContainer: Color.alphaBlend(
      v.peligro.withValues(alpha: 0.16),
      v.panel,
    ),
    onErrorContainer: v.textoFuerte,
    surface: v.panel,
    onSurface: v.texto,
    onSurfaceVariant: v.textoTenue,
    surfaceDim: v.fondo,
    surfaceBright: v.panel,
    surfaceContainerLowest: v.fondo,
    surfaceContainerLow: Color.lerp(v.fondo, v.panel, 0.5),
    surfaceContainer: v.panel,
    surfaceContainerHigh: Color.lerp(v.panel, v.borde, 0.2),
    surfaceContainerHighest: pista,
    outline: v.borde,
    outlineVariant: v.borde,
    inverseSurface: v.textoFuerte,
    onInverseSurface: v.fondo,
    inversePrimary: v.acento,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  final forma = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(v.radioChico),
  );
  final formaPanel = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(v.radioMediano),
    side: BorderSide(color: v.borde, width: v.grosorBorde),
  );
  const tamanoMinimo = Size(zonaTactilMinima, zonaTactilMinima);
  final textoBoton = v.lectura(tamano: 14, peso: FontWeight.w600);

  final base = ThemeData(
    useMaterial3: true,
    brightness: v.brillo,
    colorScheme: esquema,
    fontFamily: v.fuenteLectura,
    visualDensity: v.densidad.densidadVisual,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: v.fondo,
    canvasColor: v.fondo,
    cardColor: v.panel,
    dividerColor: v.borde,
    hintColor: v.textoTenue,
    disabledColor: v.textoTenue,
    focusColor: v.acento.withValues(alpha: 0.20),
    hoverColor: v.acento.withValues(alpha: 0.08),
    highlightColor: v.acento.withValues(alpha: 0.12),
    splashColor: v.acento.withValues(alpha: 0.14),
    iconTheme: IconThemeData(color: v.texto, size: 22),
    appBarTheme: AppBarThemeData(
      backgroundColor: v.fondo,
      foregroundColor: v.textoFuerte,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: v.titulo(tamano: 20),
    ),
    cardTheme: CardThemeData(
      color: v.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: formaPanel,
    ),
    dividerTheme: DividerThemeData(color: v.borde, thickness: 1, space: 1),
    // Tablas densas (Finanzas en la laptop): mismas superficies y medidas que
    // `TablaDensa`, por si una pantalla usa el `DataTable` de Material.
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(v.encabezadoTabla),
      headingRowHeight: zonaTactilMinima,
      headingTextStyle: v.lectura(
        tamano: v.densidad.textoTabla,
        peso: FontWeight.w600,
        color: v.etiqueta,
      ),
      dataTextStyle: v.lectura(tamano: v.densidad.textoTabla),
      dataRowColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? v.filaSeleccionada
            : estados.contains(WidgetState.hovered)
            ? v.filaResaltada
            : null,
      ),
      dataRowMinHeight: zonaTactilMinima,
      dataRowMaxHeight: zonaTactilMinima + v.espacio * 2,
      dividerThickness: 1,
      horizontalMargin: v.espacio * 3,
      columnSpacing: v.espacio * 4,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: v.acento,
        foregroundColor: v.sobreAcento,
        minimumSize: tamanoMinimo,
        shape: forma,
        textStyle: textoBoton,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: v.panel,
        foregroundColor: v.textoFuerte,
        minimumSize: tamanoMinimo,
        shape: forma,
        elevation: 0,
        textStyle: textoBoton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: v.texto,
        side: BorderSide(color: v.borde, width: v.grosorBorde),
        minimumSize: tamanoMinimo,
        shape: forma,
        textStyle: textoBoton,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: v.texto,
        minimumSize: tamanoMinimo,
        shape: forma,
        textStyle: textoBoton,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: v.texto,
        minimumSize: tamanoMinimo,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: v.acento,
      foregroundColor: v.sobreAcento,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: v.panel,
      hintStyle: TextStyle(color: v.textoTenue),
      labelStyle: TextStyle(color: v.textoTenue),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(v.radioChico),
        borderSide: BorderSide(color: v.borde, width: v.grosorBorde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(v.radioChico),
        borderSide: BorderSide(color: v.borde, width: v.grosorBorde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(v.radioChico),
        borderSide: BorderSide(color: v.acento, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: v.panel,
      selectedColor: contenedorAcento,
      side: BorderSide(color: v.borde, width: v.grosorBorde),
      labelStyle: v.lectura(tamano: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(v.radioGrande),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: v.texto,
      textColor: v.texto,
      minTileHeight: zonaTactilMinima,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: v.panel,
      surfaceTintColor: Colors.transparent,
      indicatorColor: contenedorAcento,
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected)
              ? v.textoFuerte
              : v.textoTenue,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => v.lectura(
          tamano: 12,
          peso: estados.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: estados.contains(WidgetState.selected)
              ? v.textoFuerte
              : v.textoTenue,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: v.panel,
      indicatorColor: contenedorAcento,
      selectedIconTheme: IconThemeData(color: v.textoFuerte),
      unselectedIconTheme: IconThemeData(color: v.textoTenue),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: v.acento,
      linearTrackColor: pista,
      circularTrackColor: pista,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: v.textoFuerte,
      contentTextStyle: v.lectura(tamano: 14, color: v.fondo),
      actionTextColor: v.fondo,
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: v.panel,
        border: Border.all(color: v.borde, width: v.grosorBorde),
        borderRadius: BorderRadius.circular(v.radioChico),
      ),
      textStyle: v.lectura(tamano: 12),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: v.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(v.radioGrande),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: v.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(v.radioGrande),
        side: BorderSide(color: v.borde, width: v.grosorBorde),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: v.acento,
      selectionColor: v.acento.withValues(alpha: 0.3),
      selectionHandleColor: v.acento,
    ),
    extensions: [v],
  );

  return base.copyWith(textTheme: _textos(base.textTheme, v));
}

/// Títulos con la fuente del estilo, lectura con la escala de la personalidad y
/// etiquetas pequeñas con la fuente de ancho fijo.
TextTheme _textos(TextTheme t, ValoresDiseno v) {
  TextStyle? titulo(TextStyle? s) =>
      s?.copyWith(fontFamily: v.fuenteTitulos, color: v.textoFuerte);
  TextStyle? lectura(TextStyle? s) => s?.copyWith(
    fontFamily: v.fuenteLectura,
    fontSize: (s.fontSize ?? 14) * v.escalaLectura,
    color: v.texto,
  );
  TextStyle? etiqueta(TextStyle? s) =>
      s?.copyWith(fontFamily: v.fuenteNumeros, color: v.etiqueta);
  return t.copyWith(
    displayLarge: titulo(t.displayLarge),
    displayMedium: titulo(t.displayMedium),
    displaySmall: titulo(t.displaySmall),
    headlineLarge: titulo(t.headlineLarge),
    headlineMedium: titulo(t.headlineMedium),
    headlineSmall: titulo(t.headlineSmall),
    titleLarge: titulo(t.titleLarge),
    titleMedium: lectura(t.titleMedium)?.copyWith(color: v.textoFuerte),
    titleSmall: lectura(t.titleSmall)?.copyWith(color: v.textoFuerte),
    bodyLarge: lectura(t.bodyLarge),
    bodyMedium: lectura(t.bodyMedium),
    bodySmall: lectura(t.bodySmall)?.copyWith(color: v.textoTenue),
    labelLarge: t.labelLarge?.copyWith(
      fontFamily: v.fuenteLectura,
      color: v.texto,
    ),
    labelMedium: etiqueta(t.labelMedium),
    labelSmall: etiqueta(t.labelSmall),
  );
}

/// Reglas y valores del gimnasio (`docs/specs/fase-8-habitos-gimnasio.md`,
/// convención 5): cada cifra vive en un solo lugar y se edita en Ajustes.
library;

/// Versión de una plantilla de fuerza (3.4).
enum VersionSesion {
  corta('corta'),
  estandar('estandar'),
  larga('larga');

  const VersionSesion(this.id);
  final String id;

  static VersionSesion? deId(String id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

/// Parámetros de una versión (3.4 y tolerancias de 5.5).
class ParametrosVersion {
  const ParametrosVersion({
    required this.series,
    required this.descansoS,
    required this.calentamientoMin,
    required this.cierreMin,
    required this.metaMin,
    required this.toleranciaDesdeMin,
    required this.toleranciaHastaMin,
    this.incluyeExtras = false,
    this.omiteOmitibles = false,
  });

  /// Series por ejercicio; `null` = las que declara cada slot (estándar).
  final int? series;
  final int descansoS;
  final int calentamientoMin;
  final int cierreMin;

  /// Meta de duración (30, 45 o 60); solo etiqueta.
  final int metaMin;
  final int toleranciaDesdeMin;
  final int toleranciaHastaMin;
  final bool incluyeExtras;
  final bool omiteOmitibles;
}

/// Todas las cifras de reglas del gimnasio.
class ReglasGimnasio {
  const ReglasGimnasio({
    this.corta = const ParametrosVersion(
      series: 3,
      descansoS: 45,
      calentamientoMin: 5,
      cierreMin: 3,
      metaMin: 30,
      toleranciaDesdeMin: 27,
      toleranciaHastaMin: 33,
      omiteOmitibles: true,
    ),
    this.estandar = const ParametrosVersion(
      series: null,
      descansoS: 60,
      calentamientoMin: 6,
      cierreMin: 5,
      metaMin: 45,
      toleranciaDesdeMin: 33,
      toleranciaHastaMin: 50,
    ),
    this.larga = const ParametrosVersion(
      series: 4,
      descansoS: 75,
      calentamientoMin: 8,
      cierreMin: 5,
      metaMin: 60,
      toleranciaDesdeMin: 48,
      toleranciaHastaMin: 65,
      incluyeExtras: true,
    ),
    this.segundosPorRepeticion = 4,
    this.segundosCambio = 45,
    this.descansoMinimoS = 45,
    this.descansoMaximoS = 75,
    this.descansoPisoS = 30,
    this.descansoTopeS = 120,
    this.horasEntreSesiones = 48,
    this.toleranciaEntreSesionesMin = 60,
    this.cicloSemanas = 4,
    this.cicloMinimo = 3,
    this.cicloMaximo = 8,
    this.esfuerzoMinimo = 1,
    this.esfuerzoMaximo = 5,
    this.esfuerzoMaximoParaSubir = 4,
    this.esfuerzoPorOmision = 3,
    this.seriesDescarga = 2,
    this.seriesAdaptacion = 2,
    this.semanasAdaptacion = 2,
    this.reentradaRepiteDias = 7,
    this.reentradaDias = 14,
    this.reentradaDesdeCeroDias = 56,
    this.descargaSugeridaSesiones = 2,
    this.margenHuecoMin = 10,
    this.margenDormirMin = 90,
    this.calentamientoMananaMin = 8,
    this.ventanaMananaHastaMin = 720,
    this.calibracionSesiones = 3,
    this.ventanaMinimoPlaneadas = 4,
    this.ventanaDifCumplimientoPct = 15,
    this.ventanaDifEnergiaCentesimas = 50,
    this.molestiaPreguntaCadaDias = 14,
    this.aproximacionReps = 8,
    this.techoEscaleraReps = 3,
    this.techoEscaleraSegundos = 15,
    this.seriesTopeLarga = 5,
    this.seriesTopeOtras = 4,
    this.pasoDescansoS = 15,
  });

  final ParametrosVersion corta;
  final ParametrosVersion estandar;
  final ParametrosVersion larga;

  /// Modelo de tiempo (5.5).
  final int segundosPorRepeticion;
  final int segundosCambio;

  /// Descanso (5.7).
  final int descansoMinimoS;
  final int descansoMaximoS;
  final int descansoPisoS;
  final int descansoTopeS;

  /// 48 horas con tolerancia (5.6).
  final int horasEntreSesiones;
  final int toleranciaEntreSesionesMin;

  /// Ciclo (5.9).
  final int cicloSemanas;
  final int cicloMinimo;
  final int cicloMaximo;

  /// Esfuerzo (PG-12) y progresión (5.8).
  final int esfuerzoMinimo;
  final int esfuerzoMaximo;
  final int esfuerzoMaximoParaSubir;
  final int esfuerzoPorOmision;

  final int seriesDescarga;
  final int seriesAdaptacion;
  final int semanasAdaptacion;
  final int reentradaRepiteDias;
  final int reentradaDias;
  final int reentradaDesdeCeroDias;
  final int descargaSugeridaSesiones;

  /// Margen sobre el hueco libre (5.5) y cercanía a dormir (5.13).
  final int margenHuecoMin;
  final int margenDormirMin;
  final int calentamientoMananaMin;
  final int ventanaMananaHastaMin;

  final int calibracionSesiones;
  final int ventanaMinimoPlaneadas;
  final int ventanaDifCumplimientoPct;
  final int ventanaDifEnergiaCentesimas;
  final int molestiaPreguntaCadaDias;
  final int aproximacionReps;

  /// Escalera sin carga (5.8).
  final int techoEscaleraReps;
  final int techoEscaleraSegundos;
  final int seriesTopeLarga;
  final int seriesTopeOtras;
  final int pasoDescansoS;

  ParametrosVersion de(VersionSesion v) => switch (v) {
        VersionSesion.corta => corta,
        VersionSesion.estandar => estandar,
        VersionSesion.larga => larga,
      };

  /// Mínimo entre dos sesiones que comparten grupo, inicio a inicio (min).
  int get minimoEntreSesionesMin =>
      horasEntreSesiones * 60 - toleranciaEntreSesionesMin;

  /// ¿La duración (segundos) cae dentro de la tolerancia de la versión?
  bool dentroDeTolerancia(VersionSesion v, int segundos) {
    final p = de(v);
    return segundos >= p.toleranciaDesdeMin * 60 &&
        segundos <= p.toleranciaHastaMin * 60;
  }
}

/// Valores por omisión que cambian con el objetivo (5.11, PG-21).
enum ObjetivoGimnasio {
  fuerza('fuerza'),
  masa('masa'),
  perdidaGrasa('perdida_grasa'),
  saludGeneral('salud_general');

  const ObjetivoGimnasio(this.id);
  final String id;
}

enum NivelGimnasio {
  principiante('principiante'),
  intermedio('intermedio');

  const NivelGimnasio(this.id);
  final String id;
}

enum VentanaEntrenamiento {
  manana('manana'),
  noche('noche'),
  flexible('flexible');

  const VentanaEntrenamiento(this.id);
  final String id;
}

/// Perfil de la persona (4.2, `hab_ent_perfil`), sin datos de salud.
class PerfilGimnasio {
  const PerfilGimnasio({
    this.diasPlan = 3,
    this.versionPreferida,
    this.ventana = VentanaEntrenamiento.noche,
    this.nocheDesdeMin = 19 * 60,
    this.objetivo = ObjetivoGimnasio.saludGeneral,
    this.nivel = NivelGimnasio.principiante,
    this.inicioCiclo,
    this.cicloSemanas = 4,
    this.descansoS,
    this.margenDormirMin = 90,
  });

  final int diasPlan;

  /// `null` = automática.
  final VersionSesion? versionPreferida;
  final VentanaEntrenamiento ventana;
  final int nocheDesdeMin;
  final ObjetivoGimnasio objetivo;
  final NivelGimnasio nivel;

  /// Lunes de inicio del plan; `null` = aún no empieza.
  final DateTime? inicioCiclo;

  /// 0 = sin descarga programada.
  final int cicloSemanas;

  /// `null` = el de la versión (con el ajuste del objetivo).
  final int? descansoS;
  final int margenDormirMin;
}

/// Reglas y valores de la bicicleta (`docs/specs/fase-8-habitos-bicicleta.md`,
/// 4 y 5.2): cada cifra vive en un solo lugar y se edita en Ajustes › Bicicleta
/// (convención 5, RB8). Dart puro, sin reloj propio.
library;

/// Cómo cuenta la ruta para la regla de 48 horas del gimnasio (4.6, PB-07).
///
/// - [normal]: cuenta como cuádriceps y glúteo (como hoy).
/// - [ligera]: la persona declara que la ruta no carga las piernas; no cuenta.
/// - [porEsfuerzo]: cuenta solo si alguna de las últimas tres salidas con
///   esfuerzo registrado fue de 3 o más; sin esfuerzos registrados, cuenta.
///
/// Es una declaración de la persona, no un cálculo médico.
enum CargaPiernas {
  normal('normal'),
  ligera('ligera'),
  porEsfuerzo('por_esfuerzo');

  const CargaPiernas(this.id);
  final String id;

  static CargaPiernas? deId(String id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Todas las cifras de reglas de la bicicleta. Los rangos son los de las
/// columnas de `hab_bici_perfil` (5.2); [validar] los revisa.
class ReglasBicicleta {
  const ReglasBicicleta({
    this.salidaInicioMin = 8 * 60,
    this.salidaRecordarMin = 45,
    this.preparacionDesdeMin = 19 * 60 + 30,
    this.preparacionDuracionMin = 15,
    this.preparacionAntesDeDormirMin = 60,
    this.preparacionSabadoAntesMin = 45,
    this.duracionPrevistaMin = 240,
    this.margenRevisionMin = 90,
    this.avisoPasarRevisionMin = 75,
    this.salidasParaPromedio = 4,
    this.redondeoDuracionMin = 15,
    this.topeAumentoPct = 20,
    this.cargaPiernas = CargaPiernas.normal,
    this.salidasParaEsfuerzo = 3,
    this.esfuerzoMinimoPiernas = 3,
    this.metaMensual = 3,
    this.maxPuntosPropios = 10,
    this.maxLargoPropio = 60,
    this.numeroEmergencias = '911',
  });

  /// Sábado a las 8:00 (`diseno-app-habitos.md:267`), en minutos desde la
  /// medianoche.
  final int salidaInicioMin;

  /// Aviso de salida: 45 min antes (el de ~7:15).
  final int salidaRecordarMin;

  /// Preparación del viernes: primer hueco libre desde las 19:30 …
  final int preparacionDesdeMin;
  final int preparacionDuracionMin;

  /// … y antes de `dormir − 60 min`.
  final int preparacionAntesDeDormirMin;

  /// Si el viernes no hay hueco, el sábado 45 min antes de la salida.
  final int preparacionSabadoAntesMin;

  /// Duración prevista por omisión (30 a 720).
  final int duracionPrevistaMin;

  /// Margen entre el regreso y la revisión (0 a 240; PB-18).
  final int margenRevisionMin;

  /// Con la salida en curso, a partir de «revisión − 75 min» se ofrece pasar
  /// la revisión a más tarde.
  final int avisoPasarRevisionMin;

  /// Promedio de las últimas N salidas (4.1 y 4.9).
  final int salidasParaPromedio;
  final int redondeoDuracionMin;

  /// Aumento a partir del cual la progresión informa (5 a 50; PB-12).
  final int topeAumentoPct;
  final CargaPiernas cargaPiernas;

  /// `por_esfuerzo`: últimas 3 salidas, umbral 3.
  final int salidasParaEsfuerzo;
  final int esfuerzoMinimoPiernas;

  /// Objetivo «Bicicleta»: salidas del mes (4.11, PB-06).
  final int metaMensual;

  /// Preparación: puntos propios (4.2).
  final int maxPuntosPropios;
  final int maxLargoPropio;

  /// Número de emergencias del país (Ajustes). 911 en México **[confirmar]**.
  final String numeroEmergencias;

  /// Una copia con otros valores (los que se editan en Ajustes).
  ReglasBicicleta copiaCon({
    int? salidaInicioMin,
    int? salidaRecordarMin,
    int? duracionPrevistaMin,
    int? margenRevisionMin,
    int? topeAumentoPct,
    CargaPiernas? cargaPiernas,
    int? metaMensual,
    String? numeroEmergencias,
  }) => ReglasBicicleta(
    salidaInicioMin: salidaInicioMin ?? this.salidaInicioMin,
    salidaRecordarMin: salidaRecordarMin ?? this.salidaRecordarMin,
    preparacionDesdeMin: preparacionDesdeMin,
    preparacionDuracionMin: preparacionDuracionMin,
    preparacionAntesDeDormirMin: preparacionAntesDeDormirMin,
    preparacionSabadoAntesMin: preparacionSabadoAntesMin,
    duracionPrevistaMin: duracionPrevistaMin ?? this.duracionPrevistaMin,
    margenRevisionMin: margenRevisionMin ?? this.margenRevisionMin,
    avisoPasarRevisionMin: avisoPasarRevisionMin,
    salidasParaPromedio: salidasParaPromedio,
    redondeoDuracionMin: redondeoDuracionMin,
    topeAumentoPct: topeAumentoPct ?? this.topeAumentoPct,
    cargaPiernas: cargaPiernas ?? this.cargaPiernas,
    salidasParaEsfuerzo: salidasParaEsfuerzo,
    esfuerzoMinimoPiernas: esfuerzoMinimoPiernas,
    metaMensual: metaMensual ?? this.metaMensual,
    maxPuntosPropios: maxPuntosPropios,
    maxLargoPropio: maxLargoPropio,
    numeroEmergencias: numeroEmergencias ?? this.numeroEmergencias,
  );

  /// Errores de rango (lista vacía = válido): los de `hab_bici_perfil`.
  List<String> validar() {
    final e = <String>[];
    if (duracionPrevistaMin < 30 || duracionPrevistaMin > 720) {
      e.add('duracion_prevista_min fuera de 30 a 720');
    }
    if (margenRevisionMin < 0 || margenRevisionMin > 240) {
      e.add('margen_revision_min fuera de 0 a 240');
    }
    if (topeAumentoPct < 5 || topeAumentoPct > 50) {
      e.add('tope_aumento_pct fuera de 5 a 50');
    }
    if (salidaInicioMin < 0 || salidaInicioMin >= 24 * 60) {
      e.add('salida_inicio fuera del día');
    }
    if (salidaRecordarMin < 0 || salidaRecordarMin > 1440) {
      e.add('recordar_min fuera de 0 a 1440');
    }
    if (metaMensual < 1 || metaMensual > 31) {
      e.add('meta_mensual fuera de 1 a 31');
    }
    if (numeroEmergencias.trim().isEmpty) {
      e.add('numero_emergencias vacío');
    }
    return e;
  }
}

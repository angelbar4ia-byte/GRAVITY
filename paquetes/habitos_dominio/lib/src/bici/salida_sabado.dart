/// B1.1 · La salida del sábado y su encaje con la revisión de las 14:30
/// (4.1 y 4.7). Funciones puras: el tiempo entra como parámetro.
///
/// **Propone, nunca mueve:** ninguna función de aquí cambia la hora de la
/// revisión ni guarda nada; solo devuelve números y códigos de propuesta.
library;

import '../agenda.dart';
import '../fecha.dart';
import 'reglas_bici.dart';
import 'tipos_bici.dart';

// ---------------------------------------------------------------------------
// Duración prevista y regreso (4.1)
// ---------------------------------------------------------------------------

/// Duración prevista de una salida concreta, en este orden (4.1):
/// 1. la duración de la ruta elegida, si la persona la escribió (1 a 1 440);
/// 2. el promedio de sus últimas cuatro salidas con duración, redondeado a
///    15 min (hacen falta las cuatro; con menos no hay promedio);
/// 3. la duración prevista del perfil (240 por omisión).
int duracionPrevistaMin({
  int? rutaDuracionMin,
  List<Salida> salidas = const [],
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) {
  if (rutaDuracionMin != null &&
      rutaDuracionMin >= 1 &&
      rutaDuracionMin <= 1440) {
    return rutaDuracionMin;
  }
  final n = reglas.salidasParaPromedio;
  final ultimas = [
    for (final s in salidasRecientes(salidas))
      if (s.duracionMin != null && s.duracionMin! > 0) s.duracionMin!,
  ].take(n).toList();
  if (ultimas.length == n) {
    final suma = ultimas.fold<int>(0, (a, b) => a + b);
    final r = reglas.redondeoDuracionMin;
    final redondeada = redondearMitadArriba(suma, n * r) * r;
    return redondeada < r ? r : redondeada;
  }
  return reglas.duracionPrevistaMin;
}

/// Hora de regreso: `inicio + duración prevista` (minutos desde medianoche).
int regresoMin(int inicioMin, int duracionMin) => inicioMin + duracionMin;

// ---------------------------------------------------------------------------
// Encaje con la revisión del sábado (4.7, PB-18)
// ---------------------------------------------------------------------------

/// Qué se propone cuando el regreso no deja tiempo para la revisión.
enum PropuestaRevision { acortarSalida, revisionMasTarde, revisionElDomingo }

/// ¿Alcanza el tiempo tras la ruta?
/// **regreso + margen ≤ hora de la revisión.**
class EncajeRevision {
  const EncajeRevision({
    required this.inicioMin,
    required this.duracionMin,
    required this.margenMin,
    required this.revisionMin,
  });

  final int inicioMin;
  final int duracionMin;
  final int margenMin;

  /// Hora de la revisión **tal como está en Ajustes**: la regla no la mueve.
  final int revisionMin;

  int get regresoMin => inicioMin + duracionMin;

  /// Hora a la que la persona estaría lista (regreso + margen).
  int get listoMin => regresoMin + margenMin;

  bool get cabe => listoMin <= revisionMin;

  /// Minutos de sobra (0 si cabe justo o no cabe).
  int get sobranMin => cabe ? revisionMin - listoMin : 0;

  /// Minutos que faltan (0 si cabe).
  int get faltanMin => cabe ? 0 : listoMin - revisionMin;

  /// Duración más larga con la que la salida aún cabe (null si, aun sin
  /// salir, no cabría: la salida empieza demasiado tarde).
  int? get duracionMaximaQueCabeMin {
    final m = revisionMin - margenMin - inicioMin;
    return m >= 1 ? m : null;
  }

  /// Hora más temprana a la que podría hacerse la revisión con este regreso.
  int get revisionMasTardeMin => listoMin;

  /// Siempre `false`: esta regla **nunca** mueve la revisión sola.
  bool get mueveLaRevision => false;

  /// Propuestas en orden; vacías si cabe. «Acortar» solo si acortando se
  /// llega a caber.
  List<PropuestaRevision> get propuestas => cabe
      ? const []
      : [
          if (duracionMaximaQueCabeMin != null) PropuestaRevision.acortarSalida,
          PropuestaRevision.revisionMasTarde,
          PropuestaRevision.revisionElDomingo,
        ];
}

/// Calcula el encaje. [margenMin] sale del perfil (90 por omisión).
EncajeRevision encajeConRevision({
  required int inicioMin,
  required int duracionMin,
  required int revisionMin,
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) => EncajeRevision(
  inicioMin: inicioMin,
  duracionMin: duracionMin,
  margenMin: reglas.margenRevisionMin,
  revisionMin: revisionMin,
);

/// Con la salida en curso, si pasan las 13:15 (la revisión menos 75 min) la
/// tarjeta de Hoy ofrece *Pasar mi revisión a más tarde* (un toque). Solo
/// ofrece: no pospone nada.
bool ofrecerPasarRevision({
  required int ahoraMin,
  required int revisionMin,
  required bool salidaEnCurso,
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) => salidaEnCurso && ahoraMin > revisionMin - reglas.avisoPasarRevisionMin;

// ---------------------------------------------------------------------------
// Bloques de agenda (4.1, PB-08)
// ---------------------------------------------------------------------------

/// Un bloque que «Poner en mi agenda» crearía en `hab_bloques`.
class BloqueBiciPlan {
  const BloqueBiciPlan({
    required this.nombreId,
    required this.diaSemana,
    required this.inicioMin,
    required this.duracionMin,
    required this.recordarMin,
  });

  /// `salida_bici` o `preparar_bici` (el texto lo pone la capa de pantallas).
  final String nombreId;

  /// 1 = lunes … 7 = domingo.
  final int diaSemana;
  final int inicioMin;
  final int duracionMin;
  final int recordarMin;

  /// Tipo de bloque y área (HB-13): siempre actividad de salud.
  String get tipo => 'actividad';
  String get area => 'salud';

  int get finMin => inicioMin + duracionMin;
  Intervalo get intervalo => Intervalo(inicioMin, finMin);
}

enum AvisoBloqueBici {
  /// El primer lugar deseado de la preparación choca con otro bloque.
  preparacionChoca,

  /// No hay hueco el viernes: la preparación pasa al sábado.
  sinHuecoViernes,

  /// La salida choca con otro bloque del sábado.
  salidaChoca,
}

class PlanBloquesBici {
  const PlanBloquesBici({
    required this.salida,
    required this.preparacion,
    required this.preparacionDeseadaMin,
    required this.avisos,
    required this.conflictosPreparacion,
    required this.conflictosSalida,
  });

  final BloqueBiciPlan salida;
  final BloqueBiciPlan preparacion;

  /// Donde habría caído la preparación sin otros bloques (19:30).
  final int preparacionDeseadaMin;
  final List<AvisoBloqueBici> avisos;
  final List<Intervalo> conflictosPreparacion;
  final List<Intervalo> conflictosSalida;

  /// ¿La preparación quedó en el sábado?
  bool get preparacionEnSabado => preparacion.diaSemana == DateTime.saturday;

  /// Un conflicto **avisa y no impide guardar** (Fase 3, criterio 24).
  bool get impideGuardar => false;
}

/// Planea los dos bloques (CA-B-02): el sábado a las 8:00 con 240 min y
/// `recordar_min = 45`, y la preparación el viernes en el primer hueco libre
/// de 15 min desde las 19:30 y antes de `dormir − 60 min`; si no hay hueco,
/// el sábado 45 min antes de la salida.
///
/// [ocupadosViernes] y [ocupadosSabado] son los bloques de esos días en
/// minutos desde la medianoche.
PlanBloquesBici planearBloquesBici({
  required int dormirMin,
  List<Intervalo> ocupadosViernes = const [],
  List<Intervalo> ocupadosSabado = const [],
  int? duracionSalidaMin,
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) {
  final salida = BloqueBiciPlan(
    nombreId: 'salida_bici',
    diaSemana: DateTime.saturday,
    inicioMin: reglas.salidaInicioMin,
    duracionMin: duracionSalidaMin ?? reglas.duracionPrevistaMin,
    recordarMin: reglas.salidaRecordarMin,
  );
  final avisos = <AvisoBloqueBici>[];
  final dur = reglas.preparacionDuracionMin;
  final desde = reglas.preparacionDesdeMin;

  // Lo que pasaría sin nada más en el día.
  final deseada = Intervalo(desde, desde + dur);
  final choques = conflictos(deseada, ocupadosViernes);
  if (choques.isNotEmpty) avisos.add(AvisoBloqueBici.preparacionChoca);

  final huecos = huecosLibres(
    desde,
    dormirMin - reglas.preparacionAntesDeDormirMin,
    ocupadosViernes,
    minimoMin: dur,
  );

  final BloqueBiciPlan prep;
  var conflictosPrep = choques;
  if (huecos.isNotEmpty) {
    prep = BloqueBiciPlan(
      nombreId: 'preparar_bici',
      diaSemana: DateTime.friday,
      inicioMin: huecos.first.inicio,
      duracionMin: dur,
      recordarMin: 0,
    );
  } else {
    avisos.add(AvisoBloqueBici.sinHuecoViernes);
    final inicio = salida.inicioMin - reglas.preparacionSabadoAntesMin;
    prep = BloqueBiciPlan(
      nombreId: 'preparar_bici',
      diaSemana: DateTime.saturday,
      inicioMin: inicio,
      duracionMin: dur,
      recordarMin: 0,
    );
    conflictosPrep = conflictos(prep.intervalo, ocupadosSabado);
  }

  final choquesSalida = conflictos(salida.intervalo, ocupadosSabado);
  if (choquesSalida.isNotEmpty) avisos.add(AvisoBloqueBici.salidaChoca);

  return PlanBloquesBici(
    salida: salida,
    preparacion: prep,
    preparacionDeseadaMin: desde,
    avisos: avisos,
    conflictosPreparacion: conflictosPrep,
    conflictosSalida: choquesSalida,
  );
}

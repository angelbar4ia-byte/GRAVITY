/// Salida del generador: una sesión concreta, derivada al abrirla (PG-05).
/// **No lleva texto:** los avisos son códigos y el texto sale del catálogo de
/// mensajes (CA-G-40).
library;

import 'ciclos.dart';
import 'progresion.dart';
import 'registro.dart';
import 'reglas.dart';

enum CodigoAviso {
  sinEquipoSuficiente,
  slotOmitido,
  conPrecaucion,
  topeDePila,
  cercaDeDormir,
  modoFoco,
  contenidoEnRevision,
  descargaSugerida,
  molestiaFuerte,
  ofrecerRegenerativa,
  seguridadBanda,
  versionCortaSugerida,
}

enum RazonOmision { sinEquipo, precaucion }

class AvisoGimnasio {
  const AvisoGimnasio(this.codigo, {this.slotId, this.razon});
  final CodigoAviso codigo;
  final String? slotId;
  final RazonOmision? razon;

  @override
  String toString() => '${codigo.name}${slotId == null ? '' : '@$slotId'}';
}

/// Por qué una alternativa de «Cambiar ejercicio» (5.10).
enum MotivoAlternativa { masFacil, masDificil, sinAparato, conPrecaucion }

class AlternativaSlot {
  const AlternativaSlot(this.varianteId, this.motivo);
  final String varianteId;
  final MotivoAlternativa motivo;
}

/// Serie de aproximación del primer ejercicio (PG-20): no cuenta para el
/// volumen ni el récord.
class Aproximacion {
  const Aproximacion({required this.reps, this.cargaPasos});
  final int reps;
  final int? cargaPasos;
}

class EjercicioPlanificado {
  const EjercicioPlanificado({
    required this.slotId,
    required this.ejercicioId,
    required this.varianteId,
    required this.series,
    required this.rangoMin,
    required this.rangoMax,
    required this.objetivo,
    required this.porTiempo,
    required this.porLado,
    required this.descansoS,
    required this.tempoBajadaS,
    required this.motivo,
    this.cargaPasos,
    this.bandaId,
    this.bandaDoble = false,
    this.conPrecaucion = false,
    this.esExtra = false,
    this.topeDePila = false,
    this.alternativas = const [],
    this.aproximacion,
  });

  final String slotId;
  final String ejercicioId;
  final String varianteId;
  final int series;

  /// Rango de repeticiones, o de segundos si [porTiempo].
  final int rangoMin;
  final int rangoMax;
  final int objetivo;
  final bool porTiempo;
  final bool porLado;
  final int descansoS;
  final int tempoBajadaS;
  final MotivoProgresion motivo;

  /// Carga sugerida en pasos de la pila (PG-04); `null` si no hay historial.
  final int? cargaPasos;
  final String? bandaId;
  final bool bandaDoble;
  final bool conPrecaucion;
  final bool esExtra;
  final bool topeDePila;
  final List<AlternativaSlot> alternativas;
  final Aproximacion? aproximacion;

  String get tempo => '$tempoBajadaS-1-1';
}

/// Un slot que no se pudo ocupar, con lo que la persona puede elegir.
class SlotOmitido {
  const SlotOmitido(
    this.slotId,
    this.razon, {
    this.opcionesConPrecaucion = const [],
  });
  final String slotId;
  final RazonOmision razon;

  /// Variantes disponibles que cargan una zona marcada: la persona puede
  /// volver a elegir una (5.10).
  final List<String> opcionesConPrecaucion;
}

class SesionPlanificada {
  const SesionPlanificada({
    required this.plantillaId,
    required this.version,
    required this.semana,
    required this.ejercicios,
    required this.omitidos,
    required this.calentamientoMin,
    required this.cierreMin,
    required this.calentamiento,
    required this.cierre,
    required this.duracionEstimadaSeg,
    required this.avisos,
    required this.contenidoEnRevision,
    this.versionSugerida,
  });

  final String plantillaId;
  final VersionSesion version;
  final ParametrosSemana semana;
  final List<EjercicioPlanificado> ejercicios;
  final List<SlotOmitido> omitidos;
  final int calentamientoMin;
  final int cierreMin;

  /// Ids de bloques guiados (ya sustituidos si no hay caminadora).
  final List<String> calentamiento;
  final List<String> cierre;
  final int duracionEstimadaSeg;
  final List<AvisoGimnasio> avisos;

  /// La sesión dice «Contenido en revisión» (PG-25, CA-G-05).
  final bool contenidoEnRevision;
  final VersionSesion? versionSugerida;

  TipoSemana get semanaTipo => semana.tipo;

  bool tiene(CodigoAviso c) => avisos.any((a) => a.codigo == c);

  /// Lo planeado, tal como se guarda en la sesión (4.2, `plan`): sin
  /// precauciones ni zonas.
  List<PlanEjercicioGuardado> aResumenPlan() => [
    for (final e in ejercicios)
      PlanEjercicioGuardado(
        ejercicioId: e.ejercicioId,
        varianteId: e.varianteId,
        series: e.series,
        repsMin: e.porTiempo ? null : e.rangoMin,
        repsMax: e.porTiempo ? null : e.rangoMax,
      ),
  ];
}

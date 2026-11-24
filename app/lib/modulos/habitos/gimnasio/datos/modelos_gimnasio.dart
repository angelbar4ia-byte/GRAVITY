/// Lo que las pantallas de «Mi gimnasio» leen: datos ya calculados con el
/// dominio (nada se guarda calculado: R4).
library;

import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../../nucleo/base_local/base_local.dart';
import '../../datos/modelos_agenda.dart';

/// Cómo va el entrenamiento de un día.
enum EstadoEntrenamientoDia { pendiente, enCurso, hecho, parcial }

/// Un día del plan de la semana tal como se guardó.
class DiaDelPlan {
  const DiaDelPlan({
    required this.diaSemana,
    required this.tipo,
    this.version = 'auto',
    this.horaMin,
  });

  /// 1 (lunes) a 7 (domingo).
  final int diaSemana;

  /// `A`, `B`, `C`, `R1`, `R2`, `bici` o `descanso`.
  final String tipo;

  /// `auto`, `corta`, `estandar` o `larga`.
  final String version;
  final int? horaMin;

  bool get esFuerza => TipoDia.fuerza.contains(tipo);
  bool get esRegenerativa => tipo == TipoDia.r1 || tipo == TipoDia.r2;
  bool get esSesion => esFuerza || esRegenerativa;
}

/// Todo lo del equipo y del historial de la persona, ya en tipos del dominio.
class DatosGimnasio {
  const DatosGimnasio({
    required this.persona,
    required this.perfilFila,
    required this.perfil,
    required this.inventarioFilas,
    required this.bandasFilas,
    required this.inventario,
    required this.dias,
    required this.sesionesFilas,
    required this.seriesFilas,
    required this.historial,
    required this.enCurso,
  });

  final String persona;
  final GimPerfilFila? perfilFila;
  final PerfilGimnasio perfil;
  final List<GimInventarioFila> inventarioFilas;
  final List<GimBandaFila> bandasFilas;
  final Inventario inventario;

  /// Siete días, lunes a domingo.
  final List<DiaDelPlan> dias;
  final List<GimSesionFila> sesionesFilas;
  final List<GimSerieFila> seriesFilas;

  /// Sesiones terminadas, de la más antigua a la más nueva.
  final List<SesionRegistrada> historial;

  /// La sesión que quedó `en_curso` (para retomarla), si la hay.
  final GimSesionFila? enCurso;

  /// ¿La persona ya vio y aceptó «guía general»? (1.2)
  bool get avisoVisto => perfilFila?.avisoVistoEn != null;

  /// ¿Ya empezó el plan (hay lunes de inicio)?
  bool get planIniciado => perfilFila?.inicioCiclo != null;

  DiaDelPlan dia(int diaSemana) => dias[diaSemana - 1];

  PlanSemana get plan => PlanSemana({for (final d in dias) d.diaSemana: d.tipo});
}

/// Una sesión **de hoy** (o de otro día) lista para mostrar y empezar.
class EntrenamientoHoy {
  const EntrenamientoHoy({
    required this.fecha,
    required this.tipo,
    required this.estado,
    this.sesion,
    this.regenerativa,
    this.eleccion,
    this.version,
    this.inicioMin,
    this.horaDelPlan = false,
    this.avisoDormir,
    this.noCabe = false,
    this.bloque,
    this.filaSesion,
    this.molestiasLegibles = true,
    this.modoFocoLegible = true,
    this.modoFoco = false,
    this.agendaSinLeer = false,
  });

  final DateTime fecha;

  /// `A`, `B`, `C`, `R1`, `R2`, `bici` o `descanso`.
  final String tipo;
  final EstadoEntrenamientoDia estado;
  final SesionPlanificada? sesion;
  final SesionRegenerativa? regenerativa;
  final EleccionVersion? eleccion;
  final VersionSesion? version;

  /// Hora de inicio (minutos desde la medianoche): la del plan o la propuesta
  /// con el hueco de la agenda.
  final int? inicioMin;
  final bool horaDelPlan;
  final AvisoDormir? avisoDormir;

  /// Ninguna versión cabe en el hueco (5.5): se propone mover o la regenerativa.
  final bool noCabe;

  /// El bloque de la agenda de ese día, si el plan ya está en la agenda.
  final BloqueHab? bloque;

  /// La fila de la sesión de ese día y plantilla, si ya existe.
  final GimSesionFila? filaSesion;

  /// ¿Las molestias de este equipo se pudieron leer? (4.3)
  final bool molestiasLegibles;
  final bool modoFocoLegible;
  final bool modoFoco;

  /// La agenda de Hábitos no se pudo leer (sin señal): la hora y el hueco son
  /// aproximados, con el plan y el equipo de este equipo (G6-A1).
  final bool agendaSinLeer;

  bool get esFuerza => TipoDia.fuerza.contains(tipo);
  bool get esRegenerativa => tipo == TipoDia.r1 || tipo == TipoDia.r2;
  bool get esSesion => esFuerza || esRegenerativa;
  bool get contenidoEnRevision =>
      sesion?.contenidoEnRevision ?? regenerativa?.contenidoEnRevision ?? false;

  int? get duracionSeg => sesion?.duracionEstimadaSeg ??
      (regenerativa == null ? null : regenerativa!.minutos * 60);

  TipoSemana get semanaTipo => sesion?.semanaTipo ?? TipoSemana.carga;
}

/// Resultado de terminar una sesión.
class ResultadoSesion {
  const ResultadoSesion({
    required this.records,
    required this.estado,
    this.enviarDespues = false,
  });

  final List<RecordNuevo> records;
  final EstadoSesion estado;

  /// La sesión quedó guardada en este equipo, pero el registro del día en
  /// Hábitos no se pudo escribir en la nube (sin señal): queda en la cola y se
  /// envía al volver (G6-A1).
  final bool enviarDespues;
}

/// Resultado de poner el plan en la agenda.
class ResultadoAgenda {
  const ResultadoAgenda({required this.bloques, required this.conflictos});

  final int bloques;

  /// Días (1 a 7) donde el bloque se cruza con otro: avisa, no impide guardar.
  final List<int> conflictos;
}

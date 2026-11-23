/// Lo que se hizo: sesiones y series (4.2). Hechos que se guardan; todo lo
/// demás (récords, ciclo, carga sugerida) se calcula.
///
/// **Nada de este archivo lleva molestias, zonas, precauciones ni dolor:** los
/// tipos que se serializan al servidor no tienen ese campo (PG-03, PG-19).
library;

import 'reglas.dart';

/// Motivo de un cambio de ejercicio **como lo guarda el servidor**: no existe
/// «molestia» (PG-19, CA-G-27).
enum MotivoCambio {
  noDisponible('no_disponible'),
  preferencia('preferencia'),
  otra('otra');

  const MotivoCambio(this.id);
  final String id;
}

/// Motivo de un cambio como lo vive la persona en su equipo. Solo [paraServidor]
/// sale del dispositivo, y «molestia» se vuelve `otra`.
enum MotivoCambioLocal {
  noDisponible,
  preferencia,
  molestia,
  otra;

  MotivoCambio get paraServidor => switch (this) {
    MotivoCambioLocal.noDisponible => MotivoCambio.noDisponible,
    MotivoCambioLocal.preferencia => MotivoCambio.preferencia,
    MotivoCambioLocal.molestia => MotivoCambio.otra,
    MotivoCambioLocal.otra => MotivoCambio.otra,
  };
}

enum EstadoSesion {
  enCurso('en_curso'),
  completa('completa'),
  parcial('parcial');

  const EstadoSesion(this.id);
  final String id;
}

/// Tipo de semana en que se hizo la sesión (4.2, `semana_tipo`).
enum TipoSemana {
  carga('carga'),
  descarga('descarga'),
  reentrada('reentrada'),
  foco('foco');

  const TipoSemana(this.id);
  final String id;
}

/// Una serie hecha (4.2, `hab_ent_series`).
class SerieRegistrada {
  const SerieRegistrada({
    required this.ejercicioId,
    required this.varianteId,
    required this.n,
    this.lado,
    this.reps,
    this.segundos,
    this.cargaPasos,
    this.bandaId,
    this.bandaDoble = false,
    this.esfuerzo,
    this.descansoRealS,
    this.sustituyeA,
    this.motivoCambio,
  });

  final String ejercicioId;
  final String varianteId;
  final int n;

  /// `izquierdo`, `derecho` o `null`.
  final String? lado;
  final int? reps;
  final int? segundos;

  /// Carga en pasos de la pila (PG-04).
  final int? cargaPasos;
  final String? bandaId;

  /// Dos bandas iguales juntas (5.4); solo para la progresión, no se guarda.
  final bool bandaDoble;
  final int? esfuerzo;
  final int? descansoRealS;
  final String? sustituyeA;
  final MotivoCambio? motivoCambio;

  /// Fila del servidor, solo con las columnas de 4.2 (sin molestias).
  Map<String, Object?> aJsonServidor({
    required String id,
    required String sesionId,
  }) => {
    'id': id,
    'sesion_id': sesionId,
    'ejercicio_id': ejercicioId,
    'variante_id': varianteId,
    'n': n,
    'lado': lado,
    'reps': reps,
    'segundos': segundos,
    'carga_pasos': cargaPasos,
    'banda_id': bandaId,
    'esfuerzo': esfuerzo,
    'descanso_real_s': descansoRealS,
    'sustituye_a': sustituyeA,
    'motivo_cambio': motivoCambio?.id,
  };
}

/// Una línea de lo planeado, tal como se planeó (4.2, `plan`).
class PlanEjercicioGuardado {
  const PlanEjercicioGuardado({
    required this.ejercicioId,
    required this.varianteId,
    required this.series,
    this.repsMin,
    this.repsMax,
  });

  final String ejercicioId;
  final String varianteId;
  final int series;
  final int? repsMin;
  final int? repsMax;

  Map<String, Object?> aJson() => {
    'ejercicio': ejercicioId,
    'variante': varianteId,
    'series': series,
    'reps_min': repsMin,
    'reps_max': repsMax,
  };
}

/// Tiempos medidos por la app en una sesión (solo local; calibran 5.5).
class TiemposMedidos {
  const TiemposMedidos({
    required this.segundosPorRepeticion,
    required this.segundosCambio,
  });
  final int segundosPorRepeticion;
  final int segundosCambio;
}

/// Una sesión hecha (4.2, `hab_ent_sesiones`).
class SesionRegistrada {
  const SesionRegistrada({
    required this.fecha,
    required this.plantilla,
    required this.version,
    this.semanaTipo = TipoSemana.carga,
    this.ventana,
    this.inicio,
    this.fin,
    this.estado = EstadoSesion.completa,
    this.esfuerzo,
    this.energia,
    this.plan = const [],
    this.series = const [],
    this.catalogoVersion = 1,
    this.tiempos,
  });

  final DateTime fecha;

  /// `A`, `B`, `C`, `R1` o `R2`.
  final String plantilla;
  final VersionSesion version;
  final TipoSemana semanaTipo;
  final VentanaEntrenamiento? ventana;
  final DateTime? inicio;
  final DateTime? fin;
  final EstadoSesion estado;
  final int? esfuerzo;
  final int? energia;
  final List<PlanEjercicioGuardado> plan;
  final List<SerieRegistrada> series;
  final int catalogoVersion;

  /// Solo local: calibra el modelo de tiempo; nunca se serializa.
  final TiemposMedidos? tiempos;

  bool get esDeFuerza =>
      plantilla == 'A' || plantilla == 'B' || plantilla == 'C';

  /// ¿Cuenta como hecha? (no `en_curso`).
  bool get terminada => estado != EstadoSesion.enCurso;

  /// Fila del servidor, solo con las columnas de 4.2 (sin molestias).
  Map<String, Object?> aJsonServidor({required String id, String? bloqueId}) =>
      {
        'id': id,
        'fecha':
            '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}',
        'plantilla': plantilla,
        'version': version.id,
        'semana_tipo': semanaTipo.id,
        'ventana': ventana == null || ventana == VentanaEntrenamiento.flexible
            ? null
            : ventana!.id,
        'bloque_id': bloqueId,
        'inicio': inicio?.toIso8601String(),
        'fin': fin?.toIso8601String(),
        'estado': estado.id,
        'esfuerzo': esfuerzo,
        'energia': energia,
        'plan': [for (final p in plan) p.aJson()],
        'catalogo_version': catalogoVersion,
      };
}

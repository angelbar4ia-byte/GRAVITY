/// Dónde se guardan las respuestas y declaraciones de las fugas silenciosas y
/// de la deuda buena o mala (Fase 8, bloque 6; `docs/specs/fase-8-fugas-y-
/// deudas.md`, secciones 6 y 8; migración `20261146000000_finanzas_fugas_
/// deudas.sql`).
///
/// Dos versiones detrás de la misma interfaz, como en la dispersión de
/// ingresos:
/// - [RepositorioFugasEnMemoria]: pruebas y modo demostración. Imita al
///   servidor: todo es **solo agregar** (lo vigente es la fila que ninguna otra
///   reemplaza) y las RPC son idempotentes por id.
/// - `RepositorioFugasSupabase` (`repositorio_fugas_supabase.dart`): lee las
///   vistas `fin_v_*` y escribe **solo por RPC**. Ninguna escritura va por la
///   cola sin conexión: necesitan señal (lanzan `ErrorFinanzas` con
///   `sinConexion`), igual que la dispersión.
///
/// Las fugas calculadas **no se guardan**: se derivan del libro en el
/// dispositivo ([analizarFugas]); aquí solo vive lo que la persona dijo. Nada
/// de esto va a la IA en la nube ni a las bocinas (D3, D6).
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';

// ====================================================== lo que se guarda

/// Un patrón de cobro con su estado derivado (`fin_patrones_cobro` más
/// `fin_v_patrones_estado`).
class PatronRegistrado {
  const PatronRegistrado({
    required this.id,
    required this.libroId,
    required this.clave,
    required this.cadencia,
    this.comercioNorm,
    this.categoriaId,
    this.compromisoId,
    this.automatico = false,
    this.origen = 'detectado',
    this.protegido = false,
    this.vigilar = false,
    this.canceladoEn,
    this.folio,
    this.canceladoSinFolio = false,
  });

  final String id;
  final String libroId;
  final String clave;
  final String? comercioNorm;
  final String? categoriaId;
  final String? compromisoId;
  final CadenciaCobro cadencia;
  final bool automatico;
  final String origen;

  /// «No es una fuga» de la persona: el patrón queda protegido.
  final bool protegido;

  /// «Lo necesito pero lo quiero revisar».
  final bool vigilar;
  final Fecha? canceladoEn;
  final String? folio;
  final bool canceladoSinFolio;

  PatronRegistrado conEstado({
    bool? protegido,
    bool? vigilar,
    Fecha? canceladoEn,
    String? folio,
    bool? canceladoSinFolio,
    bool sinCancelacion = false,
  }) => PatronRegistrado(
    id: id,
    libroId: libroId,
    clave: clave,
    cadencia: cadencia,
    comercioNorm: comercioNorm,
    categoriaId: categoriaId,
    compromisoId: compromisoId,
    automatico: automatico,
    origen: origen,
    protegido: protegido ?? this.protegido,
    vigilar: vigilar ?? this.vigilar,
    canceladoEn: sinCancelacion ? null : (canceladoEn ?? this.canceladoEn),
    folio: sinCancelacion ? null : (folio ?? this.folio),
    canceladoSinFolio: sinCancelacion
        ? false
        : (canceladoSinFolio ?? this.canceladoSinFolio),
  );
}

/// Una clasificación **de la persona** (`fin_fuga_clasificaciones`, vigente).
class ClasificacionRegistrada {
  const ClasificacionRegistrada({
    required this.id,
    required this.libroId,
    required this.patronId,
    required this.fuga,
    required this.decididaEn,
    this.origen = OrigenFuga.persona,
    this.regla,
    this.fugaRegla,
    this.vigilar = false,
    this.montoAlDecidirCentavos,
    this.reemplazaA,
    this.motivo,
  });

  final String id;
  final String libroId;
  final String patronId;
  final TipoFuga fuga;
  final OrigenFuga origen;
  final String? regla;

  /// Lo que dijo la regla cuando la persona decidió (para saber si la
  /// contradijo).
  final TipoFuga? fugaRegla;
  final bool vigilar;
  final int? montoAlDecidirCentavos;
  final String? reemplazaA;
  final String? motivo;
  final DateTime decididaEn;
}

/// Una respuesta de la persona (`fin_fuga_respuestas`, vigente).
class RespuestaRegistrada {
  const RespuestaRegistrada({
    required this.id,
    required this.libroId,
    required this.patronId,
    required this.pregunta,
    required this.respuesta,
    required this.periodoLunes,
    required this.registradoEn,
    this.fechaCancelacion,
    this.folio,
    this.reemplazaA,
  });

  final String id;
  final String libroId;
  final String patronId;
  final PreguntaFuga pregunta;
  final RespuestaPersona respuesta;
  final Fecha? fechaCancelacion;
  final String? folio;
  final Fecha periodoLunes;
  final String? reemplazaA;
  final DateTime registradoEn;
}

/// La declaración vigente de una deuda (`fin_deuda_propositos`).
class PropositoRegistrado {
  const PropositoRegistrado({
    required this.id,
    required this.libroId,
    required this.deudaId,
    required this.declaracion,
    required this.declaradoEn,
    this.precioContadoCentavos,
  });

  final String id;
  final String libroId;
  final String deudaId;
  final DeclaracionDeuda declaracion;

  /// Lo que habría costado de contado (corrige el de `fin_msi`).
  final int? precioContadoCentavos;
  final DateTime declaradoEn;
}

/// El último nivel registrado de una deuda (`fin_v_deuda_semaforo_actual`).
class SemaforoRegistrado {
  const SemaforoRegistrado({
    required this.libroId,
    required this.deudaId,
    required this.lunes,
    required this.nivel,
    required this.calculadoEn,
    this.senales = const [],
    this.bajasSeguidas = 0,
  });

  final String libroId;
  final String deudaId;
  final Fecha lunes;

  /// `verde`, `ambar`, `rojo` o `gris`.
  final String nivel;
  final List<String> senales;
  final int bajasSeguidas;
  final DateTime calculadoEn;
}

/// Todo lo guardado, de todos los libros que la persona ve.
class DatosFugas {
  const DatosFugas({
    this.patrones = const [],
    this.clasificaciones = const [],
    this.respuestas = const [],
    this.propositos = const [],
    this.semaforos = const [],
    this.parametros = const {},
    this.pagosAlCorte = const {},
  });

  static const DatosFugas vacio = DatosFugas();

  final List<PatronRegistrado> patrones;
  final List<ClasificacionRegistrada> clasificaciones;
  final List<RespuestaRegistrada> respuestas;
  final List<PropositoRegistrado> propositos;
  final List<SemaforoRegistrado> semaforos;

  /// Umbrales por libro (`fin_v_fuga_parametros_vigentes`); sin fila, los de
  /// omisión.
  final Map<String, ParametrosFugas> parametros;

  /// Pagos hechos al corte por id de estado de cuenta (`null` = nadie los
  /// capturó: «sin dato», no «pagó cero»).
  final Map<String, int?> pagosAlCorte;

  PatronRegistrado? patronDeClave(String libroId, String clave) {
    for (final p in patrones) {
      if (p.libroId == libroId && p.clave == clave) return p;
    }
    return null;
  }

  PatronRegistrado? patron(String id) {
    for (final p in patrones) {
      if (p.id == id) return p;
    }
    return null;
  }

  ParametrosFugas parametrosDe(String libroId) =>
      parametros[libroId] ?? ParametrosFugas.porDefecto;

  SemaforoRegistrado? semaforoDe(String deudaId) {
    for (final s in semaforos) {
      if (s.deudaId == deudaId) return s;
    }
    return null;
  }

  PropositoRegistrado? propositoDe(String deudaId) {
    for (final p in propositos) {
      if (p.deudaId == deudaId) return p;
    }
    return null;
  }

  DatosFugas copiar({
    List<PatronRegistrado>? patrones,
    List<ClasificacionRegistrada>? clasificaciones,
    List<RespuestaRegistrada>? respuestas,
    List<PropositoRegistrado>? propositos,
    List<SemaforoRegistrado>? semaforos,
    Map<String, ParametrosFugas>? parametros,
    Map<String, int?>? pagosAlCorte,
  }) => DatosFugas(
    patrones: patrones ?? this.patrones,
    clasificaciones: clasificaciones ?? this.clasificaciones,
    respuestas: respuestas ?? this.respuestas,
    propositos: propositos ?? this.propositos,
    semaforos: semaforos ?? this.semaforos,
    parametros: parametros ?? this.parametros,
    pagosAlCorte: pagosAlCorte ?? this.pagosAlCorte,
  );
}

// ============================================================ interfaz

abstract interface class RepositorioFugas {
  /// Lo guardado ahora.
  DatosFugas get actuales;

  /// Avisa cada vez que cambian [actuales].
  Stream<DatosFugas> get cambios;

  /// Vuelve a pedir todo al servidor (la versión en memoria no hace nada).
  /// Sin señal lanza `ErrorFinanzas` y deja lo que ya había.
  Future<void> cargar();

  /// Crea (o devuelve) un patrón de cobro. **Idempotente** por id y por
  /// `(libro, clave)`: devuelve el id del patrón que quedó.
  Future<String> crearPatron({
    required String id,
    required String libroId,
    required String clave,
    required CadenciaCobro cadencia,
    required bool automatico,
    String? comercioNorm,
    String? categoriaId,
    String? compromisoId,
    String origen = 'detectado',
  });

  /// Agrega una respuesta («¿Lo reconoces?», «¿Lo usaste?», «Ya no me sirve»…).
  /// En el libro de Papá lleva [motivo] (la decisión va «en nombre de» él).
  Future<void> responder({
    required String id,
    required String patronId,
    required PreguntaFuga pregunta,
    required RespuestaPersona respuesta,
    required Fecha periodoLunes,
    String? motivo,
  });

  /// Agrega una clasificación de la persona (reemplaza a la vigente).
  /// [fugaRegla] es lo que dijo la regla; si la decisión la contradice, el
  /// [motivo] es obligatorio (3 a 200 caracteres).
  Future<void> clasificar({
    required String id,
    required String patronId,
    required TipoFuga fuga,
    required TipoFuga fugaRegla,
    String? motivo,
    String? regla,
    bool vigilar = false,
    int? montoCentavos,
  });

  /// Registra la cancelación de un patrón: [fecha] y [folio] (sin folio =
  /// «cancelado sin folio»).
  Future<void> cancelar({
    required String id,
    required String patronId,
    required Fecha fecha,
    String? folio,
    String? motivo,
  });

  /// Declara el propósito de una deuda (vale la más reciente).
  Future<void> declararProposito({
    required String id,
    required String libroId,
    required String deudaId,
    required DeclaracionDeuda declaracion,
    int? precioContadoCentavos,
    String? motivo,
  });

  /// Registra el nivel de una deuda solo si cambió. Devuelve `true` si agregó
  /// una fila.
  Future<bool> registrarSemaforo({
    required String id,
    required String libroId,
    required String deudaId,
    required Fecha lunes,
    required String nivel,
    List<String> senales = const [],
    int bajasSeguidas = 0,
    DateTime? calculadoEn,
  });

  /// Cambia los umbrales del libro (fila nueva; vale la más reciente).
  Future<void> cambiarParametros(
    String libroId,
    ParametrosFugas parametros, {
    String? motivo,
  });
}

// ============================================================ conversión

/// Códigos de `fin_fuga_respuestas.pregunta`.
String preguntaFugaClave(PreguntaFuga p) => switch (p) {
  PreguntaFuga.reconoce => 'reconoce',
  PreguntaFuga.uso => 'uso',
  PreguntaFuga.yaNoSirve => 'ya_no_sirve',
  PreguntaFuga.yaNoExiste => 'ya_no_existe',
  PreguntaFuga.yaNoLaQuiero => 'ya_no_la_quiero',
  PreguntaFuga.duplicado => 'duplicado',
  PreguntaFuga.planViejo => 'plan_viejo',
  PreguntaFuga.cancelado => 'cancelado',
  PreguntaFuga.temporada => 'temporada',
};

PreguntaFuga? preguntaFugaDeClave(Object? v) {
  for (final p in PreguntaFuga.values) {
    if (preguntaFugaClave(p) == '$v') return p;
  }
  return null;
}

/// Códigos de `proposito` (`bien_duradero`...).
String propositoClave(PropositoDeuda p) => switch (p) {
  PropositoDeuda.bienDuradero => 'bien_duradero',
  PropositoDeuda.generaIngreso => 'genera_ingreso',
  PropositoDeuda.patrimonio => 'patrimonio',
  PropositoDeuda.educacionOSalud => 'educacion_o_salud',
  PropositoDeuda.emergencia => 'emergencia',
  PropositoDeuda.consumo => 'consumo',
};

PropositoDeuda? propositoDeClave(Object? v) {
  for (final p in PropositoDeuda.values) {
    if (propositoClave(p) == '$v') return p;
  }
  return null;
}

/// Códigos de `estado_objetivo`.
String estadoObjetivoClave(EstadoObjetivo e) => switch (e) {
  EstadoObjetivo.vigente => 'vigente',
  EstadoObjetivo.cumplido => 'cumplido',
  EstadoObjetivo.yaNoExiste => 'ya_no_existe',
  EstadoObjetivo.cambio => 'cambio',
};

EstadoObjetivo? estadoObjetivoDeClave(Object? v) {
  for (final e in EstadoObjetivo.values) {
    if (estadoObjetivoClave(e) == '$v') return e;
  }
  return null;
}

/// Nivel guardado de un estado de calidad (`fin_deuda_semaforo.nivel`);
/// `null` si no se registra («sin costo», «liquidada»).
String? nivelDeEstado(EstadoCalidad e) => switch (e) {
  EstadoCalidad.buena => 'verde',
  EstadoCalidad.enVigilancia => 'ambar',
  EstadoCalidad.seVolvioMala => 'rojo',
  EstadoCalidad.porDeclarar => 'gris',
  EstadoCalidad.sinCosto || EstadoCalidad.liquidada => null,
};

EstadoCalidad? estadoDeNivel(String nivel) => switch (nivel) {
  'verde' => EstadoCalidad.buena,
  'ambar' => EstadoCalidad.enVigilancia,
  'rojo' => EstadoCalidad.seVolvioMala,
  'gris' => EstadoCalidad.porDeclarar,
  _ => null,
};

// ============================================================ en memoria

/// Versión en memoria (pruebas y demostración): imita las reglas del
/// servidor (solo agregar, idempotente por id).
class RepositorioFugasEnMemoria implements RepositorioFugas {
  RepositorioFugasEnMemoria({
    DateTime Function()? reloj,
    Map<String, ParametrosFugas> parametros = const {},
  }) : _reloj = reloj ?? DateTime.now,
       _parametros = {...parametros};

  final DateTime Function() _reloj;
  final Map<String, ParametrosFugas> _parametros;
  final _patrones = <PatronRegistrado>[];
  final _clasificaciones = <ClasificacionRegistrada>[];
  final _respuestas = <RespuestaRegistrada>[];
  final _propositos = <PropositoRegistrado>[];
  final _semaforos = <SemaforoRegistrado>[];
  final _cambios = StreamController<DatosFugas>.broadcast();

  /// Cuántas escrituras se hicieron (para las pruebas).
  int escrituras = 0;

  /// Los ids ya guardados por tipo de objeto (idempotencia).
  final _ids = <String>{};

  /// Simula una caída de señal: toda escritura lanza.
  Object? falla;

  @override
  DatosFugas get actuales => DatosFugas(
    patrones: [for (final p in _patrones) _conEstado(p)],
    clasificaciones: _vigentesClasificaciones(),
    respuestas: _vigentesRespuestas(),
    propositos: _vigentesPropositos(),
    semaforos: _ultimosSemaforos(),
    parametros: Map.unmodifiable(_parametros),
  );

  @override
  Stream<DatosFugas> get cambios => _cambios.stream;

  void _avisar() => _cambios.add(actuales);

  void _escribir() {
    final f = falla;
    if (f != null) throw f;
    escrituras++;
  }

  @override
  Future<void> cargar() async {}

  // ------------------------------------------------------- lo vigente

  List<ClasificacionRegistrada> _vigentesClasificaciones() {
    final reemplazadas = {
      for (final c in _clasificaciones)
        if (c.reemplazaA != null) c.reemplazaA!,
    };
    return [
      for (final c in _clasificaciones)
        if (!reemplazadas.contains(c.id)) c,
    ];
  }

  List<RespuestaRegistrada> _vigentesRespuestas() {
    final reemplazadas = {
      for (final r in _respuestas)
        if (r.reemplazaA != null) r.reemplazaA!,
    };
    return [
      for (final r in _respuestas)
        if (!reemplazadas.contains(r.id)) r,
    ];
  }

  List<PropositoRegistrado> _vigentesPropositos() {
    final porDeuda = <String, PropositoRegistrado>{};
    for (final p in _propositos) {
      porDeuda[p.deudaId] = p;
    }
    return porDeuda.values.toList();
  }

  List<SemaforoRegistrado> _ultimosSemaforos() {
    final porDeuda = <String, SemaforoRegistrado>{};
    for (final s in _semaforos) {
      porDeuda[s.deudaId] = s;
    }
    return porDeuda.values.toList();
  }

  /// El estado derivado del patrón (la vista `fin_v_patrones_estado`).
  PatronRegistrado _conEstado(PatronRegistrado p) {
    final clas = _vigentesClasificaciones()
        .where((c) => c.patronId == p.id)
        .firstOrNull;
    final canc = _vigentesRespuestas()
        .where(
          (r) => r.patronId == p.id && r.pregunta == PreguntaFuga.cancelado,
        )
        .firstOrNull;
    return p.conEstado(
      protegido:
          clas != null &&
          clas.origen == OrigenFuga.persona &&
          clas.fuga == TipoFuga.ninguna &&
          !clas.vigilar,
      vigilar: clas?.vigilar ?? false,
      canceladoEn: canc?.fechaCancelacion,
      folio: canc?.folio,
      canceladoSinFolio:
          canc?.fechaCancelacion != null &&
          (canc?.folio == null || canc!.folio!.isEmpty),
      sinCancelacion: canc == null,
    );
  }

  // ---------------------------------------------------------- escribir

  @override
  Future<String> crearPatron({
    required String id,
    required String libroId,
    required String clave,
    required CadenciaCobro cadencia,
    required bool automatico,
    String? comercioNorm,
    String? categoriaId,
    String? compromisoId,
    String origen = 'detectado',
  }) async {
    _escribir();
    final existente = _patrones.where((p) => p.id == id).firstOrNull;
    if (existente != null) {
      if (existente.libroId != libroId || existente.clave != clave) {
        throw StateError('Ese id ya es de otro patrón.');
      }
      return existente.id;
    }
    final porClave = _patrones
        .where((p) => p.libroId == libroId && p.clave == clave)
        .firstOrNull;
    if (porClave != null) return porClave.id;
    _patrones.add(
      PatronRegistrado(
        id: id,
        libroId: libroId,
        clave: clave,
        cadencia: cadencia,
        automatico: automatico,
        comercioNorm: comercioNorm,
        categoriaId: categoriaId,
        compromisoId: compromisoId,
        origen: origen,
      ),
    );
    _avisar();
    return id;
  }

  PatronRegistrado _patron(String id) =>
      _patrones.where((p) => p.id == id).firstOrNull ??
      (throw StateError('No existe ese patrón.'));

  @override
  Future<void> responder({
    required String id,
    required String patronId,
    required PreguntaFuga pregunta,
    required RespuestaPersona respuesta,
    required Fecha periodoLunes,
    String? motivo,
  }) async {
    _escribir();
    final p = _patron(patronId);
    if (_ids.contains(id)) return;
    final vigente = _vigentesRespuestas()
        .where(
          (r) =>
              r.patronId == patronId &&
              r.pregunta == pregunta &&
              r.periodoLunes == periodoLunes,
        )
        .firstOrNull;
    if (vigente != null && vigente.respuesta == respuesta) return;
    _ids.add(id);
    _respuestas.add(
      RespuestaRegistrada(
        id: id,
        libroId: p.libroId,
        patronId: patronId,
        pregunta: pregunta,
        respuesta: respuesta,
        periodoLunes: periodoLunes,
        reemplazaA: vigente?.id,
        registradoEn: _reloj(),
      ),
    );
    _avisar();
  }

  @override
  Future<void> clasificar({
    required String id,
    required String patronId,
    required TipoFuga fuga,
    required TipoFuga fugaRegla,
    String? motivo,
    String? regla,
    bool vigilar = false,
    int? montoCentavos,
  }) async {
    _escribir();
    final p = _patron(patronId);
    if (_ids.contains(id)) return;
    final vigente = _vigentesClasificaciones()
        .where((c) => c.patronId == patronId)
        .firstOrNull;
    if (vigente != null &&
        vigente.origen == OrigenFuga.persona &&
        vigente.fuga == fuga &&
        vigente.vigilar == vigilar &&
        vigente.fugaRegla == fugaRegla) {
      return;
    }
    _ids.add(id);
    _clasificaciones.add(
      ClasificacionRegistrada(
        id: id,
        libroId: p.libroId,
        patronId: patronId,
        fuga: fuga,
        fugaRegla: fugaRegla,
        regla: regla,
        vigilar: vigilar,
        montoAlDecidirCentavos: montoCentavos,
        reemplazaA: vigente?.id,
        motivo: motivo,
        decididaEn: _reloj(),
      ),
    );
    _avisar();
  }

  @override
  Future<void> cancelar({
    required String id,
    required String patronId,
    required Fecha fecha,
    String? folio,
    String? motivo,
  }) async {
    _escribir();
    final p = _patron(patronId);
    if (_ids.contains(id)) return;
    final vigente = _vigentesRespuestas()
        .where(
          (r) => r.patronId == patronId && r.pregunta == PreguntaFuga.cancelado,
        )
        .firstOrNull;
    _ids.add(id);
    _respuestas.add(
      RespuestaRegistrada(
        id: id,
        libroId: p.libroId,
        patronId: patronId,
        pregunta: PreguntaFuga.cancelado,
        respuesta: RespuestaPersona.si,
        fechaCancelacion: fecha,
        folio: (folio == null || folio.trim().isEmpty) ? null : folio.trim(),
        periodoLunes: Semana.de(Fecha.deDateTime(_reloj())).inicio,
        reemplazaA: vigente?.id,
        registradoEn: _reloj(),
      ),
    );
    _avisar();
  }

  @override
  Future<void> declararProposito({
    required String id,
    required String libroId,
    required String deudaId,
    required DeclaracionDeuda declaracion,
    int? precioContadoCentavos,
    String? motivo,
  }) async {
    _escribir();
    if (_ids.contains(id)) return;
    _ids.add(id);
    _propositos.add(
      PropositoRegistrado(
        id: id,
        libroId: libroId,
        deudaId: deudaId,
        declaracion: declaracion,
        precioContadoCentavos: precioContadoCentavos,
        declaradoEn: _reloj(),
      ),
    );
    _avisar();
  }

  @override
  Future<bool> registrarSemaforo({
    required String id,
    required String libroId,
    required String deudaId,
    required Fecha lunes,
    required String nivel,
    List<String> senales = const [],
    int bajasSeguidas = 0,
    DateTime? calculadoEn,
  }) async {
    _escribir();
    if (_ids.contains(id)) return false;
    final ultimo = _ultimosSemaforos()
        .where((s) => s.deudaId == deudaId)
        .firstOrNull;
    if (ultimo != null &&
        ultimo.nivel == nivel &&
        ultimo.bajasSeguidas == bajasSeguidas) {
      return false;
    }
    _ids.add(id);
    _semaforos.add(
      SemaforoRegistrado(
        libroId: libroId,
        deudaId: deudaId,
        lunes: lunes,
        nivel: nivel,
        senales: senales,
        bajasSeguidas: bajasSeguidas,
        calculadoEn: calculadoEn ?? _reloj(),
      ),
    );
    _avisar();
    return true;
  }

  @override
  Future<void> cambiarParametros(
    String libroId,
    ParametrosFugas parametros, {
    String? motivo,
  }) async {
    _escribir();
    _parametros[libroId] = parametros;
    _avisar();
  }

  Future<void> cerrar() => _cambios.close();
}

import 'fecha.dart';
import 'presupuesto.dart';
import 'semana.dart';

/// Lo que se guarda del presupuesto semanal (`fin_semanas`,
/// `fin_partidas_semana`, `fin_abonos_semana`, `fin_cierres` y sus renglones,
/// `fin_ocurrencias`, `fin_conciliaciones` y `fin_importaciones`).

/// Estados de la semana (5.6 bis, punto 8; 5.9 bis, punto 4).
enum EstadoSemana { borrador, activa, pendienteIngreso, porCerrar, cerrada }

/// De dónde sale una partida de la semana.
enum OrigenPartida { compromiso, sobre }

/// Una partida de la semana activada (`fin_partidas_semana`). `asignado` ya va
/// repartido por mayor resto (R2).
class PartidaSemana {
  final String id;
  final String semanaId;
  final OrigenPartida origen;
  final String origenId;
  final String? cuentaGastoId;
  final TipoPartida tipo;
  final int asignado;
  final int arrastreRecibido;
  final bool protegida;
  final Prioridad prioridad;
  final int pisoMinimo;
  final ModoArrastre modoArrastre;

  const PartidaSemana({
    required this.id,
    required this.semanaId,
    required this.origen,
    required this.origenId,
    this.cuentaGastoId,
    required this.tipo,
    required this.asignado,
    this.arrastreRecibido = 0,
    this.protegida = false,
    this.prioridad = Prioridad.necesario,
    this.pisoMinimo = 0,
    this.modoArrastre = ModoArrastre.alRemanente,
  });
}

/// Abono planeado de una deuda en la semana (`fin_abonos_semana`).
class AbonoSemana {
  final String id;
  final String semanaId;
  final String deudaId;
  final int abonoPlaneado;

  /// Mínimo exigible semanal.
  final int minimo;

  /// Abono extra propuesto con el remanente planeado.
  final int extraPlaneado;

  const AbonoSemana({
    required this.id,
    required this.semanaId,
    required this.deudaId,
    required this.abonoPlaneado,
    this.minimo = 0,
    this.extraPlaneado = 0,
  });
}

/// La foto del plan de una semana de un libro (`fin_semanas`). Cambia solo
/// mientras no esté cerrada.
class SemanaGuardada {
  final String id;
  final String libroId;
  final Semana semana;
  final EstadoSemana estado;
  final String metodo;
  final int ingreso;
  final int presupuesto;
  final int deudaPlan;
  final int remanentePlan;
  final int metaRemanentePuntosBase;
  final int ahorroMinimoConDeudaPuntosBase;
  final int techo;
  final String? activadaPor;
  final DateTime? activadaEn;

  /// Veces que se reabrió (lo pone el servidor). El cierre siguiente es la
  /// versión `reaperturas + 1` (`fin_cierres.version`).
  final int reaperturas;
  final List<PartidaSemana> partidas;
  final List<AbonoSemana> abonos;

  SemanaGuardada({
    required this.id,
    required this.libroId,
    required this.semana,
    required this.estado,
    this.metodo = 'sobres',
    required this.ingreso,
    required this.presupuesto,
    required this.deudaPlan,
    required this.remanentePlan,
    required this.metaRemanentePuntosBase,
    required this.ahorroMinimoConDeudaPuntosBase,
    required this.techo,
    this.activadaPor,
    this.activadaEn,
    this.reaperturas = 0,
    List<PartidaSemana> partidas = const [],
    List<AbonoSemana> abonos = const [],
  }) : partidas = List.unmodifiable(partidas),
       abonos = List.unmodifiable(abonos);

  /// Versión que lleva el cierre siguiente (`reaperturas + 1`).
  int get versionDelSiguienteCierre => reaperturas + 1;

  /// La misma semana con otro estado. Como el servidor, reabrir una semana
  /// cerrada suma una reapertura.
  SemanaGuardada conEstado(EstadoSemana nuevo) => SemanaGuardada(
    id: id,
    libroId: libroId,
    semana: semana,
    estado: nuevo,
    metodo: metodo,
    ingreso: ingreso,
    presupuesto: presupuesto,
    deudaPlan: deudaPlan,
    remanentePlan: remanentePlan,
    metaRemanentePuntosBase: metaRemanentePuntosBase,
    ahorroMinimoConDeudaPuntosBase: ahorroMinimoConDeudaPuntosBase,
    techo: techo,
    activadaPor: activadaPor,
    activadaEn: activadaEn,
    reaperturas:
        estado == EstadoSemana.cerrada && nuevo != EstadoSemana.cerrada
        ? reaperturas + 1
        : reaperturas,
    partidas: partidas,
    abonos: abonos,
  );
}

/// Renglón de partida de un cierre (`fin_cierre_partidas`).
class CierrePartidaGuardada {
  final String partidaId;
  final int gastado;
  final int arrastreSiguiente;
  final int alRemanente;

  const CierrePartidaGuardada({
    required this.partidaId,
    required this.gastado,
    required this.arrastreSiguiente,
    required this.alRemanente,
  });
}

/// Renglón de abono de un cierre (`fin_cierre_abonos`): el `AbonoDiferido`
/// del diseño (diferido = planeado − real).
class CierreAbonoGuardado {
  final String deudaId;
  final int planeado;
  final int real;
  final int minimo;

  const CierreAbonoGuardado({
    required this.deudaId,
    required this.planeado,
    required this.real,
    required this.minimo,
  });

  int get diferido => planeado - real;
}

/// Qué se hizo con el remanente al cerrar (5.6 bis, punto 6, regla 6: la app
/// propone, la persona confirma).
enum AccionCierre {
  /// Se crearon los movimientos de abono extra o ahorro propuestos.
  aplicarRemanente,

  /// Se cerró sin mover dinero (se decide después).
  sinAplicar,

  /// La cerró la app a los 3 días, con pendientes marcados.
  cierreAutomatico,
}

/// Foto del cierre y del balance (`fin_cierres`, solo agregar). Reabrir y
/// volver a cerrar crea la versión siguiente.
class CierreGuardado {
  final String id;
  final String semanaId;
  final int version;
  final int ingresoReal;
  final int gastoReal;
  final int abonoReal;
  final int abonoDiferido;
  final int abonoExtraReal;
  final int ahorroReal;
  final int deficit;
  final int arrastreSiguiente;
  final AccionCierre accionElegida;
  final bool conPendientes;
  final int activos;
  final int pasivos;
  final int patrimonio;
  final String? cerradoPor;
  final DateTime cerradoEn;
  final List<CierrePartidaGuardada> partidas;
  final List<CierreAbonoGuardado> abonos;

  CierreGuardado({
    required this.id,
    required this.semanaId,
    required this.version,
    required this.ingresoReal,
    required this.gastoReal,
    required this.abonoReal,
    required this.abonoDiferido,
    required this.abonoExtraReal,
    required this.ahorroReal,
    required this.deficit,
    required this.arrastreSiguiente,
    required this.accionElegida,
    this.conPendientes = false,
    required this.activos,
    required this.pasivos,
    required this.patrimonio,
    this.cerradoPor,
    required this.cerradoEn,
    List<CierrePartidaGuardada> partidas = const [],
    List<CierreAbonoGuardado> abonos = const [],
  }) : partidas = List.unmodifiable(partidas),
       abonos = List.unmodifiable(abonos);

  /// Remanente real del cierre (abono extra + ahorro).
  int get remanenteReal => abonoExtraReal + ahorroReal;
}

/// De dónde sale una ocurrencia.
enum OrigenOcurrencia { ingreso, compromiso, deuda }

/// Estado de una ocurrencia (`fin_ocurrencias.estado`).
enum EstadoOcurrencia {
  esperada,
  cumplida,
  parcial,
  retrasada,
  noLlegara,
  omitida,
}

/// Un pago esperado con su fecha (`fin_ocurrencias`). En el MVP 1 se guarda
/// cuando la persona marca un ingreso que no llegó o se retrasó; lo demás se
/// calcula del calendario.
class Ocurrencia {
  final String id;
  final String libroId;
  final OrigenOcurrencia origen;
  final String origenId;
  final Fecha fechaProgramada;
  final Fecha fechaAjustada;
  final int montoEsperado;
  final EstadoOcurrencia estado;
  final String? movimientoId;

  const Ocurrencia({
    required this.id,
    required this.libroId,
    required this.origen,
    required this.origenId,
    required this.fechaProgramada,
    required this.fechaAjustada,
    required this.montoEsperado,
    this.estado = EstadoOcurrencia.esperada,
    this.movimientoId,
  });

  /// Un ingreso que no llegó resta completo en la semana en que debía llegar
  /// (regla 33, interpretación).
  bool get faltante =>
      estado == EstadoOcurrencia.noLlegara ||
      estado == EstadoOcurrencia.retrasada;

  Ocurrencia conEstado(EstadoOcurrencia nuevo) => Ocurrencia(
    id: id,
    libroId: libroId,
    origen: origen,
    origenId: origenId,
    fechaProgramada: fechaProgramada,
    fechaAjustada: fechaAjustada,
    montoEsperado: montoEsperado,
    estado: nuevo,
    movimientoId: movimientoId,
  );
}

/// Conciliación guardada (`fin_conciliaciones`, solo agregar).
class ConciliacionGuardada {
  final String id;
  final String libroId;
  final String cuentaId;
  final Fecha fecha;
  final int saldoDeclarado;
  final int saldoCalculado;
  final String? ajusteMovimientoId;
  final String? motivo;
  final String personaId;
  final DateTime creadoEn;

  const ConciliacionGuardada({
    required this.id,
    required this.libroId,
    required this.cuentaId,
    required this.fecha,
    required this.saldoDeclarado,
    required this.saldoCalculado,
    this.ajusteMovimientoId,
    this.motivo,
    required this.personaId,
    required this.creadoEn,
  });

  int get diferencia => saldoDeclarado - saldoCalculado;
}

/// Registro de una importación (`fin_importaciones`, solo agregar).
class ImportacionGuardada {
  final String id;
  final String archivo;
  final String hoja;
  final int filasLeidas;
  final int filasCreadas;
  final int filasOmitidas;

  /// Filas omitidas con su motivo (`detalle` jsonb).
  final List<Map<String, Object?>> detalle;
  final String personaId;
  final DateTime creadoEn;

  ImportacionGuardada({
    required this.id,
    required this.archivo,
    required this.hoja,
    required this.filasLeidas,
    required this.filasCreadas,
    required this.filasOmitidas,
    List<Map<String, Object?>> detalle = const [],
    required this.personaId,
    required this.creadoEn,
  }) : detalle = List.unmodifiable(detalle);
}

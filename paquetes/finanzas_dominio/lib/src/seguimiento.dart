import 'calendario.dart';
import 'configuracion.dart';
import 'datos_finanzas.dart';
import 'dinero.dart';
import 'fecha.dart';
import 'flujo.dart';
import 'frecuencia.dart';
import 'indicadores.dart';
import 'libro.dart';
import 'plan_guardado.dart';
import 'presupuesto.dart';
import 'semana.dart';

/// Seguimiento de la semana de un libro: arma el plan (desde la configuración
/// o desde la foto activada), mide lo real (vista devengada), calcula lo que
/// vence, el flujo con su alerta, los indicadores del MVP 1, la siguiente
/// mejor acción y el cierre (5.6 bis y 5.9 bis).

/// De dónde sale cada partida del plan.
class InfoPartida {
  /// Id de la partida en el plan (el del compromiso o sobre si el plan sale
  /// de la configuración; el de `fin_partidas_semana` si sale de la foto).
  final String partidaId;
  final OrigenPartida origen;
  final String origenId;
  final String nombre;
  final String? cuentaGastoId;

  /// Solo compromisos: la subcategoría con que se registra su pago.
  final String? categoriaId;

  const InfoPartida({
    required this.partidaId,
    required this.origen,
    required this.origenId,
    required this.nombre,
    this.cuentaGastoId,
    this.categoriaId,
  });
}

/// Una deuda ya liquidada: su abono queda libre (regla 4 de 4.5; P19).
class DeudaLiberada {
  final Deuda deuda;
  final int abonoSemanal;

  const DeudaLiberada(this.deuda, this.abonoSemanal);
}

/// El plan de una semana de un libro con el origen de sus partidas.
class PlanDelLibro {
  final PlanSemanal plan;
  final Map<String, InfoPartida> partidas;

  /// Deudas activas ya pagadas: no entran al plan y su abono pasa al
  /// remanente (que va al grupo prioritario o a ahorro).
  final List<DeudaLiberada> liberadas;

  /// `true` si sale de la foto de la semana activada.
  final bool desdeFoto;

  const PlanDelLibro({
    required this.plan,
    required this.partidas,
    this.liberadas = const [],
    this.desdeFoto = false,
  });

  InfoPartida info(String partidaId) => partidas[partidaId]!;

  int get abonoLiberado => liberadas.fold(0, (t, l) => t + l.abonoSemanal);
}

/// Saldo actual de una deuda según la vista del libro (nulo si no tiene
/// cuenta pasivo).
int? saldoDeDeuda(DatosFinanzas d, Deuda deuda) {
  final cuentaId = deuda.cuentaPasivoId;
  if (cuentaId == null || d.cuenta(cuentaId) == null) return null;
  return d.vista(deuda.libroId).saldo(cuentaId);
}

/// Arma el plan de [semana] del libro con su configuración vigente (5.6 bis,
/// punto 4).
PlanDelLibro armarPlanDelLibro(DatosFinanzas d, String libroId, Semana semana) {
  final parametros = d.parametrosDe(libroId).plan;
  final ingresos = [for (final i in d.ingresosDe(libroId)) ?i.planEn(semana)];
  final info = <String, InfoPartida>{};
  final partidas = <PartidaPlan>[];
  for (final c in d.compromisosDe(libroId)) {
    if (!c.vigenteEn(semana)) continue;
    partidas.add(c.partida);
    info[c.id] = InfoPartida(
      partidaId: c.id,
      origen: OrigenPartida.compromiso,
      origenId: c.id,
      nombre: c.nombre,
      cuentaGastoId: c.cuentaGastoId,
      categoriaId: c.categoriaId,
    );
  }
  for (final s in d.sobresDe(libroId)) {
    if (!s.activo) continue;
    partidas.add(s.partida);
    info[s.id] = InfoPartida(
      partidaId: s.id,
      origen: OrigenPartida.sobre,
      origenId: s.id,
      nombre: s.nombre,
      cuentaGastoId: s.cuentaGastoId,
    );
  }
  final deudas = <DeudaPlan>[];
  final liberadas = <DeudaLiberada>[];
  for (final deuda in d.deudasDe(libroId)) {
    if (!deuda.activa) continue;
    final saldo = saldoDeDeuda(d, deuda);
    if (saldo != null && saldo <= 0) {
      liberadas.add(
        DeudaLiberada(
          deuda,
          Equivalente.de(deuda.abono, deuda.frecuencia).semanal,
        ),
      );
      continue;
    }
    deudas.add(deuda.plan(saldo: saldo));
  }
  return PlanDelLibro(
    plan: armarPlanSemanal(
      semana: semana,
      ingresos: ingresos,
      partidas: partidas,
      deudas: deudas,
      parametros: parametros,
    ),
    partidas: info,
    liberadas: liberadas,
  );
}

/// Vuelve a armar el plan de una semana activada con su foto: los renglones
/// ya repartidos (R2) como montos semanales, así los totales son los mismos
/// que se guardaron.
PlanDelLibro planDesdeFoto(DatosFinanzas d, SemanaGuardada g) {
  final base = d.parametrosDe(g.libroId);
  final parametros = ParametrosPlan(
    metaRemanentePuntosBase: g.metaRemanentePuntosBase,
    ahorroMinimoConDeudaPuntosBase: g.ahorroMinimoConDeudaPuntosBase,
    topeArrastreSemanas: base.topeArrastreSemanas,
    umbrales: base.umbrales,
  );
  String nombreDe(PartidaSemana p) {
    if (p.origen == OrigenPartida.compromiso) {
      for (final c in d.compromisos) {
        if (c.id == p.origenId) return c.nombre;
      }
    } else {
      for (final s in d.sobres) {
        if (s.id == p.origenId) return s.nombre;
      }
    }
    return 'Partida';
  }

  String? categoriaDe(PartidaSemana p) {
    if (p.origen != OrigenPartida.compromiso) return null;
    for (final c in d.compromisos) {
      if (c.id == p.origenId) return c.categoriaId;
    }
    return null;
  }

  final info = <String, InfoPartida>{};
  final partidas = <PartidaPlan>[];
  for (final p in g.partidas) {
    final nombre = nombreDe(p);
    partidas.add(
      PartidaPlan(
        id: p.id,
        nombre: nombre,
        tipo: p.tipo,
        monto: p.asignado,
        frecuencia: Frecuencia.semanal,
        cuentaGastoId: p.cuentaGastoId,
        protegida: p.protegida,
        prioridad: p.prioridad,
        pisoMinimo: p.pisoMinimo,
        arrastre: p.modoArrastre,
      ),
    );
    info[p.id] = InfoPartida(
      partidaId: p.id,
      origen: p.origen,
      origenId: p.origenId,
      nombre: nombre,
      cuentaGastoId: p.cuentaGastoId,
      categoriaId: categoriaDe(p),
    );
  }
  final deudas = <DeudaPlan>[];
  for (final a in g.abonos) {
    Deuda? config;
    for (final x in d.deudas) {
      if (x.id == a.deudaId) config = x;
    }
    final tipo = config?.tipo ?? TipoDeuda.familiar;
    final tasa = config?.tasaAnualPuntosBase ?? 0;
    final valida = tipo != TipoDeuda.conCosto || tasa > 0;
    deudas.add(
      DeudaPlan(
        id: a.deudaId,
        nombre: config?.nombre ?? 'Deuda',
        tipo: valida ? tipo : TipoDeuda.familiar,
        abono: a.abonoPlaneado,
        frecuencia: Frecuencia.semanal,
        minimo: a.minimo,
        tasaAnualPuntosBase: valida && tipo == TipoDeuda.conCosto ? tasa : 0,
        saldo: config == null ? null : saldoDeDeuda(d, config),
        prioridadManual: config?.prioridadManual,
        grupoPrioritario: config?.grupoPrioritario ?? false,
        ordenGrupo: config?.ordenGrupo,
      ),
    );
  }
  return PlanDelLibro(
    plan: armarPlanSemanal(
      semana: g.semana,
      ingresos: [
        if (g.ingreso > 0)
          IngresoPlan(
            id: 'ingreso',
            nombre: 'Ingreso',
            monto: g.ingreso,
            frecuencia: Frecuencia.semanal,
          ),
      ],
      partidas: partidas,
      deudas: deudas,
      parametros: parametros,
    ),
    partidas: info,
    desdeFoto: true,
  );
}

/// Lo gastado en la semana por partida (vista devengada).
class GastoSemana {
  final Map<String, int> porPartida;

  /// Gasto que no es de ninguna partida ("Por clasificar", intereses,
  /// rubros sin sobre).
  final int sinPartida;

  /// Lo pagado de cada compromiso en la semana (para mostrar "pagado").
  final Map<String, int> pagadoPorPartida;

  const GastoSemana({
    required this.porPartida,
    required this.sinPartida,
    this.pagadoPorPartida = const {},
  });

  int get total => porPartida.values.fold(0, (t, v) => t + v) + sinPartida;
}

/// Mide lo gastado en [semana] por cada partida del [plan] (regla 33,
/// interpretación):
///
/// - **Compromisos** (fijos y reservas): lo asignado se da por consumido y
///   solo cuenta la diferencia del pago real contra lo esperado. El pago se
///   reconoce por su subcategoría (y sus detalles) dentro de la cuenta de
///   gasto del compromiso.
/// - **Sobres:** lo gastado en su cuenta de gasto (lo que no tomó un
///   compromiso).
/// - Lo demás es gasto sin partida.
GastoSemana gastoDeLaSemana(
  DatosFinanzas d,
  String libroId,
  Semana semana,
  PlanDelLibro plan,
) {
  final vista = d.vista(libroId);
  final deltas = <(String, String?), int>{};
  for (final m in vista.movimientos) {
    if (!semana.contiene(m.fecha)) continue;
    if (vista.estadoDe(m.id) != EstadoMovimiento.confirmado) continue;
    final origen = vista.cuenta(m.cuentaOrigenId);
    final destino = vista.cuenta(m.cuentaDestinoId);
    if (destino.clase == ClaseCuenta.gasto) {
      final k = (destino.id, m.categoriaId);
      deltas[k] = (deltas[k] ?? 0) + m.monto;
    }
    if (origen.clase == ClaseCuenta.gasto) {
      final k = (origen.id, m.categoriaId);
      deltas[k] = (deltas[k] ?? 0) - m.monto;
    }
  }
  int tomar(bool Function((String, String?) k) coincide) {
    var total = 0;
    for (final k in deltas.keys.where(coincide).toList()) {
      total += deltas.remove(k)!;
    }
    return total;
  }

  final porPartida = <String, int>{};
  final pagado = <String, int>{};
  // Primero los compromisos (toman su subcategoría), luego los sobres.
  for (final r in plan.plan.partidas) {
    final info = plan.info(r.origen.id);
    if (info.origen != OrigenPartida.compromiso) continue;
    final categoria = info.categoriaId;
    var pago = 0;
    if (categoria != null && info.cuentaGastoId != null) {
      final familia = d.arbol.conDescendientes(categoria);
      pago = tomar((k) => k.$1 == info.cuentaGastoId && familia.contains(k.$2));
    }
    pagado[r.origen.id] = pago;
    if (pago == 0) {
      porPartida[r.origen.id] = r.semanal;
      continue;
    }
    Compromiso? c;
    for (final x in d.compromisos) {
      if (x.id == info.origenId) c = x;
    }
    var esperado = 0;
    if (c != null) {
      final pagos = c.pagosEntre(semana.inicio, semana.fin, d.calendario);
      esperado = pagos.isEmpty ? c.monto : c.monto * pagos.length;
    }
    porPartida[r.origen.id] = gastoDevengado(r.semanal, [(esperado, pago)]);
  }
  for (final r in plan.plan.partidas) {
    final info = plan.info(r.origen.id);
    if (info.origen != OrigenPartida.sobre) continue;
    final cuenta = info.cuentaGastoId;
    porPartida[r.origen.id] = cuenta == null ? 0 : tomar((k) => k.$1 == cuenta);
  }
  return GastoSemana(
    porPartida: porPartida,
    sinPartida: deltas.values.fold(0, (t, v) => t + v),
    pagadoPorPartida: pagado,
  );
}

/// Extras de la semana: ingresos que llegaron por cuentas de origen que no
/// son de un ingreso configurado (5.1 bis, punto 4), netos de anulaciones.
int extrasDeLaSemana(DatosFinanzas d, String libroId, Semana semana) {
  final vista = d.vista(libroId);
  final configuradas = {
    for (final i in d.ingresosDe(libroId)) i.cuentaOrigenId,
  };
  var total = 0;
  for (final c in d.cuentasDe(libroId)) {
    if (c.tipo != TipoCuenta.origenIngreso || configuradas.contains(c.id)) {
      continue;
    }
    total += vista.saldo(c.id, desde: semana.inicio, hasta: semana.fin);
  }
  return total;
}

/// Ingresos que se marcaron como no llegados (o retrasados) en la semana.
int faltantesDeLaSemana(DatosFinanzas d, String libroId, Semana semana) => d
    .ocurrencias
    .where(
      (o) =>
          o.libroId == libroId &&
          o.origen == OrigenOcurrencia.ingreso &&
          o.faltante &&
          semana.contiene(o.fechaAjustada),
    )
    .fold(0, (t, o) => t + o.montoEsperado);

/// Ingreso real devengado: el del plan, más los extras que llegaron, menos lo
/// que no llegó (regla 33, interpretación).
int ingresoRealDeLaSemana(
  DatosFinanzas d,
  String libroId,
  Semana semana,
  PlanDelLibro plan,
) =>
    plan.plan.ingreso +
    extrasDeLaSemana(d, libroId, semana) -
    faltantesDeLaSemana(d, libroId, semana);

/// Arrastre que cada partida trae de la semana anterior, por **origen**
/// (compromiso o sobre), según el último cierre guardado.
Map<String, int> arrastresPorOrigen(
  DatosFinanzas d,
  String libroId,
  Semana semana,
) {
  final anterior = d.semanaGuardada(libroId, semana.anterior);
  if (anterior == null) return const {};
  final cierre = d.ultimoCierre(anterior.id);
  if (cierre == null) return const {};
  final origenDe = {for (final p in anterior.partidas) p.id: p.origenId};
  return {
    for (final p in cierre.partidas)
      if (p.arrastreSiguiente > 0 && origenDe[p.partidaId] != null)
        origenDe[p.partidaId]!: p.arrastreSiguiente,
  };
}

/// Un pago o un ingreso con fecha ("lo que vence", 5.9 bis punto 2).
class Vencimiento {
  final OrigenOcurrencia origen;
  final String origenId;
  final String concepto;
  final FechaPago fecha;
  final int monto;

  /// Solo ingresos.
  final Certeza? certeza;

  const Vencimiento({
    required this.origen,
    required this.origenId,
    required this.concepto,
    required this.fecha,
    required this.monto,
    this.certeza,
  });

  bool get esEntrada => origen == OrigenOcurrencia.ingreso;

  EventoFlujo get evento =>
      EventoFlujo(fecha.ajustada, esEntrada ? monto : -monto, concepto);
}

/// Ingresos, compromisos y deudas del libro con fecha ajustada entre [desde]
/// y [hasta], en orden de fecha.
List<Vencimiento> vencimientosEntre(
  DatosFinanzas d,
  String libroId,
  Fecha desde,
  Fecha hasta,
) {
  final lista = <Vencimiento>[];
  for (final i in d.ingresosDe(libroId)) {
    for (final (p, monto) in i.pagosEntre(desde, hasta, d.calendario)) {
      lista.add(
        Vencimiento(
          origen: OrigenOcurrencia.ingreso,
          origenId: i.id,
          concepto: i.nombre,
          fecha: p,
          monto: monto,
          certeza: i.certeza,
        ),
      );
    }
  }
  for (final c in d.compromisosDe(libroId)) {
    for (final p in c.pagosEntre(desde, hasta, d.calendario)) {
      lista.add(
        Vencimiento(
          origen: OrigenOcurrencia.compromiso,
          origenId: c.id,
          concepto: c.nombre,
          fecha: p,
          monto: c.monto,
        ),
      );
    }
  }
  for (final deuda in d.deudasDe(libroId)) {
    final saldo = saldoDeDeuda(d, deuda);
    if (saldo != null && saldo <= 0) continue;
    for (final p in deuda.pagosEntre(desde, hasta, d.calendario)) {
      lista.add(
        Vencimiento(
          origen: OrigenOcurrencia.deuda,
          origenId: deuda.id,
          concepto: deuda.nombre,
          fecha: p,
          monto: deuda.abono,
        ),
      );
    }
  }
  lista.sort((a, b) {
    final f = a.fecha.ajustada.compareTo(b.fecha.ajustada);
    return f != 0 ? f : a.concepto.compareTo(b.concepto);
  });
  return lista;
}

/// Calendario de flujo del libro (5.1 bis, punto 9).
class FlujoLibro {
  final int saldoInicial;
  final ProyeccionFlujo proyeccion;
  final List<FlujoSemana> semanas;

  /// Ingresos `probable` (van aparte) e `incierta` (no cuentan).
  final List<Vencimiento> noSeguros;

  const FlujoLibro({
    required this.saldoInicial,
    required this.proyeccion,
    required this.semanas,
    required this.noSeguros,
  });

  bool get hayAlerta => proyeccion.hayAlerta;
  DiaFlujo? get primerDiaEnRiesgo => proyeccion.primerDiaEnRiesgo;
}

/// Proyecta el disponible del libro (efectivo y bancos) desde [hoy] hasta el
/// domingo de la semana [semanas] − 1 después: saldo de hoy + ingresos
/// seguros − pagos programados, con el peor caso de cada día (las salidas
/// primero). Los eventos empiezan **mañana**: lo de hoy ya está en el saldo.
/// Nunca propone tapar un hueco con una tarjeta.
FlujoLibro proyectarFlujoDelLibro(
  DatosFinanzas d,
  String libroId, {
  required Fecha hoy,
  int semanas = 6,
  int saldoMinimo = 0,
}) {
  final hasta = Semana.de(hoy).mas(semanas - 1).fin;
  final desde = hoy.sumarDias(1);
  final todos = vencimientosEntre(d, libroId, desde, hasta);
  final seguros = todos
      .where((v) => !v.esEntrada || v.certeza == Certeza.segura)
      .toList();
  final saldo = d.vista(libroId).disponible(al: hoy);
  return FlujoLibro(
    saldoInicial: saldo,
    proyeccion: proyectarFlujo(
      saldoInicial: saldo,
      desde: desde,
      hasta: hasta,
      eventos: [for (final v in seguros) v.evento],
      saldoMinimo: saldoMinimo,
    ),
    semanas: flujoPorSemana(
      [for (final v in seguros) v.evento],
      desde: Semana.de(hoy).inicio,
      hasta: hasta,
    ),
    noSeguros: todos
        .where((v) => v.esEntrada && v.certeza != Certeza.segura)
        .toList(),
  );
}

/// Tendencia del patrimonio contra el último cierre anterior.
enum Tendencia { sube, igual, baja }

/// Indicadores del MVP 1 (5.9 bis, punto 3).
class IndicadoresSemana {
  final int remanentePuntosBase;
  final Semaforo remanente;
  final int cargaDeudaPuntosBase;
  final Semaforo cargaDeuda;
  final int partidasDentro;
  final int totalPartidas;
  final Semaforo cumplimiento;
  final int patrimonio;
  final Tendencia? tendenciaPatrimonio;

  const IndicadoresSemana({
    required this.remanentePuntosBase,
    required this.remanente,
    required this.cargaDeudaPuntosBase,
    required this.cargaDeuda,
    required this.partidasDentro,
    required this.totalPartidas,
    required this.cumplimiento,
    required this.patrimonio,
    this.tendenciaPatrimonio,
  });

  int get cumplimientoPuntosBase =>
      proporcionEnPuntosBase(partidasDentro, totalPartidas);
}

/// Una partida que se movió (revisión semanal, paso 3).
class Desvio {
  final InfoPartida partida;
  final CierrePartida cierre;

  const Desvio(this.partida, this.cierre);

  /// Positivo: se gastó de más; negativo: sobró.
  int get diferencia => cierre.gastado - cierre.disponible;
}

/// Qué conviene hacer ahora (5.9 bis, punto 2.4).
enum TipoAccionSugerida {
  revisarFlujo,
  compensarSobregasto,
  abonoBajoMinimo,
  cerrarSemana,
  activarSemana,
  abonarExtra,
  ahorrar,
  configurar,
  todoEnOrden,
}

/// La siguiente mejor acción: un texto con un monto aparte (para poder
/// ocultarlo) y a qué se refiere.
class AccionSugerida {
  final TipoAccionSugerida tipo;

  /// Texto con `{monto}` donde va el monto (o sin él).
  final String plantilla;
  final int? monto;

  const AccionSugerida(this.tipo, this.plantilla, {this.monto});

  /// El texto con el monto ya formateado por quien lo muestra.
  String texto(String Function(int) formato) => monto == null
      ? plantilla
      : plantilla.replaceAll('{monto}', formato(monto!));
}

/// Todo lo de una semana de un libro.
class VistaSemana {
  final String libroId;
  final Semana semana;
  final Fecha hoy;
  final EstadoSemana estado;
  final SemanaGuardada? guardada;
  final PlanDelLibro plan;

  /// El plan con la configuración de hoy (vistas por periodo, ingreso
  /// potencial y la propuesta de la semana siguiente).
  final PlanDelLibro planConfiguracion;
  final GastoSemana gasto;
  final int ingresoReal;
  final Map<String, int> arrastreRecibido;

  /// Lo real hasta hoy con las reglas del cierre (sobregasto, abono diferido,
  /// déficit y arrastre).
  final CierreSemanal real;
  final List<CierreGuardado> cierres;
  final List<Vencimiento> vencimientos;
  final FlujoLibro flujo;
  final Balance balance;
  final int? patrimonioAnterior;
  final int cierreAutomaticoDias;

  const VistaSemana({
    required this.libroId,
    required this.semana,
    required this.hoy,
    required this.estado,
    required this.guardada,
    required this.plan,
    required this.planConfiguracion,
    required this.gasto,
    required this.ingresoReal,
    required this.arrastreRecibido,
    required this.real,
    required this.cierres,
    required this.vencimientos,
    required this.flujo,
    required this.balance,
    required this.patrimonioAnterior,
    required this.cierreAutomaticoDias,
  });

  PlanSemanal get planSemanal => plan.plan;

  CierreGuardado? get ultimoCierre => cierres.isEmpty ? null : cierres.last;

  /// Una semana sin cerrar se cierra sola con pendientes a los
  /// [cierreAutomaticoDias] días de terminar (5.9 bis, punto 4).
  bool get debeCerrarseSola =>
      estado == EstadoSemana.porCerrar &&
      hoy.despuesDe(semana.fin.sumarDias(cierreAutomaticoDias));

  InfoPartida infoPartida(String partidaId) => plan.info(partidaId);

  IndicadoresSemana get indicadores {
    final u = planSemanal.parametros.umbrales;
    final dentro = real.partidas.where((p) => p.dentro).length;
    Tendencia? tendencia;
    if (patrimonioAnterior != null) {
      final c = balance.patrimonio.compareTo(patrimonioAnterior!);
      tendencia = c > 0
          ? Tendencia.sube
          : (c < 0 ? Tendencia.baja : Tendencia.igual);
    }
    return IndicadoresSemana(
      remanentePuntosBase: real.tasaRemanentePuntosBase,
      remanente: semaforoRemanente(
        real.remanenteReal,
        real.ingresoReal,
        umbrales: u,
      ),
      cargaDeudaPuntosBase: planSemanal.cargaDeudaPuntosBase,
      cargaDeuda: planSemanal.semaforoDeLaCarga,
      partidasDentro: dentro,
      totalPartidas: real.partidas.length,
      cumplimiento: real.semaforoDelCumplimiento,
      patrimonio: balance.patrimonio,
      tendenciaPatrimonio: tendencia,
    );
  }

  /// Las [cuantos] partidas que más se movieron (revisión semanal, paso 3):
  /// primero las que se pasaron (de más a menos) y después las que más
  /// sobraron.
  List<Desvio> desvios({int cuantos = 3}) {
    final lista =
        [
          for (final p in real.partidas)
            if (p.gastado != p.disponible) Desvio(plan.info(p.partida.id), p),
        ]..sort((a, b) {
          final pasoA = a.diferencia > 0;
          final pasoB = b.diferencia > 0;
          if (pasoA != pasoB) return pasoA ? -1 : 1;
          final c = b.diferencia.abs().compareTo(a.diferencia.abs());
          return c != 0 ? c : a.partida.nombre.compareTo(b.partida.nombre);
        });
    return lista.take(cuantos).toList();
  }

  /// Propuesta de recortes si el plan de la semana siguiente no cabe en el
  /// techo (5.6 bis, punto 6, reglas 5 y 6). Nunca toca lo protegido.
  PropuestaRecortes? recortesSiguiente(PlanDelLibro siguiente) {
    final p = siguiente.plan;
    final exceso = p.presupuesto - p.techo;
    if (exceso <= 0) return null;
    return proponerRecortes(exceso, [
      for (final r in p.partidas)
        (partida: r.origen, disponible: r.semanal, gastado: 0),
    ]);
  }

  /// La siguiente mejor acción (una sola).
  AccionSugerida get siguienteAccion {
    if (planSemanal.partidas.isEmpty && planSemanal.ingreso == 0) {
      return const AccionSugerida(
        TipoAccionSugerida.configurar,
        'Configura tus ingresos y sobres con el asistente de arranque.',
      );
    }
    final riesgo = flujo.primerDiaEnRiesgo;
    if (riesgo != null) {
      return AccionSugerida(
        TipoAccionSugerida.revisarFlujo,
        'El ${_fechaCorta(riesgo.fecha)} el saldo puede bajar a {monto}: '
        'revisa el flujo antes de pagar.',
        monto: riesgo.saldoPeorCaso,
      );
    }
    final pasadas = real.partidasPasadas
      ..sort((a, b) => b.sobregasto.compareTo(a.sobregasto));
    if (pasadas.isNotEmpty) {
      final p = pasadas.first;
      return AccionSugerida(
        TipoAccionSugerida.compensarSobregasto,
        '${plan.info(p.partida.id).nombre} se pasó {monto}: compénsalo con '
        'otra partida o con la semana siguiente.',
        monto: p.sobregasto,
      );
    }
    if (real.abonosBajoMinimo.isNotEmpty) {
      final a = real.abonosBajoMinimo.first;
      return AccionSugerida(
        TipoAccionSugerida.abonoBajoMinimo,
        'El abono a ${a.deuda.nombre} queda {monto} bajo el mínimo.',
        monto: a.minimo - a.real,
      );
    }
    if (estado == EstadoSemana.porCerrar) {
      return const AccionSugerida(
        TipoAccionSugerida.cerrarSemana,
        'Cierra la semana con la revisión de 3 minutos.',
      );
    }
    if (estado == EstadoSemana.borrador) {
      return const AccionSugerida(
        TipoAccionSugerida.activarSemana,
        'Revisa el plan y activa la semana.',
      );
    }
    final destino = real.destino;
    if (destino.abonosExtra.isNotEmpty) {
      final a = destino.abonosExtra.first;
      return AccionSugerida(
        TipoAccionSugerida.abonarExtra,
        'Abona {monto} extra a ${a.deuda.nombre} al cerrar la semana.',
        monto: a.monto,
      );
    }
    if (destino.ahorro > 0) {
      return AccionSugerida(
        TipoAccionSugerida.ahorrar,
        'Aparta {monto} para ahorro al cerrar la semana.',
        monto: destino.ahorro,
      );
    }
    return const AccionSugerida(
      TipoAccionSugerida.todoEnOrden,
      'Todo en orden esta semana.',
    );
  }
}

const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

String _fechaCorta(Fecha f) =>
    '${_diasCortos[f.diaSemana - 1]} ${f.dia} ${_mesesCortos[f.mes - 1]}';

/// Estado de la semana según la foto y el día de hoy.
EstadoSemana estadoDeLaSemana(SemanaGuardada? g, Semana semana, Fecha hoy) {
  if (g == null) return EstadoSemana.borrador;
  if (g.estado == EstadoSemana.cerrada) return EstadoSemana.cerrada;
  if (g.estado == EstadoSemana.pendienteIngreso) {
    return EstadoSemana.pendienteIngreso;
  }
  if (semana.fin.antesDe(hoy)) return EstadoSemana.porCerrar;
  return g.estado;
}

/// Arma todo lo de [semana] del libro [libroId] (tablero y pantalla Semana).
VistaSemana vistaSemana(
  DatosFinanzas d,
  String libroId,
  Semana semana, {
  required Fecha hoy,
  int semanasFlujo = 6,
}) {
  final guardada = d.semanaGuardada(libroId, semana);
  final planConfig = armarPlanDelLibro(d, libroId, semana);
  final plan = guardada == null ? planConfig : planDesdeFoto(d, guardada);
  final gasto = gastoDeLaSemana(d, libroId, semana, plan);
  final ingresoReal = ingresoRealDeLaSemana(d, libroId, semana, plan);
  Map<String, int> arrastres;
  if (guardada != null) {
    arrastres = {
      for (final p in guardada.partidas)
        if (p.arrastreRecibido > 0) p.id: p.arrastreRecibido,
    };
  } else {
    final porOrigen = arrastresPorOrigen(d, libroId, semana);
    arrastres = {
      for (final e in porOrigen.entries)
        if (plan.partidas.containsKey(e.key)) e.key: e.value,
    };
  }
  final real = cerrarSemana(
    plan.plan,
    ingresoReal: ingresoReal,
    gastadoPorPartida: gasto.porPartida,
    arrastreRecibido: arrastres,
    gastoSinPartida: gasto.sinPartida,
  );
  final vista = d.vista(libroId);
  final balance = vista.balance(al: semana.fin.antesDe(hoy) ? semana.fin : hoy);
  // El último cierre anterior: busca la semana anterior más reciente.
  final anteriores =
      d.semanas
          .where(
            (s) =>
                s.libroId == libroId && s.semana.inicio.antesDe(semana.inicio),
          )
          .toList()
        ..sort((a, b) => b.semana.inicio.compareTo(a.semana.inicio));
  int? patrimonioAnterior;
  for (final s in anteriores) {
    final c = d.ultimoCierre(s.id);
    if (c != null) {
      patrimonioAnterior = c.patrimonio;
      break;
    }
  }
  return VistaSemana(
    libroId: libroId,
    semana: semana,
    hoy: hoy,
    estado: estadoDeLaSemana(guardada, semana, hoy),
    guardada: guardada,
    plan: plan,
    planConfiguracion: planConfig,
    gasto: gasto,
    ingresoReal: ingresoReal,
    arrastreRecibido: arrastres,
    real: real,
    cierres: guardada == null ? const [] : d.cierresDe(guardada.id),
    vencimientos: vencimientosEntre(d, libroId, semana.inicio, semana.fin),
    flujo: proyectarFlujoDelLibro(d, libroId, hoy: hoy, semanas: semanasFlujo),
    balance: balance,
    patrimonioAnterior: patrimonioAnterior,
    cierreAutomaticoDias: d.parametrosDe(libroId).cierreAutomaticoDias,
  );
}

/// La foto del plan para activar la semana (`fin_semanas` con sus partidas y
/// abonos). Lleva el arrastre que trae cada partida.
///
/// Con [idPara], los ids de las partidas y los abonos salen de una clave
/// estable (`partida:<semana>:<origen>:<id>` y `abono:<semana>:<deuda>`): volver
/// a guardar la misma foto no choca con los únicos (`semana_id`, `origen`,
/// `origen_id`) y (`semana_id`, `deuda_id`).
SemanaGuardada fotoDelPlan(
  PlanDelLibro p, {
  required String id,
  required String libroId,
  required Map<String, int> arrastrePorOrigen,
  required String activadaPor,
  required DateTime activadaEn,
  String Function()? generarId,
  String Function(String clave)? idPara,
}) {
  if (generarId == null && idPara == null) {
    throw ArgumentError('Falta cómo generar los ids (generarId o idPara)');
  }
  String idDe(String clave) => idPara != null ? idPara(clave) : generarId!();
  final plan = p.plan;
  return SemanaGuardada(
    id: id,
    libroId: libroId,
    semana: plan.semana,
    estado: EstadoSemana.activa,
    ingreso: plan.ingreso,
    presupuesto: plan.presupuesto,
    deudaPlan: plan.deudaPlaneada,
    remanentePlan: plan.remanente,
    metaRemanentePuntosBase: plan.parametros.metaRemanentePuntosBase,
    ahorroMinimoConDeudaPuntosBase:
        plan.parametros.ahorroMinimoConDeudaPuntosBase,
    techo: plan.techo,
    activadaPor: activadaPor,
    activadaEn: activadaEn,
    partidas: [
      for (final r in plan.partidas)
        PartidaSemana(
          id: idDe(
            'partida:$id:${p.info(r.origen.id).origen.name}:'
            '${p.info(r.origen.id).origenId}',
          ),
          semanaId: id,
          origen: p.info(r.origen.id).origen,
          origenId: p.info(r.origen.id).origenId,
          cuentaGastoId: r.origen.cuentaGastoId,
          tipo: r.origen.tipo,
          asignado: r.semanal,
          arrastreRecibido:
              arrastrePorOrigen[p.info(r.origen.id).origenId] ?? 0,
          protegida: r.origen.protegida,
          prioridad: r.origen.prioridad,
          pisoMinimo: r.origen.pisoMinimo,
          modoArrastre: r.origen.arrastre,
        ),
    ],
    abonos: [
      for (final r in plan.abonos)
        AbonoSemana(
          id: idDe('abono:$id:${r.origen.id}'),
          semanaId: id,
          deudaId: r.origen.id,
          abonoPlaneado: r.semanal,
          minimo: () {
            final m = Equivalente.de(
              r.origen.minimo,
              r.origen.frecuencia,
            ).semanal;
            return m < r.semanal ? m : r.semanal;
          }(),
          extraPlaneado: plan.destino.extraPara(r.origen.id),
        ),
    ],
  );
}

/// La foto del cierre (`fin_cierres` y sus renglones) con el balance al
/// domingo de la semana.
CierreGuardado cierreDeLaVista(
  VistaSemana v,
  DatosFinanzas d, {
  required String id,
  required AccionCierre accion,
  required String? cerradoPor,
  required DateTime cerradoEn,
  bool conPendientes = false,
}) {
  final g = v.guardada;
  if (g == null) {
    throw StateError('Solo se cierra una semana activada');
  }
  final balance = d.vista(v.libroId).balance(al: v.semana.fin);
  final r = v.real;
  return CierreGuardado(
    id: id,
    semanaId: g.id,
    // El servidor exige la versión `reaperturas + 1` (fin_cierres_validar).
    version: g.versionDelSiguienteCierre,
    ingresoReal: r.ingresoReal,
    gastoReal: r.gastoReal,
    abonoReal: r.abonoReal,
    abonoDiferido: r.abonoDiferido,
    abonoExtraReal: r.destino.totalAbonoExtra,
    ahorroReal: r.destino.ahorro,
    deficit: r.deficit,
    arrastreSiguiente: r.arrastreSiguiente,
    accionElegida: accion,
    conPendientes: conPendientes,
    activos: balance.activos,
    pasivos: balance.pasivos,
    patrimonio: balance.patrimonio,
    cerradoPor: cerradoPor,
    cerradoEn: cerradoEn,
    partidas: [
      for (final p in r.partidas)
        CierrePartidaGuardada(
          partidaId: p.partida.id,
          gastado: p.gastado,
          arrastreSiguiente: p.arrastreSiguiente,
          alRemanente: p.alRemanente,
        ),
    ],
    abonos: [
      for (final a in r.abonos)
        CierreAbonoGuardado(
          deudaId: a.deuda.id,
          planeado: a.planeado,
          real: a.real,
          minimo: a.minimo,
        ),
    ],
  );
}

/// Gasto de cada semana que empieza (lunes) en un mes, con su promedio
/// semanal: los meses tienen 4 o 5 lunes (5.9 bis, punto 5; T8).
class MesPorSemanas {
  final int anio;
  final int mes;
  final List<(Semana, int)> semanas;

  const MesPorSemanas(this.anio, this.mes, this.semanas);

  int get total => semanas.fold(0, (t, s) => t + s.$2);

  /// Promedio semanal (R1).
  int get promedioSemanal =>
      semanas.isEmpty ? 0 : dividirRedondeando(total, semanas.length);
}

MesPorSemanas gastoDelMesPorSemanas(
  DatosFinanzas d,
  String libroId,
  int anio,
  int mes,
) {
  final vista = d.vista(libroId);
  final primero = Fecha(anio, mes, 1);
  var s = Semana.de(primero);
  if (s.inicio.antesDe(primero)) s = s.siguiente;
  final lista = <(Semana, int)>[];
  while (s.inicio.mes == mes && s.inicio.anio == anio) {
    final r = vista.estadoResultados(Periodo(s.inicio, s.fin));
    lista.add((s, r.gastos + r.gastoFinanciero));
    s = s.siguiente;
  }
  return MesPorSemanas(anio, mes, lista);
}

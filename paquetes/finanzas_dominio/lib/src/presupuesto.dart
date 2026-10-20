import 'dinero.dart';
import 'frecuencia.dart';
import 'indicadores.dart';
import 'semana.dart';

/// Motor del presupuesto semanal y la cascada (5.6 bis; decisiones 45, 46 y
/// 49 de FINANZAS):
///
/// ```text
/// INGRESO
///   − PRESUPUESTO   (egreso tipo 1: fijos, variables y reservas)
///   − DEUDA         (egreso tipo 2: abonos planeados)
///   = REMANENTE     → abono extra a deuda con costo, después a préstamos
///                     familiares; sin deuda, ahorro
/// ```
///
/// Todo se calcula en la **vista devengada** (equivalentes semanales, sección
/// 4). Los montos van en centavos con las reglas de redondeo R1 y R2 de
/// `dinero.dart`.

/// Certeza de un ingreso (5.1). Los `incierta` no cuentan en el presupuesto
/// base: se muestran aparte como "ingreso potencial".
enum Certeza { segura, probable, incierta }

/// Un ingreso recurrente que entra al plan.
class IngresoPlan {
  final String id;
  final String nombre;

  /// Monto neto en centavos por cada pago (5.1 bis: se trabaja con el neto).
  final int monto;
  final Frecuencia frecuencia;
  final int? diasActivosPorSemana;
  final Certeza certeza;

  const IngresoPlan({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.frecuencia,
    this.diasActivosPorSemana,
    this.certeza = Certeza.segura,
  });

  Equivalente get equivalente => Equivalente.de(
    monto,
    frecuencia,
    diasActivosPorSemana: diasActivosPorSemana,
  );
}

/// Naturaleza de una partida del presupuesto (5.6 bis, punto 3).
enum TipoPartida {
  /// Compromiso fijo (renta, servicios): se convierte en ocurrencias con fecha.
  fija,

  /// Sobre semanal de una cuenta de gasto por rubro.
  variable,

  /// Se aparta un monto semanal para un pago grande futuro.
  reserva,
}

/// Prioridad de la categoría (5.2): define el orden de las propuestas de
/// recorte (primero lo discrecional).
enum Prioridad { necesario, deseable, discrecional }

/// Qué pasa con lo que sobra de una partida al cerrar la semana.
enum ModoArrastre {
  /// Pasa a la semana siguiente hasta un tope (por defecto 2 semanas de su
  /// monto, decisión 49); el exceso va al remanente.
  arrastrar,

  /// Va al remanente (que paga deuda y después ahorra). Las opciones "al
  /// ahorro" y "se pierde" de 5.6 se tratan así: el dinero no desaparece y,
  /// con deuda, el remanente la paga (decisión 46).
  alRemanente,
}

/// Una partida del presupuesto (entidad `PartidaPresupuesto`, 5.6 bis).
class PartidaPlan {
  final String id;
  final String nombre;
  final TipoPartida tipo;

  /// Cuenta de gasto por rubro a la que pertenece (5.0 bis).
  final String? cuentaGastoId;
  final int monto;
  final Frecuencia frecuencia;
  final int? diasActivosPorSemana;

  /// Renta, servicios y cuidados de largo plazo: nunca se recortan solos
  /// (5.6 bis, punto 6, regla 5).
  final bool protegida;
  final Prioridad prioridad;

  /// Lo mínimo que se deja en la partida al proponer recortes (semanal).
  final int pisoMinimo;
  final ModoArrastre arrastre;

  const PartidaPlan({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.monto,
    required this.frecuencia,
    this.cuentaGastoId,
    this.diasActivosPorSemana,
    this.protegida = false,
    this.prioridad = Prioridad.necesario,
    this.pisoMinimo = 0,
    this.arrastre = ModoArrastre.alRemanente,
  });

  /// Sobre semanal de una cuenta de gasto (arrastra por defecto).
  const PartidaPlan.variable({
    required this.id,
    required this.nombre,
    required int montoSemanal,
    this.cuentaGastoId,
    this.protegida = false,
    this.prioridad = Prioridad.deseable,
    this.pisoMinimo = 0,
    this.arrastre = ModoArrastre.arrastrar,
  }) : tipo = TipoPartida.variable,
       monto = montoSemanal,
       frecuencia = Frecuencia.semanal,
       diasActivosPorSemana = null;

  /// Compromiso fijo con su frecuencia (renta, luz, internet…).
  ///
  /// Interpretación: los fijos y las reservas se cierran en la vista
  /// devengada (lo asignado se da por consumido y solo cuenta la diferencia
  /// del pago real, ver [gastoDevengado]); por eso no arrastran.
  const PartidaPlan.fija({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.frecuencia,
    this.cuentaGastoId,
    this.protegida = false,
    this.prioridad = Prioridad.necesario,
  }) : tipo = TipoPartida.fija,
       diasActivosPorSemana = null,
       pisoMinimo = 0,
       arrastre = ModoArrastre.alRemanente;

  /// Reserva para un pago grande (placas, predial…).
  const PartidaPlan.reserva({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.frecuencia,
    this.cuentaGastoId,
    this.protegida = false,
    this.prioridad = Prioridad.necesario,
  }) : tipo = TipoPartida.reserva,
       diasActivosPorSemana = null,
       pisoMinimo = 0,
       arrastre = ModoArrastre.alRemanente;

  Equivalente get equivalente => Equivalente.de(
    monto,
    frecuencia,
    diasActivosPorSemana: diasActivosPorSemana,
  );
}

/// Clase de deuda para la cascada (5.3 y decisión 51).
enum TipoDeuda {
  /// Tarjetas y créditos con interés: reciben el abono extra por tasa.
  conCosto,

  /// Préstamo entre familiares: siempre sin interés; extra al final.
  familiar,

  /// Compra a meses sin intereses: no recibe abono extra.
  msi,
}

/// Una deuda con su abono planeado (en el MVP 1 se captura lo mínimo para la
/// cascada; el módulo completo de deudas es de la Fase 2).
class DeudaPlan {
  final String id;
  final String nombre;
  final TipoDeuda tipo;

  /// Abono acordado por pago, en centavos, con su [frecuencia].
  final int abono;
  final Frecuencia frecuencia;

  /// Pago mínimo exigible por pago (misma frecuencia que el abono). En MSI es
  /// toda la mensualidad; en préstamos familiares, cero.
  final int minimo;

  /// Tasa anual en puntos base (4800 = 48 %). Obligatoria y mayor que cero en
  /// deudas con costo; cero en familiares y MSI.
  final int tasaAnualPuntosBase;

  /// Saldo actual (opcional): limita cuánto abono extra puede recibir.
  final int? saldo;

  /// Prioridad fijada por la persona (1 = primero). Pasa por encima del orden
  /// por costo (5.3, prioridad de pago, punto 4).
  final int? prioridadManual;

  DeudaPlan({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.abono,
    required this.frecuencia,
    int minimo = 0,
    this.tasaAnualPuntosBase = 0,
    this.saldo,
    this.prioridadManual,
  }) : minimo = tipo == TipoDeuda.msi ? abono : minimo {
    if (abono < 0 || minimo < 0) {
      throw ArgumentError('Abono y mínimo no pueden ser negativos ($id)');
    }
    if (tipo == TipoDeuda.conCosto && tasaAnualPuntosBase <= 0) {
      throw ArgumentError(
        'Una deuda con costo necesita su tasa anual mayor que cero ($id). '
        'Si no se conoce, se captura del estado de cuenta.',
      );
    }
    if (tipo != TipoDeuda.conCosto && tasaAnualPuntosBase != 0) {
      throw ArgumentError('Préstamos familiares y MSI no llevan tasa ($id)');
    }
  }

  Equivalente get equivalente => Equivalente.de(abono, frecuencia);

  /// La misma deuda con otro saldo.
  DeudaPlan conSaldo(int nuevoSaldo) => DeudaPlan(
    id: id,
    nombre: nombre,
    tipo: tipo,
    abono: abono,
    frecuencia: frecuencia,
    minimo: minimo,
    tasaAnualPuntosBase: tasaAnualPuntosBase,
    saldo: nuevoSaldo,
    prioridadManual: prioridadManual,
  );

  /// Interés en pesos por año (desempate del orden, 5.3).
  int get interesAnualEstimado =>
      aplicarPorcentaje(saldo ?? 0, tasaAnualPuntosBase);
}

/// Parámetros del hogar para el motor.
class ParametrosPlan {
  /// Meta de remanente: 20 % del ingreso (decisión 46). Es una **meta**, no un
  /// apartado previo.
  final int metaRemanentePuntosBase;

  /// Parte del remanente que va a ahorro aunque haya deuda. 0 % por defecto
  /// (decisión 46, confirmada).
  ///
  /// Interpretación conservadora: es un porcentaje **del remanente** (nunca
  /// del ingreso), así no puede quitar dinero al presupuesto ni a los abonos.
  final int ahorroMinimoConDeudaPuntosBase;

  /// Tope del arrastre en semanas del monto de la partida (decisión 49).
  final int topeArrastreSemanas;

  final Umbrales umbrales;

  const ParametrosPlan({
    this.metaRemanentePuntosBase = 2000,
    this.ahorroMinimoConDeudaPuntosBase = 0,
    this.topeArrastreSemanas = 2,
    this.umbrales = Umbrales.porDefecto,
  });
}

/// Un renglón del plan con su monto semanal ya repartido (regla R2).
class Renglon<T> {
  final T origen;
  final int semanal;

  const Renglon(this.origen, this.semanal);
}

/// Abono extra propuesto a una deuda.
class AbonoExtra {
  final DeudaPlan deuda;
  final int monto;

  const AbonoExtra(this.deuda, this.monto);
}

/// A dónde va el remanente (5.6 bis, punto 4, paso 6, y punto 7).
class DestinoRemanente {
  final List<AbonoExtra> abonosExtra;
  final int ahorro;

  const DestinoRemanente(this.abonosExtra, this.ahorro);

  static const DestinoRemanente vacio = DestinoRemanente([], 0);

  int get totalAbonoExtra => abonosExtra.fold(0, (t, a) => t + a.monto);

  int extraPara(String deudaId) => abonosExtra
      .where((a) => a.deuda.id == deudaId)
      .fold(0, (t, a) => t + a.monto);
}

/// Montos de un periodo de visualización (5.6 bis, punto 2).
class ResumenPeriodo {
  final TipoPeriodo periodo;
  final int ingreso;
  final int presupuesto;
  final int deuda;

  const ResumenPeriodo(this.periodo, this.ingreso, this.presupuesto, this.deuda);

  int get remanente => ingreso - presupuesto - deuda;
}

/// El plan de una semana (entidad `PresupuestoSemana`, 5.6 bis punto 11).
class PlanSemanal {
  final Semana semana;
  final ParametrosPlan parametros;
  final List<Renglon<IngresoPlan>> ingresos;

  /// Ingresos `incierta`: se muestran como potencial y no cuentan.
  final List<Renglon<IngresoPlan>> ingresosPotenciales;
  final List<Renglon<PartidaPlan>> partidas;
  final List<Renglon<DeudaPlan>> abonos;

  /// Sumas exactas (anuales) para las vistas por periodo.
  final Equivalente ingresoEquivalente;
  final Equivalente presupuestoEquivalente;
  final Equivalente deudaEquivalente;

  /// Destino propuesto del remanente planeado.
  final DestinoRemanente destino;

  const PlanSemanal._({
    required this.semana,
    required this.parametros,
    required this.ingresos,
    required this.ingresosPotenciales,
    required this.partidas,
    required this.abonos,
    required this.ingresoEquivalente,
    required this.presupuestoEquivalente,
    required this.deudaEquivalente,
    required this.destino,
  });

  /// INGRESO semanal (solo `segura` y `probable`).
  int get ingreso => ingresoEquivalente.semanal;

  int get ingresoPotencial => ingresosPotenciales.fold(0, (t, r) => t + r.semanal);

  /// PRESUPUESTO (egreso tipo 1).
  int get presupuesto => presupuestoEquivalente.semanal;

  /// DEUDA planeada (egreso tipo 2).
  int get deudaPlaneada => deudaEquivalente.semanal;

  /// REMANENTE planeado = ingreso − presupuesto − deuda (con los totales ya
  /// redondeados, así la cascada siempre cuadra en pantalla).
  int get remanente => ingreso - presupuesto - deudaPlaneada;

  /// Meta de remanente (20 % del ingreso por defecto).
  int get metaRemanente =>
      aplicarPorcentaje(ingreso, parametros.metaRemanentePuntosBase);

  /// Lo que el remanente supera (o le falta a) la meta.
  int get diferenciaContraMeta => remanente - metaRemanente;

  /// Techo de presupuesto = ingreso − deuda planeada − meta de remanente
  /// (5.6 bis, punto 4, paso 7).
  int get techo => ingreso - deudaPlaneada - metaRemanente;

  bool get dentroDelTecho => presupuesto <= techo;

  /// El plan no alcanza: el presupuesto y la deuda superan el ingreso.
  bool get enDeficit => remanente < 0;

  /// Resultado del periodo (ingreso − gasto) = remanente + abonos; aumenta
  /// el patrimonio (5.6 bis, punto 5).
  int get resultado => ingreso - presupuesto;

  int get tasaRemanentePuntosBase => proporcionEnPuntosBase(remanente, ingreso);
  int get tasaResultadoPuntosBase => proporcionEnPuntosBase(resultado, ingreso);
  int get cargaDeudaPuntosBase => proporcionEnPuntosBase(deudaPlaneada, ingreso);

  Semaforo get semaforoDelRemanente =>
      semaforoRemanente(remanente, ingreso, umbrales: parametros.umbrales);

  Semaforo get semaforoDeLaCarga =>
      semaforoCargaDeuda(deudaPlaneada, ingreso, umbrales: parametros.umbrales);

  int asignadoA(String partidaId) =>
      partidas.firstWhere((r) => r.origen.id == partidaId).semanal;

  int abonoPlaneadoA(String deudaId) =>
      abonos.firstWhere((r) => r.origen.id == deudaId).semanal;

  /// Ingreso, presupuesto y deuda en el periodo que la persona eligió ver
  /// (semana, catorcena = ×2, quincena = ×52÷24, mes = ×52÷12).
  ResumenPeriodo enPeriodo(TipoPeriodo periodo) => ResumenPeriodo(
    periodo,
    ingresoEquivalente.enPeriodo(periodo),
    presupuestoEquivalente.enPeriodo(periodo),
    deudaEquivalente.enPeriodo(periodo),
  );
}

List<Renglon<T>> _renglones<T>(List<T> origenes, Equivalente Function(T) eq) {
  final semanales = semanalesQueSuman([for (final o in origenes) eq(o)]);
  return List.unmodifiable([
    for (var i = 0; i < origenes.length; i++) Renglon(origenes[i], semanales[i]),
  ]);
}

/// Arma el plan de [semana] (5.6 bis, punto 4, pasos 2 a 7).
PlanSemanal armarPlanSemanal({
  required Semana semana,
  required List<IngresoPlan> ingresos,
  required List<PartidaPlan> partidas,
  List<DeudaPlan> deudas = const [],
  ParametrosPlan parametros = const ParametrosPlan(),
}) {
  _validarIds(partidas.map((p) => p.id), 'partida');
  _validarIds(deudas.map((d) => d.id), 'deuda');
  final contados = ingresos.where((i) => i.certeza != Certeza.incierta).toList();
  final inciertos = ingresos.where((i) => i.certeza == Certeza.incierta).toList();

  final renglonesIngreso = _renglones(contados, (i) => i.equivalente);
  final renglonesPartida = _renglones(partidas, (p) => p.equivalente);
  final renglonesAbono = _renglones(deudas, (d) => d.equivalente);

  final ingresoEq = Equivalente.suma(contados.map((i) => i.equivalente));
  final presupuestoEq = Equivalente.suma(partidas.map((p) => p.equivalente));
  final deudaEq = Equivalente.suma(deudas.map((d) => d.equivalente));

  final remanente = ingresoEq.semanal - presupuestoEq.semanal - deudaEq.semanal;
  final destino = repartirRemanente(
    remanente,
    {for (final r in renglonesAbono) r.origen: r.semanal},
    parametros: parametros,
  );

  return PlanSemanal._(
    semana: semana,
    parametros: parametros,
    ingresos: renglonesIngreso,
    ingresosPotenciales: _renglones(inciertos, (i) => i.equivalente),
    partidas: renglonesPartida,
    abonos: renglonesAbono,
    ingresoEquivalente: ingresoEq,
    presupuestoEquivalente: presupuestoEq,
    deudaEquivalente: deudaEq,
    destino: destino,
  );
}

void _validarIds(Iterable<String> ids, String que) {
  final vistos = <String>{};
  for (final id in ids) {
    if (!vistos.add(id)) throw ArgumentError('Hay dos $que con el id $id');
  }
}

/// Orden en que las deudas reciben el **abono extra** (5.3 y decisión 51):
///
/// 1. Las que tienen prioridad manual, de menor a mayor número.
/// 2. Deudas con costo por **mayor tasa**; desempate por mayor interés en
///    pesos y después por id.
/// 3. Préstamos familiares (sin interés), al final.
///
/// Las compras a MSI **no reciben extra** (salvo con prioridad manual).
List<DeudaPlan> ordenDeAbonoExtra(Iterable<DeudaPlan> deudas) {
  final manuales = deudas.where((d) => d.prioridadManual != null).toList()
    ..sort((a, b) {
      final p = a.prioridadManual!.compareTo(b.prioridadManual!);
      return p != 0 ? p : a.id.compareTo(b.id);
    });
  final conCosto = deudas
      .where((d) => d.prioridadManual == null && d.tipo == TipoDeuda.conCosto)
      .toList()
    ..sort((a, b) {
      final t = b.tasaAnualPuntosBase.compareTo(a.tasaAnualPuntosBase);
      if (t != 0) return t;
      final i = b.interesAnualEstimado.compareTo(a.interesAnualEstimado);
      return i != 0 ? i : a.id.compareTo(b.id);
    });
  final familiares = deudas
      .where((d) => d.prioridadManual == null && d.tipo == TipoDeuda.familiar)
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return [...manuales, ...conCosto, ...familiares];
}

/// Reparte el [remanente] según 5.6 bis, punto 7: abono extra a las deudas en
/// [ordenDeAbonoExtra] (sin pasar de su saldo menos el abono ya aplicado) y,
/// cuando ya no hay deuda, ahorro. Con [ParametrosPlan.ahorroMinimoConDeudaPuntosBase]
/// una parte va a ahorro desde el inicio.
///
/// [abonosAplicados] es el abono (planeado o real) de cada deuda en la semana.
DestinoRemanente repartirRemanente(
  int remanente,
  Map<DeudaPlan, int> abonosAplicados, {
  ParametrosPlan parametros = const ParametrosPlan(),
}) {
  if (remanente <= 0) return DestinoRemanente.vacio;
  int? capacidad(DeudaPlan d) {
    final saldo = d.saldo;
    if (saldo == null) return null; // sin saldo capturado: sin límite
    final c = saldo - (abonosAplicados[d] ?? 0);
    return c > 0 ? c : 0;
  }

  final elegibles = ordenDeAbonoExtra(
    abonosAplicados.keys,
  ).where((d) => capacidad(d) != 0).toList();
  if (elegibles.isEmpty) return DestinoRemanente(const [], remanente);

  final ahorroMinimo = aplicarPorcentaje(
    remanente,
    parametros.ahorroMinimoConDeudaPuntosBase,
  );
  var porRepartir = remanente - ahorroMinimo;
  final extras = <AbonoExtra>[];
  for (final d in elegibles) {
    if (porRepartir <= 0) break;
    final tope = capacidad(d);
    final monto = tope == null || tope > porRepartir ? porRepartir : tope;
    extras.add(AbonoExtra(d, monto));
    porRepartir -= monto;
  }
  return DestinoRemanente(List.unmodifiable(extras), ahorroMinimo + porRepartir);
}

/// Gasto devengado de una partida fija o de reserva en la semana: lo
/// asignado, más la diferencia entre lo **pagado** y lo **esperado** en las
/// ocurrencias que se pagaron esa semana.
///
/// Interpretación: el plan y el cierre se hacen en la vista devengada; la
/// fecha real del pago la cuida la vista de flujo. Así, una renta mensual no
/// aparece como "sobregasto" en la semana en que se paga, y una luz que llegó
/// $200 más cara sí.
int gastoDevengado(int asignadoSemanal, Iterable<(int esperado, int pagado)> pagos) =>
    asignadoSemanal + pagos.fold(0, (t, p) => t + p.$2 - p.$1);

/// Estado de una partida al cierre de la semana.
class CierrePartida {
  final PartidaPlan partida;
  final int asignado;
  final int arrastreRecibido;
  final int gastado;

  /// Lo que pasa a la semana siguiente (con tope).
  final int arrastreSiguiente;

  /// Sobrante que va al remanente.
  final int alRemanente;
  final Semaforo semaforo;

  const CierrePartida({
    required this.partida,
    required this.asignado,
    required this.arrastreRecibido,
    required this.gastado,
    required this.arrastreSiguiente,
    required this.alRemanente,
    required this.semaforo,
  });

  int get disponible => asignado + arrastreRecibido;
  int get restante => disponible - gastado;
  int get sobregasto => gastado > disponible ? gastado - disponible : 0;
  bool get dentro => sobregasto == 0;
}

/// Abono real de una deuda al cierre.
class AbonoReal {
  final DeudaPlan deuda;
  final int planeado;
  final int real;

  /// Mínimo exigible semanal.
  final int minimo;

  const AbonoReal(this.deuda, this.planeado, this.real, this.minimo);

  /// Lo no abonado: **no reduce el saldo** de la deuda (5.6 bis, punto 6).
  int get diferido => planeado - real;

  /// Alerta roja: el abono quedó por debajo del mínimo exigible.
  bool get bajoMinimo => minimo > 0 && real < minimo;
}

/// Resultado del cierre semanal (entidad `CierreSemana`, 5.6 bis punto 11).
class CierreSemanal {
  final PlanSemanal plan;
  final int ingresoReal;
  final int gastoReal;
  final List<CierrePartida> partidas;
  final List<AbonoReal> abonos;

  /// Remanente real (abono extra o ahorro).
  final int remanenteReal;

  /// Faltante que se cubre con saldo de cuentas o con deuda nueva.
  final int deficit;
  final DestinoRemanente destino;

  const CierreSemanal._({
    required this.plan,
    required this.ingresoReal,
    required this.gastoReal,
    required this.partidas,
    required this.abonos,
    required this.remanenteReal,
    required this.deficit,
    required this.destino,
  });

  int get abonoReal => abonos.fold(0, (t, a) => t + a.real);
  int get abonoDiferido => abonos.fold(0, (t, a) => t + a.diferido);
  int get arrastreSiguiente => partidas.fold(0, (t, p) => t + p.arrastreSiguiente);

  /// Lo que el gasto real superó al presupuesto de la semana.
  int get sobregasto {
    final s = gastoReal - plan.presupuesto;
    return s > 0 ? s : 0;
  }

  List<CierrePartida> get partidasPasadas =>
      partidas.where((p) => !p.dentro).toList();

  List<AbonoReal> get abonosBajoMinimo =>
      abonos.where((a) => a.bajoMinimo).toList();

  int get tasaRemanentePuntosBase =>
      proporcionEnPuntosBase(remanenteReal, ingresoReal);

  Semaforo get semaforoDelRemanente => semaforoRemanente(
    remanenteReal,
    ingresoReal,
    umbrales: plan.parametros.umbrales,
  );

  Semaforo get semaforoDelCumplimiento => semaforoCumplimiento(
    partidas.where((p) => p.dentro).length,
    partidas.length,
    umbrales: plan.parametros.umbrales,
  );
}

/// Cierra la semana: compara lo real contra el plan y aplica la **regla de
/// sobregasto** (5.6 bis, punto 6) y el **arrastre** (punto 8, decisión 49).
///
/// - [ingresoReal]: ingreso devengado de la semana, más los extras que
///   llegaron en ella, menos lo que no llegó (interpretación conservadora: un
///   ingreso retrasado o perdido resta completo en la semana en que debía
///   llegar).
/// - [gastadoPorPartida]: gasto de cada partida (id → centavos). En variables,
///   la suma de sus movimientos; en fijas y reservas, [gastoDevengado].
/// - [arrastreRecibido]: sobrante que cada partida trae de semanas anteriores.
/// - [gastoSinPartida]: gasto que no corresponde a ninguna partida (por
///   ejemplo, "Por clasificar").
///
/// Orden de absorción del sobregasto: primero el **remanente**, después el
/// **abono planeado** a la deuda (lo no abonado queda como abono diferido) y
/// al final el **déficit**.
CierreSemanal cerrarSemana(
  PlanSemanal plan, {
  required int ingresoReal,
  required Map<String, int> gastadoPorPartida,
  Map<String, int> arrastreRecibido = const {},
  int gastoSinPartida = 0,
}) {
  final ids = {for (final r in plan.partidas) r.origen.id};
  for (final id in [...gastadoPorPartida.keys, ...arrastreRecibido.keys]) {
    if (!ids.contains(id)) {
      throw ArgumentError('La partida $id no está en el plan');
    }
  }
  final p = plan.parametros;
  final cierres = <CierrePartida>[];
  for (final r in plan.partidas) {
    final partida = r.origen;
    final recibido = arrastreRecibido[partida.id] ?? 0;
    final gastado = gastadoPorPartida[partida.id] ?? 0;
    final sobrante = r.semanal + recibido - gastado;
    var siguiente = 0;
    var alRemanente = 0;
    if (sobrante > 0) {
      if (partida.arrastre == ModoArrastre.arrastrar) {
        final tope = p.topeArrastreSemanas * r.semanal;
        siguiente = sobrante < tope ? sobrante : tope;
      }
      alRemanente = sobrante - siguiente;
    }
    cierres.add(
      CierrePartida(
        partida: partida,
        asignado: r.semanal,
        arrastreRecibido: recibido,
        gastado: gastado,
        arrastreSiguiente: siguiente,
        alRemanente: alRemanente,
        semaforo: semaforoPartida(gastado, r.semanal + recibido, umbrales: p.umbrales),
      ),
    );
  }

  final gastoReal = cierres.fold(0, (t, c) => t + c.gastado) + gastoSinPartida;
  final recibidoTotal = cierres.fold(0, (t, c) => t + c.arrastreRecibido);
  final siguienteTotal = cierres.fold(0, (t, c) => t + c.arrastreSiguiente);
  final disponible = ingresoReal - gastoReal + recibidoTotal - siguienteTotal;

  final deudaPlaneada = plan.deudaPlaneada;
  final abonoTotal = disponible <= 0
      ? 0
      : (disponible >= deudaPlaneada ? deudaPlaneada : disponible);
  final remanenteReal = disponible > deudaPlaneada ? disponible - deudaPlaneada : 0;
  final deficit = disponible < 0 ? -disponible : 0;

  final abonos = _repartirAbonoReal(plan.abonos, deudaPlaneada - abonoTotal);
  final destino = repartirRemanente(remanenteReal, {
    for (final a in abonos) a.deuda: a.real,
  }, parametros: p);

  return CierreSemanal._(
    plan: plan,
    ingresoReal: ingresoReal,
    gastoReal: gastoReal,
    partidas: List.unmodifiable(cierres),
    abonos: List.unmodifiable(abonos),
    remanenteReal: remanenteReal,
    deficit: deficit,
    destino: destino,
  );
}

/// Reduce los abonos planeados en [reduccion] centavos, en el orden de 5.6
/// bis, punto 6, regla 3:
///
/// 1. Primero los **préstamos familiares** (siempre los últimos en pagarse).
/// 2. Después, en tarjetas y créditos, lo que pasa del mínimo, de **menor a
///    mayor costo** (tasa).
/// 3. Al final los **pagos mínimos**, también de menor a mayor costo.
///
/// Interpretación: las mensualidades de MSI cuentan completas como mínimo y
/// son lo último que se reduce (no pagarlas puede costar la promoción).
List<AbonoReal> _repartirAbonoReal(
  List<Renglon<DeudaPlan>> planeados,
  int reduccion,
) {
  final real = {for (final r in planeados) r.origen.id: r.semanal};
  final minimo = {
    for (final r in planeados)
      r.origen.id: () {
        final m = Equivalente.de(r.origen.minimo, r.origen.frecuencia).semanal;
        return m < r.semanal ? m : r.semanal;
      }(),
  };
  var falta = reduccion;
  void reducir(Iterable<DeudaPlan> orden, int Function(DeudaPlan) reducible) {
    for (final d in orden) {
      if (falta <= 0) return;
      final puede = reducible(d);
      final quita = puede < falta ? puede : falta;
      real[d.id] = real[d.id]! - quita;
      falta -= quita;
    }
  }

  final deudas = [for (final r in planeados) r.origen];
  final familiares = ordenDeAbonoExtra(
    deudas.where((d) => d.tipo == TipoDeuda.familiar),
  ).reversed;
  final porCostoAscendente =
      deudas.where((d) => d.tipo == TipoDeuda.conCosto).toList()..sort((a, b) {
        final t = a.tasaAnualPuntosBase.compareTo(b.tasaAnualPuntosBase);
        return t != 0 ? t : a.id.compareTo(b.id);
      });
  final msi = deudas.where((d) => d.tipo == TipoDeuda.msi).toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  reducir(familiares, (d) => real[d.id]!);
  reducir(porCostoAscendente, (d) => real[d.id]! - minimo[d.id]!);
  reducir([...porCostoAscendente, ...msi], (d) => real[d.id]!);

  return [
    for (final r in planeados)
      AbonoReal(r.origen, r.semanal, real[r.origen.id]!, minimo[r.origen.id]!),
  ];
}

/// Un recorte propuesto a una partida.
class Recorte {
  final PartidaPlan partida;
  final int monto;

  const Recorte(this.partida, this.monto);
}

/// Propuesta de recortes para cubrir [monto] (5.6 bis, punto 6, reglas 5 y 6).
class PropuestaRecortes {
  final List<Recorte> recortes;

  /// Lo que no se pudo cubrir sin tocar lo protegido.
  final int faltante;

  const PropuestaRecortes(this.recortes, this.faltante);

  int get total => recortes.fold(0, (t, r) => t + r.monto);
}

/// Propone recortes por [monto] en las partidas **no protegidas**: primero lo
/// discrecional, luego lo deseable y al final lo necesario; dentro de cada
/// prioridad, la partida con más margen primero. Respeta el piso mínimo y lo
/// ya gastado. Los gastos protegidos **nunca** aparecen (prueba 7 de 5.6 bis).
///
/// Es solo una propuesta: la app no mueve dinero sola.
///
/// [estado] trae, por partida, lo disponible (asignado más arrastre) y lo
/// gastado en la semana.
PropuestaRecortes proponerRecortes(
  int monto,
  List<({PartidaPlan partida, int disponible, int gastado})> estado,
) {
  int margen(({PartidaPlan partida, int disponible, int gastado}) e) {
    final usado = e.gastado > e.partida.pisoMinimo ? e.gastado : e.partida.pisoMinimo;
    final m = e.disponible - usado;
    return m > 0 ? m : 0;
  }

  final candidatas = estado
      .where((e) => !e.partida.protegida && margen(e) > 0)
      .toList()
    ..sort((a, b) {
      final p = b.partida.prioridad.index.compareTo(a.partida.prioridad.index);
      if (p != 0) return p;
      final m = margen(b).compareTo(margen(a));
      return m != 0 ? m : a.partida.id.compareTo(b.partida.id);
    });
  var falta = monto;
  final recortes = <Recorte>[];
  for (final e in candidatas) {
    if (falta <= 0) break;
    final quita = margen(e) < falta ? margen(e) : falta;
    recortes.add(Recorte(e.partida, quita));
    falta -= quita;
  }
  return PropuestaRecortes(List.unmodifiable(recortes), falta > 0 ? falta : 0);
}

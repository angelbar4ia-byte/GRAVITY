import 'datos_finanzas.dart';
import 'dinero.dart';
import 'frecuencia.dart';
import 'fecha.dart';
import 'libro.dart';
import 'presupuesto.dart';
import 'semana.dart';

/// Dispersión de ingresos con confirmación (Fase 8, paquete F8-6.4;
/// `docs/specs/fase-8-finanzas-dispersion.md`).
///
/// Cada ingreso que entra al libro se **reparte** con la cascada del diseño
/// (5.6 bis, puntos 1 y 7, y 5.1 bis, punto 4):
///
/// ```text
/// INGRESO → PRESUPUESTO → DEUDA (mínimos y abonos) → REMANENTE
///   REMANENTE → abono extra a la deuda de mayor costo (después, préstamos
///               familiares); sin deuda, ahorro
/// ```
///
/// Este archivo **no repite** las reglas de la cascada: arma la propuesta con
/// [PlanSemanal] (sumas y equivalentes exactos), [ordenDeAbonoExtra] y
/// [repartirRemanente] (destino del remanente) y [proponerRecortes] (qué se
/// recorta primero cuando el ingreso no alcanza).
///
/// Reglas de oro: dinero en centavos con redondeo R1/R2 (`dinero.dart`);
/// **la app propone y la persona confirma** (5.6 bis, punto 6); nada se edita
/// (el libro es solo-agregar, también al corregir el tipo de un ingreso).

/// Error de una regla de la dispersión (propuesta editada que no cuadra,
/// corrección de tipo no permitida…). El mensaje va listo para la pantalla.
class ErrorDispersion implements Exception {
  final String mensaje;
  const ErrorDispersion(this.mensaje);

  @override
  String toString() => 'ErrorDispersion: $mensaje';
}

/// Cómo se aplica la dispersión (decisión 1 del dueño, 18/nov/2026).
enum ModoDispersion {
  /// Lo normal: la persona valida o edita antes de aplicar.
  confirmacion,

  /// Si el ingreso cubre todo lo comprometido (presupuesto y pagos de deuda
  /// del periodo), la app asigna sola **lo comprometido**. El remanente (abono
  /// extra o ahorro) queda "por repartir" hasta que la persona lo confirme:
  /// la app no mueve dinero sola (5.6 bis, punto 6). *Pregunta abierta P1.*
  automatico,
}

/// Estado de un ingreso respecto de su reparto.
enum EstadoDispersion {
  /// Entró y nadie lo repartió: todo el monto está por repartir.
  porRepartir,

  /// Hay una propuesta guardada (con ediciones) sin confirmar: sigue por
  /// repartir.
  propuesta,

  /// La persona la confirmó.
  confirmada,

  /// Se aplicó sola (modo automático).
  automatica,

  /// El ingreso se anuló o se corrigió su tipo: el reparto ya no vale.
  anulada,

  /// Se **cambió** el reparto (P5): otra versión lo sustituyó. Conserva su
  /// historial pero ya no es el vigente.
  reemplazada;

  /// Lo que falta decidir: cuenta en "Por repartir".
  bool get pendiente => this == porRepartir || this == propuesta;

  bool get aplicada => this == confirmada || this == automatica;

  /// El reparto que cuenta hoy para el ingreso (ni anulado ni reemplazado).
  bool get vigente => this != anulada && this != reemplazada;
}

/// A dónde va un renglón de la dispersión.
enum DestinoLinea {
  /// Sobre o compromiso de la semana (se asigna en el plan; no mueve dinero).
  presupuesto,

  /// Abono planeado a una deuda: se aparta para pagarlo en su fecha (el pago
  /// se registra con "Registrar pago"; no mueve dinero al confirmar).
  pagoDeuda,

  /// Abono extra a una deuda: sí mueve dinero (pago de deuda) al confirmar.
  abonoExtra,

  /// Ahorro: sí mueve dinero (transferencia a la cuenta de ahorro).
  ahorro,

  /// Parte libre (premio o gasto personal; 5.1 bis, punto 4, paso 5).
  libre,

  /// Lo no repartido: se arrastra a la semana actual y cuenta en "Quedan".
  porRepartir;

  /// Mueve dinero entre cuentas al confirmar.
  bool get mueveDinero => this == abonoExtra || this == ahorro;
}

/// Un renglón de la propuesta (o de la dispersión guardada).
class LineaDispersion {
  final DestinoLinea destino;

  /// Id de la partida (presupuesto) o de la deuda; nulo en ahorro, libre y
  /// por repartir.
  final String? referenciaId;
  final String etiqueta;

  /// Centavos, cero o positivo.
  final int monto;

  const LineaDispersion({
    required this.destino,
    this.referenciaId,
    required this.etiqueta,
    required this.monto,
  });

  LineaDispersion conMonto(int nuevo) => LineaDispersion(
    destino: destino,
    referenciaId: referenciaId,
    etiqueta: etiqueta,
    monto: nuevo,
  );

  @override
  bool operator ==(Object other) =>
      other is LineaDispersion &&
      other.destino == destino &&
      other.referenciaId == referenciaId &&
      other.etiqueta == etiqueta &&
      other.monto == monto;

  @override
  int get hashCode => Object.hash(destino, referenciaId, etiqueta, monto);

  @override
  String toString() => '${destino.name} $etiqueta $monto';
}

/// Parámetros de la dispersión (por libro).
class ParametrosDispersion {
  /// Lo normal es [ModoDispersion.confirmacion].
  final ModoDispersion modo;

  /// Solo los ingresos con fecha desde este día piden reparto; lo anterior se
  /// da por repartido (así no se llena de pendientes el historial al activar
  /// la función). Nulo = todos.
  final Fecha? desde;

  /// De un **extra**, la parte libre (por defecto 0 %, en línea con "primero
  /// la deuda"; 5.1 bis, punto 4). Es un porcentaje del remanente.
  final int parteLibrePuntosBase;

  /// Tope del ahorro de un ingreso (la meta); lo que pasa del tope queda
  /// libre (5.6 bis, punto 7, regla 3). Nulo = sin tope.
  final int? topeAhorro;

  const ParametrosDispersion({
    this.modo = ModoDispersion.confirmacion,
    this.desde,
    this.parteLibrePuntosBase = 0,
    this.topeAhorro,
  });
}

/// Un ingreso del libro con su estado de reparto.
class IngresoPorRepartir {
  /// El movimiento de ingreso en el libro (su id es la clave del reparto).
  final String movimientoId;
  final String libroId;

  /// Fecha económica: la semana de la fecha es su semana de origen.
  final Fecha fecha;
  final int monto;
  final String cuentaDestinoId;

  /// Nombre de la cuenta de origen ("Sueldo de Ana", "Extras").
  final String nombre;

  /// Id del ingreso configurado (sueldo) del que viene; nulo en un extra.
  final String? ingresoPlanId;
  final EstadoDispersion estado;

  /// Id de la dispersión guardada, si la hay.
  final String? dispersionId;

  /// Lo que sigue sin repartir de este ingreso (todo el monto mientras está
  /// pendiente; en uno aplicado, el renglón "por repartir").
  final int pendiente;

  const IngresoPorRepartir({
    required this.movimientoId,
    required this.libroId,
    required this.fecha,
    required this.monto,
    required this.cuentaDestinoId,
    required this.nombre,
    this.ingresoPlanId,
    this.estado = EstadoDispersion.porRepartir,
    this.dispersionId,
    int? pendiente,
  }) : pendiente = pendiente ?? monto;

  Semana get semana => Semana.de(fecha);

  /// Viene de un ingreso configurado (sueldo); si no, es un extra.
  bool get esSueldo => ingresoPlanId != null;
}

/// La propuesta de reparto de un ingreso: editable hasta confirmarla.
class PropuestaDispersion {
  final String movimientoId;
  final int monto;
  final List<LineaDispersion> lineas;

  /// Lo que le falta al ingreso para cubrir presupuesto y deuda del periodo
  /// (cero si los cubre).
  final int faltante;

  /// Destino calculado del remanente (por deuda y ahorro), tal como lo da la
  /// cascada.
  final DestinoRemanente destinoRemanente;

  PropuestaDispersion({
    required this.movimientoId,
    required this.monto,
    required Iterable<LineaDispersion> lineas,
    this.faltante = 0,
    this.destinoRemanente = DestinoRemanente.vacio,
  }) : lineas = List.unmodifiable(lineas);

  int _suma(DestinoLinea d) =>
      lineas.where((l) => l.destino == d).fold<int>(0, (t, l) => t + l.monto);

  List<LineaDispersion> _de(DestinoLinea d) =>
      lineas.where((l) => l.destino == d).toList();

  /// Partidas propuestas (presupuesto de la semana).
  List<LineaDispersion> get partidas => _de(DestinoLinea.presupuesto);

  /// Pagos a deuda: mínimos y abonos planeados, apartados para su fecha.
  List<LineaDispersion> get pagosDeuda => _de(DestinoLinea.pagoDeuda);

  List<LineaDispersion> get abonosExtra => _de(DestinoLinea.abonoExtra);

  int get totalPresupuesto => _suma(DestinoLinea.presupuesto);
  int get totalPagosDeuda => _suma(DestinoLinea.pagoDeuda);
  int get totalAbonoExtra => _suma(DestinoLinea.abonoExtra);
  int get ahorro => _suma(DestinoLinea.ahorro);
  int get libre => _suma(DestinoLinea.libre);

  /// Remanente propuesto (abono extra + ahorro + parte libre).
  int get remanente => totalAbonoExtra + ahorro + libre;

  int get totalRepartido => lineas.fold<int>(0, (t, l) => t + l.monto);

  /// Lo que queda por repartir: el monto menos los renglones. Cero en una
  /// propuesta completa; positivo si la persona quitó algo. Se arrastra a la
  /// semana actual y cuenta en "Quedan".
  int get quedaPorRepartir => monto - totalRepartido;

  /// El ingreso cubre presupuesto y pagos de deuda del periodo.
  bool get cubreTodo => faltante == 0;

  /// Los renglones que mueven dinero (abono extra y ahorro).
  bool get mueveDinero =>
      lineas.any((l) => l.destino.mueveDinero && l.monto > 0);

  /// Cambia el monto del renglón [indice]. No puede pasar de lo que queda por
  /// repartir más el monto actual del renglón, ni ser negativo.
  PropuestaDispersion editar(int indice, int nuevoMonto) {
    if (indice < 0 || indice >= lineas.length) {
      throw const ErrorDispersion('Ese renglón no existe.');
    }
    if (nuevoMonto < 0) {
      throw const ErrorDispersion('El monto no puede ser negativo.');
    }
    final disponible = quedaPorRepartir + lineas[indice].monto;
    if (nuevoMonto > disponible) {
      throw const ErrorDispersion(
        'Ese monto pasa de lo que queda por repartir del ingreso.',
      );
    }
    final nuevas = [...lineas];
    nuevas[indice] = nuevas[indice].conMonto(nuevoMonto);
    return PropuestaDispersion(
      movimientoId: movimientoId,
      monto: monto,
      lineas: nuevas,
      faltante: faltante,
      destinoRemanente: destinoRemanente,
    );
  }

  /// Los renglones que se guardan: los de la propuesta (sin los de cero) más
  /// un renglón "por repartir" con lo que no se repartió.
  List<LineaDispersion> lineasParaGuardar() => [
    for (final l in lineas)
      if (l.monto > 0 && l.destino != DestinoLinea.porRepartir) l,
    if (quedaPorRepartir > 0)
      LineaDispersion(
        destino: DestinoLinea.porRepartir,
        etiqueta: 'Por repartir',
        monto: quedaPorRepartir,
      ),
  ];

  /// La versión del modo automático: solo lo comprometido (presupuesto y
  /// pagos de deuda); el remanente queda por repartir.
  List<LineaDispersion> lineasAutomaticas() {
    final comprometido = [
      for (final l in lineas)
        if (l.monto > 0 &&
            (l.destino == DestinoLinea.presupuesto ||
                l.destino == DestinoLinea.pagoDeuda))
          l,
    ];
    final resto = monto - comprometido.fold<int>(0, (t, l) => t + l.monto);
    return [
      ...comprometido,
      if (resto > 0)
        LineaDispersion(
          destino: DestinoLinea.porRepartir,
          etiqueta: 'Por repartir',
          monto: resto,
        ),
    ];
  }
}

/// Estado con el que nace el reparto de un ingreso: automática solo en el
/// modo automático y si el ingreso cubre todo lo comprometido.
///
/// *Pregunta abierta P1:* la regla de cuándo es automática es lectura del
/// arquitecto ("deuda menor que el ingreso"); el dueño la confirma.
EstadoDispersion estadoAlRecibir(
  PropuestaDispersion propuesta,
  ModoDispersion modo,
) => modo == ModoDispersion.automatico && propuesta.cubreTodo
    ? EstadoDispersion.automatica
    : EstadoDispersion.porRepartir;

/// Reparte [ingreso] con la cascada de [plan] (5.6 bis, puntos 1, 4 y 7).
///
/// **Sueldo** (ingreso configurado que está en el plan): cubre su parte del
/// presupuesto y de la deuda de **un periodo** de su frecuencia. Su parte es
/// el monto planeado del ingreso entre el ingreso total del plan (en anual,
/// exacto), así que no depende de la frecuencia:
///
/// ```text
/// cubre(partida) = anual(partida) × monto planeado ÷ ingreso anual del plan
/// ```
///
/// (R2: los renglones suman exactamente el total redondeado). Lo que pasa de
/// eso es **remanente** y va a abono extra o ahorro con [repartirRemanente].
///
/// **Extra** (sin ingreso configurado): sin periodo que cubrir. Sigue 5.1 bis,
/// punto 4: primero los sobres de previsión que no alcanzan
/// ([faltantePrevision], partida → centavos), después deuda con costo por
/// mayor tasa, préstamos familiares, ahorro y la parte libre.
///
/// **Si el ingreso no alcanza** (interpretación, *pregunta abierta P3*): se
/// financia en este orden y lo que falta se recorta del final hacia el
/// principio: partidas protegidas, mínimos de deuda, demás partidas
/// (necesarias primero, discrecionales al último), y abonos sobre el mínimo
/// (préstamos familiares al final de las deudas y primeros en recortarse).
/// Reusa [proponerRecortes] para elegir qué partida se recorta. El
/// [PropuestaDispersion.faltante] dice cuánto no alcanzó.
///
/// [deudas] trae los saldos actuales; por omisión, las del plan.
PropuestaDispersion proponerDispersion({
  required IngresoPorRepartir ingreso,
  required PlanSemanal plan,
  List<DeudaPlan>? deudas,
  ParametrosDispersion parametros = const ParametrosDispersion(),
  Map<String, int> faltantePrevision = const {},
}) {
  if (ingreso.monto <= 0) {
    throw const ErrorDispersion('El ingreso debe ser mayor que cero.');
  }
  final listaDeudas = deudas ?? [for (final r in plan.abonos) r.origen];
  final monto = ingreso.monto;

  final renglonIngreso = ingreso.ingresoPlanId == null
      ? null
      : plan.ingresos
            .where((r) => r.origen.id == ingreso.ingresoPlanId)
            .firstOrNull;
  final anualIngresos = plan.ingresoEquivalente.anualCentavos;
  final esSueldo = renglonIngreso != null && anualIngresos > 0;

  // Lo que el ingreso cubre del plan: partida → centavos, deuda → centavos.
  final cubrePartida = <PartidaPlan, int>{};
  final cubreDeuda = <DeudaPlan, int>{};
  if (esSueldo) {
    final base = renglonIngreso.origen.monto;
    final partidas = [for (final r in plan.partidas) r.origen];
    final enPartidas = repartirConMayorResto([
      for (final p in partidas) p.equivalente.anualCentavos * base,
    ], anualIngresos);
    for (var i = 0; i < partidas.length; i++) {
      cubrePartida[partidas[i]] = enPartidas[i];
    }
    final enDeudas = repartirConMayorResto([
      for (final d in listaDeudas) d.equivalente.anualCentavos * base,
    ], anualIngresos);
    for (var i = 0; i < listaDeudas.length; i++) {
      cubreDeuda[listaDeudas[i]] = enDeudas[i];
    }
  } else {
    var restante = monto;
    for (final r in plan.partidas) {
      final falta = faltantePrevision[r.origen.id] ?? 0;
      if (falta <= 0 || restante <= 0) continue;
      final cubre = falta < restante ? falta : restante;
      cubrePartida[r.origen] = cubre;
      restante -= cubre;
    }
    for (final d in listaDeudas) {
      cubreDeuda[d] = 0;
    }
  }

  // Si no alcanza, se recorta del final hacia el principio.
  final comprometido =
      cubrePartida.values.fold<int>(0, (t, v) => t + v) +
      cubreDeuda.values.fold<int>(0, (t, v) => t + v);
  final faltante = comprometido > monto ? comprometido - monto : 0;
  if (faltante > 0) {
    _recortar(faltante, cubrePartida, cubreDeuda, listaDeudas);
  }

  // Remanente → destino (abono extra o ahorro) con la cascada existente.
  final cubierto =
      cubrePartida.values.fold<int>(0, (t, v) => t + v) +
      cubreDeuda.values.fold<int>(0, (t, v) => t + v);
  var remanente = monto - cubierto;
  var libre = 0;
  if (!esSueldo && remanente > 0) {
    libre = aplicarPorcentaje(remanente, parametros.parteLibrePuntosBase);
    remanente -= libre;
  }
  var destino = repartirRemanente(remanente, {
    for (final e in cubreDeuda.entries) e.key: e.value,
  }, parametros: plan.parametros);
  final tope = parametros.topeAhorro;
  if (tope != null && destino.ahorro > tope) {
    libre += destino.ahorro - tope;
    destino = DestinoRemanente(destino.abonosExtra, tope);
  }

  final lineas = <LineaDispersion>[
    for (final e in cubrePartida.entries)
      if (e.value > 0)
        LineaDispersion(
          destino: DestinoLinea.presupuesto,
          referenciaId: e.key.id,
          etiqueta: e.key.nombre,
          monto: e.value,
        ),
    for (final e in cubreDeuda.entries)
      if (e.value > 0)
        LineaDispersion(
          destino: DestinoLinea.pagoDeuda,
          referenciaId: e.key.id,
          etiqueta: e.key.nombre,
          monto: e.value,
        ),
    for (final a in destino.abonosExtra)
      if (a.monto > 0)
        LineaDispersion(
          destino: DestinoLinea.abonoExtra,
          referenciaId: a.deuda.id,
          etiqueta: a.deuda.nombre,
          monto: a.monto,
        ),
    if (destino.ahorro > 0)
      LineaDispersion(
        destino: DestinoLinea.ahorro,
        etiqueta: 'Ahorro',
        monto: destino.ahorro,
      ),
    if (libre > 0)
      LineaDispersion(
        destino: DestinoLinea.libre,
        etiqueta: 'Libre',
        monto: libre,
      ),
  ];
  return PropuestaDispersion(
    movimientoId: ingreso.movimientoId,
    monto: monto,
    lineas: lineas,
    faltante: faltante,
    destinoRemanente: destino,
  );
}

/// Quita [falta] centavos de lo que el ingreso cubre, en el orden descrito en
/// [proponerDispersion].
void _recortar(
  int falta,
  Map<PartidaPlan, int> cubrePartida,
  Map<DeudaPlan, int> cubreDeuda,
  List<DeudaPlan> deudas,
) {
  int minimoDe(DeudaPlan d) {
    final c = cubreDeuda[d] ?? 0;
    final propio = Equivalente.de(d.minimo, d.frecuencia).anualCentavos;
    final plan = d.equivalente.anualCentavos;
    if (plan <= 0) return 0;
    final m = dividirRedondeando(c * propio, plan);
    return m < c ? m : c;
  }

  void quitarDeDeuda(DeudaPlan d, int tope) {
    if (falta <= 0 || tope <= 0) return;
    final q = tope < falta ? tope : falta;
    cubreDeuda[d] = cubreDeuda[d]! - q;
    falta -= q;
  }

  // 1. Abonos sobre el mínimo: primero los últimos en recibir extra
  //    (familiares), luego los de menor costo.
  final ordenExtra = ordenDeAbonoExtra(deudas);
  final inversoExtra = [
    ...ordenExtra.reversed,
    for (final d in deudas)
      if (!ordenExtra.contains(d)) d,
  ];
  for (final d in inversoExtra) {
    quitarDeDeuda(d, (cubreDeuda[d] ?? 0) - minimoDe(d));
  }
  // 2. Partidas no protegidas, con la propuesta de recortes existente.
  if (falta > 0) {
    final p = proponerRecortes(falta, [
      for (final e in cubrePartida.entries)
        (partida: e.key, disponible: e.value, gastado: 0),
    ]);
    for (final r in p.recortes) {
      cubrePartida[r.partida] = cubrePartida[r.partida]! - r.monto;
      falta -= r.monto;
    }
  }
  // 3. Mínimos de deuda, de menor a mayor costo (MSI al final).
  if (falta > 0) {
    final conCosto = deudas.where((d) => d.tipo == TipoDeuda.conCosto).toList()
      ..sort(
        (a, b) => a.tasaAnualPuntosBase != b.tasaAnualPuntosBase
            ? a.tasaAnualPuntosBase.compareTo(b.tasaAnualPuntosBase)
            : a.id.compareTo(b.id),
      );
    final resto = deudas.where((d) => d.tipo != TipoDeuda.conCosto).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final d in [...conCosto, ...resto]) {
      quitarDeDeuda(d, cubreDeuda[d] ?? 0);
    }
  }
  // 4. Lo protegido, solo si no queda otra cosa (el faltante lo avisa).
  if (falta > 0) {
    for (final e in cubrePartida.entries.toList().reversed) {
      if (falta <= 0) break;
      final q = e.value < falta ? e.value : falta;
      cubrePartida[e.key] = e.value - q;
      falta -= q;
    }
  }
}

/// El reparto guardado de un ingreso (`fin_dispersiones`).
class Dispersion {
  final String id;
  final String libroId;

  /// Movimiento de ingreso que se repartió (único por reparto vigente).
  final String movimientoId;
  final EstadoDispersion estado;
  final ModoDispersion modo;
  final List<LineaDispersion> lineas;
  final DateTime creadaEn;

  /// Quién y cuándo lo confirmó (en el modo automático, nulo).
  final String? resueltaPor;
  final DateTime? resueltaEn;

  /// Persona en cuyo nombre se confirmó (albacea en el libro de papá).
  final String? enNombreDe;
  final String? motivo;

  /// Versión dentro de la cadena de cambios del ingreso (1 el primer reparto,
  /// 2 el primer cambio…). Es lo que el cliente manda al cambiar el reparto
  /// para que dos dispositivos no se pisen (control de versión del servidor).
  final int version;

  /// El reparto al que sustituye este (nulo en la versión 1).
  final String? reemplazaA;

  Dispersion({
    required this.id,
    required this.libroId,
    required this.movimientoId,
    required this.estado,
    this.modo = ModoDispersion.confirmacion,
    required Iterable<LineaDispersion> lineas,
    required this.creadaEn,
    this.resueltaPor,
    this.resueltaEn,
    this.enNombreDe,
    this.motivo,
    this.version = 1,
    this.reemplazaA,
  }) : lineas = List.unmodifiable(lineas);

  /// Lo que sigue por repartir de este reparto.
  int get porRepartir => lineas
      .where((l) => l.destino == DestinoLinea.porRepartir)
      .fold<int>(0, (t, l) => t + l.monto);

  Dispersion conEstado(EstadoDispersion nuevo) => Dispersion(
    id: id,
    libroId: libroId,
    movimientoId: movimientoId,
    estado: nuevo,
    modo: modo,
    lineas: lineas,
    creadaEn: creadaEn,
    resueltaPor: resueltaPor,
    resueltaEn: resueltaEn,
    enNombreDe: enNombreDe,
    motivo: motivo,
    version: version,
    reemplazaA: reemplazaA,
  );
}

/// Ingresos del libro con su estado de reparto (los confirmados y no
/// anulados), del más reciente al más antiguo.
///
/// - Solo cuentan los movimientos de tipo ingreso que **entran a una cuenta
///   del libro**, confirmados y sin anulación confirmada.
/// - [ParametrosDispersion.desde]: lo anterior se da por repartido y no
///   aparece.
/// - Un ingreso es **sueldo** si viene de la cuenta de origen de un ingreso
///   configurado del libro; si no, es **extra**.
List<IngresoPorRepartir> ingresosDelLibro(
  DatosFinanzas d,
  String libroId,
  List<Dispersion> dispersiones, {
  ParametrosDispersion parametros = const ParametrosDispersion(),
}) {
  final vista = d.vista(libroId);
  final propias = {for (final c in d.cuentasDe(libroId)) c.id};
  final sueldos = {
    for (final i in d.ingresosDe(libroId)) i.cuentaOrigenId: i.id,
  };
  final vigentes = <String, Dispersion>{
    for (final x in dispersiones)
      if (x.libroId == libroId && x.estado.vigente) x.movimientoId: x,
  };
  final lista = <IngresoPorRepartir>[];
  for (final m in vista.movimientos) {
    if (m.tipo != TipoMovimiento.ingreso) continue;
    if (!propias.contains(m.cuentaDestinoId)) continue;
    if (vista.estadoDe(m.id) != EstadoMovimiento.confirmado) continue;
    if (vista.estaAnulado(m.id)) continue;
    final desde = parametros.desde;
    if (desde != null && m.fecha.antesDe(desde)) continue;
    final x = vigentes[m.id];
    final estado = x?.estado ?? EstadoDispersion.porRepartir;
    lista.add(
      IngresoPorRepartir(
        movimientoId: m.id,
        libroId: libroId,
        fecha: m.fecha,
        monto: m.monto,
        cuentaDestinoId: m.cuentaDestinoId,
        nombre: vista.cuenta(m.cuentaOrigenId).nombre,
        ingresoPlanId: sueldos[m.cuentaOrigenId],
        estado: estado,
        dispersionId: x?.id,
        pendiente: estado.pendiente ? m.monto : x!.porRepartir,
      ),
    );
  }
  lista.sort((a, b) {
    final f = b.fecha.compareTo(a.fecha);
    return f != 0 ? f : a.movimientoId.compareTo(b.movimientoId);
  });
  return List.unmodifiable(lista);
}

/// Lo que sigue por repartir y **se arrastra a [semana]** (la semana actual):
/// la suma de lo pendiente de los ingresos con fecha hasta el domingo de
/// [semana] (decisión 2 del dueño, 18/nov/2026).
///
/// Solo la semana de [hoy] y las siguientes lo llevan: una semana pasada
/// conserva sus cifras de entonces (el arrastre es de "ahora").
int porRepartirArrastrado(
  List<IngresoPorRepartir> ingresos, {
  required Semana semana,
  required Fecha hoy,
}) {
  if (semana.inicio.antesDe(Semana.de(hoy).inicio)) return 0;
  return ingresos
      .where((i) => !i.fecha.despuesDe(semana.fin))
      .fold<int>(0, (t, i) => t + i.pendiente);
}

/// "Quedan" de la semana con lo por repartir (decisión 2): lo que queda del
/// presupuesto más lo que aún no tiene destino. *Lectura:* se suma completo,
/// como pidió el dueño; la pregunta P6 deja anotado que el presupuesto de la
/// semana ya podría estar contado dentro de ese dinero.
int quedanConPorRepartir({required int disponible, required int porRepartir}) =>
    disponible + porRepartir;

// ------------------------------------------------------ cambiar un reparto

/// Identifica un renglón dentro de un reparto (destino y referencia): sirve
/// para comparar el reparto vigente con el editado. Un reparto no repite
/// destino y referencia.
String claveDeLinea(LineaDispersion l) => '${l.destino.name}:${l.referenciaId}';

/// La propuesta **editable** para cambiar un reparto ya confirmado (P5): parte
/// de la estructura que da `proponerDispersion` ([base], con todos los
/// renglones posibles, también los que hoy valen cero) y le pone los montos
/// **del reparto vigente**. Los renglones del reparto que [base] no trae (por
/// ejemplo, una deuda que cambió de orden) se conservan al final. El renglón
/// «por repartir» no se copia: se recalcula como `quedaPorRepartir`.
///
/// Así la hoja reutiliza `editar` y las mismas reglas de siempre (sin pasar
/// del monto, sin negativos).
PropuestaDispersion propuestaParaCambiar({
  required Dispersion vigente,
  required PropuestaDispersion base,
}) {
  if (base.movimientoId != vigente.movimientoId) {
    throw const ErrorDispersion('Ese reparto no es de ese ingreso.');
  }
  final guardados = {
    for (final l in vigente.lineas)
      if (l.destino != DestinoLinea.porRepartir) claveDeLinea(l): l,
  };
  final lineas = <LineaDispersion>[];
  final usadas = <String>{};
  for (final l in base.lineas) {
    if (l.destino == DestinoLinea.porRepartir) continue;
    final k = claveDeLinea(l);
    lineas.add(l.conMonto(guardados[k]?.monto ?? 0));
    usadas.add(k);
  }
  for (final e in guardados.entries) {
    if (!usadas.contains(e.key)) lineas.add(e.value);
  }
  final total = vigente.lineas.fold<int>(0, (t, l) => t + l.monto);
  if (total != base.monto) {
    throw const ErrorDispersion(
      'El reparto vigente no suma el monto del ingreso: vuelve a cargar.',
    );
  }
  return PropuestaDispersion(
    movimientoId: base.movimientoId,
    monto: base.monto,
    lineas: lineas,
    faltante: base.faltante,
    destinoRemanente: base.destinoRemanente,
  );
}

/// Lo que cambia al editar un reparto ya confirmado: la diferencia entre el
/// reparto vigente y el editado, y qué movimientos se anulan y cuáles se
/// crean (libro solo-agregar: el servidor anula con contraasiento **todo lo
/// que creó el reparto anterior** y crea lo del nuevo, en una transacción).
class CambioReparto {
  /// El reparto vigente que se reemplaza. Su [Dispersion.id] y su
  /// [Dispersion.version] viajan al servidor para el control de versión.
  final Dispersion anterior;

  /// Los renglones del reparto nuevo (los de la propuesta sin los de cero y el
  /// sobrante como «por repartir»); suman el monto del ingreso.
  final List<LineaDispersion> lineas;

  /// Renglones del anterior que movieron dinero: sus movimientos se anulan.
  final List<LineaDispersion> anulan;

  /// Renglones del nuevo que mueven dinero: se crean sus movimientos.
  final List<LineaDispersion> crean;

  /// Los renglones (por destino y referencia) cuyo monto cambió, entraron o
  /// salieron.
  final List<String> renglonesDistintos;

  const CambioReparto({
    required this.anterior,
    required this.lineas,
    required this.anulan,
    required this.crean,
    required this.renglonesDistintos,
  });

  /// La versión que el cliente vio: se manda como `version_esperada`.
  int get versionEsperada => anterior.version;

  /// Hay algo distinto que guardar (si no, no hay cambio que hacer).
  bool get hayCambios => renglonesDistintos.isNotEmpty;

  /// Dinero que se devuelve a la cuenta del ingreso al anular lo anterior.
  int get dineroDevuelto => anulan.fold<int>(0, (t, l) => t + l.monto);

  /// Dinero que sale de la cuenta del ingreso con lo nuevo.
  int get dineroNuevo => crean.fold<int>(0, (t, l) => t + l.monto);

  /// Cuánto más (positivo) o menos (negativo) sale de la cuenta del ingreso.
  int get diferenciaDeSalida => dineroNuevo - dineroDevuelto;
}

/// Arma el cambio de [vigente] a [editada] (la propuesta de
/// `propuestaParaCambiar` con las ediciones de la persona). Rechaza lo que el
/// servidor también rechazaría: un reparto que no está aplicado, otro ingreso,
/// una suma distinta del monto.
CambioReparto armarCambioDeReparto({
  required Dispersion vigente,
  required PropuestaDispersion editada,
}) {
  if (!vigente.estado.aplicada) {
    throw const ErrorDispersion(
      'Solo se cambia un reparto confirmado: una propuesta se confirma.',
    );
  }
  if (editada.movimientoId != vigente.movimientoId) {
    throw const ErrorDispersion('Ese reparto no es de ese ingreso.');
  }
  if (editada.quedaPorRepartir < 0 || editada.totalRepartido > editada.monto) {
    throw const ErrorDispersion(
      'El reparto pasa del monto del ingreso: revísalo.',
    );
  }
  final nuevas = editada.lineasParaGuardar();
  final antes = {for (final l in vigente.lineas) claveDeLinea(l): l.monto};
  final despues = {for (final l in nuevas) claveDeLinea(l): l.monto};
  final distintos = <String>[
    for (final k in {...antes.keys, ...despues.keys})
      if ((antes[k] ?? 0) != (despues[k] ?? 0)) k,
  ];
  return CambioReparto(
    anterior: vigente,
    lineas: nuevas,
    anulan: [
      for (final l in vigente.lineas)
        if (l.destino.mueveDinero && l.monto > 0) l,
    ],
    crean: [
      for (final l in nuevas)
        if (l.destino.mueveDinero && l.monto > 0) l,
    ],
    renglonesDistintos: distintos,
  );
}

// ------------------------------------------------- corregir el tipo de ingreso

/// Los dos asientos de la corrección del tipo de un ingreso: la anulación del
/// original y el ingreso nuevo con el tipo correcto. Se agregan juntos.
class CorreccionIngreso {
  final Movimiento anulacion;
  final Movimiento nuevo;

  const CorreccionIngreso(this.anulacion, this.nuevo);
}

/// Corrige el tipo de un ingreso (por ejemplo, un sueldo que se registró como
/// extra) **sin borrar nada**: anula el original con un contraasiento y
/// registra un ingreso igual (mismo monto, fecha y cuenta de destino) desde la
/// cuenta de origen correcta. Los dos asientos comparten [grupoId] y el motivo
/// para que el historial muestre la corrección completa.
///
/// Se valida contra [libro] (una copia: `DatosFinanzas.nuevoLibroHogar()`);
/// al volver, [libro] ya tiene los dos asientos. Reglas:
/// - Solo un ingreso confirmado y sin anular.
/// - La cuenta nueva debe ser de origen de ingreso y distinta de la actual.
/// - El nuevo ingreso conserva la **fecha económica** del original: la semana
///   se recalcula como si se hubiera capturado bien.
CorreccionIngreso corregirTipoDeIngreso(
  LibroMovimientos libro, {
  required String movimientoId,
  required String nuevaCuentaOrigenId,
  required String idAnulacion,
  required String idNuevo,
  required String grupoId,
  required String motivo,
  required String registradoPor,
  required DateTime registradoEn,
  EstadoMovimiento estado = EstadoMovimiento.confirmado,
}) {
  final original = libro.movimiento(movimientoId);
  if (original.tipo != TipoMovimiento.ingreso) {
    throw const ErrorDispersion('Solo se corrige el tipo de un ingreso.');
  }
  if (libro.estadoDe(original.id) != EstadoMovimiento.confirmado) {
    throw const ErrorDispersion(
      'Solo se corrige un ingreso confirmado; uno pendiente se rechaza.',
    );
  }
  if (libro.contraasientoDe(original.id) != null) {
    throw const ErrorDispersion('Ese ingreso ya está anulado.');
  }
  if (nuevaCuentaOrigenId == original.cuentaOrigenId) {
    throw const ErrorDispersion('Elige un tipo distinto del actual.');
  }
  final destino = libro.cuenta(nuevaCuentaOrigenId);
  if (destino.tipo != TipoCuenta.origenIngreso) {
    throw const ErrorDispersion('Elige un tipo de ingreso válido.');
  }
  try {
    final anulacion = libro.agregar(
      Movimiento(
        id: idAnulacion,
        tipo: TipoMovimiento.anulacion,
        fecha: original.fecha,
        registradoEn: registradoEn,
        cuentaOrigenId: original.cuentaDestinoId,
        cuentaDestinoId: original.cuentaOrigenId,
        monto: original.monto,
        realizadoPor: original.realizadoPor,
        registradoPor: registradoPor,
        grupoId: grupoId,
        motivo: motivo,
        anulaA: original.id,
        enNombreDe: original.enNombreDe,
        estadoInicial: estado,
      ),
    );
    final nuevo = libro.agregar(
      Movimiento(
        id: idNuevo,
        tipo: TipoMovimiento.ingreso,
        fecha: original.fecha,
        registradoEn: registradoEn,
        cuentaOrigenId: nuevaCuentaOrigenId,
        cuentaDestinoId: original.cuentaDestinoId,
        monto: original.monto,
        realizadoPor: original.realizadoPor,
        registradoPor: registradoPor,
        grupoId: grupoId,
        nota: original.nota,
        motivo: motivo,
        enNombreDe: original.enNombreDe,
        estadoInicial: estado,
      ),
    );
    return CorreccionIngreso(anulacion, nuevo);
  } on ErrorLibro catch (e) {
    throw ErrorDispersion(e.mensaje);
  }
}

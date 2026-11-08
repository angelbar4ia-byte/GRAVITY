/// Simulador de estrategias de pago de deudas (Fase 8, bloque 2;
/// `docs/specs/fase-8-deudas-intereses.md`). Dart puro, dinero en centavos y
/// tasas en puntos base (2000 = 20 %).
///
/// - Las tres estrategias pagan **los mínimos de todas las deudas** y dirigen
///   el resto del presupuesto mensual (suma de mínimos + extra) a la deuda
///   que toca; al liquidar una, su mínimo se sigue usando (bola de nieve).
/// - El interés mensual es saldo × tasa ÷ 12, redondeado al centavo (R1).
/// - **Ninguna cifra se inventa**: si falta un dato que la estrategia
///   necesita, el resultado es [EstadoEstrategia.faltaDato] y no trae cifras.
/// - El simulador **no decide**: [recomendar] solo señala la de menores
///   intereses; el pago lo confirma la persona.
library;

import 'dinero.dart';

/// Las tres estrategias de la especificación.
enum EstrategiaPago {
  /// Primero la deuda de saldo más chico.
  bolaDeNieve('bola_de_nieve', 'Bola de nieve'),

  /// Primero la de tasa más alta.
  avalancha('avalancha', 'Avalancha'),

  /// Primero la que vence antes (evita recargos y mora).
  porVencimiento('por_vencimiento', 'Por fecha de vencimiento');

  const EstrategiaPago(this.clave, this.nombre);

  /// Nombre estable (el que usa el servidor en `fin_simular_estrategias`).
  final String clave;
  final String nombre;

  static EstrategiaPago? deClave(String clave) {
    for (final e in values) {
      if (e.clave == clave) return e;
    }
    return null;
  }
}

enum EstadoEstrategia {
  calculada,
  faltaDato,

  /// El presupuesto pedido es menor que la suma de los pagos mínimos.
  noAlcanza,
}

/// Una deuda para simular. `null` en un campo = el dato no se tiene.
class DeudaSimulable {
  const DeudaSimulable({
    required this.id,
    required this.nombre,
    this.saldo,
    this.tasaAnualPuntosBase,
    this.minimoMensual,
    this.diasParaVencer,
  });

  final String id;
  final String nombre;

  /// Saldo actual en centavos.
  final int? saldo;

  /// Tasa anual en puntos base; cero en préstamos familiares y MSI.
  final int? tasaAnualPuntosBase;

  /// Pago mínimo mensual en centavos.
  final int? minimoMensual;

  /// Días desde hoy hasta la fecha límite de pago (solo la usa la estrategia
  /// por vencimiento).
  final int? diasParaVencer;

  /// Campos que faltan para [estrategia] (vacío si puede calcularse).
  List<String> faltantes(EstrategiaPago estrategia) => [
    if (saldo == null) 'saldo',
    if (tasaAnualPuntosBase == null) 'tasa',
    if (minimoMensual == null) 'pago mínimo',
    if (estrategia == EstrategiaPago.porVencimiento && diasParaVencer == null)
      'fecha límite',
  ];
}

/// Un paso del orden de pago: cuándo queda liquidada cada deuda.
class PasoDeOrden {
  const PasoDeOrden(this.deudaId, this.nombre, this.mesDeLiquidacion);

  final String deudaId;
  final String nombre;

  /// Mes (1 = el primero) en que la deuda queda en cero; `null` si no se
  /// liquida dentro del horizonte.
  final int? mesDeLiquidacion;
}

class ResultadoEstrategia {
  const ResultadoEstrategia._({
    required this.estrategia,
    required this.estado,
    this.faltantes = const [],
    this.capitalPagado = 0,
    this.interesesTotales = 0,
    this.meses = 0,
    this.liquidada = false,
    this.orden = const [],
  });

  const ResultadoEstrategia.faltaDato(
    EstrategiaPago estrategia,
    List<String> faltantes,
  ) : this._(
        estrategia: estrategia,
        estado: EstadoEstrategia.faltaDato,
        faltantes: faltantes,
      );

  const ResultadoEstrategia.noAlcanza(EstrategiaPago estrategia)
    : this._(estrategia: estrategia, estado: EstadoEstrategia.noAlcanza);

  final EstrategiaPago estrategia;
  final EstadoEstrategia estado;

  /// Qué datos faltan (solo con [EstadoEstrategia.faltaDato]).
  final List<String> faltantes;

  /// Capital pagado: es el mismo en las tres estrategias (criterio 1).
  final int capitalPagado;
  final int interesesTotales;

  /// Meses hasta quedar libre de deuda (o hasta el horizonte).
  final int meses;

  /// `false` si con el presupuesto no se liquida dentro del horizonte.
  final bool liquidada;

  /// Orden en que se van liquidando las deudas.
  final List<PasoDeOrden> orden;

  bool get calculada => estado == EstadoEstrategia.calculada;

  /// Capital más intereses.
  int get totalPagado => capitalPagado + interesesTotales;
}

/// Intereses pagando solo los mínimos (sin reasignar lo que libera cada deuda).
class ResultadoSoloMinimos {
  const ResultadoSoloMinimos.faltaDato(this.faltantes)
    : calculado = false,
      interesesTotales = 0,
      meses = 0,
      liquidada = false;

  const ResultadoSoloMinimos._(
    this.interesesTotales,
    this.meses,
    this.liquidada,
  ) : calculado = true,
      faltantes = const [];

  final bool calculado;
  final List<String> faltantes;
  final int interesesTotales;
  final int meses;

  /// `false` si el mínimo no alcanza a liquidar en el horizonte (el interés
  /// mostrado es el acumulado hasta ahí).
  final bool liquidada;
}

/// Horizonte máximo de la simulación (meses).
const int horizonteMesesDeuda = 600;

int _interesMensual(int saldo, int tasaPb) =>
    dividirRedondeando(saldo * tasaPb, puntosBaseEnCien * 12);

/// Duración de un ciclo de pago para proyectar vencimientos futuros (días).
const int diasCicloPago = 30;

/// Días (desde hoy) de la **primera fecha límite que cae en el mes [mes]** o
/// después de su inicio, proyectando ciclos futuros de [diasCicloPago]. Una
/// deuda ya vencida (negativo) conserva su fecha en el mes 1: es la primera.
int diasProyectadosDeVencimiento(int dias, int mes) {
  final inicio = diasCicloPago * (mes - 1);
  if (mes <= 1 || dias >= inicio) return dias;
  final ciclos = (inicio - dias + diasCicloPago - 1) ~/ diasCicloPago;
  return dias + ciclos * diasCicloPago;
}

/// Suma de los pagos mínimos mensuales: el presupuesto por omisión. `null` si
/// a alguna deuda con saldo le falta el mínimo (no se adivina).
int? sumaDeMinimos(List<DeudaSimulable> deudas) {
  var t = 0;
  for (final d in deudas) {
    if (d.saldo != null && d.saldo! <= 0) continue;
    if (d.minimoMensual == null) return null;
    t += d.minimoMensual!;
  }
  return t;
}

/// Orden de prioridad de [estrategia] sobre [deudas] (desempate estable). En
/// la estrategia por vencimiento se proyectan los ciclos del [mes].
List<DeudaSimulable> _ordenar(
  EstrategiaPago estrategia,
  List<DeudaSimulable> deudas, [
  int mes = 1,
]) {
  int porId(DeudaSimulable a, DeudaSimulable b) => a.id.compareTo(b.id);
  final copia = [...deudas];
  copia.sort((a, b) {
    final c = switch (estrategia) {
      EstrategiaPago.bolaDeNieve => a.saldo!.compareTo(b.saldo!),
      EstrategiaPago.avalancha => b.tasaAnualPuntosBase!.compareTo(
        a.tasaAnualPuntosBase!,
      ),
      EstrategiaPago.porVencimiento => diasProyectadosDeVencimiento(
        a.diasParaVencer!,
        mes,
      ).compareTo(diasProyectadosDeVencimiento(b.diasParaVencer!, mes)),
    };
    if (c != 0) return c;
    // Desempates: mayor tasa, menor saldo, id.
    final t = b.tasaAnualPuntosBase!.compareTo(a.tasaAnualPuntosBase!);
    if (t != 0) return t;
    final s = a.saldo!.compareTo(b.saldo!);
    return s != 0 ? s : porId(a, b);
  });
  return copia;
}

/// Simula [estrategia] con un presupuesto mensual de **la suma de los mínimos
/// más [extraMensual]**, o con [presupuestoMensual] si se pide (nulo = por
/// omisión). Un [presupuestoMensual] menor que la suma de mínimos da
/// [EstadoEstrategia.noAlcanza]. Las deudas con saldo cero se ignoran.
ResultadoEstrategia simularEstrategia(
  EstrategiaPago estrategia,
  List<DeudaSimulable> deudas, {
  int extraMensual = 0,
  int? presupuestoMensual,
}) {
  if (presupuestoMensual != null && presupuestoMensual < 0) {
    throw ArgumentError('El presupuesto mensual no puede ser negativo');
  }
  if (extraMensual < 0) {
    throw ArgumentError('El extra mensual no puede ser negativo');
  }
  final faltantes = <String>{
    for (final d in deudas)
      for (final f in d.faltantes(estrategia)) f,
  }.toList();
  if (faltantes.isNotEmpty) {
    return ResultadoEstrategia.faltaDato(estrategia, faltantes);
  }
  final activas = [
    for (final d in deudas)
      if (d.saldo! > 0) d,
  ];
  final minimos = activas.fold<int>(0, (t, d) => t + d.minimoMensual!);
  if (presupuestoMensual != null && presupuestoMensual < minimos) {
    return ResultadoEstrategia.noAlcanza(estrategia);
  }
  final orden = _ordenar(estrategia, activas);
  final saldos = {for (final d in activas) d.id: d.saldo!};
  final liquidadaEn = <String, int>{};
  final presupuesto = presupuestoMensual ?? minimos + extraMensual;
  var intereses = 0;
  var mes = 0;
  while (saldos.values.any((s) => s > 0) && mes < horizonteMesesDeuda) {
    mes++;
    var disponible = presupuesto;
    // 1. Interés del mes.
    for (final d in activas) {
      final s = saldos[d.id]!;
      if (s <= 0) continue;
      final i = _interesMensual(s, d.tasaAnualPuntosBase!);
      saldos[d.id] = s + i;
      intereses += i;
    }
    // 2. Mínimos de todas.
    for (final d in activas) {
      final s = saldos[d.id]!;
      if (s <= 0) continue;
      final p = d.minimoMensual! < s ? d.minimoMensual! : s;
      saldos[d.id] = s - p;
      disponible -= p;
    }
    // 3. Lo que sobra, a la deuda que toca.
    final prioridad = estrategia == EstrategiaPago.porVencimiento
        ? _ordenar(estrategia, activas, mes)
        : orden;
    for (final d in prioridad) {
      if (disponible <= 0) break;
      final s = saldos[d.id]!;
      if (s <= 0) continue;
      final p = disponible < s ? disponible : s;
      saldos[d.id] = s - p;
      disponible -= p;
    }
    for (final d in activas) {
      if (saldos[d.id]! <= 0) liquidadaEn.putIfAbsent(d.id, () => mes);
    }
  }
  final liquidada = saldos.values.every((s) => s <= 0);
  // Total pagado = saldo inicial + intereses causados - lo que queda debiendo.
  // Con la deuda liquidada, el capital pagado es el saldo inicial.
  final restante = saldos.values.fold<int>(0, (t, s) => t + s);
  final inicial = activas.fold<int>(0, (t, d) => t + d.saldo!);
  final pagado = inicial + intereses - restante;
  final capital = liquidada
      ? inicial
      : (pagado - intereses < 0 ? 0 : pagado - intereses);
  // Orden de liquidación: por mes y, en el mismo mes, por prioridad.
  final pasos = [
    for (var i = 0; i < orden.length; i++)
      (i, PasoDeOrden(orden[i].id, orden[i].nombre, liquidadaEn[orden[i].id])),
  ];
  pasos.sort((a, b) {
    final ma = a.$2.mesDeLiquidacion ?? 1 << 30;
    final mb = b.$2.mesDeLiquidacion ?? 1 << 30;
    return ma != mb ? ma.compareTo(mb) : a.$1.compareTo(b.$1);
  });
  return ResultadoEstrategia._(
    estrategia: estrategia,
    estado: EstadoEstrategia.calculada,
    capitalPagado: capital,
    interesesTotales: intereses,
    meses: mes,
    liquidada: liquidada,
    orden: [for (final p in pasos) p.$2],
  );
}

/// Las tres estrategias, en el orden del enum.
List<ResultadoEstrategia> simularTodas(
  List<DeudaSimulable> deudas, {
  int extraMensual = 0,
  int? presupuestoMensual,
}) => [
  for (final e in EstrategiaPago.values)
    simularEstrategia(
      e,
      deudas,
      extraMensual: extraMensual,
      presupuestoMensual: presupuestoMensual,
    ),
];

/// Intereses que se pagan con **solo el pago mínimo** de cada deuda.
ResultadoSoloMinimos interesesConPagoMinimo(
  List<DeudaSimulable> deudas, {
  int horizonteMeses = horizonteMesesDeuda,
}) {
  final faltantes = <String>{
    for (final d in deudas)
      for (final f in d.faltantes(EstrategiaPago.bolaDeNieve)) f,
  }.toList();
  if (faltantes.isNotEmpty) return ResultadoSoloMinimos.faltaDato(faltantes);
  final saldos = {
    for (final d in deudas)
      if (d.saldo! > 0) d.id: d.saldo!,
  };
  final por = {for (final d in deudas) d.id: d};
  var intereses = 0;
  var mes = 0;
  while (saldos.values.any((s) => s > 0) && mes < horizonteMeses) {
    mes++;
    for (final id in saldos.keys.toList()) {
      var s = saldos[id]!;
      if (s <= 0) continue;
      final i = _interesMensual(s, por[id]!.tasaAnualPuntosBase!);
      s += i;
      intereses += i;
      final m = por[id]!.minimoMensual!;
      saldos[id] = s - (m < s ? m : s);
    }
  }
  return ResultadoSoloMinimos._(
    intereses,
    mes,
    saldos.values.every((s) => s <= 0),
  );
}

/// La estrategia de **menores intereses** entre las calculadas; ante empate,
/// la primera por orden de menos meses y luego la de más prioridad en el
/// enum. `null` si ninguna se pudo calcular. Es una sugerencia: el pago lo
/// confirma la persona.
ResultadoEstrategia? recomendar(List<ResultadoEstrategia> resultados) {
  ResultadoEstrategia? mejor;
  for (final r in resultados) {
    if (!r.calculada) continue;
    if (mejor == null ||
        r.interesesTotales < mejor.interesesTotales ||
        (r.interesesTotales == mejor.interesesTotales &&
            r.meses < mejor.meses)) {
      mejor = r;
    }
  }
  return mejor;
}

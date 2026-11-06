import 'fecha.dart';

enum FaseHabito {
  noIniciado,
  lineaBase,
  reduccion,
  preparacion,
  diaD,
  libre,
  mantenimiento,
}

/// Plan del cigarrillo (reglas 30 a 34, F.14). Todo es editable.
class PlanCigarrillo {
  PlanCigarrillo({
    required DateTime inicio,
    DateTime? diaD,
    this.lineaBaseDias = 7,
    this.porcentajes = const [25, 50, 75],
    this.consolidacionDias = 28,
    this.focoDias = 14,
    this.preparacionDias = 7,
  })  : inicio = soloDia(inicio),
        diaD = soloDia(diaD ?? sumarDias(inicio, 28));

  final DateTime inicio;
  final DateTime diaD;
  final int lineaBaseDias;
  final List<int> porcentajes;
  final int consolidacionDias;
  final int focoDias;
  final int preparacionDias;

  /// Fase de una fecha (regla 32).
  FaseHabito fase(DateTime f) {
    final d = soloDia(f);
    if (d.isBefore(inicio)) return FaseHabito.noIniciado;
    if (d.isBefore(sumarDias(inicio, lineaBaseDias))) {
      return FaseHabito.lineaBase;
    }
    if (d.isBefore(sumarDias(diaD, -preparacionDias))) {
      return FaseHabito.reduccion;
    }
    if (d.isBefore(diaD)) return FaseHabito.preparacion;
    if (d == diaD) return FaseHabito.diaD;
    if (d.isBefore(sumarDias(diaD, consolidacionDias))) {
      return FaseHabito.libre;
    }
    return FaseHabito.mantenimiento;
  }

  /// Modo foco: del Día D a Día D + [focoDias] − 1.
  bool enFoco(DateTime f) {
    final d = soloDia(f);
    return !d.isBefore(diaD) && d.isBefore(sumarDias(diaD, focoDias));
  }

  /// Porcentaje de reducción de la etapa (semanas desde el fin de la línea
  /// base; después de la última se mantiene la última). Nulo fuera de
  /// reducción y preparación.
  int? porcentajeEtapa(DateTime f) {
    final fase_ = fase(f);
    if (fase_ != FaseHabito.reduccion && fase_ != FaseHabito.preparacion) {
      return null;
    }
    if (porcentajes.isEmpty) return null;
    final semanas =
        diasEntre(sumarDias(inicio, lineaBaseDias), soloDia(f)) ~/ 7;
    return porcentajes[semanas.clamp(0, porcentajes.length - 1)];
  }

  /// Límite del día en cigarrillos, dado el promedio en centésimas.
  int? limiteDelDia(DateTime f, int promedioCentesimas) {
    final p = porcentajeEtapa(f);
    return p == null ? null : limiteReduccion(promedioCentesimas, p);
  }
}

/// `promedio × (100 − pct) ÷ 100`, mitad hacia arriba, mínimo 0.
int limiteReduccion(int promedioCentesimas, int pct) {
  final v = redondearMitadArriba(promedioCentesimas * (100 - pct), 10000);
  return v < 0 ? 0 : v;
}

/// Promedio de la línea base en centésimas (regla 31). [consumosPorDiaConDatos]
/// trae solo los días con datos. Nulo si hay menos de [minimoDias].
int? promedioLineaBase(List<int> consumosPorDiaConDatos, {int minimoDias = 5}) {
  final n = consumosPorDiaConDatos.length;
  if (n < minimoDias || n == 0) return null;
  final suma = consumosPorDiaConDatos.fold<int>(0, (a, b) => a + b);
  return redondearMitadArriba(suma * 100, n);
}

class RachaLibre {
  const RachaLibre(this.actual, this.mejor, this.acumulados);
  final int actual;
  final int mejor;
  final int acumulados;
}

/// Días libres desde el Día D (regla 41). [consumoPorDia]: cigarrillos por
/// día (ausente = 0). Hoy cuenta libre mientras no haya consumo.
RachaLibre calcularRachaLibre({
  required DateTime diaD,
  required DateTime hoy,
  required Map<DateTime, int> consumoPorDia,
}) {
  final h = soloDia(hoy);
  var actual = 0, mejor = 0, acum = 0;
  for (var d = soloDia(diaD); !d.isAfter(h); d = sumarDias(d, 1)) {
    if ((consumoPorDia[d] ?? 0) == 0) {
      actual++;
      acum++;
      if (actual > mejor) mejor = actual;
    } else {
      actual = 0;
    }
  }
  return RachaLibre(actual, mejor, acum);
}

/// Días de recaída: desde el Día D con al menos un cigarrillo (regla 40).
List<DateTime> diasDeRecaida(
    DateTime diaD, Map<DateTime, int> consumoPorDia) {
  final l = [
    for (final e in consumoPorDia.entries)
      if (e.value > 0 && !soloDia(e.key).isBefore(soloDia(diaD))) soloDia(e.key)
  ]..sort();
  return l;
}

/// Sugerir apoyo profesional con calidez (regla 42).
bool sugerirApoyo(List<DateTime> recaidas, DateTime hoy,
    {int dias = 14, int minimo = 3}) {
  final desde = sumarDias(soloDia(hoy), -(dias - 1));
  return recaidas
          .where((d) => !d.isBefore(desde) && !d.isAfter(soloDia(hoy)))
          .length >=
      minimo;
}

enum SemaforoHabito { verde, ambar, terracota }

/// Semáforo del refresco ocasional (regla 45), con enteros.
SemaforoHabito semaforoAzucar(int usadas, int limite, {int umbralPb = 7500}) {
  if (limite <= 0) {
    return usadas == 0 ? SemaforoHabito.verde : SemaforoHabito.terracota;
  }
  if (usadas > limite) return SemaforoHabito.terracota;
  if (usadas * 10000 >= limite * umbralPb) return SemaforoHabito.ambar;
  return SemaforoHabito.verde;
}

/// Ahorro de un día en centavos (regla 49). Nunca negativo.
int ahorroDia({
  required int promedioCentesimas,
  required int consumoDia,
  required int precioCajetillaCentavos,
  required int cigarrillosPorCajetilla,
}) {
  final dif = promedioCentesimas - consumoDia * 100;
  if (dif <= 0 || cigarrillosPorCajetilla <= 0) return 0;
  return redondearMitadArriba(
      dif * precioCajetillaCentavos, cigarrillosPorCajetilla * 100);
}

/// Ahorro total: solo días con datos y desde que termina la línea base.
int ahorroTotal({
  required DateTime finLineaBase,
  required Map<DateTime, int> consumoDiasConDatos,
  required int promedioCentesimas,
  required int precioCajetillaCentavos,
  required int cigarrillosPorCajetilla,
}) {
  var t = 0;
  for (final e in consumoDiasConDatos.entries) {
    if (soloDia(e.key).isBefore(soloDia(finLineaBase))) continue;
    t += ahorroDia(
      promedioCentesimas: promedioCentesimas,
      consumoDia: e.value,
      precioCajetillaCentavos: precioCajetillaCentavos,
      cigarrillosPorCajetilla: cigarrillosPorCajetilla,
    );
  }
  return t;
}

/// Hitos de constancia (regla 48): solo cifras, sin afirmaciones médicas.
const hitosCigarrillo = [1, 3, 7, 14, 30, 60, 90, 180, 365];
const hitosAzucar = [3, 7, 14, 30];

List<int> hitosAlcanzados(int diasLibres, List<int> hitos) =>
    [for (final h in hitos) if (diasLibres >= h) h];

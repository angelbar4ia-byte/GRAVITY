import 'fecha.dart';

/// Bloque recurrente (regla 65). Horas en minutos desde medianoche.
class BloqueRecurrente {
  const BloqueRecurrente({
    required this.id,
    required this.inicioMin,
    required this.duracionMin,
    required this.dias,
    required this.desde,
    this.hasta,
    this.cadaSemanas = 1,
    this.minimo = false,
  });
  final String id;
  final int inicioMin;
  final int duracionMin;
  final int dias; // máscara lun = 1 … dom = 64
  final DateTime desde;
  final DateTime? hasta;
  final int cadaSemanas;
  final bool minimo;

  int get finMin => inicioMin + duracionMin;

  /// ¿Ocurre en [f]? (por días, intervalo de semanas y vigencia)
  bool ocurreEn(DateTime f) {
    final d = soloDia(f);
    if (d.isBefore(soloDia(desde))) return false;
    if (hasta != null && d.isAfter(soloDia(hasta!))) return false;
    if (dias & mascaraDia(d) == 0) return false;
    final semanas = diasEntre(lunesDe(desde), lunesDe(d)) ~/ 7;
    return semanas % (cadaSemanas < 1 ? 1 : cadaSemanas) == 0;
  }
}

class Intervalo {
  const Intervalo(this.inicio, this.fin);
  final int inicio;
  final int fin;
}

/// Huecos libres del día entre [despertarMin] y [dormirMin] (regla 67),
/// ordenados por cercanía a [preferidaMin] si se da, si no por hora.
List<Intervalo> huecosLibres(
  int despertarMin,
  int dormirMin,
  List<Intervalo> ocupados, {
  int minimoMin = 1,
  int? preferidaMin,
}) {
  final o = [...ocupados]..sort((a, b) => a.inicio.compareTo(b.inicio));
  final r = <Intervalo>[];
  var cursor = despertarMin;
  for (final x in o) {
    if (x.inicio - cursor >= minimoMin) r.add(Intervalo(cursor, x.inicio));
    if (x.fin > cursor) cursor = x.fin;
  }
  if (dormirMin - cursor >= minimoMin) r.add(Intervalo(cursor, dormirMin));
  if (preferidaMin != null) {
    int dist(Intervalo i) => preferidaMin < i.inicio
        ? i.inicio - preferidaMin
        : (preferidaMin > i.fin ? preferidaMin - i.fin : 0);
    r.sort((a, b) => dist(a).compareTo(dist(b)));
  }
  return r;
}

/// Bloques que se cruzan con [nuevo] (el aviso no impide guardar).
List<Intervalo> conflictos(Intervalo nuevo, List<Intervalo> otros) => [
      for (final x in otros)
        if (nuevo.inicio < x.fin && x.inicio < nuevo.fin) x
    ];

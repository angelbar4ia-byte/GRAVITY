import 'fecha.dart';
import 'semana.dart';

/// Una entrada (+) o salida (−) de dinero en su fecha real (vista de flujo,
/// sección 4 y 5.6 bis, punto 4, pasos 9 y 10).
class EventoFlujo {
  final Fecha fecha;

  /// Centavos: positivo si entra, negativo si sale. Nunca cero.
  final int monto;
  final String concepto;

  EventoFlujo(this.fecha, this.monto, this.concepto) {
    if (monto == 0) throw ArgumentError('Un evento de flujo no puede ser cero');
  }

  bool get esEntrada => monto > 0;

  @override
  String toString() => '$fecha $concepto $monto';
}

/// Saldo proyectado de un día con la **regla prudente** de 5.1 bis, punto 9:
/// si en un mismo día hay entradas y salidas, se suponen **primero las
/// salidas** (peor caso) y se muestra también el saldo al cierre.
class DiaFlujo {
  final Fecha fecha;
  final int saldoInicial;
  final int entradas;

  /// Suma de salidas, en positivo.
  final int salidas;
  final List<EventoFlujo> eventos;

  const DiaFlujo({
    required this.fecha,
    required this.saldoInicial,
    required this.entradas,
    required this.salidas,
    required this.eventos,
  });

  /// Saldo después de las salidas y antes de las entradas.
  int get saldoPeorCaso => saldoInicial - salidas;

  int get saldoCierre => saldoInicial - salidas + entradas;
}

/// Proyección de saldo día por día (calendario de flujo, 5.1 bis punto 9).
class ProyeccionFlujo {
  final List<DiaFlujo> dias;

  /// Saldo mínimo aceptable (por defecto cero, configurable: 5.6 bis punto 4).
  final int saldoMinimo;

  const ProyeccionFlujo(this.dias, this.saldoMinimo);

  /// Días en que el saldo en el peor caso baja del mínimo (alerta de flujo).
  List<DiaFlujo> get diasEnRiesgo =>
      dias.where((d) => d.saldoPeorCaso < saldoMinimo).toList();

  bool get hayAlerta => diasEnRiesgo.isNotEmpty;

  DiaFlujo? get primerDiaEnRiesgo {
    final riesgo = diasEnRiesgo;
    return riesgo.isEmpty ? null : riesgo.first;
  }

  DiaFlujo dia(Fecha fecha) => dias.firstWhere((d) => d.fecha == fecha);
}

/// Proyecta el saldo de [desde] a [hasta] a partir de [saldoInicial]
/// (el saldo al empezar [desde]) y los [eventos] con fecha.
///
/// Los eventos fuera del rango se ignoran. La alerta usa el saldo en el peor
/// caso de cada día contra [saldoMinimo].
ProyeccionFlujo proyectarFlujo({
  required int saldoInicial,
  required Fecha desde,
  required Fecha hasta,
  required Iterable<EventoFlujo> eventos,
  int saldoMinimo = 0,
}) {
  final porDia = <Fecha, List<EventoFlujo>>{};
  for (final e in eventos) {
    if (e.fecha.antesDe(desde) || e.fecha.despuesDe(hasta)) continue;
    porDia.putIfAbsent(e.fecha, () => []).add(e);
  }
  final dias = <DiaFlujo>[];
  var saldo = saldoInicial;
  for (var f = desde; !f.despuesDe(hasta); f = f.sumarDias(1)) {
    final delDia = porDia[f] ?? const <EventoFlujo>[];
    final entradas = delDia
        .where((e) => e.esEntrada)
        .fold<int>(0, (t, e) => t + e.monto);
    final salidas = delDia
        .where((e) => !e.esEntrada)
        .fold<int>(0, (t, e) => t - e.monto);
    final dia = DiaFlujo(
      fecha: f,
      saldoInicial: saldo,
      entradas: entradas,
      salidas: salidas,
      eventos: List.unmodifiable(delDia),
    );
    dias.add(dia);
    saldo = dia.saldoCierre;
  }
  return ProyeccionFlujo(List.unmodifiable(dias), saldoMinimo);
}

/// Entradas y salidas de una semana en la vista de flujo.
class FlujoSemana {
  final Semana semana;
  final int entradas;

  /// Suma de salidas, en positivo.
  final int salidas;

  const FlujoSemana(this.semana, this.entradas, this.salidas);

  int get neto => entradas - salidas;
}

/// Agrupa los [eventos] por semana (lunes a domingo) entre las semanas de
/// [desde] y [hasta], incluidas las semanas sin eventos.
///
/// Ejemplo (5.6 bis, punto 5): la semana del 26/oct al 1/nov/2026 tiene
/// entradas $0 y salidas $8,000; la del 2 al 8/nov, entradas $23,000.
List<FlujoSemana> flujoPorSemana(
  Iterable<EventoFlujo> eventos, {
  required Fecha desde,
  required Fecha hasta,
}) {
  final resultado = <FlujoSemana>[];
  final lista = eventos.toList();
  for (var s = Semana.de(desde); !s.inicio.despuesDe(hasta); s = s.siguiente) {
    final deLaSemana = lista.where((e) => s.contiene(e.fecha));
    final entradas = deLaSemana
        .where((e) => e.esEntrada)
        .fold<int>(0, (t, e) => t + e.monto);
    final salidas = deLaSemana
        .where((e) => !e.esEntrada)
        .fold<int>(0, (t, e) => t - e.monto);
    resultado.add(FlujoSemana(s, entradas, salidas));
  }
  return resultado;
}

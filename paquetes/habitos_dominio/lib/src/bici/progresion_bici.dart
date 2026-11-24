/// B1.4 · Progresión informativa de la salida (4.9, PB-12). **La app no
/// propone una meta:** informa cuánto cambió la salida respecto al promedio de
/// las últimas cuatro y, si el aumento pasa del tope, muestra una nota. No
/// bloquea, no tiene alarma y **no se muestra en modo foco** (4.10). No es
/// consejo de entrenamiento: es una comparación de números.
library;

import '../fecha.dart';
import 'reglas_bici.dart';
import 'tipos_bici.dart';

class ProgresionBici {
  const ProgresionBici({
    this.promedioDuracionMin,
    this.cambioDuracionPct,
    this.promedioDistanciaM,
    this.cambioDistanciaPct,
    this.mostrarNota = false,
    this.enFoco = false,
  });

  /// Sin historial suficiente o en modo foco: no hay nada que mostrar.
  static const vacia = ProgresionBici();

  final int? promedioDuracionMin;

  /// Cambio de la salida frente al promedio, en % entero (puede ser negativo).
  final int? cambioDuracionPct;
  final int? promedioDistanciaM;
  final int? cambioDistanciaPct;

  /// ¿Mostrar la nota «bastante más larga que tus últimas»?
  final bool mostrarNota;

  /// Modo foco: la bicicleta no sugiere aumentos.
  final bool enFoco;

  /// Nunca bloquea.
  bool get bloquea => false;
}

class _Medida {
  const _Medida(this.suma, this.n, this.actual);
  final int suma;
  final int n;
  final int actual;

  int get promedio => redondearMitadArriba(suma, n);

  /// Cambio % con enteros, mitad hacia arriba en valor absoluto.
  int get cambioPct {
    final dif = actual * n - suma; // (actual − suma/n) × n
    final base = suma;
    final abs = redondearMitadArriba(dif.abs() * 100, base);
    return dif < 0 ? -abs : abs;
  }

  /// ¿Pasa del tope? Estrictamente más (exactamente 20 % no pasa).
  bool pasa(int topePct) => actual * n * 100 > suma * (100 + topePct);
}

/// Evalúa [actual] contra las últimas [ReglasBicicleta.salidasParaPromedio]
/// salidas **anteriores** a ella que sí salieron y traen el dato.
///
/// - Menos de cuatro con dato: sin comparación (`vacia`), sin nota.
/// - Una salida de 0 minutos (o sin dato) no entra al promedio: nunca se
///   divide entre cero.
/// - [modoFoco]: devuelve `vacia` con `enFoco` (no se muestra nada).
ProgresionBici evaluarProgresion({
  required Salida actual,
  required List<Salida> historial,
  bool modoFoco = false,
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) {
  if (modoFoco) return const ProgresionBici(enFoco: true);
  final dia = soloDia(actual.fecha);
  final previas = [
    for (final s in salidasRecientes(historial))
      if (s.id != actual.id &&
          (soloDia(s.fecha).isBefore(dia) ||
              (soloDia(s.fecha) == dia && s.n < actual.n)))
        s,
  ];
  final n = reglas.salidasParaPromedio;

  _Medida? medir(int? Function(Salida) dato) {
    final valor = dato(actual);
    if (valor == null || valor <= 0) return null;
    final vs = [
      for (final s in previas)
        if ((dato(s) ?? 0) > 0) dato(s)!,
    ].take(n).toList();
    if (vs.length < n) return null;
    return _Medida(vs.fold<int>(0, (a, b) => a + b), n, valor);
  }

  final d = medir((s) => s.duracionMin);
  final k = medir((s) => s.distanciaM);
  if (d == null && k == null) return ProgresionBici.vacia;
  return ProgresionBici(
    promedioDuracionMin: d?.promedio,
    cambioDuracionPct: d?.cambioPct,
    promedioDistanciaM: k?.promedio,
    cambioDistanciaPct: k?.cambioPct,
    mostrarNota:
        (d?.pasa(reglas.topeAumentoPct) ?? false) ||
        (k?.pasa(reglas.topeAumentoPct) ?? false),
  );
}

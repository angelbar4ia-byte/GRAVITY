import 'dinero.dart';
import 'presupuesto.dart';

/// Una semana de la proyección de salida de deuda.
class SemanaDeuda {
  /// 1 = la primera semana proyectada.
  final int numero;

  /// Saldo de cada deuda al terminar la semana.
  final Map<String, int> saldos;

  /// Intereses estimados que se generaron en la semana.
  final int intereses;

  /// Parte del remanente que ya no tuvo deuda que pagar y va a ahorro.
  final int ahorro;

  const SemanaDeuda(this.numero, this.saldos, this.intereses, this.ahorro);
}

/// Proyección ilustrativa de salida de deuda (5.6 bis, punto 5, "Salida de
/// deuda del ejemplo"; prueba 10 del motor).
class ProyeccionDeuda {
  final List<SemanaDeuda> semanas;

  const ProyeccionDeuda(this.semanas);

  int get interesesTotales => semanas.fold(0, (t, s) => t + s.intereses);

  /// Primera semana en que la deuda [deudaId] queda en cero.
  int? semanaDeLiquidacion(String deudaId) {
    for (final s in semanas) {
      if ((s.saldos[deudaId] ?? 0) == 0) return s.numero;
    }
    return null;
  }

  /// Primera semana sin ninguna deuda.
  int? get semanaLibreDeDeuda {
    for (final s in semanas) {
      if (s.saldos.values.every((v) => v == 0)) return s.numero;
    }
    return null;
  }
}

/// Proyecta semana a semana cómo baja la deuda con los abonos planeados y el
/// remanente como abono extra (5.6 bis, punto 7).
///
/// Supuestos (los del ejemplo del diseño; el estimador real de intereses es
/// de la Fase 2, 5.3):
/// - Interés **semanal simple** = saldo × tasa anual ÷ 52, redondeado al
///   centavo (R1), solo en deudas con costo. Los préstamos familiares no
///   crecen.
/// - Cada deuda recibe su abono planeado sin pasar de su saldo.
/// - El [remanenteSemanal] se aplica como abono extra en el orden de
///   [ordenDeAbonoExtra] y lo que sobra va a ahorro.
/// - **Sin grupo de deudas prioritarias**, el abono planeado de una deuda ya
///   liquidada **no se reasigna solo**: se libera cuando la persona vuelve a
///   armar el plan (la app propone y la persona confirma). Así se reproduce
///   el ejemplo del diseño (ahorro de $160.09 en la semana 5 y $1,520.00
///   desde la semana 6).
/// - **Con grupo** (P12 y P19; regla 4 de 4.5), el abono que libera una
///   deuda liquidada (completo, o lo que sobró en la semana en que se
///   liquidó) se suma al remanente y va a la siguiente deuda del grupo; cuando
///   el grupo queda pagado, va a ahorro.
ProyeccionDeuda proyectarSalidaDeDeuda({
  required List<Renglon<DeudaPlan>> abonos,
  required int remanenteSemanal,
  int semanas = 52,
  ParametrosPlan parametros = const ParametrosPlan(),
}) {
  final saldos = <String, int>{};
  for (final r in abonos) {
    final saldo = r.origen.saldo;
    if (saldo == null) {
      throw ArgumentError('La deuda ${r.origen.id} necesita su saldo');
    }
    saldos[r.origen.id] = saldo;
  }
  final conGrupo = hayGrupoPrioritario(abonos.map((r) => r.origen));
  final resultado = <SemanaDeuda>[];
  for (var n = 1; n <= semanas; n++) {
    var intereses = 0;
    var liberado = 0;
    for (final r in abonos) {
      final d = r.origen;
      var saldo = saldos[d.id]!;
      if (saldo <= 0) {
        liberado += r.semanal;
        continue;
      }
      if (d.tipo == TipoDeuda.conCosto) {
        final interes = dividirRedondeando(
          saldo * d.tasaAnualPuntosBase,
          puntosBaseEnCien * 52,
        );
        saldo += interes;
        intereses += interes;
      }
      final aplicado = r.semanal < saldo ? r.semanal : saldo;
      saldo -= aplicado;
      liberado += r.semanal - aplicado;
      saldos[d.id] = saldo;
    }
    final destino = repartirRemanente(
      remanenteSemanal,
      {for (final r in abonos) r.origen.conSaldo(saldos[r.origen.id]!): 0},
      parametros: parametros,
      liberado: conGrupo ? liberado : 0,
    );
    for (final extra in destino.abonosExtra) {
      saldos[extra.deuda.id] = saldos[extra.deuda.id]! - extra.monto;
    }
    resultado.add(
      SemanaDeuda(n, Map.unmodifiable(saldos), intereses, destino.ahorro),
    );
  }
  return ProyeccionDeuda(List.unmodifiable(resultado));
}

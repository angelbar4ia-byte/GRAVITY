import 'dinero.dart';
import 'semana.dart';

/// Frecuencias de ingresos y pagos (sección 4 del diseño de FINANZAS).
///
/// [vecesAlAnio] es cuántas veces ocurre en un año de 52 semanas, 12 meses o
/// 24 quincenas, que es la base de la tabla de la sección 4:
///
/// | Frecuencia | Equivalente semanal |
/// |---|---|
/// | Semanal | monto |
/// | Catorcenal | monto × 26 / 52 (= monto ÷ 2) |
/// | Quincenal | monto × 24 / 52 |
/// | Mensual | monto × 12 / 52 |
/// | Bimestral / trimestral / semestral | monto × (12/n) / 52 |
/// | Anual | monto / 52 |
/// | Diaria | monto × días activos por semana |
enum Frecuencia {
  semanal(52),
  catorcenal(26),
  quincenal(24),
  mensual(12),
  bimestral(6),
  trimestral(4),
  semestral(2),
  anual(1),

  /// Diaria con días activos por semana (por ejemplo, el pasaje de lunes a
  /// viernes): monto × días activos.
  diaria(null);

  /// Veces al año; nulo en [diaria], que depende de los días activos.
  final int? vecesAlAnio;

  const Frecuencia(this.vecesAlAnio);
}

/// Equivalente de un monto recurrente, guardado **exacto** como monto anual en
/// centavos (regla R2 de `dinero.dart`).
///
/// Como todas las frecuencias de la sección 4 son un número entero de veces
/// al año, el monto anual es exacto y la única división ocurre al pedir el
/// valor de un periodo (÷52 semana, ÷26 catorcena, ÷24 quincena, ÷12 mes),
/// redondeado una sola vez con la regla R1.
///
/// Ejemplo (5.6 bis, punto 5): $9,000 quincenal = 21,600,000 centavos al año;
/// semanal = 21,600,000 ÷ 52 = 415,384.6 → **$4,153.85**.
class Equivalente {
  /// Monto anual exacto en centavos.
  final int anualCentavos;

  const Equivalente(this.anualCentavos);

  static const Equivalente cero = Equivalente(0);

  /// Equivalente de [montoCentavos] que se repite con [frecuencia].
  ///
  /// En [Frecuencia.diaria] hay que indicar [diasActivosPorSemana] (1 a 7).
  factory Equivalente.de(
    int montoCentavos,
    Frecuencia frecuencia, {
    int? diasActivosPorSemana,
  }) {
    if (frecuencia == Frecuencia.diaria) {
      if (diasActivosPorSemana == null ||
          diasActivosPorSemana < 1 ||
          diasActivosPorSemana > 7) {
        throw ArgumentError(
          'La frecuencia diaria necesita de 1 a 7 días activos por semana',
        );
      }
      return Equivalente(montoCentavos * diasActivosPorSemana * 52);
    }
    if (diasActivosPorSemana != null) {
      throw ArgumentError('Los días activos solo aplican a la frecuencia diaria');
    }
    return Equivalente(montoCentavos * frecuencia.vecesAlAnio!);
  }

  /// Suma exacta de varios equivalentes.
  static Equivalente suma(Iterable<Equivalente> equivalentes) => Equivalente(
    equivalentes.fold<int>(0, (total, e) => total + e.anualCentavos),
  );

  Equivalente operator +(Equivalente otro) =>
      Equivalente(anualCentavos + otro.anualCentavos);

  Equivalente operator -(Equivalente otro) =>
      Equivalente(anualCentavos - otro.anualCentavos);

  /// Equivalente semanal en centavos (÷ 52, regla R1).
  int get semanal => dividirRedondeando(anualCentavos, 52);

  /// Valor del periodo, con los factores de 5.6 bis, punto 2 (los mismos de
  /// la sección 4): semana ÷52, catorcena ÷26 (semanal × 2), quincena ÷24
  /// (semanal × 52 ÷ 24) y mes ÷12 (semanal × 52 ÷ 12).
  int enPeriodo(TipoPeriodo periodo) {
    switch (periodo) {
      case TipoPeriodo.semana:
        return semanal;
      case TipoPeriodo.catorcena:
        return dividirRedondeando(anualCentavos, 26);
      case TipoPeriodo.quincena:
        return dividirRedondeando(anualCentavos, 24);
      case TipoPeriodo.mes:
        return dividirRedondeando(anualCentavos, 12);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Equivalente && other.anualCentavos == anualCentavos;

  @override
  int get hashCode => anualCentavos.hashCode;

  @override
  String toString() => 'Equivalente(${formatearCentavos(semanal)} por semana)';
}

/// Reparte los equivalentes semanales de varios renglones para que sumen
/// exactamente el total semanal redondeado (regla R2, mayor resto).
///
/// Ejemplo (5.6 bis, punto 5): renta, luz, agua, internet, celular, reserva y
/// variables dan $1,846.15, $103.85, $69.23, $92.31, $80.77, $30.00 y
/// $3,250.00, que suman exactamente $5,472.31.
List<int> semanalesQueSuman(List<Equivalente> renglones) {
  if (renglones.any((e) => e.anualCentavos < 0)) {
    throw ArgumentError('Los renglones deben ser cero o positivos');
  }
  return repartirConMayorResto(
    [for (final e in renglones) e.anualCentavos],
    52,
  );
}

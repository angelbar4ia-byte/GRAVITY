import 'fecha.dart';

/// Semana de lunes a domingo (convención de GRAVITY y decisión 43 de FINANZAS).
///
/// Cada movimiento pertenece a la semana de su **fecha**, no de cuándo se
/// capturó (5.6 bis, punto 2).
///
/// Interpretación: el diseño permite configurar el inicio de semana por hogar
/// (5.0), pero la convención obligatoria de GRAVITY (fase-0, sección 4) la fija
/// en **lunes**. Aquí es fija; si el dueño quiere otro inicio se agrega como
/// parámetro (pregunta en la especificación de la Fase 1).
class Semana implements Comparable<Semana> {
  /// Lunes con el que empieza la semana.
  final Fecha inicio;

  const Semana._(this.inicio);

  /// La semana (lunes a domingo) a la que pertenece [fecha].
  factory Semana.de(Fecha fecha) =>
      Semana._(fecha.sumarDias(DateTime.monday - fecha.diaSemana));

  /// La semana [numero] del año ISO [anioIso] (ISO 8601: la semana 1 es la
  /// que contiene el primer jueves del año).
  factory Semana.iso(int anioIso, int numero) {
    if (numero < 1 || numero > semanasIsoDelAnio(anioIso)) {
      throw ArgumentError('El año ISO $anioIso no tiene semana $numero');
    }
    // El 4 de enero siempre cae en la semana 1.
    final semana1 = Semana.de(Fecha(anioIso, 1, 4));
    return Semana._(semana1.inicio.sumarDias((numero - 1) * 7));
  }

  /// Domingo con el que termina la semana.
  Fecha get fin => inicio.sumarDias(6);

  /// Los siete días, de lunes a domingo.
  List<Fecha> get dias => [for (var i = 0; i < 7; i++) inicio.sumarDias(i)];

  bool contiene(Fecha fecha) => !fecha.antesDe(inicio) && !fecha.despuesDe(fin);

  Semana get siguiente => Semana._(inicio.sumarDias(7));
  Semana get anterior => Semana._(inicio.sumarDias(-7));

  /// Suma (o resta) semanas completas.
  Semana mas(int semanas) => Semana._(inicio.sumarDias(7 * semanas));

  /// Semanas completas desde esta hasta [otra] (negativo si es anterior).
  int semanasHasta(Semana otra) => inicio.diasHasta(otra.inicio) ~/ 7;

  Fecha get _jueves => inicio.sumarDias(3);

  /// Año ISO de la semana: el año de su jueves (puede diferir del año de
  /// [inicio] en las semanas que cruzan el año).
  int get anioIso => _jueves.anio;

  /// Número de semana ISO 8601 (1 a 52 o 53).
  int get numeroIso => (_jueves.diaDelAnio - 1) ~/ 7 + 1;

  /// Cuántas semanas ISO tiene [anioIso] (52 o 53).
  static int semanasIsoDelAnio(int anioIso) =>
      Semana.de(Fecha(anioIso, 12, 28)).numeroIso;

  @override
  int compareTo(Semana otra) => inicio.compareTo(otra.inicio);

  @override
  bool operator ==(Object other) => other is Semana && other.inicio == inicio;

  @override
  int get hashCode => inicio.hashCode;

  @override
  String toString() =>
      'Semana $anioIso-W${numeroIso.toString().padLeft(2, '0')} '
      '($inicio a $fin)';
}

/// Periodos en que una persona puede ver sus datos (5.1 y 5.6 bis, punto 2).
enum TipoPeriodo { semana, catorcena, quincena, mes }

/// Rango de fechas cerrado `[inicio, fin]`.
class Periodo {
  final Fecha inicio;
  final Fecha fin;

  Periodo(this.inicio, this.fin) {
    if (fin.antesDe(inicio)) {
      throw ArgumentError(
        'El periodo termina ($fin) antes de empezar ($inicio)',
      );
    }
  }

  /// La semana (lunes a domingo) de [fecha].
  factory Periodo.semana(Fecha fecha) {
    final semana = Semana.de(fecha);
    return Periodo(semana.inicio, semana.fin);
  }

  /// La catorcena de [fecha]: bloques de 14 días a partir de la [ancla] que
  /// fija la persona (5.6 bis, punto 2). Funciona antes y después del ancla.
  factory Periodo.catorcena(Fecha fecha, {required Fecha ancla}) {
    final dias = ancla.diasHasta(fecha);
    final bloque = (dias / 14).floor();
    final inicio = ancla.sumarDias(bloque * 14);
    return Periodo(inicio, inicio.sumarDias(13));
  }

  /// La quincena de [fecha]: del 1 al [diaCorte] y del día siguiente al último
  /// del mes.
  ///
  /// Interpretación: se usan las quincenas del calendario (1–15 y 16–fin por
  /// defecto), sin depender del día exacto de pago de cada persona.
  factory Periodo.quincena(Fecha fecha, {int diaCorte = 15}) {
    if (diaCorte < 1 || diaCorte >= 28) {
      throw ArgumentError.value(
        diaCorte,
        'diaCorte',
        'debe estar entre 1 y 27',
      );
    }
    if (fecha.dia <= diaCorte) {
      return Periodo(
        fecha.primerDiaDelMes,
        Fecha(fecha.anio, fecha.mes, diaCorte),
      );
    }
    return Periodo(
      Fecha(fecha.anio, fecha.mes, diaCorte + 1),
      fecha.ultimoDiaDelMes,
    );
  }

  /// El mes natural de [fecha].
  factory Periodo.mes(Fecha fecha) =>
      Periodo(fecha.primerDiaDelMes, fecha.ultimoDiaDelMes);

  /// El periodo de [tipo] que contiene [fecha]. La catorcena necesita [ancla].
  factory Periodo.de(TipoPeriodo tipo, Fecha fecha, {Fecha? ancla}) {
    switch (tipo) {
      case TipoPeriodo.semana:
        return Periodo.semana(fecha);
      case TipoPeriodo.catorcena:
        if (ancla == null) {
          throw ArgumentError('La catorcena necesita una fecha ancla');
        }
        return Periodo.catorcena(fecha, ancla: ancla);
      case TipoPeriodo.quincena:
        return Periodo.quincena(fecha);
      case TipoPeriodo.mes:
        return Periodo.mes(fecha);
    }
  }

  int get numeroDeDias => inicio.diasHasta(fin) + 1;

  bool contiene(Fecha fecha) => !fecha.antesDe(inicio) && !fecha.despuesDe(fin);

  @override
  bool operator ==(Object other) =>
      other is Periodo && other.inicio == inicio && other.fin == fin;

  @override
  int get hashCode => Object.hash(inicio, fin);

  @override
  String toString() => '$inicio a $fin';
}

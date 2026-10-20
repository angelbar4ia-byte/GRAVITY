/// Fecha de calendario sin hora ni zona horaria.
///
/// Convención de GRAVITY: las fechas se toman en la **hora local del
/// dispositivo** y en la base se guardan como `date`. Esta clase representa
/// solo año, mes y día, y hace la aritmética en UTC para no depender de los
/// cambios de horario.
class Fecha implements Comparable<Fecha> {
  final int anio;
  final int mes;
  final int dia;

  const Fecha._(this.anio, this.mes, this.dia);

  /// Crea una fecha y valida que exista (por ejemplo, rechaza el 30 de febrero).
  factory Fecha(int anio, int mes, int dia) {
    final utc = DateTime.utc(anio, mes, dia);
    if (utc.year != anio || utc.month != mes || utc.day != dia) {
      throw ArgumentError('Fecha inválida: $anio-$mes-$dia');
    }
    return Fecha._(anio, mes, dia);
  }

  /// Toma el año, mes y día del [DateTime] tal como viene (local o UTC).
  factory Fecha.deDateTime(DateTime fechaHora) =>
      Fecha._(fechaHora.year, fechaHora.month, fechaHora.day);

  /// Lee el formato ISO `AAAA-MM-DD`.
  factory Fecha.parse(String texto) {
    final partes = texto.split('-');
    if (partes.length != 3) {
      throw FormatException('Se esperaba AAAA-MM-DD', texto);
    }
    return Fecha(
      int.parse(partes[0]),
      int.parse(partes[1]),
      int.parse(partes[2]),
    );
  }

  DateTime get _utc => DateTime.utc(anio, mes, dia);

  /// Día de la semana: 1 = lunes … 7 = domingo (ISO 8601).
  int get diaSemana => _utc.weekday;

  bool get esFinDeSemana => diaSemana >= DateTime.saturday;

  /// Número de día dentro del año (1 = 1 de enero).
  int get diaDelAnio => Fecha(anio, 1, 1).diasHasta(this) + 1;

  Fecha sumarDias(int dias) => Fecha.deDateTime(_utc.add(Duration(days: dias)));

  /// Días desde esta fecha hasta [otra] (negativo si [otra] es anterior).
  int diasHasta(Fecha otra) => otra._utc.difference(_utc).inDays;

  bool antesDe(Fecha otra) => compareTo(otra) < 0;
  bool despuesDe(Fecha otra) => compareTo(otra) > 0;

  /// Días que tiene el mes de [mes] en [anio].
  static int diasDelMes(int anio, int mes) =>
      DateTime.utc(anio, mes + 1, 0).day;

  Fecha get primerDiaDelMes => Fecha._(anio, mes, 1);
  Fecha get ultimoDiaDelMes => Fecha._(anio, mes, diasDelMes(anio, mes));

  /// El día [dia] del mes [mes] de [anio]; si el mes es más corto, el último
  /// día del mes (un "día 31" en abril es el 30). [mes] puede salirse de 1 a
  /// 12 y se normaliza (mes 13 = enero del año siguiente).
  static Fecha enMes(int anio, int mes, int dia) {
    final base = DateTime.utc(anio, mes, 1);
    final ultimo = diasDelMes(base.year, base.month);
    return Fecha._(base.year, base.month, dia > ultimo ? ultimo : dia);
  }

  @override
  int compareTo(Fecha otra) {
    if (anio != otra.anio) return anio.compareTo(otra.anio);
    if (mes != otra.mes) return mes.compareTo(otra.mes);
    return dia.compareTo(otra.dia);
  }

  @override
  bool operator ==(Object other) =>
      other is Fecha &&
      other.anio == anio &&
      other.mes == mes &&
      other.dia == dia;

  @override
  int get hashCode => Object.hash(anio, mes, dia);

  /// Formato ISO `AAAA-MM-DD`.
  @override
  String toString() =>
      '${anio.toString().padLeft(4, '0')}-'
      '${mes.toString().padLeft(2, '0')}-'
      '${dia.toString().padLeft(2, '0')}';
}

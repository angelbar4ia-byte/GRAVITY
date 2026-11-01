/// Días como `DateTime` en UTC a las 00:00 (solo la fecha cuenta).
DateTime dia(int anio, int mes, int d) => DateTime.utc(anio, mes, d);

/// Normaliza cualquier fecha a su día.
DateTime soloDia(DateTime f) => DateTime.utc(f.year, f.month, f.day);

DateTime sumarDias(DateTime f, int n) =>
    DateTime.utc(f.year, f.month, f.day + n);

/// Días entre dos fechas (b − a).
int diasEntre(DateTime a, DateTime b) =>
    soloDia(b).difference(soloDia(a)).inDays;

/// Lunes de la semana de [f] (la semana empieza en lunes).
DateTime lunesDe(DateTime f) =>
    sumarDias(soloDia(f), -(soloDia(f).weekday - DateTime.monday));

/// Máscara de día de la semana: lunes = 1 … domingo = 64.
int mascaraDia(DateTime f) => 1 << (f.weekday - 1);

/// Mitad hacia arriba de `num / den` (enteros no negativos).
int redondearMitadArriba(int num, int den) => (2 * num + den) ~/ (2 * den);

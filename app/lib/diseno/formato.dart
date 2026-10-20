/// Formatos de México para la interfaz: montos en centavos, fechas y horas.
///
/// Funciones puras, sin depender de la configuración regional del dispositivo.
library;

/// Texto que reemplaza a un monto oculto (modo privado).
const String montoOculto = r'$ • • • • •';

/// Formatea centavos como pesos mexicanos: `123450` → `$1,234.50`.
///
/// Los negativos llevan el signo antes del símbolo: `-$85.00`. Con
/// [mostrarSigno], los positivos llevan `+`.
String formatearCentavos(int centavos, {bool mostrarSigno = false}) {
  final negativo = centavos < 0;
  final absoluto = centavos.abs();
  final pesos = absoluto ~/ 100;
  final resto = (absoluto % 100).toString().padLeft(2, '0');
  final digitos = pesos.toString();
  final grupos = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) grupos.write(',');
    grupos.write(digitos[i]);
  }
  final signo = negativo ? '-' : (mostrarSigno && centavos > 0 ? '+' : '');
  return '$signo\$$grupos.$resto';
}

const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _diasLargos = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const _mesesLargos = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// `19:42`
String horaMinutos(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// `mar 20 oct`
String fechaCorta(DateTime t) =>
    '${_diasCortos[t.weekday - 1]} ${t.day} ${_mesesCortos[t.month - 1]}';

/// `Martes 20 de octubre`
String fechaLarga(DateTime t) =>
    '${_diasLargos[t.weekday - 1]} ${t.day} de ${_mesesLargos[t.month - 1]}';

/// `mar 20 oct · 19:42`
String fechaYHora(DateTime t) => '${fechaCorta(t)} · ${horaMinutos(t)}';

/// Número de semana ISO 8601 (la semana empieza en lunes).
int semanaIso(DateTime t) {
  final fecha = DateTime.utc(t.year, t.month, t.day);
  final diaDelAnio = fecha.difference(DateTime.utc(t.year)).inDays + 1;
  final semana = (diaDelAnio - fecha.weekday + 10) ~/ 7;
  if (semana < 1) return semanaIso(DateTime.utc(t.year - 1, 12, 28));
  if (semana > 52) {
    // La semana 53 solo existe si el 28 de diciembre cae en ella.
    final ultima = semanaIso(DateTime.utc(t.year, 12, 28));
    if (semana > ultima) return 1;
  }
  return semana;
}

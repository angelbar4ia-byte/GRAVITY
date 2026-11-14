/// Edición, marcas del lector, hitos de constancia y revisión corta
/// (Fase 4: E4, E8, E9, E10 y E12). Lógica pura, sin Flutter.
library;

import 'fecha.dart';
import 'revision_semanal.dart';

/// Las seis áreas de Hábitos (mismos valores que la base de datos).
const areasHabitos = [
  'espiritual',
  'salud',
  'educacion',
  'personal',
  'laboral',
  'proyectos',
];

/// Valida la edición de un bloque de agenda; devuelve los errores (vacío =
/// se puede guardar). Las horas van en minutos desde medianoche.
List<String> validarBloque({
  required String titulo,
  required String area,
  required int inicioMin,
  required int duracionMin,
  required int dias,
  int? recordarMin,
}) {
  final e = <String>[];
  if (titulo.trim().isEmpty || titulo.trim().length > 120) {
    e.add('El nombre va de 1 a 120 caracteres.');
  }
  if (!areasHabitos.contains(area)) e.add('Elige un área.');
  if (inicioMin < 0 || inicioMin >= 1440) e.add('La hora de inicio no es válida.');
  if (duracionMin < 5 || duracionMin > 1440) {
    e.add('La duración va de 5 minutos a 24 horas.');
  }
  if (dias < 1 || dias > 127) e.add('Elige al menos un día.');
  if (recordarMin != null && (recordarMin < 0 || recordarMin > 1440)) {
    e.add('El recordatorio va de 0 a 1440 minutos antes.');
  }
  return e;
}

/// Valida la edición de un objetivo (además de [validarObjetivo]): el área y
/// los días de la semana. Devuelve los errores.
List<String> validarEdicionObjetivo({
  required String area,
  required bool porDiasDeSemana,
  required int diasSemana,
  int? metaValor,
  String? unidad,
}) {
  final e = <String>[];
  if (!areasHabitos.contains(area)) e.add('Elige un área.');
  if (porDiasDeSemana && (diasSemana < 1 || diasSemana > 127)) {
    e.add('Elige al menos un día.');
  }
  if (metaValor != null && metaValor <= 0) e.add('La meta debe ser mayor que cero.');
  if (unidad != null && unidad.length > 20) {
    e.add('La unidad admite hasta 20 caracteres.');
  }
  return e;
}

/// Límites de las listas de la configuración de un hábito a eliminar.
const maxElementosLista = 10;
const maxLargoElemento = 200;

/// Limpia una lista de motivos, disparadores o reemplazos: sin vacíos ni
/// repetidos, recortada a [maxLargoElemento]. Lanza [ArgumentError] si pasa de
/// [maxElementosLista].
List<String> limpiarLista(Iterable<String> entrada) {
  final r = <String>[];
  for (final t in entrada) {
    var s = t.trim();
    if (s.isEmpty) continue;
    if (s.length > maxLargoElemento) s = s.substring(0, maxLargoElemento);
    if (!r.contains(s)) r.add(s);
  }
  if (r.length > maxElementosLista) {
    throw ArgumentError('Hasta $maxElementosLista elementos por lista.');
  }
  return r;
}

// ------------------------------------------------------------- marcas Biblia

/// Los seis colores de subrayado (sin texto: solo el nombre del color).
const coloresSubrayado = [
  'amarillo',
  'verde',
  'azul',
  'rosa',
  'naranja',
  'morado',
];

/// Referencia de una marca: `libro:capítulo:versículo` (formato de la base).
String referenciaMarca(int libro, int cap, int ver) => '$libro:$cap:$ver';

({int libro, int cap, int ver})? analizarReferenciaMarca(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{1,3}):(\d{1,3})$').firstMatch(s);
  if (m == null) return null;
  return (
    libro: int.parse(m.group(1)!),
    cap: int.parse(m.group(2)!),
    ver: int.parse(m.group(3)!),
  );
}

// -------------------------------------------------------------------- hitos

/// Hitos alcanzados y todavía no vistos (cada uno sale una sola vez).
List<int> hitosPorVer(int diasLibres, List<int> hitos, Set<int> vistos) =>
    [for (final h in hitos) if (diasLibres >= h && !vistos.contains(h)) h];

/// Texto de un hito de constancia: solo cifras, sin afirmaciones médicas ni
/// culpa.
String textoHito(int dias) =>
    dias == 1 ? 'Un día completo. Un paso a la vez.' : '$dias días seguidos. Eso es constancia.';

// --------------------------------------------------------- revisión corta

/// Pregunta de la versión corta de la revisión semanal (30 segundos).
const preguntasRevisionCorta = ['agradezco'];

/// ¿Ya llegó la hora del aviso de la revisión de esta semana y sigue
/// vigente? [diaSemana] 1 (lunes) a 7; [horaMin] y [avisoMin] en minutos.
bool revisionDisponible({
  required DateTime ahora,
  required int diaSemana,
  required int horaMin,
  required int avisoMin,
}) {
  final lunes = lunesDe(ahora);
  if (!revisionVigente(lunes, ahora)) return false;
  final dia = diaDeRevision(lunes, diaSemana: diaSemana);
  final hoy = soloDia(ahora);
  if (hoy.isAfter(dia)) return true;
  if (hoy.isBefore(dia)) return false;
  return ahora.hour * 60 + ahora.minute >= minutoDeAviso(horaMin, avisoMin);
}

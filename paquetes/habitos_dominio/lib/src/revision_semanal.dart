import 'fecha.dart';

/// Cumplimiento semanal de un área en % entero hacia abajo; nulo = sin dato.
int? cumplimientoSemanal(int cumplidos, int programados) =>
    programados <= 0 ? null : (cumplidos * 100) ~/ programados;

/// Cuándo es la revisión de la semana de [f] (regla 124): por omisión el
/// sábado (día 6). Devuelve el día; la hora se combina en la capa de app.
DateTime diaDeRevision(DateTime f, {int diaSemana = DateTime.saturday}) =>
    sumarDias(lunesDe(f), diaSemana - 1);

/// Aviso previo en minutos desde medianoche (14:30 − 15 = 14:15).
int minutoDeAviso(int horaMin, int avisoMin) => horaMin - avisoMin;

enum EstadoRevision { pendiente, enCurso, completada, omitida }

/// ¿Aún se puede hacer sin consecuencias? Hasta el miércoles siguiente.
bool revisionVigente(DateTime semanaLunes, DateTime hoy) =>
    !soloDia(hoy).isAfter(sumarDias(semanaLunes, 9));

/// Pasos de la revisión (regla 125).
const pasosRevision = [
  'resumen_areas',
  'habitos_eliminar',
  'espiritual',
  'dar',
  'ajustes_semana',
];

/// Turnos de cuidado de Papá y qué recordatorios le tocan a cada quien
/// (`docs/specs/fase-5-cuidados.md`, secciones 3 y 7). Todo es puro: recibe la
/// hora de pared y la lista de turnos, sin reloj ni red.
///
/// Los recordatorios llegan **solo a quien está de turno** en ese momento (D5);
/// fuera de turno no llega nada. El texto es genérico y nunca nombra un
/// medicamento (D6): sale de `catalogo_avisos.dart`.
library;

import 'package:flutter/foundation.dart';

import '../avisos/aviso.dart' show HoraDelDia;
import '../avisos/catalogo_avisos.dart';

/// Quién cubre el turno, por clave estable (el esquema los enlaza con personas).
abstract final class RolDeTurno {
  static const cuidadoraPrincipal = 'cuidadora_principal';
  static const hermana = 'hermana';
  static const dueno = 'dueno';
}

/// Un tramo de turno de un día de la semana (1 = lunes … 7 = domingo).
/// [hasta] es exclusivo; `HoraDelDia(24)` es el fin del día.
@immutable
class Turno {
  const Turno({
    required this.cuidador,
    required this.dia,
    required this.desde,
    required this.hasta,
  });

  final String cuidador;
  final int dia;
  final HoraDelDia desde;
  final HoraDelDia hasta;

  bool contiene(DateTime cuando) =>
      cuando.weekday == dia &&
      cuando.hour * 60 + cuando.minute >= desde.minutos &&
      cuando.hour * 60 + cuando.minute < hasta.minutos;
}

const _finDelDia = HoraDelDia(24);
const _c = RolDeTurno.cuidadoraPrincipal;
const _h = RolDeTurno.hermana;
const _d = RolDeTurno.dueno;

/// Turnos de la sección 3 (respuesta del dueño, 7/nov/2026). La noche no tiene
/// responsable asignado (pregunta abierta). El dueño puede editarlos en la
/// laptop; esta es la base cuando no hay otros.
const List<Turno> turnosPorOmision = [
  // Lunes
  Turno(cuidador: _c, dia: 1, desde: HoraDelDia(9), hasta: HoraDelDia(15)),
  Turno(cuidador: _d, dia: 1, desde: HoraDelDia(15), hasta: _finDelDia),
  // Martes: la hermana desde las 15:00 hasta el miércoles a las 7:00.
  Turno(cuidador: _c, dia: 2, desde: HoraDelDia(7, 30), hasta: HoraDelDia(15)),
  Turno(cuidador: _h, dia: 2, desde: HoraDelDia(15), hasta: _finDelDia),
  Turno(cuidador: _h, dia: 3, desde: HoraDelDia(0), hasta: HoraDelDia(7)),
  // Miércoles a viernes
  Turno(
    cuidador: _c,
    dia: 3,
    desde: HoraDelDia(7, 30),
    hasta: HoraDelDia(18, 30),
  ),
  Turno(
    cuidador: _c,
    dia: 4,
    desde: HoraDelDia(7, 30),
    hasta: HoraDelDia(18, 30),
  ),
  Turno(
    cuidador: _c,
    dia: 5,
    desde: HoraDelDia(7, 30),
    hasta: HoraDelDia(18, 30),
  ),
  // Sábado
  Turno(cuidador: _c, dia: 6, desde: HoraDelDia(9), hasta: HoraDelDia(15)),
  Turno(cuidador: _d, dia: 6, desde: HoraDelDia(15), hasta: _finDelDia),
  // Domingo: el dueño todo el día.
  Turno(cuidador: _d, dia: 7, desde: HoraDelDia(0), hasta: _finDelDia),
];

/// Quién está de turno en [cuando] (hora de pared), o `null` si nadie. Las
/// visitas de la hermana no cuentan: no cambian el turno.
String? cuidadorDeTurno(
  DateTime cuando, [
  List<Turno> turnos = turnosPorOmision,
]) {
  for (final t in turnos) {
    if (t.contiene(cuando)) return t.cuidador;
  }
  return null;
}

/// Una toma o comida de Papá que hay que recordar. [objetoId] entra en la
/// `clave`, nunca en el texto.
@immutable
class EventoDeCuidado {
  const EventoDeCuidado({
    required this.tipo,
    required this.objetoId,
    required this.cuando,
  });

  /// `recordatorio_toma` o `recordatorio_comida`.
  final String tipo;
  final String objetoId;
  final DateTime cuando;
}

@immutable
class RecordatorioCuidado {
  const RecordatorioCuidado({
    required this.clave,
    required this.tipo,
    required this.cuando,
  });

  final String clave;
  final String tipo;
  final DateTime cuando;

  /// Título del catálogo: genérico, sin medicamento.
  String get titulo => tituloDeAviso(tipo);
}

String _dia(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Los recordatorios que le tocan a [cuidador]: solo los eventos que caen en
/// su turno, a partir de [ahora] y dentro de [dias]. Sin turno, nada.
List<RecordatorioCuidado> recordatoriosParaCuidador({
  required String cuidador,
  required List<EventoDeCuidado> eventos,
  required DateTime ahora,
  List<Turno> turnos = turnosPorOmision,
  int dias = 7,
}) {
  final limite = ahora.add(Duration(days: dias));
  return [
    for (final e in eventos)
      if ((e.tipo == 'recordatorio_toma' || e.tipo == 'recordatorio_comida') &&
          e.cuando.isAfter(ahora) &&
          !e.cuando.isAfter(limite) &&
          cuidadorDeTurno(e.cuando, turnos) == cuidador)
        RecordatorioCuidado(
          clave:
              'cui:${e.tipo}:${e.objetoId}:${_dia(e.cuando)}:${e.cuando.hour}${e.cuando.minute}',
          tipo: e.tipo,
          cuando: e.cuando,
        ),
  ]..sort((a, b) => a.cuando.compareTo(b.cuando));
}

/// A quién avisa un cambio urgente del dueño: a quien está de turno en [ahora],
/// o `null` si nadie (el esquema decide el respaldo).
String? destinatarioDeCambioUrgente(
  DateTime ahora, [
  List<Turno> turnos = turnosPorOmision,
]) => cuidadorDeTurno(ahora, turnos);

/// Los fines de turno de [cuidador] entre [ahora] y [dias] días después. Los
/// tramos pegados (martes 24:00 con miércoles 0:00) cuentan como un solo turno.
/// Cada uno es un recordatorio `entrega_turno` para que deje sus notas; sin
/// contenido clínico.
List<RecordatorioCuidado> entregasDeTurno({
  required String cuidador,
  required DateTime ahora,
  List<Turno> turnos = turnosPorOmision,
  int dias = 7,
}) {
  final inicio = DateTime(ahora.year, ahora.month, ahora.day);
  final tramos = <({DateTime desde, DateTime hasta})>[];
  for (var i = 0; i <= dias + 1; i++) {
    final dia = DateTime(inicio.year, inicio.month, inicio.day + i);
    for (final t in turnos) {
      if (t.cuidador != cuidador || t.dia != dia.weekday) continue;
      final desde = DateTime(
        dia.year,
        dia.month,
        dia.day,
        t.desde.hora,
        t.desde.minuto,
      );
      final hasta = DateTime(
        dia.year,
        dia.month,
        dia.day,
        t.hasta.hora,
        t.hasta.minuto,
      );
      tramos.add((desde: desde, hasta: hasta));
    }
  }
  tramos.sort((a, b) => a.desde.compareTo(b.desde));
  final fines = <DateTime>[];
  DateTime? finActual;
  for (final t in tramos) {
    if (finActual != null && t.desde.isAfter(finActual)) {
      fines.add(finActual);
      finActual = t.hasta;
    } else if (finActual == null || t.hasta.isAfter(finActual)) {
      finActual = t.hasta;
    }
  }
  if (finActual != null) fines.add(finActual);
  final limite = ahora.add(Duration(days: dias));
  return [
    for (final f in fines)
      if (f.isAfter(ahora) && !f.isAfter(limite))
        RecordatorioCuidado(
          clave: 'cui:entrega_turno:$cuidador:${_dia(f)}:${f.hour}${f.minute}',
          tipo: 'entrega_turno',
          cuando: f,
        ),
  ];
}

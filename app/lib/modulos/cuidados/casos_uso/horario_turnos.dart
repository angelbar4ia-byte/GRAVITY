/// Horario de turnos (spec Fase 5, sección 3) y la regla de a quién llega un
/// recordatorio: **solo a quien está de turno** en ese momento (D5). Las
/// visitas de la hermana no cambian el turno de la cuidadora.
///
/// La plataforma usa [recibeRecordatorio] para decidir a quién avisar.
library;

import '../datos/modelos.dart';

/// Quién está de turno en [ahora]: personas con un turno (no visita) vigente.
Set<String> deTurnoAhora(Iterable<Turno> turnos, DateTime ahora) => {
  for (final t in turnos)
    if (t.tipo == TipoTurno.turno && t.cubre(ahora)) t.personaId,
};

/// `true` si a [personaId] le corresponde un recordatorio de medicamento o de
/// comida en [ahora]. Fuera de turno no llega nada (criterio 1).
bool recibeRecordatorio(
  String personaId,
  Iterable<Turno> turnos,
  DateTime ahora,
) => deTurnoAhora(turnos, ahora).contains(personaId);

/// Personas del horario base: a quién corresponde cada franja.
class PersonasTurno {
  const PersonasTurno({
    required this.cuidadoraId,
    required this.cuidadoraNombre,
    required this.hermanaId,
    required this.hermanaNombre,
    required this.duenoId,
    required this.duenoNombre,
  });

  final String cuidadoraId, cuidadoraNombre;
  final String hermanaId, hermanaNombre;
  final String duenoId, duenoNombre;
}

/// Turnos de la semana que empieza en [lunes], según la tabla de la
/// especificación. Sirve para la demostración y para precargar el
/// calendario; el servidor guarda los turnos reales (`cui_turnos`).
///
/// Supuestos a confirmar con el dueño: el turno del dueño por la tarde llega
/// hasta las 24:00, y las visitas de fin de semana se muestran todo el día.
List<Turno> turnosDeLaSemana(DateTime lunes, PersonasTurno p) {
  final salida = <Turno>[];
  void agregar(
    int dia,
    String id,
    String nombre,
    (int, int) desde,
    (int, int) hasta, {
    TipoTurno tipo = TipoTurno.turno,
  }) {
    final base = soloFecha(lunes).add(Duration(days: dia));
    final inicio = DateTime(
      base.year,
      base.month,
      base.day,
      desde.$1,
      desde.$2,
    );
    final fin = DateTime(base.year, base.month, base.day, hasta.$1, hasta.$2);
    salida.add(
      Turno(
        id: idEstableCuidados(
          'turno:${fechaClave(base)}:$id:${desde.$1}:${desde.$2}',
        ),
        personaId: id,
        nombre: nombre,
        inicio: inicio,
        fin: fin,
        tipo: tipo,
      ),
    );
  }

  final c = (p.cuidadoraId, p.cuidadoraNombre);
  final h = (p.hermanaId, p.hermanaNombre);
  final d = (p.duenoId, p.duenoNombre);
  // Lunes (0): 9:00 a 15:00 cuidadora; dueño de 15:00 en adelante.
  agregar(0, c.$1, c.$2, (9, 0), (15, 0));
  agregar(0, d.$1, d.$2, (15, 0), (24, 0));
  // Martes (1): cuidadora 7:30 a 15:00; hermana de 15:00 en adelante.
  agregar(1, c.$1, c.$2, (7, 30), (15, 0));
  agregar(1, h.$1, h.$2, (15, 0), (24, 0));
  // Miércoles (2): la hermana se va a las 7:00; cuidadora 7:30 a 18:30.
  agregar(2, h.$1, h.$2, (0, 0), (7, 0));
  agregar(2, c.$1, c.$2, (7, 30), (18, 30));
  // Jueves (3) y viernes (4).
  agregar(3, c.$1, c.$2, (7, 30), (18, 30));
  agregar(4, c.$1, c.$2, (7, 30), (18, 30));
  // Sábado (5): 9:00 a 15:00 cuidadora; dueño de 15:00 en adelante; visitas.
  agregar(5, c.$1, c.$2, (9, 0), (15, 0));
  agregar(5, d.$1, d.$2, (15, 0), (24, 0));
  agregar(5, h.$1, h.$2, (0, 0), (24, 0), tipo: TipoTurno.visita);
  // Domingo (6): el dueño todo el día; visitas de la hermana.
  agregar(6, d.$1, d.$2, (0, 0), (24, 0));
  agregar(6, h.$1, h.$2, (0, 0), (24, 0), tipo: TipoTurno.visita);
  return salida;
}

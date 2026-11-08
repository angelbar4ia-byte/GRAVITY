/// Votación del plan familiar (D28; Fase 7, decisión 5): modelo puro.
///
/// Alguien propone un menú; otra persona propone el suyo; se vota **un día**.
/// Si hay empate, cada quien puede **cambiar su voto**.
library;

class ErrorVotacion implements Exception {
  const ErrorVotacion(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Un menú que alguien propone para el plan familiar de un día.
class PropuestaMenu {
  const PropuestaMenu({
    required this.id,
    required this.autorId,
    required this.autorNombre,
    required this.titulo,
    this.platilloIds = const [],
  });
  final String id;
  final String autorId;
  final String autorNombre;
  final String titulo;
  final List<String> platilloIds;
}

enum EstadoVotacion {
  /// Falta la segunda propuesta (de otra persona).
  faltaPropuesta,

  /// Hay dos propuestas y el día de votación sigue abierto.
  enCurso,

  /// Los votos están igualados: cualquiera puede cambiar el suyo.
  empate,

  /// El día terminó y una propuesta ganó.
  ganador,
}

/// Duración de una votación (decisión del dueño): un día.
const duracionVotacion = Duration(days: 1);

class VotacionPlan {
  const VotacionPlan({
    required this.id,
    required this.dia,
    required this.abiertaEn,
    this.propuestas = const [],
    this.votos = const {},
  });

  final String id;

  /// Día del plan que se decide (sin hora).
  final DateTime dia;

  /// Cuándo se abrió (al llegar la primera propuesta). Cierra un día después.
  final DateTime abiertaEn;
  final List<PropuestaMenu> propuestas;

  /// persona -> propuesta elegida. Una persona, un voto.
  final Map<String, String> votos;

  DateTime get cierraEn => abiertaEn.add(duracionVotacion);
  bool abierta(DateTime ahora) => ahora.isBefore(cierraEn);

  int conteo(String propuestaId) =>
      votos.values.where((v) => v == propuestaId).length;

  /// Hay dos propuestas, al menos un voto y van igualadas.
  bool get hayEmpate =>
      propuestas.length == 2 &&
      votos.isNotEmpty &&
      conteo(propuestas[0].id) == conteo(propuestas[1].id);

  EstadoVotacion estado(DateTime ahora) {
    if (propuestas.length < 2) return EstadoVotacion.faltaPropuesta;
    if (hayEmpate) return EstadoVotacion.empate;
    if (abierta(ahora)) return EstadoVotacion.enCurso;
    // Cerrada sin votos: nadie decidió, se trata como empate (se puede votar).
    if (votos.isEmpty) return EstadoVotacion.empate;
    return EstadoVotacion.ganador;
  }

  /// Propuesta que va ganando o ganó; `null` si no hay dos propuestas o van
  /// igualadas.
  PropuestaMenu? get delante {
    if (propuestas.length < 2 || hayEmpate || votos.isEmpty) return null;
    final a = conteo(propuestas[0].id), b = conteo(propuestas[1].id);
    return a > b ? propuestas[0] : propuestas[1];
  }

  /// El ganador definitivo: solo cuando el día terminó y no hay empate.
  PropuestaMenu? ganador(DateTime ahora) =>
      estado(ahora) == EstadoVotacion.ganador ? delante : null;

  /// Se puede votar o cambiar el voto mientras el día está abierto, y también
  /// después si el resultado es un empate.
  bool puedeVotar(DateTime ahora) =>
      propuestas.length == 2 && (abierta(ahora) || hayEmpate || votos.isEmpty);

  VotacionPlan _con({List<PropuestaMenu>? propuestas, Map<String, String>? votos}) =>
      VotacionPlan(
        id: id,
        dia: dia,
        abiertaEn: abiertaEn,
        propuestas: propuestas ?? this.propuestas,
        votos: votos ?? this.votos,
      );

  /// Agrega una propuesta: máximo dos, de personas distintas.
  VotacionPlan conPropuesta(PropuestaMenu p, DateTime ahora) {
    if (!abierta(ahora)) {
      throw const ErrorVotacion('La votación de este día ya cerró.');
    }
    if (propuestas.length >= 2) {
      throw const ErrorVotacion('Ya hay dos propuestas: toca votar.');
    }
    if (propuestas.any((x) => x.autorId == p.autorId)) {
      throw const ErrorVotacion('Otra persona debe dar la segunda propuesta.');
    }
    return _con(propuestas: [...propuestas, p]);
  }

  /// Registra el voto de [personaId]; si ya votó, lo **cambia**.
  VotacionPlan conVoto(String personaId, String propuestaId, DateTime ahora) {
    if (propuestas.length < 2) {
      throw const ErrorVotacion('Todavía falta la segunda propuesta.');
    }
    if (!propuestas.any((p) => p.id == propuestaId)) {
      throw const ErrorVotacion('Esa propuesta no existe.');
    }
    if (!puedeVotar(ahora)) {
      throw const ErrorVotacion('La votación de este día ya cerró.');
    }
    return _con(votos: {...votos, personaId: propuestaId});
  }
}

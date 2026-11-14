/// Votación del plan familiar (D28; Fase 7, decisión 5): modelo puro.
///
/// Alguien propone un menú; otra persona propone el suyo; se vota **un día**.
/// Cada quien puede **cambiar su voto** mientras la votación esté abierta. Si
/// al cierre hay empate, lo resuelve un **volado** que decide el servidor
/// (`ali_cerrar_votaciones`); la app solo muestra el resultado, no decide.
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

  /// El día terminó con empate (o sin votos) y el servidor aún no hace el
  /// volado. La app no decide: espera el resultado del servidor.
  empatePendiente,

  /// El día terminó y una propuesta ganó (por votos o por volado).
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
    this.ganadoraVoladoId,
  });

  final String id;

  /// Día del plan que se decide (sin hora).
  final DateTime dia;

  /// Cuándo se abrió (al llegar la primera propuesta). Cierra un día después.
  final DateTime abiertaEn;
  final List<PropuestaMenu> propuestas;

  /// persona -> propuesta elegida. Una persona, un voto.
  final Map<String, String> votos;

  /// Propuesta que ganó por volado: la fija el servidor al cerrar con empate.
  /// La app nunca la calcula.
  final String? ganadoraVoladoId;

  DateTime get cierraEn => abiertaEn.add(duracionVotacion);
  bool abierta(DateTime ahora) => ahora.isBefore(cierraEn);

  int conteo(String propuestaId) =>
      votos.values.where((v) => v == propuestaId).length;

  /// Hay dos propuestas, al menos un voto y van igualadas.
  bool get hayEmpate =>
      propuestas.length == 2 &&
      votos.isNotEmpty &&
      conteo(propuestas[0].id) == conteo(propuestas[1].id);

  /// Cerrada con empate (o sin votos): se decide por volado en el servidor.
  bool _empateAlCierre(DateTime ahora) =>
      propuestas.length == 2 &&
      !abierta(ahora) &&
      (votos.isEmpty || hayEmpate);

  EstadoVotacion estado(DateTime ahora) {
    if (propuestas.length < 2) return EstadoVotacion.faltaPropuesta;
    if (abierta(ahora)) return EstadoVotacion.enCurso;
    if (_empateAlCierre(ahora)) {
      return ganadoraVoladoId == null
          ? EstadoVotacion.empatePendiente
          : EstadoVotacion.ganador;
    }
    return EstadoVotacion.ganador;
  }

  /// Propuesta que va ganando por votos; `null` si van igualadas o no hay
  /// votos.
  PropuestaMenu? get delante {
    if (propuestas.length < 2 || hayEmpate || votos.isEmpty) return null;
    final a = conteo(propuestas[0].id), b = conteo(propuestas[1].id);
    return a > b ? propuestas[0] : propuestas[1];
  }

  /// El ganador definitivo: cerrada la votación, por votos o por el volado
  /// del servidor. `null` mientras siga abierta o el servidor no resuelva.
  PropuestaMenu? ganador(DateTime ahora) {
    if (estado(ahora) != EstadoVotacion.ganador) return null;
    if (_empateAlCierre(ahora)) {
      return propuestas.firstWhere((p) => p.id == ganadoraVoladoId);
    }
    return delante;
  }

  /// `true` si el ganador salió del volado del servidor, no de los votos.
  bool resueltaPorVolado(DateTime ahora) =>
      estado(ahora) == EstadoVotacion.ganador && _empateAlCierre(ahora);

  /// Se puede votar o cambiar el voto mientras la votación esté abierta,
  /// haya o no empate. Cerrada, nunca.
  bool puedeVotar(DateTime ahora) => propuestas.length == 2 && abierta(ahora);

  VotacionPlan _con({List<PropuestaMenu>? propuestas, Map<String, String>? votos}) =>
      VotacionPlan(
        id: id,
        dia: dia,
        abiertaEn: abiertaEn,
        propuestas: propuestas ?? this.propuestas,
        votos: votos ?? this.votos,
        ganadoraVoladoId: ganadoraVoladoId,
      );

  /// Copia con el resultado del volado que decidió el servidor.
  VotacionPlan conVolado(String propuestaId) => VotacionPlan(
        id: id,
        dia: dia,
        abiertaEn: abiertaEn,
        propuestas: propuestas,
        votos: votos,
        ganadoraVoladoId: propuestaId,
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

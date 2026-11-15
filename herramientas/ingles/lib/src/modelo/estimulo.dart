/// Un turno de un guion de audio.
class Turno {
  const Turno({required this.voz, required this.texto});
  final String voz;
  final String texto;
}

/// El estímulo de una unidad: texto, audio, imagen, consigna o ninguno.
class Estimulo {
  const Estimulo({
    required this.tipo,
    this.titulo,
    this.texto,
    this.guion = const [],
    this.reproducciones,
    this.descripcion,
    this.archivo,
  });

  final String tipo;
  final String? titulo;
  final String? texto;
  final List<Turno> guion;
  final int? reproducciones;
  final String? descripcion;
  final String? archivo;
}

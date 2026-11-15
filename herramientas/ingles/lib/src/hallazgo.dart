/// Gravedad de un hallazgo: un error impide el estado `validado`; un aviso se
/// reporta y no lo impide (formato, sección 11).
enum Gravedad { error, aviso }

/// Resultado de una comprobación sobre un archivo o una pregunta.
class Hallazgo {
  const Hallazgo({
    required this.archivo,
    required this.id,
    required this.codigo,
    required this.gravedad,
    required this.mensaje,
  });

  /// Ruta del archivo, relativa a la carpeta que se validó.
  final String archivo;

  /// Id del archivo o, si el hallazgo es de una pregunta, el de la pregunta.
  final String id;

  /// V01 a V26.
  final String codigo;
  final Gravedad gravedad;
  final String mensaje;

  bool get esError => gravedad == Gravedad.error;

  @override
  String toString() =>
      '$archivo [$id] $codigo ${esError ? 'error' : 'aviso'}: $mensaje';
}

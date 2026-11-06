enum TipoObjetivo { construir, meta, proyecto }

enum Frecuencia { diaria, diasSemana, nPorSemana, semanal, total }

/// Ritmo necesario por día para una meta (regla 5): hacia arriba.
int ritmoPorDia({
  required int meta,
  required int avance,
  required int diasRestantes,
}) {
  final falta = meta - avance;
  if (falta <= 0) return 0;
  final d = diasRestantes <= 0 ? 1 : diasRestantes;
  return (falta + d - 1) ~/ d;
}

/// Avance de un proyecto: % entero hacia abajo.
int avanceProyecto(int hechos, int total) =>
    total <= 0 ? 0 : (hechos * 100) ~/ total;

class PasoSmart {
  const PasoSmart(this.clave, this.titulo);
  final String clave;
  final String titulo;
}

/// Los 5 pasos del asistente SMART (regla 2).
const pasosSmart = [
  PasoSmart('especifica', 'Específica'),
  PasoSmart('medible', 'Medible'),
  PasoSmart('alcanzable', 'Alcanzable'),
  PasoSmart('relevante', 'Relevante'),
  PasoSmart('fecha', 'Con fecha'),
];

/// Valida un borrador; devuelve los errores (vacío = se puede crear).
/// Un objetivo de tipo eliminar no existe aquí (regla 8).
List<String> validarObjetivo({
  required String titulo,
  required TipoObjetivo tipo,
  int? metaValor,
  String? motivo,
}) {
  final e = <String>[];
  if (titulo.trim().isEmpty || titulo.length > 120) {
    e.add('El título va de 1 a 120 caracteres.');
  }
  if (tipo == TipoObjetivo.meta && (metaValor == null || metaValor <= 0)) {
    e.add('Una meta necesita un valor mayor que cero.');
  }
  if (motivo != null && motivo.length > 200) {
    e.add('El motivo admite hasta 200 caracteres.');
  }
  return e;
}

import 'dart:convert';

import 'package:habitos_dominio/habitos_dominio.dart';

/// Convierte la entrada (lista de libros `{abbrev, chapters: [[versículos]]}`,
/// orden canónico de 66 libros) al formato propio y **valida el canon**
/// (66 libros y los capítulos de `habitos_dominio`). Lanza [FormatException].
Map<String, Object?> convertir({
  required List<Object?> entrada,
  required String version,
  required String nombre,
  required String licencia,
  required String origen,
}) {
  if (entrada.length != 66) {
    throw FormatException('Se esperaban 66 libros y hay ${entrada.length}.');
  }
  final libros = <List<List<String>>>[];
  for (var i = 0; i < 66; i++) {
    final caps = ((entrada[i]! as Map)['chapters']! as List).cast<List>();
    if (caps.length != canon[i].capitulos) {
      throw FormatException(
          '${canon[i].nombre}: ${caps.length} capítulos, se esperaban ${canon[i].capitulos}.');
    }
    libros.add([
      for (final c in caps)
        [for (final v in c) (v as String).replaceAll(RegExp(r'\s+'), ' ').trim()]
    ]);
  }
  return {
    'formato': 'gravity-biblia-v1',
    'version': version,
    'nombre': nombre,
    'licencia': licencia,
    'origen': origen,
    'libros': libros,
  };
}

String serializar(Map<String, Object?> m) => jsonEncode(m);

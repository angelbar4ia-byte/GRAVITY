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
  _exigirTexto('version', version, 20, RegExp(r'^[a-z0-9_-]+$'));
  _exigirTexto('nombre', nombre, 100);
  _exigirTexto('licencia', licencia, 200);
  _exigirTexto('origen', origen, 300);
  if (entrada.length != 66) {
    throw FormatException('Se esperaban 66 libros y hay ${entrada.length}.');
  }
  final libros = <List<List<String>>>[];
  for (var i = 0; i < 66; i++) {
    final libro = entrada[i];
    if (libro is! Map) throw FormatException('${canon[i].nombre}: el libro no es un objeto.');
    final caps = libro['chapters'];
    if (caps is! List) throw FormatException('${canon[i].nombre}: faltan los capítulos.');
    if (caps.length != canon[i].capitulos) {
      throw FormatException(
          '${canon[i].nombre}: ${caps.length} capítulos, se esperaban ${canon[i].capitulos}.');
    }
    final capitulos = <List<String>>[];
    for (var c = 0; c < caps.length; c++) {
      final vs = caps[c];
      if (vs is! List || vs.isEmpty) {
        throw FormatException('${canon[i].nombre} ${c + 1}: capítulo sin versículos.');
      }
      final limpios = <String>[];
      for (var v = 0; v < vs.length; v++) {
        final t = vs[v];
        final donde = '${canon[i].nombre} ${c + 1}:${v + 1}';
        if (t is! String) throw FormatException('$donde: el versículo no es texto.');
        if (_prohibido.hasMatch(t)) {
          throw FormatException('$donde: tiene caracteres de control o de dirección de texto.');
        }
        final limpio = t.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (limpio.isEmpty) throw FormatException('$donde: versículo vacío.');
        if (limpio.length > maximoCaracteresVersiculo) {
          throw FormatException('$donde: pasa de $maximoCaracteresVersiculo caracteres.');
        }
        limpios.add(limpio);
      }
      capitulos.add(limpios);
    }
    libros.add(capitulos);
  }
  return {
    'formato': 'gravity-biblia-v1',
    'version': version,
    'nombre': nombre.trim(),
    'licencia': licencia.trim(),
    'origen': origen.trim(),
    'libros': libros,
  };
}

/// Un versículo más largo que esto no es un versículo.
const maximoCaracteresVersiculo = 5000;

// Controles C0 y C1 (menos tabulador y saltos, que se normalizan a espacio) y
// marcas de dirección de texto (U+200E/F, U+202A-E, U+2066-9, U+061C).
final RegExp _prohibido = RegExp(
    '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]');

void _exigirTexto(String campo, String valor, int maximo, [RegExp? formato]) {
  final v = valor.trim();
  if (v.isEmpty) throw FormatException('$campo no puede estar vacío.');
  if (v.length > maximo) throw FormatException('$campo pasa de $maximo caracteres.');
  if (_prohibido.hasMatch(valor)) throw FormatException('$campo tiene caracteres no permitidos.');
  if (formato != null && !formato.hasMatch(v)) throw FormatException('$campo tiene un formato inválido.');
}

String serializar(Map<String, Object?> m) => jsonEncode(m);

import 'dart:convert';
import 'dart:io';

import 'package:importar_biblia/importador.dart';

/// Uso: `dart run bin/importar.dart entrada salida.gz version nombre licencia origen`.
/// No descarga nada: el dueño confirma la edición y la fuente (P10) y pone el
/// archivo de entrada. Deja la licencia y el origen dentro de la salida.
void main(List<String> a) {
  if (a.length != 6) {
    stderr.writeln('Uso: importar <entrada> <salida.gz> <version> <nombre> <licencia> <origen>');
    exit(64);
  }
  try {
    final texto = utf8.decode(File(a[0]).readAsBytesSync()).replaceFirst('\uFEFF', '');
    final d = jsonDecode(texto);
    if (d is! List) throw const FormatException('La entrada debe ser una lista de 66 libros.');
    final m = convertir(entrada: d, version: a[2], nombre: a[3], licencia: a[4], origen: a[5]);
    File(a[1]).writeAsBytesSync(gzip.encode(utf8.encode(serializar(m))));
  } on FormatException catch (e) {
    stderr.writeln('Entrada rechazada: ${e.message}');
    exit(65);
  }
  stdout.writeln('Listo: ${a[1]}');
}

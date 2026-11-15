import 'dart:io';

import 'package:ingles/ingles.dart';

const String _uso = '''Uso: dart run bin/ingles.dart <orden> [argumentos]

Órdenes:
  validar [ruta]   Comprueba los .yaml de la ruta (por defecto, data/ingles).
                   V01 a V14 (salvo V06) y V24 sin revisiones. Sale con 1 si hay errores.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    stdout.write(_uso);
    exit(args.isEmpty ? 64 : 0);
  }
  switch (args.first) {
    case 'validar':
      exit(_validar(args.skip(1).toList()));
    default:
      stderr.writeln('Orden desconocida: "${args.first}".\n');
      stderr.write(_uso);
      exit(64);
  }
}

int _validar(List<String> args) {
  if (args.length > 1) {
    stderr.write(_uso);
    return 64;
  }
  final ruta = args.isEmpty ? buscarDataIngles() : args.first;
  if (ruta == null) {
    stderr.writeln('No encuentro data/ingles: pásame la ruta.');
    return 66;
  }
  final Resultado r;
  try {
    r = validarRuta(ruta);
  } on FileSystemException catch (e) {
    stderr.writeln('${e.message}: ${e.path}');
    return 66;
  }
  for (final h in r.hallazgos) {
    stdout.writeln(h);
  }
  stdout.writeln('Resumen: ${r.archivos.length} archivos leídos, '
      '${r.errores} errores, ${r.avisos} avisos.');
  return r.limpio ? 0 : 1;
}

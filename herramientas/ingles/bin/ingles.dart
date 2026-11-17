import 'dart:io';

import 'package:ingles/ingles.dart';

const String _uso = '''Uso: dart run bin/ingles.dart <orden> [argumentos]

Órdenes:
  validar [ruta]   Comprueba los .yaml de la ruta (por defecto, data/ingles).
                   V01 a V23, V27 y V28 (sin V06) y V24 sin revisiones. Sale con 1 si hay errores.
  informe [ruta]   Cuenta lo que hay frente a lo que pide cada contrato, la fidelidad
                   de cada forma y la cobertura por escalón. No es una validación: sale
                   con 0 siempre que pueda leer la ruta.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    stdout.write(_uso);
    exit(args.isEmpty ? 64 : 0);
  }
  switch (args.first) {
    case 'validar':
      exit(_validar(args.skip(1).toList()));
    case 'informe':
      exit(_informe(args.skip(1).toList()));
    default:
      stderr.writeln('Orden desconocida: "${args.first}".\n');
      stderr.write(_uso);
      exit(64);
  }
}

/// La ruta de la orden: la que se pasó o, por defecto, `data/ingles`. Null si
/// no hay forma de encontrarla (ya se avisó por stderr).
String? _ruta(List<String> args) {
  final ruta = args.isEmpty ? buscarDataIngles() : args.first;
  if (ruta == null) stderr.writeln('No encuentro data/ingles: pásame la ruta.');
  return ruta;
}

int _validar(List<String> args) {
  if (args.length > 1) {
    stderr.write(_uso);
    return 64;
  }
  final ruta = _ruta(args);
  if (ruta == null) return 66;
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

int _informe(List<String> args) {
  if (args.length > 1) {
    stderr.write(_uso);
    return 64;
  }
  final ruta = _ruta(args);
  if (ruta == null) return 66;
  final List<Archivo> archivos;
  try {
    archivos = leerRuta(ruta);
  } on FileSystemException catch (e) {
    stderr.writeln('${e.message}: ${e.path}');
    return 66;
  }
  stdout.write(Informe.de(archivos).aTexto(ruta: ruta));
  return 0;
}

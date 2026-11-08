/// Importación de recetas desde un archivo JSON (Fase 7, decisión 1).
///
/// La app **solo importa**: la IA puede ayudar a redactar el archivo fuera de
/// ella. El archivo no es confiable, así que se valida todo antes de mostrar
/// la vista previa; si algo falla, no se guarda nada (todo o nada).
///
/// Formato (`version` 1):
/// ```json
/// {"version": 1, "recetas": [{
///   "titulo": "Avena con fruta", "porciones": 2,
///   "pasos": ["Calienta la leche."],
///   "ingredientes": [{"nombre": "Avena", "cantidad": 50, "unidad": "g",
///                     "pasillo": "Abarrotes"}]
/// }]}
/// ```
/// `pasillo` es opcional (sin él, "Otros"). Un arreglo de recetas sin envoltura
/// también se acepta.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../datos/modelos.dart';

const maxBytesArchivoRecetas = 1024 * 1024;
const maxRecetasPorArchivo = 100;
const maxPasosPorReceta = 50;
const maxCaracteresPaso = 200;
const maxIngredientesPorReceta = 50;
const maxCaracteresTitulo = 120;
const maxCaracteresNombre = 80;
const maxCaracteresUnidad = 20;
const maxPorciones = 50;

class ErrorReceta {
  const ErrorReceta(this.donde, this.mensaje);

  /// "Receta 2 · paso 3", "Archivo"...
  final String donde;
  final String mensaje;
  @override
  String toString() => '$donde: $mensaje';
}

class RecetaImportada {
  const RecetaImportada(this.platillo, {this.advertencias = const []});
  final Platillo platillo;

  /// Avisos que no impiden importar (por ejemplo, cifras en los pasos).
  final List<String> advertencias;
}

class ResultadoImportacion {
  const ResultadoImportacion(this.recetas, this.errores);
  final List<RecetaImportada> recetas;
  final List<ErrorReceta> errores;

  /// Solo se puede guardar si no hubo ningún error y hay al menos una receta.
  bool get valido => errores.isEmpty && recetas.isNotEmpty;
}

ResultadoImportacion _rechazo(String donde, String mensaje) =>
    ResultadoImportacion(const [], [ErrorReceta(donde, mensaje)]);

/// Texto plano: sin caracteres de control ni etiquetas (`<`, `>`).
bool _textoValido(String s) {
  for (final u in s.runes) {
    if (u < 0x20 || (u >= 0x7f && u < 0xa0) || u == 0xfffd) return false;
    if (u == 0x3c || u == 0x3e) return false;
  }
  return true;
}

String _slug(String t) {
  const de = 'áéíóúüñ';
  const a = 'aeiouun';
  final b = StringBuffer();
  for (final c in t.toLowerCase().runes) {
    final ch = String.fromCharCode(c);
    final i = de.indexOf(ch);
    final x = i >= 0 ? a[i] : ch;
    b.write(RegExp(r'[a-z0-9]').hasMatch(x) ? x : '-');
  }
  return b.toString().replaceAll(RegExp(r'-+'), '-').replaceAll(
    RegExp(r'^-|-$'),
    '',
  );
}

/// Id estable de un platillo importado: dos importaciones del mismo título
/// reemplazan la receta en vez de duplicarla.
String idRecetaImportada(String titulo) => 'imp-${_slug(titulo)}';

SeccionCompra? pasilloDeTexto(String t) {
  final n = t.trim().toLowerCase();
  for (final s in SeccionCompra.values) {
    if (s.name.toLowerCase() == n || s.etiqueta.toLowerCase() == n) return s;
  }
  return null;
}

ResultadoImportacion importarRecetasDeBytes(Uint8List bytes) {
  if (bytes.length > maxBytesArchivoRecetas) {
    return _rechazo('Archivo', 'Pesa más de 1 MB: no es un archivo de recetas.');
  }
  final String texto;
  try {
    texto = utf8.decode(bytes);
  } on FormatException {
    return _rechazo('Archivo', 'El texto no es válido (debe ser UTF-8).');
  }
  return importarRecetasDeTexto(texto);
}

ResultadoImportacion importarRecetasDeTexto(String texto) {
  final Object? raiz;
  try {
    raiz = jsonDecode(texto);
  } on FormatException {
    return _rechazo('Archivo', 'No es un JSON válido.');
  }
  final List<Object?> lista;
  if (raiz is List) {
    lista = raiz;
  } else if (raiz is Map && raiz['recetas'] is List) {
    final v = raiz['version'];
    if (v != null && v != 1) {
      return _rechazo('Archivo', 'Versión $v no compatible (se espera la 1).');
    }
    lista = raiz['recetas'] as List<Object?>;
  } else {
    return _rechazo('Archivo', 'Falta la lista "recetas".');
  }
  if (lista.isEmpty) return _rechazo('Archivo', 'No trae ninguna receta.');
  if (lista.length > maxRecetasPorArchivo) {
    return _rechazo(
      'Archivo',
      'Trae más de $maxRecetasPorArchivo recetas.',
    );
  }

  final errores = <ErrorReceta>[];
  final recetas = <RecetaImportada>[];
  final ids = <String>{};
  for (var n = 0; n < lista.length; n++) {
    final r = _receta(lista[n], n + 1, errores);
    if (r == null) continue;
    if (!ids.add(r.platillo.id)) {
      errores.add(
        ErrorReceta('Receta ${n + 1}', 'El título "${r.platillo.nombre}" está repetido.'),
      );
      continue;
    }
    recetas.add(r);
  }
  return ResultadoImportacion(errores.isEmpty ? recetas : const [], errores);
}

/// Texto obligatorio, no vacío, plano y de a lo más [max] caracteres.
String? _texto(
  Object? v,
  String donde,
  String campo,
  int max,
  List<ErrorReceta> e,
) {
  if (v is! String || v.trim().isEmpty) {
    e.add(ErrorReceta(donde, '"$campo" está vacío o falta.'));
    return null;
  }
  final t = v.trim();
  if (t.length > max) {
    e.add(ErrorReceta(donde, '"$campo" pasa de $max caracteres.'));
    return null;
  }
  if (!_textoValido(t)) {
    e.add(
      ErrorReceta(donde, '"$campo" trae texto no válido (símbolos de control o etiquetas).'),
    );
    return null;
  }
  return t;
}

RecetaImportada? _receta(Object? o, int n, List<ErrorReceta> errores) {
  final d = 'Receta $n';
  if (o is! Map) {
    errores.add(ErrorReceta(d, 'No es una receta.'));
    return null;
  }
  final antes = errores.length;
  final titulo = _texto(o['titulo'], d, 'titulo', maxCaracteresTitulo, errores);
  final dr = titulo == null ? d : '$d ("$titulo")';

  final por = o['porciones'];
  if (por is! int || por < 1 || por > maxPorciones) {
    errores.add(ErrorReceta(dr, '"porciones" debe ser un entero de 1 a $maxPorciones.'));
  }

  final pasosCrudos = o['pasos'];
  final pasos = <String>[];
  final advertencias = <String>[];
  if (pasosCrudos is! List || pasosCrudos.isEmpty) {
    errores.add(ErrorReceta(dr, 'Faltan los "pasos".'));
  } else if (pasosCrudos.length > maxPasosPorReceta) {
    errores.add(ErrorReceta(dr, 'Tiene más de $maxPasosPorReceta pasos.'));
  } else {
    for (var i = 0; i < pasosCrudos.length; i++) {
      final p = _texto(
        pasosCrudos[i],
        '$dr · paso ${i + 1}',
        'paso',
        maxCaracteresPaso,
        errores,
      );
      if (p == null) continue;
      pasos.add(p);
      if (RegExp(r'\d').hasMatch(p)) {
        advertencias.add(
          'El paso ${i + 1} lleva cifras: la bocina no las lee (conviene escribirlas con letra).',
        );
      }
    }
  }

  final ingCrudos = o['ingredientes'];
  final ings = <Ingrediente>[];
  if (ingCrudos is! List || ingCrudos.isEmpty) {
    errores.add(ErrorReceta(dr, 'Faltan los "ingredientes".'));
  } else if (ingCrudos.length > maxIngredientesPorReceta) {
    errores.add(
      ErrorReceta(dr, 'Tiene más de $maxIngredientesPorReceta ingredientes.'),
    );
  } else {
    for (var i = 0; i < ingCrudos.length; i++) {
      final di = '$dr · ingrediente ${i + 1}';
      final m = ingCrudos[i];
      if (m is! Map) {
        errores.add(ErrorReceta(di, 'No es un ingrediente.'));
        continue;
      }
      final nombre = _texto(m['nombre'], di, 'nombre', maxCaracteresNombre, errores);
      final unidad = _texto(m['unidad'], di, 'unidad', maxCaracteresUnidad, errores);
      final c = m['cantidad'];
      if (c is! num || !c.isFinite || c <= 0 || c > 100000) {
        errores.add(ErrorReceta(di, '"cantidad" debe ser un número mayor que cero.'));
      }
      var pasillo = SeccionCompra.otros;
      final pc = m['pasillo'];
      if (pc != null) {
        final p = pc is String ? pasilloDeTexto(pc) : null;
        if (p == null) {
          errores.add(
            ErrorReceta(
              di,
              '"pasillo" no se reconoce (usa: ${SeccionCompra.values.map((s) => s.etiqueta).join(', ')}).',
            ),
          );
        } else {
          pasillo = p;
        }
      }
      if (nombre != null && unidad != null && c is num && c > 0) {
        ings.add(Ingrediente(nombre, c.toDouble(), unidad, pasillo));
      }
    }
  }

  if (titulo != null && _slug(titulo).isEmpty) {
    errores.add(ErrorReceta(dr, '"titulo" necesita letras o números.'));
  }
  if (errores.length > antes || titulo == null) return null;
  return RecetaImportada(
    Platillo(
      idRecetaImportada(titulo),
      titulo,
      ings,
      pasos: pasos,
      porciones: por as int,
    ),
    advertencias: advertencias,
  );
}

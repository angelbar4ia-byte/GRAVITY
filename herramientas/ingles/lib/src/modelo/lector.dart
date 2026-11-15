import 'package:yaml/yaml.dart';

import '../hallazgo.dart';

/// Convierte lo que devuelve `yaml` en mapas, listas y valores simples de Dart.
Object? aPlano(Object? v) {
  if (v is YamlMap || v is Map) {
    final m = v! as Map;
    return <String, Object?>{
      for (final e in m.entries) '${e.key}': aPlano(e.value),
    };
  }
  if (v is YamlList || v is List) {
    return [for (final e in v! as List) aPlano(e)];
  }
  return v;
}

/// Acumula los hallazgos V01 (esquema) mientras se lee un archivo.
class Lector {
  Lector(this.archivo, this.idArchivo);

  final String archivo;
  String idArchivo;
  final List<Hallazgo> hallazgos = [];

  void error(String ruta, String mensaje, {String? id}) {
    hallazgos.add(Hallazgo(
      archivo: archivo,
      id: id ?? idArchivo,
      codigo: 'V01',
      gravedad: Gravedad.error,
      mensaje: ruta.isEmpty ? mensaje : '$ruta: $mensaje',
    ));
  }

  /// Vista de un mapa (con su ruta, para decir dónde está el problema).
  Vista? vista(Object? valor, String ruta, {String? id, bool requerido = true}) {
    if (valor == null) {
      if (requerido) error(ruta, 'falta este bloque', id: id);
      return null;
    }
    if (valor is! Map<String, Object?>) {
      error(ruta, 'debe ser un bloque con campos', id: id);
      return null;
    }
    return Vista(this, valor, ruta, id ?? idArchivo);
  }
}

/// Un mapa leído con comprobación de tipos: cada acceso que no cuadra deja un
/// hallazgo V01 y devuelve un valor neutro.
class Vista {
  Vista(this.lector, this.datos, this.ruta, this.id);

  final Lector lector;
  final Map<String, Object?> datos;
  final String ruta;
  final String id;

  String _en(String k) => ruta.isEmpty ? k : '$ruta.$k';

  void _falla(String k, String mensaje) =>
      lector.error(_en(k), mensaje, id: id);

  bool tiene(String k) => datos[k] != null;

  /// Texto. Si `en` se da, el valor debe estar en la lista.
  String? texto(String k, {bool requerido = true, Iterable<String>? en}) {
    final v = datos[k];
    if (v == null) {
      if (requerido) _falla(k, 'falta el campo');
      return null;
    }
    if (v is! String) {
      _falla(k, 'debe ser texto');
      return null;
    }
    if (requerido && v.trim().isEmpty) {
      _falla(k, 'no puede estar vacío');
      return null;
    }
    if (en != null && !en.contains(v)) {
      _falla(k, 'valor "$v" no permitido (válidos: ${en.join(', ')})');
      return v;
    }
    return v;
  }

  int? entero(String k, {bool requerido = false}) {
    final v = datos[k];
    if (v == null) {
      if (requerido) _falla(k, 'falta el campo');
      return null;
    }
    if (v is! int) {
      _falla(k, 'debe ser un número entero');
      return null;
    }
    return v;
  }

  num? numero(String k, {bool requerido = false}) {
    final v = datos[k];
    if (v == null) {
      if (requerido) _falla(k, 'falta el campo');
      return null;
    }
    if (v is! num) {
      _falla(k, 'debe ser un número');
      return null;
    }
    return v;
  }

  bool? booleano(String k) {
    final v = datos[k];
    if (v == null) return null;
    if (v is! bool) {
      _falla(k, 'debe ser verdadero o falso');
      return null;
    }
    return v;
  }

  /// Lista cualquiera; `[]` es válida salvo que `noVacia` lo impida.
  List<Object?>? lista(String k, {bool requerido = true, bool noVacia = false}) {
    final v = datos[k];
    if (v == null) {
      if (requerido) _falla(k, 'falta el campo');
      return null;
    }
    if (v is! List<Object?>) {
      _falla(k, 'debe ser una lista');
      return null;
    }
    if (noVacia && v.isEmpty) {
      _falla(k, 'no puede estar vacía');
    }
    return v;
  }

  /// Lista de textos no vacíos.
  List<String> textos(String k, {bool requerido = true, bool noVacia = false}) {
    final l = lista(k, requerido: requerido, noVacia: noVacia);
    if (l == null) return const [];
    final salida = <String>[];
    for (var i = 0; i < l.length; i++) {
      final e = l[i];
      if (e is! String || e.trim().isEmpty) {
        lector.error('${_en(k)}[$i]', 'debe ser un texto no vacío', id: id);
      } else {
        salida.add(e);
      }
    }
    return salida;
  }

  /// Bloque anidado.
  Vista? mapa(String k, {bool requerido = true, String? idPropio}) =>
      lector.vista(datos[k], _en(k), id: idPropio ?? id, requerido: requerido);

  /// Lista de bloques; cada elemento que no es un bloque deja un hallazgo.
  List<Vista> mapas(String k, {bool requerido = true, bool noVacia = false}) {
    final l = lista(k, requerido: requerido, noVacia: noVacia);
    if (l == null) return const [];
    final salida = <Vista>[];
    for (var i = 0; i < l.length; i++) {
      final v = lector.vista(l[i], '${_en(k)}[$i]', id: id);
      if (v != null) salida.add(v);
    }
    return salida;
  }
}

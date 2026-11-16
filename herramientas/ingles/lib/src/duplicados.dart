/// Contenido repetido entre archivos (V19, reglas a y b). Se calcula una sola
/// vez para todo el conjunto, porque los duplicados solo se ven en conjunto
/// (plan, 5.7).
///
/// **Regla a · oraciones.** Una oración de [oracionMinimaPalabras] palabras o
/// más (normalizada: minúsculas y sin puntuación) que está en dos archivos
/// distintos. **Regla b · similitud.** Dos estímulos con similitud de Jaccard
/// de [similitudMinima] o más sobre su conjunto de trigramas de palabras. El
/// método está explicado en el README.
///
/// Solo se comparan unidades y sesiones que no estén `retiradas`. Una oración
/// repetida dentro de un mismo archivo no cuenta: solo se comparan archivos
/// distintos.
library;

import 'contenido.dart';
import 'modelo/archivo.dart';
import 'texto.dart';
import 'usos.dart';

/// Una oración de este número de palabras o más cuenta para V19 (regla a).
const int oracionMinimaPalabras = 7;

/// La similitud mínima (Jaccard sobre trigramas de palabras) que V19 (regla b)
/// da por repetición.
const double similitudMinima = 0.85;

/// Lo que un archivo comparte con otro.
class Coincidencia {
  const Coincidencia({
    required this.otro,
    required this.oraciones,
    this.similitud,
  });

  /// El otro archivo.
  final Archivo otro;

  /// Las oraciones de [oracionMinimaPalabras] o más que comparten, tal como
  /// están escritas en el archivo del que se pregunta.
  final List<String> oraciones;

  /// La similitud de Jaccard de los dos estímulos, solo si llega a
  /// [similitudMinima]; null si no.
  final double? similitud;
}

/// Los trigramas de palabras de un texto: cada tres palabras seguidas (en
/// minúsculas, sin puntuación ni marcas de hueco). Un texto de una o dos
/// palabras da un solo trigrama con todas ellas, para que dos textos cortos
/// idénticos se reconozcan; un texto sin palabras, ninguno.
Set<String> trigramasDePalabras(String texto) {
  final p = palabrasDe(sinMarcasDeHueco(texto));
  if (p.isEmpty) return {};
  if (p.length < 3) return {p.join(' ')};
  return {for (var i = 0; i + 2 < p.length; i++) '${p[i]} ${p[i + 1]} ${p[i + 2]}'};
}

/// La similitud de Jaccard de dos conjuntos: lo que tienen en común sobre lo
/// que suman sin repetir. Vale 1 si son iguales y 0 si no comparten nada.
double similitudJaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 0;
  final (menor, mayor) = a.length <= b.length ? (a, b) : (b, a);
  final comunes = menor.where(mayor.contains).length;
  return comunes / (a.length + b.length - comunes);
}

/// Las coincidencias de todos los archivos del conjunto.
class IndiceDuplicados {
  IndiceDuplicados(List<Archivo> archivos) {
    final fuentes = [
      for (final a in archivos)
        if ((a is Unidad || a is Sesion) && a.estado != Estado.retirado) a,
    ];
    final porId = <String, Archivo>{};
    for (final a in archivos) {
      porId.putIfAbsent(a.id, () => a);
    }

    final oraciones = <Archivo, Map<String, String>>{
      for (final f in fuentes) f: _oraciones(f),
    };
    // Una oración de una sesión que está en uno de sus propios audios de
    // traslado sale de ese audio (el método pide repetir frases del audio): no
    // es una repetición.
    for (final f in fuentes) {
      if (f is! Sesion) continue;
      for (final id in audiosDeSesion(f)) {
        final audio = porId[id];
        if (audio is! Unidad) continue;
        final propias = (oraciones[audio] ?? _oraciones(audio)).keys.toSet();
        oraciones[f]!.removeWhere((clave, _) => propias.contains(clave));
      }
    }

    // Regla a: las oraciones que aparecen en dos archivos.
    final porClave = <String, List<int>>{};
    for (var i = 0; i < fuentes.length; i++) {
      for (final clave in oraciones[fuentes[i]]!.keys) {
        (porClave[clave] ??= []).add(i);
      }
    }
    final compartidas = <(int, int), List<String>>{};
    for (final e in porClave.entries) {
      final l = e.value;
      for (var x = 0; x < l.length; x++) {
        for (var y = x + 1; y < l.length; y++) {
          (compartidas[(l[x], l[y])] ??= []).add(e.key);
        }
      }
    }

    // Regla b: similitud de los estímulos, con un índice de trigramas para no
    // comparar todos con todos.
    final similares = <(int, int), double>{};
    final conjuntos = <int, Set<String>>{};
    final porTrigrama = <String, List<int>>{};
    for (var i = 0; i < fuentes.length; i++) {
      final f = fuentes[i];
      if (f is! Unidad) continue;
      final t = trigramasDePalabras(textoParaSimilitud(f));
      if (t.isEmpty) continue;
      conjuntos[i] = t;
      final comunes = <int, int>{};
      for (final g in t) {
        for (final j in porTrigrama[g] ?? const <int>[]) {
          comunes[j] = (comunes[j] ?? 0) + 1;
        }
      }
      for (final e in comunes.entries) {
        final union = t.length + conjuntos[e.key]!.length - e.value;
        final similitud = e.value / union;
        if (similitud >= similitudMinima - 1e-9) similares[(e.key, i)] = similitud;
      }
      for (final g in t) {
        (porTrigrama[g] ??= []).add(i);
      }
    }

    // Las dos direcciones de cada par.
    final pares = {...compartidas.keys, ...similares.keys};
    for (final par in pares) {
      final (i, j) = par;
      final a = fuentes[i];
      final b = fuentes[j];
      final claves = compartidas[par] ?? const <String>[];
      final similitud = similares[par];
      (_porArchivo[a] ??= []).add(Coincidencia(
        otro: b,
        oraciones: [for (final k in claves) oraciones[a]![k]!],
        similitud: similitud,
      ));
      (_porArchivo[b] ??= []).add(Coincidencia(
        otro: a,
        oraciones: [for (final k in claves) oraciones[b]![k]!],
        similitud: similitud,
      ));
    }
    for (final l in _porArchivo.values) {
      l.sort((x, y) => x.otro.ruta.compareTo(y.otro.ruta));
    }
  }

  final Map<Archivo, List<Coincidencia>> _porArchivo = {};

  /// Lo que el archivo comparte con otros, ordenado por la ruta del otro.
  List<Coincidencia> de(Archivo a) => _porArchivo[a] ?? const [];
}

/// Las oraciones de [oracionMinimaPalabras] palabras o más de un archivo, por su
/// clave (la oración normalizada) y tal como está escrita la primera vez.
Map<String, String> _oraciones(Archivo a) {
  final salida = <String, String>{};
  for (final texto in textosParaOraciones(a)) {
    for (final o in dividirOraciones(texto)) {
      final clave = claveDeOracion(o);
      if (clave.isEmpty) continue;
      if (clave.split(' ').length >= oracionMinimaPalabras) {
        salida.putIfAbsent(clave, () => o);
      }
    }
  }
  return salida;
}

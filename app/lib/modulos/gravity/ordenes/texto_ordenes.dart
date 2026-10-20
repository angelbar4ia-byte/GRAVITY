/// Utilidades de texto de la barra de órdenes: normalizar y comparar.
library;

import 'dart:math' as math;

const Map<String, String> _sinAcento = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c',
};

final RegExp _noAlfanumerico = RegExp(r'[^a-z0-9]+');

/// Minúsculas, sin acentos ni signos, con un solo espacio entre palabras.
/// `"¡Ábreme el MENÚ!"` → `"abreme el menu"`.
String normalizarTexto(String texto) {
  final minusculas = texto.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in minusculas.runes) {
    final letra = String.fromCharCode(rune);
    buffer.write(_sinAcento[letra] ?? letra);
  }
  return buffer.toString().replaceAll(_noAlfanumerico, ' ').trim();
}

/// Palabras normalizadas de [texto].
List<String> palabrasDe(String texto) {
  final normalizado = normalizarTexto(texto);
  return normalizado.isEmpty ? const [] : normalizado.split(' ');
}

/// Palabras de relleno de una orden de navegación (verbos y artículos).
/// Se comparan ya normalizadas.
const Set<String> palabrasDeRelleno = {
  // Verbos para abrir o ir.
  'abre', 'abrir', 'abreme', 'abra', 'abran', 'abrime',
  'ir', 've', 'vete', 'vamos', 'voy', 'llevame', 'lleva',
  'muestra', 'muestrame', 'mostrar', 'ensename', 'ver', 'veamos',
  'entra', 'entrar', 'pon', 'ponme', 'cambia', 'cambiar',
  'regresa', 'regresar', 'vuelve', 'volver', 'navega', 'navegar',
  'quiero', 'necesito', 'puedes',
  // Artículos, preposiciones y cortesía.
  'a', 'al', 'el', 'la', 'los', 'las', 'de', 'del', 'en', 'y',
  'mi', 'mis', 'tu', 'me', 'por', 'favor', 'porfa',
  'oye', 'hola', 'modulo', 'seccion', 'pantalla', 'app',
};

/// Quita las palabras de relleno. Si la orden empieza con "gravity" y sigue
/// algo más ("gravity, abre finanzas"), "gravity" es el llamado, no el destino.
List<String> quitarRelleno(List<String> palabras) {
  var resto = palabras.where((p) => !palabrasDeRelleno.contains(p)).toList();
  if (resto.length > 1 && resto.first == 'gravity') {
    resto = resto.sublist(1);
  }
  return resto;
}

/// Distancia de edición con transposiciones (Damerau, alineación óptima):
/// cuántas letras hay que insertar, borrar, cambiar o intercambiar.
int distanciaEdicion(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final n = a.length;
  final m = b.length;
  // d[i][j]: distancia entre los primeros i caracteres de a y j de b.
  final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final costo = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var mejor = math.min(
        math.min(d[i - 1][j] + 1, d[i][j - 1] + 1),
        d[i - 1][j - 1] + costo,
      );
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        mejor = math.min(mejor, d[i - 2][j - 2] + 1);
      }
      d[i][j] = mejor;
    }
  }
  return d[n][m];
}

/// Cuántos errores se toleran para una palabra de [largo] letras.
int toleranciaPara(int largo) {
  if (largo <= 4) return 1;
  if (largo <= 7) return 2;
  return 3;
}

/// Parte un turno en frases para sintetizar de a una (spec 4.2.3): un turno
/// largo (los guiones traen párrafos de unas 50 palabras) no se genera de
/// golpe, porque el tiempo hasta el primer sonido dependería del turno
/// entero. Con frases, la primera suena en cuanto está lista y la siguiente
/// se genera mientras suena.
///
/// Es una división por la puntuación, sin entender el texto: no corta en
/// abreviaturas comunes (`Mr.`, `a.m.`), iniciales (`J. K. Rowling`) ni en
/// números con punto (`3.5`).
library;

/// Una frase no pasa de este largo (se corta en una coma o en un espacio).
const largoMaximoDeFrase = 220;

const _abreviaturas = {
  'mr',
  'mrs',
  'ms',
  'dr',
  'prof',
  'st',
  'jr',
  'sr',
  'vs',
  'etc',
  'no',
  'a.m',
  'p.m',
  'e.g',
  'i.e',
  'sra',
  'dra',
  'lic',
  'ing',
};

bool _esFinal(String c) => c == '.' || c == '!' || c == '?' || c == '…';

/// `true` si el punto en [pos] cierra una abreviatura o una inicial.
bool _puntoDeAbreviatura(String texto, int pos) {
  var i = pos - 1;
  while (i >= 0 && !RegExp(r'\s').hasMatch(texto[i])) {
    i--;
  }
  final palabra = texto.substring(i + 1, pos).toLowerCase();
  if (palabra.isEmpty) return false;
  if (_abreviaturas.contains(palabra)) return true;
  // Una inicial suelta: "J." o "K."
  return palabra.length == 1 && RegExp(r'[a-z]').hasMatch(palabra);
}

/// Las frases de [texto], sin espacios sobrantes. Si no hay nada que decir,
/// la lista queda vacía.
List<String> partirEnFrases(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[ \t\r]+'), ' ').trim();
  if (limpio.isEmpty) return const [];
  final crudas = <String>[];
  var inicio = 0;
  for (var i = 0; i < limpio.length; i++) {
    final c = limpio[i];
    final salto = c == '\n';
    if (!_esFinal(c) && !salto) continue;
    if (!salto) {
      // Sigue la puntuación (`?!`, `...`) y cierres (comillas, paréntesis).
      var fin = i;
      while (fin + 1 < limpio.length &&
          (_esFinal(limpio[fin + 1]) || '"\'”’)»'.contains(limpio[fin + 1]))) {
        fin++;
      }
      final sigue = fin + 1 >= limpio.length || limpio[fin + 1] == ' ';
      if (!sigue) continue;
      if (c == '.' && fin == i && _puntoDeAbreviatura(limpio, i)) continue;
      crudas.add(limpio.substring(inicio, fin + 1));
      inicio = fin + 1;
      i = fin;
    } else {
      crudas.add(limpio.substring(inicio, i));
      inicio = i + 1;
    }
  }
  if (inicio < limpio.length) crudas.add(limpio.substring(inicio));

  final frases = <String>[];
  var pendiente = '';
  for (final cruda in crudas) {
    final t = cruda.trim();
    if (t.isEmpty) continue;
    // Un fragmento sin letras ni números (solo signos) se pega al anterior.
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(t)) {
      if (frases.isNotEmpty) {
        frases[frases.length - 1] = '${frases.last} $t';
      } else {
        pendiente = pendiente.isEmpty ? t : '$pendiente $t';
      }
      continue;
    }
    final completo = pendiente.isEmpty ? t : '$pendiente $t';
    pendiente = '';
    frases.addAll(_acortar(completo));
  }
  return frases;
}

/// Parte una frase demasiado larga en una coma, un punto y coma o un espacio.
List<String> _acortar(String frase) {
  if (frase.length <= largoMaximoDeFrase) return [frase];
  final trozos = <String>[];
  var resto = frase;
  while (resto.length > largoMaximoDeFrase) {
    var corte = -1;
    for (final signo in const [', ', '; ', ': ', ' ']) {
      corte = resto.lastIndexOf(signo, largoMaximoDeFrase);
      if (corte > largoMaximoDeFrase ~/ 3) break;
      corte = -1;
    }
    if (corte < 0) corte = largoMaximoDeFrase;
    trozos.add(resto.substring(0, corte + 1).trim());
    resto = resto.substring(corte + 1).trim();
  }
  if (resto.isNotEmpty) trozos.add(resto);
  return trozos;
}

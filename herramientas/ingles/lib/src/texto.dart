/// Utilidades de texto. Hay una sola función para cada cosa: todo el paquete
/// cuenta, divide y compara palabras con estas.
library;


final RegExp _secuencia = RegExp(r"[\p{L}\p{N}'’\-]+", unicode: true);
final RegExp _tieneLetraODigito = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Cuenta cada secuencia de letras, dígitos, apóstrofos o guiones (formato,
/// sección 6.2). Una secuencia sin letras ni dígitos (un apóstrofo suelto) no
/// cuenta. Los números de hueco (`{1}`) cuentan, como en las medidas de los
/// contratos.
int contarPalabras(String texto) => _secuencia
    .allMatches(texto)
    .where((m) => _tieneLetraODigito.hasMatch(m.group(0)!))
    .length;

const Set<String> _tomanS = {
  'it', 'he', 'she', 'that', 'there', 'here', 'what', 'who', 'where', 'when',
  'why', 'how', 'let', 'everyone', 'everybody', 'someone', 'somebody',
  'nobody', 'anyone', 'everything', 'something', 'nothing', 'one', //
};
const Map<String, String> _raicesIrregulares = {
  'ca': 'can',
  'wo': 'will',
  'sha': 'shall',
};
const List<String> _sufijos = ["'m", "'re", "'ve", "'ll", "'d"];

/// Palabras "de examen": en minúsculas y con cada contracción repartida en dos
/// (`I'm` es `i` y `'m`; `don't`, `do` y `n't`). `'s` solo se separa tras los
/// pronombres y adverbios de la lista (`it's`, `there's`): `Maria's` es posesivo
/// y cuenta una.
List<String> palabrasDeExamen(String texto) {
  final salida = <String>[];
  for (final m in _secuencia.allMatches(texto)) {
    final p = m.group(0)!.toLowerCase().replaceAll('’', "'");
    if (!_tieneLetraODigito.hasMatch(p)) continue;
    if (p.endsWith("n't") && p.length > 3) {
      final raiz = p.substring(0, p.length - 3);
      salida
        ..add(_raicesIrregulares[raiz] ?? raiz)
        ..add("n't");
      continue;
    }
    var partida = false;
    for (final s in _sufijos) {
      if (p.endsWith(s) && p.length > s.length) {
        salida
          ..add(p.substring(0, p.length - s.length))
          ..add(s);
        partida = true;
        break;
      }
    }
    if (partida) continue;
    if (p.endsWith("'s") && _tomanS.contains(p.substring(0, p.length - 2))) {
      salida
        ..add(p.substring(0, p.length - 2))
        ..add("'s");
      continue;
    }
    salida.add(p);
  }
  return salida;
}

/// Palabras que cuenta el examen en una respuesta: una contracción cuenta dos.
int contarPalabrasExamen(String texto) => palabrasDeExamen(texto).length;

/// Normaliza una respuesta escrita para compararla con `aceptadas` (formato,
/// sección 9): sin distinguir mayúsculas, sin espacios repetidos, con
/// apóstrofo recto o curvo y sin el punto o el signo de interrogación final.
String normalizarRespuesta(String texto) {
  var t = texto.replaceAll('’', "'").replaceAll('‘', "'").toLowerCase();
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.endsWith('.') || t.endsWith('?')) {
    t = t.substring(0, t.length - 1).trimRight();
  }
  return t;
}

/// Forma con la que se comparan opciones entre sí (V03): sin mayúsculas, sin
/// espacios y sin puntuación.
String normalizarOpcion(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

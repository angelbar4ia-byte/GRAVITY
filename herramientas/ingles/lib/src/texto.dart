/// Utilidades de texto. Hay una sola función para cada cosa: todo el paquete
/// cuenta, divide y compara palabras con estas.
library;


final RegExp _secuencia = RegExp(r"[\p{L}\p{N}'’\-]+", unicode: true);
final RegExp _tieneLetraODigito = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Las palabras de un texto: cada secuencia de letras, dígitos, apóstrofos o
/// guiones que tenga al menos una letra o un dígito. Es la única tokenización
/// del paquete: todo lo que cuenta, compara o divide palabras parte de aquí.
Iterable<String> _palabras(String texto) => _secuencia
    .allMatches(texto)
    .map((m) => m.group(0)!)
    .where(_tieneLetraODigito.hasMatch);

/// Cuenta cada secuencia de letras, dígitos, apóstrofos o guiones (formato,
/// sección 6.2). Una secuencia sin letras ni dígitos (un apóstrofo suelto) no
/// cuenta. Los números de hueco (`{1}`) cuentan, como en las medidas de los
/// contratos.
int contarPalabras(String texto) => _palabras(texto).length;

/// Las palabras de un texto para compararlas: en minúsculas, con apóstrofo
/// recto y sin apóstrofos ni guiones en los bordes (`'Instead` es `instead`).
/// Una contracción sigue siendo una palabra (`don't`); para contarla como dos,
/// [palabrasDeExamen].
List<String> palabrasDe(String texto) => [
      for (final p in _palabras(texto))
        p
            .toLowerCase()
            .replaceAll('’', "'")
            .replaceAll(RegExp(r"^['\-]+|['\-]+$"), ''),
    ];

final RegExp _marcaNumerica = RegExp(r'\{\d+\}');
final RegExp _marcaDeLetras = RegExp(r'(\p{L}*)\{(\p{L}+)\}', unicode: true);

/// Une las palabras que `completar_palabras` corta con llaves: `la{yer}` es
/// `layer`, una sola palabra. Los números de hueco (`{1}`) no se tocan.
String unirPalabrasCortadas(String texto) =>
    texto.replaceAllMapped(_marcaDeLetras, (m) => '${m[1]}${m[2]}');

/// Cuenta las palabras de un estímulo como las mide el contrato: cada número
/// de hueco (`{1}`) cuenta como una palabra y una palabra cortada
/// (`la{yer}`) cuenta una sola vez.
int contarPalabrasEstimulo(String texto) =>
    contarPalabras(unirPalabrasCortadas(texto));

/// El texto sin ninguna marca de hueco: sin los números (`{1}`) y con las
/// palabras cortadas unidas. Para comparar contenido, no para contarlo.
String sinMarcasDeHueco(String texto) =>
    unirPalabrasCortadas(texto).replaceAll(_marcaNumerica, ' ');

final RegExp _finDeOracion = RegExp(r'[.!?…]+["”’)\]]*\s+');
final RegExp _parrafo = RegExp(r'\n[ \t]*\n');

/// Divide un texto en oraciones: corta tras `.`, `!`, `?` o `…` y en cada
/// salto de párrafo (una línea en blanco). Un salto de línea suelto no corta:
/// en los textos del formato las oraciones atraviesan los renglones. Las
/// abreviaturas (`p.m.`) cortan de más; da igual, porque las dos copias de una
/// misma oración se cortan igual.
List<String> dividirOraciones(String texto) {
  final salida = <String>[];
  for (final parrafo in texto.replaceAll('\r\n', '\n').split(_parrafo)) {
    final plano = parrafo.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (plano.isEmpty) continue;
    var inicio = 0;
    for (final m in _finDeOracion.allMatches(plano)) {
      salida.add(plano.substring(inicio, m.end).trim());
      inicio = m.end;
    }
    if (inicio < plano.length) salida.add(plano.substring(inicio).trim());
  }
  return salida;
}

/// La clave con la que se reconoce una oración repetida (V19): sus palabras,
/// sin marcas de hueco, en minúsculas y sin puntuación, separadas por un
/// espacio.
String claveDeOracion(String oracion) =>
    palabrasDe(sinMarcasDeHueco(oracion)).join(' ');

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
  for (final crudo in _palabras(texto)) {
    final p = crudo.toLowerCase().replaceAll('’', "'");
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

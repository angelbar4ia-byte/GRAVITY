/// Palabras funcionales del español para V17 (un enunciado o una opción de un
/// examen en inglés no debe llevar español).
///
/// **Método.** Un enunciado o una opción con dos o más palabras DISTINTAS de esta
/// lista es un error. Una sola no basta: un nombre propio (`El Paso`, `de
/// Gaulle`) o un préstamo (`en route`) trae una palabra suelta, pero casi nunca
/// dos. La lista es corta a propósito: una falsa alarma bloquea el estado
/// `validado` de una unidad y un español que se cuela deja casi siempre varias
/// de estas palabras, no una.
///
/// **Qué entra.** Palabras funcionales (artículos, preposiciones, conjunciones,
/// pronombres, interrogativos, verbos muy frecuentes) que NO sean también
/// inglesas: ni palabras de diccionario, ni nombres propios corrientes, ni
/// letras, ni siglas, ni notas musicales. Para ampliarla, se agrega aquí bajo su
/// categoría; para sacar una palabra, se mueve a [palabrasEspanolasExcluidas]
/// con su razón.
///
/// **Qué no entra y por qué.** Está documentado en
/// [palabrasEspanolasExcluidas]. Sobre todo: `a`, `he`, `no`, `me` y `pan`
/// (palabras inglesas), `con`, `sin`, `son`, `come`, `sale`, `era`, `hay` y
/// `dice` (también inglesas, con otro sentido), las letras sueltas (`y`, `o`,
/// `u`, `e`) y las que coinciden con un nombre o una sigla en minúsculas (`la`
/// de LA, `se` de SE, `al` de Al). Las formas con tilde (`qué`, `más`, `está`)
/// casi nunca chocan con el inglés y por eso abundan.
///
/// **Cómo se comprobó.** Contra las líneas que parecen inglés de
/// `docs/contenido/ingles/` y `data/ingles/` (30 662 palabras, escogidas por su
/// proporción de palabras funcionales inglesas): las 126 palabras de la lista
/// aparecen 9 veces y las 9 son notas en español dentro de líneas mezcladas
/// (revisadas a mano), mientras que `a` aparece 1 238 veces, `he` 90, `me` 89,
/// `no` 55, `e` y `come` 17 cada una. Las pruebas de `test/v17_v18_test.dart`
/// vigilan que la lista no tenga nada de [palabrasEspanolasExcluidas] ni
/// palabras gramaticales del inglés, y los ejemplos de `data/ingles` pasan V17
/// sin un hallazgo.
library;

/// Las palabras del español, por categoría. Todo en minúsculas y con tilde.
const Map<String, List<String>> palabrasEspanolasPorCategoria = {
  // Artículos y demostrativos.
  'articulos_y_demostrativos': [
    'el', 'los', 'las', 'una', 'unos', 'unas', 'del', 'este', 'esta', 'esto',
    'estos', 'estas', 'ese', 'esa', 'eso', 'esos', 'esas', 'aquel', 'aquella',
    'aquello', 'aquellos', 'aquellas',
  ],
  // Preposiciones.
  'preposiciones': [
    'de', 'en', 'por', 'para', 'sobre', 'entre', 'hasta', 'desde', 'hacia',
    'según', 'durante', 'mediante', 'tras',
  ],
  // Conjunciones y conectores.
  'conjunciones_y_conectores': [
    'que', 'pero', 'porque', 'pues', 'aunque', 'como', 'cuando', 'donde',
    'mientras', 'entonces', 'también', 'tampoco', 'además', 'después',
  ],
  // Adverbios.
  'adverbios': [
    'muy', 'más', 'menos', 'siempre', 'nunca', 'ahora', 'todavía', 'aquí',
    'allí', 'ahí', 'así',
  ],
  // Cuantificadores e indefinidos.
  'cuantificadores_e_indefinidos': [
    'mucho', 'mucha', 'muchos', 'muchas', 'toda', 'todos', 'todas', 'otro',
    'otra', 'otros', 'otras', 'mismo', 'misma', 'cada', 'nadie', 'alguien',
  ],
  // Pronombres y posesivos.
  'pronombres_y_posesivos': [
    'tú', 'él', 'ellos', 'ellas', 'nosotros', 'vosotros', 'usted', 'ustedes',
    'sí', 'nuestro', 'nuestra', 'nuestros', 'nuestras',
  ],
  // Interrogativos y exclamativos (con tilde: en inglés no existen).
  'interrogativos': [
    'qué', 'cómo', 'dónde', 'cuándo', 'cuál', 'cuáles', 'quién', 'quiénes',
    'cuánto', 'cuánta', 'cuántos', 'cuántas',
  ],
  // Verbos muy frecuentes.
  'verbos_frecuentes': [
    'es', 'está', 'están', 'estás', 'estoy', 'fue', 'fueron', 'ser', 'eres',
    'somos', 'tiene', 'tienen', 'tienes', 'tengo', 'hace', 'hacen', 'puede',
    'pueden', 'debe', 'deben', 'quiero', 'quiere', 'quieren', 'había', 'hubo',
  ],
};

/// Todas las palabras españolas, sin repetir.
/// Préstamos que el inglés usa con tilde (del francés y del español). Sirven
/// de excepción a la segunda señal de V17: una palabra en minúscula con una
/// letra como á, é, í, ó, ú o ñ cuenta como evidencia de español, salvo estas.
/// Los nombres propios (`José`, `García`) no necesitan entrar aquí: se
/// excluyen por su mayúscula inicial.
const Set<String> prestamosConTilde = {
  'café', 'cafés', 'résumé', 'résumés', 'resumé', 'fiancé', 'fiancée', 'cliché',
  'clichés', 'entrée', 'protégé', 'soufflé', 'touché', 'née', 'canapé',
  'sauté', 'exposé', 'matinée', 'attaché', 'passé', 'jalapeño', 'jalapeños',
  'piñata', 'piñatas', 'señor', 'señora', 'señorita',
};

final Set<String> palabrasEspanolas = {
  for (final lista in palabrasEspanolasPorCategoria.values) ...lista,
};

/// Palabras funcionales del español que se consideraron y NO entran, cada una
/// con su razón. Es la documentación de "por qué excluí X" y la guarda de las
/// pruebas: ninguna de estas puede estar en [palabrasEspanolas].
const Map<String, String> palabrasEspanolasExcluidas = {
  // Palabras inglesas con el mismo aspecto (las que pidió el encargo y las que
  // se hallaron al revisar).
  'a': 'artículo indefinido inglés (1 238 veces en las líneas en inglés del repositorio)',
  'he': 'pronombre inglés',
  'me': 'pronombre inglés',
  'no': 'negación inglesa',
  'pan': 'sustantivo inglés (sartén) y nombre del dios',
  'sin': 'sustantivo inglés (pecado)',
  'con': 'sustantivo y verbo ingleses (estafa, estafar) y "pros and cons"',
  'son': 'sustantivo inglés (hijo)',
  'come': 'verbo inglés',
  'sale': 'sustantivo inglés (venta)',
  'era': 'sustantivo inglés (época)',
  'hay': 'sustantivo inglés (heno)',
  'dice': 'sustantivo inglés (plural de die: dados)',
  'van': 'sustantivo inglés (camioneta)',
  'ya': 'saludo informal inglés (see ya)',
  'yo': 'interjección inglesa',
  'ha': 'interjección inglesa',
  'ante': 'sustantivo y verbo ingleses (la apuesta inicial del póker)',
  'contra': 'palabra inglesa (los "contras", y "contra" en música)',
  'nada': 'jerga inglesa (nada: nada de nada)',
  'solo': 'palabra inglesa (solo)',
  'poco': 'término musical inglés (poco a poco)',
  'don': 'verbo inglés (to don a hat) y nombre propio',
  'algo': 'jerga informática inglesa (algo, por algoritmo)',
  'todo': 'inglés informal y de programadores (the todo list, TODO)',
  // Letras sueltas: en inglés aparecen como letra ("the letter y", "x and y",
  // "blood type O").
  'y': 'letra suelta',
  'o': 'letra suelta',
  'u': 'letra suelta',
  'e': 'letra suelta (17 veces en las líneas en inglés del repositorio)',
  // Coinciden en minúsculas con un nombre, una sigla o una nota musical.
  'la': 'nota musical y "LA" (Los Ángeles) en minúsculas',
  'lo': 'interjección inglesa arcaica ("lo and behold")',
  'le': 'artículo francés y apellido (Le Monde, Le)',
  'les': 'nombre propio (Les) y artículo francés',
  'se': 'sigla SE (sureste, direcciones) en minúsculas',
  'te': 'nota musical y palabra maorí',
  'ti': 'nota musical',
  'mi': 'nota musical',
  'si': 'nota musical y la sigla SI (sistema internacional)',
  'nos': 'abreviatura de "numbers" (Nos. 1 to 3)',
  'os': 'sustantivo anatómico inglés y la sigla OS (sistema operativo)',
  'un': 'sigla UN (Naciones Unidas) en minúsculas',
  'al': 'nombre propio (Al Gore) y "al dente", "al fresco"',
  'ella': 'nombre propio (Ella)',
  'su': 'apellido (Su)',
  'sus': 'jerga británica (to sus out)',
  'tu': 'apellido (Tu)',
  'mis': 'sigla MIS (sistemas de información)',
  'ni': 'apellido (Ni)',
};

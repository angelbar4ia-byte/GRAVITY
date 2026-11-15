/// Palabras gramaticales para V09 (`hueco_abierto` con `clase: gramatical`).
///
/// Una palabra gramatical es de clase cerrada: sirve para construir la oración
/// y no para nombrar cosas, acciones o cualidades. Una palabra puede estar en
/// varias categorías (`since` es preposición y conector). Todo en minúsculas.
/// Para ampliar la lista, se agrega aquí, bajo su categoría, y nada más.
const Map<String, List<String>> palabrasGramaticalesPorCategoria = {
  // Preposiciones.
  'preposiciones': [
    'about', 'above', 'across', 'after', 'against', 'along', 'among', 'amongst',
    'around', 'as', 'at', 'before', 'behind', 'below', 'beneath', 'beside',
    'besides', 'between', 'beyond', 'by', 'concerning', 'despite', 'down',
    'during', 'except', 'for', 'from', 'in', 'inside', 'into', 'like', 'near',
    'of', 'off', 'on', 'onto', 'opposite', 'out', 'outside', 'over', 'past',
    'per', 'plus', 'regarding', 'round', 'since', 'than', 'through',
    'throughout', 'till', 'to', 'toward', 'towards', 'under', 'underneath',
    'unlike', 'until', 'up', 'upon', 'via', 'with', 'within', 'without',
  ],
  // Artículos y determinantes (demostrativos y posesivos).
  'articulos_y_determinantes': [
    'a', 'an', 'the', 'this', 'that', 'these', 'those', 'my', 'your', 'his',
    'her', 'its', 'our', 'their', 'whose', 'what', 'which', 'whatever',
    'whichever',
  ],
  // Verbos auxiliares y modales.
  'auxiliares_y_modales': [
    'am', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'do', 'does',
    'did', 'done', 'have', 'has', 'had', 'having', 'will', 'would', 'shall',
    'should', 'can', 'could', 'may', 'might', 'must', 'ought', 'need', 'dare',
  ],
  // Pronombres (personales, reflexivos, posesivos, indefinidos) y relativos.
  'pronombres_y_relativos': [
    'i', 'me', 'you', 'he', 'him', 'she', 'it', 'we', 'us', 'they', 'them',
    'myself', 'yourself', 'himself', 'herself', 'itself', 'ourselves',
    'yourselves', 'themselves', 'mine', 'yours', 'hers', 'ours', 'theirs',
    'one', 'ones', 'who', 'whom', 'whose', 'which', 'that', 'what', 'whoever',
    'whomever', 'where', 'when', 'why', 'how', 'whenever', 'wherever', 'there',
    'here', 'someone', 'somebody', 'something', 'anyone', 'anybody',
    'anything', 'everyone', 'everybody', 'everything', 'nobody', 'nothing',
  ],
  // Conectores y adverbios de enlace.
  'conectores': [
    'and', 'but', 'or', 'nor', 'so', 'yet', 'because', 'although', 'though',
    'while', 'whilst', 'whereas', 'whether', 'if', 'unless', 'once', 'since',
    'until', 'as', 'than', 'however', 'therefore', 'thus', 'hence', 'moreover',
    'furthermore', 'nevertheless', 'nonetheless', 'otherwise', 'instead',
    'meanwhile', 'anyway', 'then', 'else', 'also', 'too', 'even', 'still',
    'rather', 'such', 'both', 'either', 'neither',
  ],
  // Partículas de verbos frasales (las que no son también preposiciones).
  'particulas_de_verbos_frasales': [
    'up', 'down', 'out', 'off', 'on', 'in', 'over', 'away', 'back', 'along',
    'around', 'about', 'through', 'apart', 'aside', 'ahead', 'together',
    'across', 'by', 'forth',
  ],
  // Cuantificadores y determinantes de cantidad.
  'cuantificadores': [
    'all', 'any', 'some', 'no', 'none', 'many', 'much', 'more', 'most', 'few',
    'fewer', 'less', 'least', 'little', 'enough', 'several', 'each', 'every',
    'another', 'other', 'others', 'plenty', 'half', 'both', 'either',
    'neither', 'lot', 'lots', 'couple',
  ],
  // Negaciones.
  'negaciones': [
    'not', 'no', 'never', 'nor', 'neither', 'none', 'nothing', 'nobody',
    'nowhere', 'hardly', 'barely', 'scarcely', 'without',
  ],
};

/// Todas las palabras gramaticales, sin repetir.
final Set<String> palabrasGramaticales = {
  for (final lista in palabrasGramaticalesPorCategoria.values) ...lista,
};

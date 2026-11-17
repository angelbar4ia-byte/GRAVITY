/// Formas de una palabra inglesa para V23: ¿contiene el ejemplo de una tarjeta
/// la palabra de la tarjeta o una forma suya (plural, -ing, -ed, un participio
/// irregular...)? Es una heurística acotada, no un analizador: una lista de
/// sufijos regulares y una tabla corta de formas irregulares frecuentes.
library;

import 'texto.dart';

/// Formas irregulares frecuentes: cada línea es la base y sus formas.
const List<String> _irregulares = [
  'be: am is are was were been being',
  'have: has had having',
  'do: does did done doing',
  'go: goes went gone going',
  'get: gets got gotten getting',
  'make: makes made making',
  'take: takes took taken taking',
  'see: sees saw seen seeing',
  'come: comes came coming',
  'know: knows knew known knowing',
  'think: thinks thought thinking',
  'give: gives gave given giving',
  'find: finds found finding',
  'tell: tells told telling',
  'become: becomes became becoming',
  'leave: leaves left leaving',
  'feel: feels felt feeling',
  'put: puts putting',
  'bring: brings brought bringing',
  'begin: begins began begun beginning',
  'keep: keeps kept keeping',
  'hold: holds held holding',
  'write: writes wrote written writing',
  'stand: stands stood standing',
  'hear: hears heard hearing',
  'let: lets letting',
  'mean: means meant meaning',
  'set: sets setting',
  'meet: meets met meeting',
  'run: runs ran running',
  'pay: pays paid paying',
  'sit: sits sat sitting',
  'speak: speaks spoke spoken speaking',
  'lie: lies lay lain lying',
  'lead: leads led leading',
  'read: reads reading',
  'grow: grows grew grown growing',
  'lose: loses lost losing',
  'fall: falls fell fallen falling',
  'send: sends sent sending',
  'build: builds built building',
  'understand: understands understood understanding',
  'draw: draws drew drawn drawing',
  'break: breaks broke broken breaking',
  'spend: spends spent spending',
  'cut: cuts cutting',
  'rise: rises rose risen rising',
  'drive: drives drove driven driving',
  'buy: buys bought buying',
  'wear: wears wore worn wearing',
  'choose: chooses chose chosen choosing',
  'eat: eats ate eaten eating',
  'drink: drinks drank drunk drinking',
  'sleep: sleeps slept sleeping',
  'teach: teaches taught teaching',
  'catch: catches caught catching',
  'fly: flies flew flown flying',
  'forget: forgets forgot forgotten forgetting',
  'sing: sings sang sung singing',
  'swim: swims swam swum swimming',
  'win: wins won winning',
  'sell: sells sold selling',
  'throw: throws threw thrown throwing',
  'wake: wakes woke woken waking',
  'ride: rides rode ridden riding',
  'lend: lends lent lending',
  'steal: steals stole stolen stealing',
  'hide: hides hid hidden hiding',
  'shake: shakes shook shaken shaking',
  'show: shows showed shown showing',
  'good: better best',
  'bad: worse worst',
  'far: further farther furthest farthest',
  'many: more most',
  'much: more most',
  'little: less least',
  'person: people',
  'child: children',
  'man: men',
  'woman: women',
  'foot: feet',
  'tooth: teeth',
  'mouse: mice',
];

final Map<String, Set<String>> _baseDeIrregular = () {
  final m = <String, Set<String>>{};
  for (final linea in _irregulares) {
    final i = linea.indexOf(':');
    final base = linea.substring(0, i);
    for (final f in linea.substring(i + 1).trim().split(' ')) {
      (m[f] ??= {}).add(base);
    }
    (m[base] ??= {}).add(base);
  }
  return m;
}();

bool _vocal(String ch) => 'aeiou'.contains(ch);

/// Las bases posibles de una palabra: ella misma, sin cada sufijo regular, y
/// la base de su forma irregular.
Set<String> basesDe(String palabra) {
  final p = palabra.toLowerCase();
  final b = <String>{p};
  void quita(String sufijo, {String pon = ''}) {
    if (p.length > sufijo.length + 1 && p.endsWith(sufijo)) {
      b.add('${p.substring(0, p.length - sufijo.length)}$pon');
    }
  }

  quita('s');
  quita('es');
  quita('ies', pon: 'y');
  quita('ied', pon: 'y');
  quita('ed');
  quita('d');
  quita('ing');
  quita('ing', pon: 'e');
  quita('er');
  quita('er', pon: 'e');
  quita('est');
  quita('est', pon: 'e');
  quita('ier', pon: 'y');
  quita('iest', pon: 'y');
  quita('ly');
  quita("'s");
  // Consonante doblada: stopped, running.
  for (final suf in ['ed', 'ing', 'er', 'est']) {
    if (p.length > suf.length + 2 && p.endsWith(suf)) {
      final raiz = p.substring(0, p.length - suf.length);
      if (raiz.length >= 2 &&
          raiz[raiz.length - 1] == raiz[raiz.length - 2] &&
          !_vocal(raiz[raiz.length - 1])) {
        b.add(raiz.substring(0, raiz.length - 1));
      }
    }
  }
  for (final base in [...b]) {
    final irr = _baseDeIrregular[base];
    if (irr != null) b.addAll(irr);
  }
  return b;
}

/// ¿Es [token] la [palabra] o una forma suya (o al revés)?
bool esFormaDe(String palabra, String token) {
  final a = basesDe(palabra);
  final b = basesDe(token);
  return a.any(b.contains);
}

/// Palabras de relleno de una tarjeta que no hay que buscar en el ejemplo.
const Set<String> _relleno = {
  'sb',
  'sth',
  'someone',
  'something',
  'somebody',
  'one',
};

/// ¿Contiene el [ejemplo] lo que dice la tarjeta [en] (una palabra, una frase o
/// varias alternativas separadas con `/`)? Basta una alternativa: todas sus
/// palabras deben aparecer en el ejemplo, cada una tal cual o en una forma suya.
/// Lo que va entre paréntesis en la tarjeta es opcional y no se busca.
bool ejemploContiene(String en, String ejemplo) {
  final tokens = palabrasDe(ejemplo);
  final plano = ' ${tokens.join(' ')} ';
  final sinParentesis = en.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  for (final alt in sinParentesis.split('/')) {
    final palabras = [
      for (final p in palabrasDe(alt))
        if (!_relleno.contains(p)) p,
    ];
    if (palabras.isEmpty) continue;
    if (plano.contains(' ${palabras.join(' ')} ')) return true;
    if (palabras.every((p) => tokens.any((t) => esFormaDe(p, t)))) return true;
  }
  return false;
}

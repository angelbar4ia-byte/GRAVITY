/// Lista de control de grafías británicas y americanas para V18: un archivo con
/// las dos variantes mezcladas, o cuya grafía no coincide con su `variante`
/// declarada, recibe un aviso.
///
/// **Método.** Cada entrada pone la grafía británica y, a su derecha, la
/// americana. Una palabra de la lista que aparece en el texto en inglés de una
/// unidad o una sesión cuenta como prueba de esa variante. Las formas con
/// inflexión están escritas una por una (colour, colours, coloured...): una regla
/// que las genere se equivoca con `centre` frente a `centred` o con `analyse`
/// frente a `analysed`, y aquí cada forma se puede revisar a simple vista.
///
/// **Qué no cuenta como prueba.** Una forma americana que también es correcta
/// en inglés británico con otro sentido no prueba nada: está en
/// [americanasAmbiguas] y se ignora (`tire` es también el verbo "cansar";
/// `check`, `program` y `meter` son comunes en Gran Bretaña; `story` es
/// también "cuento"). De esos pares solo cuenta la forma británica. Lo mismo al
/// revés con [britanicasAmbiguas] (`cancelled` se usa también en Estados
/// Unidos).
///
/// **Límites.** Es una lista de control, no un corrector: no sabe nada de las
/// palabras que no están en ella ni de los nombres propios (`Grey`, `Centre
/// Point`). Un aviso se resuelve cambiando la grafía o, si la mezcla es a
/// propósito (una lección sobre las diferencias entre las dos variantes), con
/// la certeza de que es solo un aviso. Las diferencias de vocabulario (`flat` y
/// `apartment`, `lorry` y `truck`) no son de grafía y no están aquí.
///
/// Para ampliarla, se agrega la pareja bajo su grupo, en minúsculas.
library;

/// Grafía británica → americana.
const Map<String, String> grafiasBritanicas = {
  // -our / -or
  'colour': 'color',
  'colours': 'colors',
  'coloured': 'colored',
  'colourful': 'colorful',
  'colouring': 'coloring',
  'colourless': 'colorless',
  'behaviour': 'behavior',
  'behaviours': 'behaviors',
  'behavioural': 'behavioral',
  'favour': 'favor',
  'favours': 'favors',
  'favoured': 'favored',
  'favourite': 'favorite',
  'favourites': 'favorites',
  'favourable': 'favorable',
  'neighbour': 'neighbor',
  'neighbours': 'neighbors',
  'neighbouring': 'neighboring',
  'neighbourhood': 'neighborhood',
  'neighbourhoods': 'neighborhoods',
  'honour': 'honor',
  'honours': 'honors',
  'honoured': 'honored',
  'honourable': 'honorable',
  'labour': 'labor',
  'laboured': 'labored',
  'harbour': 'harbor',
  'harbours': 'harbors',
  'flavour': 'flavor',
  'flavours': 'flavors',
  'flavoured': 'flavored',
  'rumour': 'rumor',
  'rumours': 'rumors',
  'vapour': 'vapor',
  'odour': 'odor',
  'odours': 'odors',
  'endeavour': 'endeavor',
  'saviour': 'savior',
  'armour': 'armor',
  'parlour': 'parlor',
  'splendour': 'splendor',
  'rigour': 'rigor',
  'vigour': 'vigor',
  'tumour': 'tumor',

  // -re / -er
  'centre': 'center',
  'centres': 'centers',
  'centred': 'centered',
  'theatre': 'theater',
  'theatres': 'theaters',
  'metre': 'meter',
  'metres': 'meters',
  'kilometre': 'kilometer',
  'kilometres': 'kilometers',
  'centimetre': 'centimeter',
  'centimetres': 'centimeters',
  'millimetre': 'millimeter',
  'millimetres': 'millimeters',
  'litre': 'liter',
  'litres': 'liters',
  'fibre': 'fiber',
  'fibres': 'fibers',
  'calibre': 'caliber',
  'sombre': 'somber',
  'lustre': 'luster',
  'spectre': 'specter',

  // -ise / -ize (el inglés británico de Oxford también admite -ize: aquí se
  // trata como americano, que es lo que pide el encargo).
  'realise': 'realize',
  'realises': 'realizes',
  'realised': 'realized',
  'realising': 'realizing',
  'realisation': 'realization',
  'organise': 'organize',
  'organises': 'organizes',
  'organised': 'organized',
  'organising': 'organizing',
  'organisation': 'organization',
  'organisations': 'organizations',
  'recognise': 'recognize',
  'recognises': 'recognizes',
  'recognised': 'recognized',
  'recognising': 'recognizing',
  'apologise': 'apologize',
  'apologised': 'apologized',
  'apologising': 'apologizing',
  'criticise': 'criticize',
  'criticised': 'criticized',
  'criticising': 'criticizing',
  'emphasise': 'emphasize',
  'emphasised': 'emphasized',
  'summarise': 'summarize',
  'summarised': 'summarized',
  'specialise': 'specialize',
  'specialised': 'specialized',
  'memorise': 'memorize',
  'minimise': 'minimize',
  'maximise': 'maximize',
  'civilisation': 'civilization',
  'customise': 'customize',
  'familiarise': 'familiarize',
  'modernise': 'modernize',
  'normalise': 'normalize',

  // -yse / -yze
  'analyse': 'analyze',
  'analyses': 'analyzes',
  'analysed': 'analyzed',
  'analysing': 'analyzing',
  'paralyse': 'paralyze',
  'catalyse': 'catalyze',

  // Consonante doblada: -ll- frente a -l-, y al revés.
  'travelled': 'traveled',
  'travelling': 'traveling',
  'traveller': 'traveler',
  'travellers': 'travelers',
  'cancelled': 'canceled',
  'cancelling': 'canceling',
  'labelled': 'labeled',
  'labelling': 'labeling',
  'modelled': 'modeled',
  'modelling': 'modeling',
  'counsellor': 'counselor',
  'counsellors': 'counselors',
  'jewellery': 'jewelry',
  'marvellous': 'marvelous',
  'levelled': 'leveled',
  'levelling': 'leveling',
  'fuelled': 'fueled',
  'fuelling': 'fueling',
  'signalled': 'signaled',
  'signalling': 'signaling',
  'skilful': 'skillful',
  'fulfil': 'fulfill',
  'fulfils': 'fulfills',
  'enrol': 'enroll',
  'enrols': 'enrolls',
  'instalment': 'installment',
  'instalments': 'installments',

  // -ence / -ense
  'defence': 'defense',
  'defences': 'defenses',
  'offence': 'offense',
  'offences': 'offenses',
  'pretence': 'pretense',
  'licence': 'license',
  'licences': 'licenses',

  // -ogue / -og y -amme / -am
  'catalogue': 'catalog',
  'catalogues': 'catalogs',
  'dialogue': 'dialog',
  'dialogues': 'dialogs',
  'analogue': 'analog',
  'programme': 'program',
  'programmes': 'programs',

  // Palabras sueltas.
  'grey': 'gray',
  'greys': 'grays',
  'greyish': 'grayish',
  'tyre': 'tire',
  'tyres': 'tires',
  'cheque': 'check',
  'cheques': 'checks',
  'kerb': 'curb',
  'kerbs': 'curbs',
  'plough': 'plow',
  'ploughs': 'plows',
  'ploughed': 'plowed',
  'mould': 'mold',
  'moulds': 'molds',
  'mouldy': 'moldy',
  'moustache': 'mustache',
  'pyjamas': 'pajamas',
  'aluminium': 'aluminum',
  'sceptic': 'skeptic',
  'sceptical': 'skeptical',
  'scepticism': 'skepticism',
  'storey': 'story',
  'storeys': 'stories',
  'draught': 'draft',
  'draughts': 'drafts',
  'cosy': 'cozy',
  'ageing': 'aging',
  'judgement': 'judgment',
  'enquire': 'inquire',
  'enquiry': 'inquiry',
  'enquiries': 'inquiries',
  'practise': 'practice',
  'practised': 'practiced',
  'practising': 'practicing',
  'artefact': 'artifact',
  'artefacts': 'artifacts',
  'yoghurt': 'yogurt',
  'sulphur': 'sulfur',
  'aeroplane': 'airplane',
  'aeroplanes': 'airplanes',
  'anaemia': 'anemia',
  'paediatric': 'pediatric',
  'oestrogen': 'estrogen',
  'foetus': 'fetus',
  'manoeuvre': 'maneuver',
  'manoeuvres': 'maneuvers',
  'diarrhoea': 'diarrhea',
  'encyclopaedia': 'encyclopedia',
  'liquorice': 'licorice',
  'gaol': 'jail',

  // Pasados británicos en -t (`learnt` frente a `learned`).
  'learnt': 'learned',
  'spelt': 'spelled',
  'burnt': 'burned',
  'dreamt': 'dreamed',
  'spoilt': 'spoiled',
  'leapt': 'leaped',
};

/// Formas americanas que también son correctas en inglés británico (con otro
/// sentido o como variante corriente): no prueban que el texto sea americano.
const Set<String> americanasAmbiguas = {
  'meter', 'meters', //                    "meter": el aparato (gas meter, parking meter)
  'tire', 'tires', //                      "tire": el verbo cansar
  'check', 'checks', //                    "check": comprobar, cuenta de restaurante
  'program', 'programs', //                "program": programa de computadora, también en Gran Bretaña
  'catalog', 'catalogs', //                "catalog": también en informática británica
  'dialog', 'dialogs', //                  "dialog box" es común en Gran Bretaña
  'analog', //                             "analog" en electrónica
  'license', 'licenses', //                "license": el verbo, también británico
  'story', 'stories', //                   "story": el cuento
  'draft', 'drafts', //                    "draft": el borrador
  'curb', 'curbs', //                      "curb": frenar
  'practice', //                           "practice": el sustantivo, igual en las dos
  'learned', 'spelled', 'burned', //       los pasados regulares también se usan en Gran Bretaña
  'dreamed', 'spoiled', 'leaped',
  'inquiry', 'inquiries', //               "inquiry" se usa en Gran Bretaña para investigaciones formales
};

/// Formas británicas que también son corrientes en inglés americano: no
/// prueban que el texto sea británico. (`cancelled` se escribe así en los dos
/// lados; `canceled` sí es solo americano y por eso sigue contando.)
const Set<String> britanicasAmbiguas = {'cancelled', 'cancelling'};

/// Las grafías británicas de la lista que sí prueban la variante.
final Set<String> formasBritanicas = {
  for (final b in grafiasBritanicas.keys)
    if (!britanicasAmbiguas.contains(b)) b,
};

/// Las grafías americanas que sí prueban la variante: las de la lista menos las
/// ambiguas.
final Set<String> formasAmericanas = {
  for (final a in grafiasBritanicas.values)
    if (!americanasAmbiguas.contains(a)) a,
};

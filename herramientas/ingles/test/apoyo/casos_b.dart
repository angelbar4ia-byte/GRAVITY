import 'ayudas.dart';
import 'casos.dart';

/// Casos de P1.2b: longitud, audio, idioma, grafías, duplicados, usos y
/// fidelidad. Cada caso bueno pasa todas las comprobaciones sin un hallazgo
/// (cada grupo de pruebas lo exige) y cada caso malo cambia un solo dato de uno
/// bueno.
///
/// Los textos son de relleno y de longitud exacta: [relleno] da `n` palabras en
/// oraciones de cinco, distintas para cada semilla. Así dos unidades con
/// semillas distintas no comparten ninguna oración de siete palabras ni
/// trigramas por casualidad, y la longitud de cada estímulo se conoce.

const List<String> _vocabulario = [
  'river', 'stone', 'lamp', 'garden', 'window', 'paper', 'bridge', 'cloud',
  'bread', 'table', 'candle', 'mirror', 'forest', 'island', 'ladder', 'basket',
  'engine', 'feather', 'glove', 'hammer', 'jacket', 'kettle', 'lemon', 'magnet',
  'needle', 'orange', 'pencil', 'pillow', 'rabbit', 'saddle', 'ticket',
  'umbrella', 'valley', 'wagon', 'yellow', 'zebra', 'anchor', 'blanket',
  'cabin', 'dragon', 'elbow', 'fabric', 'guitar', 'harvest', 'igloo', 'jungle',
  'kitchen', 'lantern', 'market', 'napkin', 'ocean', 'pepper', 'quilt',
  'rocket', 'spoon', 'tunnel', 'violin', 'whistle', 'marble', 'thunder',
  'cactus', 'compass', 'bottle', 'castle',
];

/// Un hash de 32 bits (lowbias32): reparte bien aunque las entradas sean
/// seguidas.
int _hash(int x) {
  x &= 0xFFFFFFFF;
  x ^= x >> 16;
  x = (x * 0x7feb352d) & 0xFFFFFFFF;
  x ^= x >> 15;
  x = (x * 0x846ca68b) & 0xFFFFFFFF;
  x ^= x >> 16;
  return x;
}

String _palabra(int semilla, int i) =>
    _vocabulario[_hash(semilla * 1000003 + i * 7 + 11) % _vocabulario.length];

/// [n] palabras en inglés, en oraciones de cinco palabras: distintas para cada
/// [semilla].
String relleno(int semilla, int n) {
  final palabras = <String>[];
  for (var i = 0; i < n; i++) {
    var p = _palabra(semilla, i);
    if (i % 5 == 0) p = '${p[0].toUpperCase()}${p.substring(1)}';
    palabras.add(i % 5 == 4 || i == n - 1 ? '$p.' : p);
  }
  return palabras.join(' ');
}

/// Una sola oración de [n] palabras, distinta para cada [semilla].
String oracion(int semilla, int n) {
  final palabras = [for (var i = 0; i < n; i++) _palabra(semilla + 1000, i)];
  palabras[0] = '${palabras[0][0].toUpperCase()}${palabras[0].substring(1)}';
  return '${palabras.join(' ')}.';
}

/// Una oración de nueve palabras que se repite a propósito en las pruebas de V19.
const String fraseCompartida = 'The old bridge was closed because of the storm.';

const String _razon = 'La razón cita la evidencia del texto con palabras suficientes.';

// ---------------------------------------------------------------------------
// Contratos

Doc _parte(
  String id,
  String tipoPregunta,
  String tipoEstimulo, {
  required int unidades,
  required int porUnidad,
  int? opciones,
  int? reproducciones,
  Doc? palabras,
}) =>
    {
      'id': id,
      'tarea': 'Parte de prueba $id',
      'tipo_pregunta': tipoPregunta,
      'tipo_estimulo': tipoEstimulo,
      'unidades': unidades,
      'preguntas_por_unidad': porUnidad,
      'preguntas_total': unidades * porUnidad,
      'opciones': ?opciones,
      'reproducciones': ?reproducciones,
      'palabras_estimulo': ?palabras,
      'pagina_manual': 1,
    };

/// Un examen de prueba completo, sin datos pendientes, con seis partes:
/// dos textos (`r-1`), un texto con dos preguntas (`r-2`), tres transformaciones
/// sueltas (`r-tr`), unas oraciones omitidas (`r-oo`), dos audios (`l-1`) y un
/// audio de notas (`l-2`).
Doc contratoFidelidad() => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'formato',
      'id': 'prueba-fidelidad',
      'estado': 'borrador',
      'nombre': 'Examen de prueba para la fidelidad',
      'fuente': {'titulo': 'Manual de prueba', 'url': 'https://example.org/manual.pdf', 'consultado': '2026-01-01'},
      'variante': 'en-GB',
      'idioma_instrucciones': 'en',
      'secciones': [
        {
          'id': 'reading',
          'minutos': 30,
          'partes': [
            _parte('r-1', 'opcion_multiple', 'texto', unidades: 2, porUnidad: 1, opciones: 3, palabras: {'min': 20, 'max': 40, 'origen': 'medido'}),
            _parte('r-2', 'opcion_multiple', 'texto', unidades: 1, porUnidad: 2, opciones: 3, palabras: {'min': 50, 'max': 80, 'origen': 'declarado'}),
            _parte('r-tr', 'transformacion', 'ninguno', unidades: 3, porUnidad: 1, palabras: {'min': 5, 'max': 12, 'origen': 'medido'}),
            _parte('r-oo', 'oracion_omitida', 'texto', unidades: 1, porUnidad: 2, opciones: 3, palabras: {'min': 40, 'max': 70, 'origen': 'medido'}),
          ],
        },
        {
          'id': 'listening',
          'minutos': 20,
          'partes': [
            _parte('l-1', 'opcion_multiple', 'audio', unidades: 2, porUnidad: 1, opciones: 3, reproducciones: 2, palabras: {'min': 15, 'max': 40, 'origen': 'medido'}),
            _parte('l-2', 'completar_nota', 'audio', unidades: 1, porUnidad: 2, reproducciones: 2, palabras: {'min': 30, 'max': 60, 'origen': 'medido'}),
          ],
        },
      ],
    };

/// El contrato de prueba con un dato cambiado en una de sus partes: así un caso
/// malo se construye sobre el bueno cambiando un solo dato del contrato.
Doc contratoCon(String parte, void Function(Doc) cambia) {
  final c = clonar(contratoFidelidad());
  for (final s in lista(c['secciones'])) {
    for (final p in lista(mapa(s)['partes'])) {
      if (mapa(p)['id'] == parte) cambia(mapa(p));
    }
  }
  return c;
}

// ---------------------------------------------------------------------------
// Unidades

Doc _base(String id, String parte, String formato, String variante, String estado) => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'unidad',
      'id': id,
      'estado': estado,
      'formato': formato,
      'parte': parte,
      'nivel': 'B1',
      'variante': variante,
      'origen': 'nuevo',
    };

Doc _preguntaOpciones(String id, int semilla, {String habilidad = 'lectura'}) => {
      'id': id,
      'tipo': 'opcion_multiple',
      'habilidad': habilidad,
      'foco': 'detalle',
      'enunciado': 'What is said about the ${_palabra(semilla, 3)}?',
      'opciones': [
        {'texto': 'It is quite old.', 'porque': _razon},
        {'texto': 'It is very new.', 'porque_no': 'El texto no dice eso.'},
        {'texto': 'It is for sale.', 'porque_no': 'El texto no dice eso.'},
      ],
    };

/// Una unidad de lectura: un texto de [palabras] palabras y [preguntas]
/// preguntas de tres opciones. Con [texto] se pone el texto tal cual.
Doc lectura(
  String id, {
  String parte = 'r-1',
  int semilla = 1,
  int palabras = 30,
  int preguntas = 1,
  String? texto,
  String formato = 'prueba-fidelidad',
  String variante = 'en-GB',
  String estado = 'borrador',
}) =>
    {
      ..._base(id, parte, formato, variante, estado),
      'estimulo': {'tipo': 'texto', 'titulo': 'A short text', 'texto': texto ?? relleno(semilla, palabras)},
      'preguntas': [
        for (var i = 0; i < preguntas; i++) _preguntaOpciones('$id-${i + 1}', semilla + i),
      ],
    };

/// Un audio de [palabras] palabras de habla (dos voces) más una frase del
/// narrador, con una pregunta de tres opciones. Con [guion] se pone el guion tal
/// cual.
Doc audio(
  String id, {
  String parte = 'l-1',
  int semilla = 1,
  int palabras = 24,
  int reproducciones = 2,
  List<Doc>? guion,
  String formato = 'prueba-fidelidad',
  String variante = 'en-GB',
  String estado = 'borrador',
}) =>
    {
      ..._base(id, parte, formato, variante, estado),
      'estimulo': {
        'tipo': 'audio',
        'reproducciones': reproducciones,
        'guion': guion ??
            [
              {'voz': 'N', 'texto': 'You will hear a short talk.'},
              {'voz': 'F1', 'texto': relleno(semilla, palabras - palabras ~/ 2)},
              {'voz': 'M1', 'texto': relleno(semilla + 500, palabras ~/ 2)},
            ],
      },
      'preguntas': [_preguntaOpciones('$id-1', semilla, habilidad: 'escucha')],
    };

/// Un audio de notas con dos huecos (parte `l-2`).
Doc audioNotas(String id, {int semilla = 1, int palabras = 40, int reproducciones = 2}) => {
      ..._base(id, 'l-2', 'prueba-fidelidad', 'en-GB', 'borrador'),
      'estimulo': {
        'tipo': 'audio',
        'reproducciones': reproducciones,
        'guion': [
          {'voz': 'N', 'texto': 'You will hear a short talk.'},
          {'voz': 'F1', 'texto': relleno(semilla, palabras)},
        ],
      },
      'preguntas': [
        for (var i = 1; i <= 2; i++)
          {
            'id': '$id-$i',
            'tipo': 'completar_nota',
            'habilidad': 'escucha',
            'hueco': i,
            'aceptadas': ['nine'],
            'porque': 'La hablante dice la cifra exacta en este momento.',
          },
      ],
    };

/// [n] transformaciones sueltas (`estimulo: ninguno`) cuyas oraciones originales
/// tienen [palabrasOriginal] palabras (parte `r-tr`).
Doc transformaciones(String id, {int n = 3, int semilla = 1, int palabrasOriginal = 8}) => {
      ..._base(id, 'r-tr', 'prueba-fidelidad', 'en-GB', 'borrador'),
      'estimulo': {'tipo': 'ninguno'},
      'preguntas': [
        for (var i = 1; i <= n; i++)
          {
            'id': '$id-$i',
            'tipo': 'transformacion',
            'habilidad': 'gramatica',
            'original': oracion(semilla + i, palabrasOriginal),
            'clave': 'WHILE',
            'antes': 'We',
            'despues': 'the road.',
            'aceptadas': ['walked while crossing'],
            'porque': 'La clave pide dos acciones que ocurren a la vez.',
          },
      ],
    };

/// Oraciones omitidas (parte `r-oo`): un texto con dos huecos, dos oraciones
/// colocadas y una sobrante. Texto de 38 palabras (con las dos marcas) más tres
/// oraciones de cinco palabras: 53 en total.
Doc omitidas(String id, {int semilla = 1}) => {
      ..._base(id, 'r-oo', 'prueba-fidelidad', 'en-GB', 'borrador'),
      'estimulo': {
        'tipo': 'texto',
        'texto': '${relleno(semilla, 14)} {1} ${relleno(semilla + 1, 14)} {2} ${relleno(semilla + 2, 8)}',
      },
      'preguntas': [
        {
          'id': '$id-a',
          'tipo': 'oracion_omitida',
          'habilidad': 'lectura',
          'porque': 'Cada oración se ata por lo que retoma y por lo que prepara.',
          'oraciones': [
            {'texto': oracion(semilla + 10, 5), 'hueco': 1, 'ancla': 'Retoma la idea del párrafo anterior con otras palabras.'},
            {'texto': oracion(semilla + 11, 5), 'hueco': 2, 'ancla': 'Prepara la cifra que aparece en la oración siguiente.'},
            {'texto': oracion(semilla + 12, 5), 'sobrante': true, 'porque_no': 'Contradice lo que dice el texto en su primer párrafo.'},
          ],
        },
      ],
    };

// ---------------------------------------------------------------------------
// Formas y sesiones

/// Una forma con las secciones que se le den: `{parte: [ids de unidades]}`.
Doc formaDe(String id, Map<String, List<String>> partes, {String uso = 'simulacro', String estado = 'borrador'}) => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'forma',
      'id': id,
      'estado': estado,
      'formato': 'prueba-fidelidad',
      'uso': uso,
      'semilla': 2026111601,
      'secciones': [
        for (final e in partes.entries) {'parte': e.key, 'unidades': e.value},
      ],
    };

/// Las ocho unidades de la forma completa de prueba.
List<Doc> unidadesCompletas() => [
      lectura('u-r1-a', parte: 'r-1', semilla: 1, palabras: 30),
      lectura('u-r1-b', parte: 'r-1', semilla: 2, palabras: 25),
      lectura('u-r2', parte: 'r-2', semilla: 3, palabras: 60, preguntas: 2),
      transformaciones('u-tr', semilla: 4),
      omitidas('u-oo', semilla: 5),
      audio('u-l1-a', semilla: 6, palabras: 24),
      audio('u-l1-b', semilla: 7, palabras: 20),
      audioNotas('u-l2', semilla: 8, palabras: 40),
    ];

/// Las secciones de la forma completa de prueba.
Map<String, List<String>> seccionesCompletas() => {
      'r-1': ['u-r1-a', 'u-r1-b'],
      'r-2': ['u-r2'],
      'r-tr': ['u-tr'],
      'r-oo': ['u-oo'],
      'l-1': ['u-l1-a', 'u-l1-b'],
      'l-2': ['u-l2'],
    };

/// La forma completa de prueba.
Doc formaCompleta({String id = 'f-completa', String uso = 'simulacro'}) =>
    formaDe(id, seccionesCompletas(), uso: uso);

/// Una sesión de prueba con su propio id (también en sus preguntas y tarjetas),
/// sus audios de traslado y sus frases. La [semilla] cambia el enunciado de su
/// pregunta, para que dos sesiones con semillas distintas no compartan una
/// oración de siete palabras por casualidad.
Doc sesionDe(
  String id, {
  List<String> audios = const ['u-au'],
  List<String> frases = const ['Normally, my days are all the same.'],
  String variante = 'en-US',
  int semilla = 1,
}) {
  final s = clonar(sesion())
    ..['id'] = id
    ..['variante'] = variante;
  for (final b in lista(s['bloques'])) {
    final m = mapa(b);
    if (m['tipo'] == 'leccion') {
      final q = mapa(lista(m['preguntas']).first);
      q['id'] = '$id-01';
      q['enunciado'] = '${relleno(semilla, 4).replaceAll('.', '')} ___ in a bank, but this month ___ from home.';
    }
    if (m['tipo'] == 'produccion') mapa(m['tarea'])['id'] = '$id-prod';
    if (m['tipo'] == 'traslado') {
      m['audios'] = audios;
      m['frases'] = frases;
    }
  }
  mapa(lista(s['tarjetas']).first)['id'] = '$id-tarjeta-0001';
  return s;
}

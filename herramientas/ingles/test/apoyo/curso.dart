import 'dart:io';

import 'package:ingles/ingles.dart';
import 'package:ingles/src/modelo/lector.dart' show aPlano;
import 'package:yaml/yaml.dart';

import 'ayudas.dart';

/// Casos del curso (V21 a V23, V27 y V28): se construyen sobre los contratos
/// REALES de `data/ingles/formatos/` y sobre `niveles.yaml`, para que lo que se
/// prueba sea lo que dice el contrato y no una copia que se pueda desviar. Cada
/// caso malo cambia un dato de un caso bueno.

const String _datos = '../../data/ingles';

/// Un archivo YAML de `data/ingles` como mapa editable.
Doc yamlReal(String ruta) => aPlano(loadYaml(File('$_datos/$ruta').readAsStringSync()))! as Doc;

Doc contratoReal(String id) => yamlReal('formatos/$id.yaml');
Doc nivelesReales() => yamlReal('niveles.yaml');

/// `gravity-sesion-60` más la sección que hoy le falta: las partes de las formas
/// de prueba por unidad y de mini prueba (formato 0.5, 5.1). Se agrega como
/// sección sin `minutos` para que no cuente en el total de la sesión.
Doc contratoSesionConPruebas() {
  final c = contratoReal('gravity-sesion-60');
  lista(c['secciones']).add({
    'id': 'pruebas',
    'partes': [
      {'id': 'prueba-unidad', 'tarea': 'Prueba por unidad del viernes', 'tipo_pregunta': 'opcion_multiple', 'unidades': 4, 'opciones': 3},
      {'id': 'mini', 'tarea': 'Mini prueba del viernes', 'tipo_pregunta': 'opcion_multiple', 'unidades': 1, 'opciones': 3},
    ],
  });
  return c;
}

/// Los contratos y los niveles reales, listos para añadir los casos.
List<Archivo> baseDelCurso({Doc? sesion, Doc? escalon, Doc? ubicacion, Doc? niveles}) => [
      leerMapa('formatos/gravity-sesion-60.yaml', sesion ?? contratoSesionConPruebas()),
      leerMapa('formatos/gravity-escalon.yaml', escalon ?? contratoReal('gravity-escalon')),
      leerMapa('formatos/gravity-ubicacion.yaml', ubicacion ?? contratoReal('gravity-ubicacion')),
      leerMapa('niveles.yaml', niveles ?? nivelesReales()),
    ];

/// Valida los casos con los contratos y niveles reales (o los que se pasen).
List<Hallazgo> correrCurso(List<Doc> docs, {Doc? sesion, Doc? escalon, Doc? ubicacion, Doc? niveles}) {
  final archivos = <Archivo>[
    ...baseDelCurso(sesion: sesion, escalon: escalon, ubicacion: ubicacion, niveles: niveles),
    for (var i = 0; i < docs.length; i++) leerMapa('doc$i.yaml', clonar(docs[i])),
  ];
  return validarArchivos(archivos).hallazgos;
}

/// Hallazgos de un código en el archivo de un contrato o de niveles.
List<Hallazgo> deArchivo(List<Hallazgo> h, String codigo, String archivo) =>
    h.where((x) => x.codigo == codigo && x.archivo == archivo).toList();

// ----------------------------------------------------------------- textos

/// `n` palabras que no se repiten en ningún otro texto de las pruebas (por el
/// sello), para que V19 no vea duplicados.
String palabras(String sello, int n) => [for (var i = 0; i < n; i++) '${sello}w$i'].join(' ');

const String _razon = 'La razón explica la respuesta con palabras suficientes.';

String slug(String escalon) => escalon.toLowerCase().replaceAll('.', '');

const List<String> _dias3 = ['lun', 'mar', 'mie', 'jue', 'vie'];
const List<String> _dias = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes'];

String _nn(int n) => n.toString().padLeft(2, '0');

// ------------------------------------------------------------- preguntas

/// Una pregunta de opción múltiple de tres opciones, con la correcta (la
/// primera) más corta que las demás.
Doc preguntaOM(String id, String habilidad, String sello) => {
      'id': id,
      'tipo': 'opcion_multiple',
      'habilidad': habilidad,
      'enunciado': 'Question about ${palabras(sello, 4)}?',
      'opciones': [
        {'texto': 'ok ${sello}a', 'porque': _razon},
        {'texto': 'a longer wrong option for ${sello}b', 'porque_no': 'No corresponde a lo que se pregunta.'},
        {'texto': 'another longer wrong option for ${sello}c', 'porque_no': 'Cambia el sentido de la frase.'},
      ],
    };

Doc preguntaCorta(String id, String habilidad, String sello) => {
      'id': id,
      'tipo': 'respuesta_corta',
      'habilidad': habilidad,
      'enunciado': 'Complete ${palabras(sello, 3)} ___ now.',
      'aceptadas': ['x$sello'],
      'porque': _razon,
    };

// -------------------------------------------------------- unidades sueltas

Doc _unidad(String id, String parte, Map<String, Object?> estimulo, List<Doc> preguntas, {String estado = 'borrador'}) => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'unidad',
      'id': id,
      'estado': estado,
      'formato': 'gravity-sesion-60',
      'parte': parte,
      'nivel': 'A2',
      'variante': 'en-US',
      'origen': 'nuevo',
      'temas': ['gram.presente_continuo'],
      'estimulo': estimulo,
      'preguntas': preguntas,
    };

/// Un audio de traslado de la semana: el A es un monólogo (una voz) y el B, un
/// diálogo (dos voces). Cada uno de [palabrasDelAudio] palabras (rango de A2:
/// 120 a 200).
Doc audioDeTraslado(String id, {bool dialogo = false, int palabrasDelAudio = 160, int reproducciones = 2}) {
  final mitad = palabrasDelAudio ~/ 2;
  return _unidad(
    id,
    'traslado-audio',
    {
      'tipo': 'audio',
      'reproducciones': reproducciones,
      'guion': dialogo
          ? [
              {'voz': 'F1', 'texto': palabras('${id}f', mitad)},
              {'voz': 'M1', 'texto': palabras('${id}m', palabrasDelAudio - mitad)},
            ]
          : [
              {'voz': 'M1', 'texto': palabras('${id}m', palabrasDelAudio)},
            ],
    },
    [],
  );
}

// ---------------------------------------------------------------- sesiones

/// Un turno de la conversación guiada de la persona.
Doc turnoPersona(String sello, {int variantes = 2, bool claves = true}) => {
      'rol': 'persona',
      'guia': 'Pide algo en español ${palabras(sello, 2)}.',
      'modelo': ['I would like ${palabras(sello, 2)}.'],
      'variantes': [for (var i = 0; i < variantes; i++) 'Can I have ${palabras('${sello}v$i', 2)}?'],
      if (claves) 'palabras_clave': ['${sello}w0'],
    };

Doc turnoSistema(String sello) => {'rol': 'sistema', 'en': 'Hello ${palabras(sello, 3)}.', 'es': 'Hola.'};

/// Las preguntas de la lección del lunes: diez de opción múltiple y cuatro de
/// respuesta corta (lo que hace falta para llegar al 70 % del bloque).
List<Doc> _preguntasLeccion(String id) => [
      for (var i = 0; i < 10; i++) preguntaOM('$id-${_nn(i + 1)}', 'gramatica', '${slug(id)}om$i'),
      for (var i = 0; i < 4; i++) preguntaCorta('$id-c${_nn(i + 1)}', 'gramatica', '${slug(id)}rc$i'),
    ];

Doc _tarea(String id, String modalidad) => {
      'id': '$id-prod',
      'tipo': 'produccion',
      'habilidad': modalidad == 'habla' ? 'habla' : 'escritura',
      'modalidad': modalidad,
      'consigna': 'Write about ${palabras('${slug(id)}prod', 5)}.',
      'extension': {'min': 50, 'max': 80, 'unidad': modalidad == 'habla' ? 'segundos' : 'palabras'},
      'puntos_obligatorios': ['Un punto obligatorio.'],
      'cotejo': ['Usé lo que pide la tarea.'],
      'modelo': 'A model ${palabras('${slug(id)}modelo', 6)}.',
    };

/// Una sesión completa y buena del curso (A2.1) con sus audios y, el viernes,
/// las formas a las que remite. Devuelve todos los documentos.
///
/// `dia` es uno de lunes a viernes. En los viernes de las semanas 2, 4, 6 y 7 la
/// lección es la prueba por unidad; en los demás, la conversación guiada; y en
/// la semana 8 no hay mini prueba.
List<Doc> sesionDelCurso({String dia = 'lunes', int semana = 1, String escalon = 'A2.1', int turnosDePersona = 8}) {
  final esc = slug(escalon);
  final id = 's-$esc-s${_nn(semana)}-${_dias3[_dias.indexOf(dia)]}';
  final audioA = 'au-$esc-s${_nn(semana)}-a';
  final audioB = 'au-$esc-s${_nn(semana)}-b';
  final docs = <Doc>[];
  final viernes = dia == 'viernes';
  final unidadPU = const {2: 1, 4: 2, 6: 3, 7: 4}[semana];
  final bloques = <Doc>[];

  // Repaso o mini prueba.
  if (viernes && semana <= 7) {
    final mini = 'mini-$esc-s${_nn(semana)}';
    bloques.add({'tipo': 'mini_prueba', 'minutos': 5, 'forma': mini});
    docs.addAll(formaMini(escalon, semana));
  } else {
    bloques.add({'tipo': 'repaso', 'minutos': 5});
  }

  // Lección o lo que la sustituye.
  if (viernes) {
    if (unidadPU != null) {
      bloques.add({'tipo': 'prueba_unidad', 'minutos': 10, 'forma': 'pu-$esc-u$unidadPU-a', 'repeticion': 'pu-$esc-u$unidadPU-b'});
      docs.addAll(formaPruebaUnidad(escalon, unidadPU, 'a'));
      docs.addAll(formaPruebaUnidad(escalon, unidadPU, 'b'));
    } else {
      bloques.add({
        'tipo': 'conversacion_guiada',
        'minutos': 10,
        'situacion': 'Pedir un café y preguntar por el precio',
        'turnos': [
          for (var i = 0; i < turnosDePersona; i++) ...[turnoSistema('$id-s$i'), turnoPersona('$id-p$i')],
        ],
      });
    }
  } else {
    bloques.add({
      'tipo': 'leccion',
      'minutos': 10,
      'explicacion': 'Explicación breve en español. ${palabras('$id-expl', 90)}',
      'ejemplos': [
        for (var i = 0; i < 6; i++) {'en': 'Example ${palabras('$id-e$i', 3)}.', 'es': 'Ejemplo $i.'},
      ],
      'error_comun': {'mal': 'I am knowing it.', 'bien': 'I know it.', 'porque': 'Verbo de estado, no va en continuo.'},
      'preguntas': _preguntasLeccion(id),
    });
  }

  bloques.addAll([
    {
      'tipo': 'pronunciacion',
      'minutos': 8,
      'foco': 'final -s',
      'elementos': [
        for (var i = 0; i < 14; i++) {'texto': 'Sound ${palabras('$id-pr$i', 2)}.', 'nota': 'Nota del sonido.'},
      ],
    },
    {'tipo': 'produccion', 'minutos': 12, 'tarea': _tarea(id, dia == 'viernes' ? 'habla' : 'escritura')},
    {
      'tipo': 'traslado',
      'minutos': 25,
      'audios': [audioA, audioB],
      'frases': [for (var i = 0; i < 24; i++) 'Phrase ${palabras('$id-f$i', 2)}.'],
    },
  ]);

  final nTarjetas = viernes ? 0 : 8;
  docs.insert(0, {
    'esquema': 'gravity-ingles-v1',
    'tipo': 'sesion',
    'id': id,
    'estado': 'borrador',
    'escalon': escalon,
    'semana': semana,
    'dia': dia,
    'enfoque': dia == 'lunes' ? 'gramatica_vocabulario' : 'escucha',
    'variante': 'en-US',
    'titulo': 'Sesión de prueba',
    'puedo': 'Puedo hacer algo.',
    'temas': ['gram.presente_continuo'],
    'bloques': bloques,
    'tarjetas': [
      for (var i = 0; i < nTarjetas; i++)
        {'id': '$id-t${_nn(i + 1)}', 'en': 'word$i', 'es': 'palabra $i', 'ejemplo': 'This is the word$i in use.'},
    ],
  });
  // Los audios de la semana los comparten las cinco sesiones: una sola vez.
  docs.addAll([audioDeTraslado(audioA), audioDeTraslado(audioB, dialogo: true)]);
  return docs;
}

// ------------------------------------------------------ formas de prueba

Doc _forma(String id, String uso, String escalon, String parte, List<String> unidades, Map<String, Object?> extra) => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'forma',
      'id': id,
      'estado': 'borrador',
      'formato': 'gravity-sesion-60',
      'uso': uso,
      'escalon': escalon,
      'semilla': 2026111701,
      ...extra,
      'secciones': [
        {'parte': parte, 'unidades': unidades},
      ],
    };

/// La mini prueba de la semana: una forma de diez preguntas y su unidad.
List<Doc> formaMini(String escalon, int semana, {int preguntas = 10, String? sello}) {
  final id = 'mini-${slug(escalon)}-s${_nn(semana)}';
  final u = '$id-u';
  final s = sello ?? id;
  return [
    _forma(id, 'mini', escalon, 'mini', [u], {}),
    _unidad(u, 'mini', {'tipo': 'ninguno'}, [
      for (var i = 0; i < preguntas; i++) preguntaOM('$u-${_nn(i + 1)}', i.isEven ? 'gramatica' : 'vocabulario', '${slug(s)}q$i'),
    ]),
  ];
}

/// Una prueba por unidad (variante `a` o `b`) con su composición: 6 de
/// gramática, 4 de vocabulario, 5 de lectura y, con audio, 5 de escucha.
List<Doc> formaPruebaUnidad(String escalon, int unidad, String variante, {bool conAudio = true, String? sello}) {
  final id = 'pu-${slug(escalon)}-u$unidad-$variante';
  final s = slug(sello ?? id);
  final gram = '$id-gram';
  final voc = '$id-voc';
  final lec = '$id-lec';
  final esc = '$id-esc';
  List<Doc> qs(String u, String hab, int n, String sello) => [for (var i = 0; i < n; i++) preguntaOM('$u-${_nn(i + 1)}', hab, '$sello$i')];
  return [
    _forma(id, 'prueba_unidad', escalon, 'prueba-unidad', [gram, voc, lec, if (conAudio) esc], {
      'unidad_del_escalon': unidad,
      'variante': variante,
      'con_audio': conAudio,
    }),
    _unidad(gram, 'prueba-unidad', {'tipo': 'ninguno'}, qs(gram, 'gramatica', 6, '${s}g')),
    _unidad(voc, 'prueba-unidad', {'tipo': 'ninguno'}, qs(voc, 'vocabulario', 4, '${s}v')),
    _unidad(lec, 'prueba-unidad', {'tipo': 'texto', 'texto': palabras('${s}lec', 150)}, qs(lec, 'lectura', 5, '${s}l')),
    if (conAudio)
      _unidad(
        esc,
        'prueba-unidad',
        {
          'tipo': 'audio',
          'reproducciones': 2,
          'guion': [
            {'voz': 'F1', 'texto': palabras('${s}ea', 60)},
            {'voz': 'M1', 'texto': palabras('${s}eb', 60)},
          ],
        },
        qs(esc, 'escucha', 5, '${s}e'),
      ),
  ];
}

/// Los documentos de una forma de prueba por unidad con los hallazgos propios de
/// sus archivos (los que empiezan con `doc`).
Doc formaDe(List<Doc> docs, String id) => docs.firstWhere((d) => d['id'] == id && d['tipo'] == 'forma');
Doc unidadDe(List<Doc> docs, String id) => docs.firstWhere((d) => d['id'] == id && d['tipo'] == 'unidad');
Doc sesionDeLista(List<Doc> docs) => docs.firstWhere((d) => d['tipo'] == 'sesion');

/// Un bloque de la sesión por su tipo.
Doc bloque(Doc sesion, String tipo) => mapa(lista(sesion['bloques']).firstWhere((b) => mapa(b)['tipo'] == tipo));

/// Quita de la lista de hallazgos los que no son de los casos (los de los
/// contratos y niveles reales).
List<Hallazgo> soloDeLosCasos(List<Hallazgo> h) => propios(h);

/// Junta listas de documentos sin repetir los que ya están (los audios de una
/// semana los comparten sus cinco sesiones).
List<Doc> juntar(Iterable<List<Doc>> listas) {
  final vistos = <String>{};
  return [
    for (final l in listas)
      for (final d in l)
        if (vistos.add('${d['tipo']}:${d['id']}')) d,
  ];
}

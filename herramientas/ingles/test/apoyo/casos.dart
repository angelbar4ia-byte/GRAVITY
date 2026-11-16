import 'ayudas.dart';

/// Casos buenos: cada uno pasa todas las comprobaciones sin un solo hallazgo
/// (la prueba "casos_buenos" lo exige). Cada prueba de caso malo parte de uno
/// de estos y cambia un solo dato.

const String _razon = 'La razón cita la evidencia del texto con palabras suficientes.';

Doc _base(String id, String parte, {String estado = 'borrador', String formato = 'prueba-examen'}) => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'unidad',
      'id': id,
      'estado': estado,
      'formato': formato,
      'parte': parte,
      'nivel': 'B1',
      'variante': 'en-GB',
      'origen': 'nuevo',
    };

Doc _opcion(String id, String enunciado, List<String> textos) => {
      'id': id,
      'tipo': 'opcion_multiple',
      'habilidad': 'lectura',
      'foco': 'detalle',
      'enunciado': enunciado,
      'opciones': [
        for (var i = 0; i < textos.length; i++)
          i == 0 ? {'texto': textos[i], 'porque': _razon} : {'texto': textos[i], 'porque_no': 'No aparece en el texto.'},
      ],
    };

/// Lectura con dos preguntas de cuatro opciones (parte `p-om`).
Doc opcionMultiple() => {
      ..._base('t-om-0001', 'p-om'),
      'estimulo': {'tipo': 'texto', 'titulo': 'Un texto', 'texto': 'Elena sold her old car last year because the repairs were too expensive.'},
      'preguntas': [
        _opcion('t-om-0001-a', 'Why did Elena sell her car?', ['Repairs cost too much.', 'She moved abroad.', 'She disliked driving.', 'It was stolen.']),
        _opcion('t-om-0001-b', 'When did she sell it?', ['Last year.', 'Last month.', 'Last week.', 'Yesterday.']),
      ],
    };

/// Ocho preguntas de cuatro opciones (parte `p-om8`). La correcta es la más
/// larga en `masLargas` de las ocho.
Doc ochoPreguntas({int masLargas = 1}) => {
      ..._base('t-om8-0001', 'p-om8'),
      'estimulo': {'tipo': 'texto', 'texto': 'A long text with eight questions about its content.'},
      'preguntas': [
        for (var i = 0; i < 8; i++)
          _opcion(
            't-om8-0001-$i',
            'Question $i?',
            i < masLargas
                ? ['an answer much longer than any other', 'short one', 'short two', 'short three']
                : ['short', 'a distractor that is quite a bit longer', 'another distractor that is quite a bit longer', 'a third long distractor'],
          ),
      ],
    };

/// Cloze de opciones con dos huecos (parte `p-ho`).
Doc huecoOpciones() => {
      ..._base('t-ho-0001', 'p-ho'),
      'estimulo': {'tipo': 'texto', 'texto': 'She {1} to the market and bought {2} apples.'},
      'preguntas': [
        {
          'id': 't-ho-0001-1',
          'tipo': 'hueco_opciones',
          'habilidad': 'gramatica',
          'hueco': 1,
          'opciones': [
            {'texto': 'went', 'porque': 'Pasado simple con el tiempo del relato.'},
            {'texto': 'goes', 'porque_no': 'Presente.'},
            {'texto': 'going', 'porque_no': 'Sin auxiliar.'},
            {'texto': 'gone', 'porque_no': 'Participio.'},
          ],
        },
        {
          'id': 't-ho-0001-2',
          'tipo': 'hueco_opciones',
          'habilidad': 'gramatica',
          'hueco': 2,
          'opciones': [
            {'texto': 'some', 'porque': 'Cuantificador que va con un plural en afirmativa.'},
            {'texto': 'a', 'porque_no': 'No va con plural.'},
            {'texto': 'an', 'porque_no': 'No va con plural.'},
            {'texto': 'much', 'porque_no': 'No va con contables.'},
          ],
        },
      ],
    };

/// Cloze abierto con dos huecos gramaticales (parte `p-ha`).
Doc huecoAbierto() => {
      ..._base('t-ha-0001', 'p-ha'),
      'estimulo': {'tipo': 'texto', 'texto': 'The man {1} lives next door works at a bank {2} the river.'},
      'preguntas': [
        {
          'id': 't-ha-0001-1',
          'tipo': 'hueco_abierto',
          'habilidad': 'gramatica',
          'hueco': 1,
          'clase': 'gramatical',
          'aceptadas': ['who', 'that'],
          'porque': 'Pronombre relativo de persona, sujeto de lives.',
        },
        {
          'id': 't-ha-0001-2',
          'tipo': 'hueco_abierto',
          'habilidad': 'gramatica',
          'hueco': 2,
          'clase': 'gramatical',
          'aceptadas': ['near', 'by', 'beside'],
          'porque': 'Preposición de lugar que sigue a un sustantivo.',
        },
      ],
    };

/// Formación de palabras con dos huecos (parte `p-fp`).
Doc formacionPalabra() => {
      ..._base('t-fp-0001', 'p-fp'),
      'estimulo': {'tipo': 'texto', 'texto': 'The road was {1} and the weather was {2}.'},
      'preguntas': [
        {
          'id': 't-fp-0001-1',
          'tipo': 'formacion_palabra',
          'habilidad': 'vocabulario',
          'hueco': 1,
          'base': 'DANGER',
          'aceptadas': ['dangerous'],
          'porque': 'Hace falta un adjetivo después de was.',
        },
        {
          'id': 't-fp-0001-2',
          'tipo': 'formacion_palabra',
          'habilidad': 'vocabulario',
          'hueco': 2,
          'base': 'PLEASE',
          'aceptadas': ['unpleasant'],
          'porque': 'Adjetivo negativo que describe el mal tiempo.',
        },
      ],
    };

/// Transformación con palabra clave (parte `p-tr`).
Doc transformacion() => {
      ..._base('t-tr-0001', 'p-tr'),
      'estimulo': {'tipo': 'ninguno'},
      'preguntas': [
        {
          'id': 't-tr-0001-1',
          'tipo': 'transformacion',
          'habilidad': 'gramatica',
          'original': 'I have never read a better book than this one.',
          'clave': 'BEST',
          'antes': 'This is',
          'despues': 'ever read.',
          'aceptadas': ['the best book I have', "the best book I've"],
          'porque': 'Superlativo con presente perfecto y la palabra clave.',
        },
      ],
    };

/// Oraciones omitidas: tres colocadas y una sobrante (parte `p-oo`).
Doc oracionOmitida() => {
      ..._base('t-oo-0001', 'p-oo'),
      'estimulo': {'tipo': 'texto', 'texto': 'First paragraph. {1} Second paragraph. {2} Third paragraph. {3} End.'},
      'preguntas': [
        {
          'id': 't-oo-0001-a',
          'tipo': 'oracion_omitida',
          'habilidad': 'lectura',
          'porque': 'Cada oración se ata por lo que retoma y por lo que prepara.',
          'oraciones': [
            {'texto': 'One.', 'hueco': 1, 'ancla': 'Retoma la primera idea del párrafo anterior.'},
            {'texto': 'Two.', 'hueco': 2, 'ancla': 'Su pronombre se refiere al párrafo anterior.'},
            {'texto': 'Three.', 'hueco': 3, 'ancla': 'Prepara la cifra de la oración siguiente.'},
            {'texto': 'Four.', 'sobrante': true, 'porque_no': 'Contradice lo que dice el texto en su primer párrafo.'},
          ],
        },
      ],
    };

/// Correspondencia con cuatro textos y cuatro preguntas (parte `p-co`).
Doc correspondencia() => {
      ..._base('t-co-0001', 'p-co'),
      'estimulo': {'tipo': 'texto', 'texto': 'Cuatro secciones A, B, C y D.'},
      'textos': [
        {'id': 'A', 'texto': 'Sección A'},
        {'id': 'B', 'texto': 'Sección B'},
        {'id': 'C', 'texto': 'Sección C'},
        {'id': 'D', 'texto': 'Sección D'},
      ],
      'preguntas': [
        for (final (i, r) in [(1, 'A'), (2, 'B'), (3, 'C'), (4, 'D')])
          {
            'id': 't-co-0001-$i',
            'tipo': 'correspondencia',
            'habilidad': 'lectura',
            'enunciado': 'Which section says something about topic $i?',
            'respuesta': r,
            'evidencia': 'La sección $r habla de este tema de forma explícita.',
            'porque': 'Solo esa sección trata el tema con tantas palabras.',
          },
      ],
    };

/// Emparejar con cinco opciones y tres preguntas (parte `p-em`).
Doc emparejar() => {
      ..._base('t-em-0001', 'p-em'),
      'estimulo': {'tipo': 'texto', 'texto': 'Tres personas y cinco textos.'},
      'opciones': [
        {'id': 'A', 'texto': 'Text A'},
        {'id': 'B', 'texto': 'Text B'},
        {'id': 'C', 'texto': 'Text C'},
        {'id': 'D', 'texto': 'Text D', 'porque_no': 'Ninguna persona busca lo que ofrece.'},
        {'id': 'E', 'texto': 'Text E', 'porque_no': 'Ofrece lo contrario de lo que se pide.'},
      ],
      'preguntas': [
        for (final (i, r) in [(1, 'A'), (2, 'B'), (3, 'C')])
          {
            'id': 't-em-0001-$i',
            'tipo': 'emparejar',
            'habilidad': 'lectura',
            'elemento': 'Persona $i',
            'respuesta': r,
            'evidencia': 'El texto $r ofrece justo lo que busca la persona.',
            'porque': 'Es el único texto que cumple todas sus condiciones.',
          },
      ],
    };

/// Notas al escuchar, con audio (parte `p-cn`).
Doc completarNota() => {
      ..._base('t-cn-0001', 'p-cn'),
      'estimulo': {
        'tipo': 'audio',
        'reproducciones': 2,
        'guion': [
          {'voz': 'F1', 'texto': 'The class starts at nine and finishes at noon.'},
          {'voz': 'M1', 'texto': 'Thanks. I will bring my laptop.'},
        ],
      },
      'preguntas': [
        {
          'id': 't-cn-0001-1',
          'tipo': 'completar_nota',
          'habilidad': 'escucha',
          'hueco': 1,
          'aceptadas': ['nine', '9'],
          'porque': 'La mujer dice a qué hora empieza la clase.',
        },
        {
          'id': 't-cn-0001-2',
          'tipo': 'completar_nota',
          'habilidad': 'escucha',
          'hueco': 2,
          'aceptadas': ['laptop'],
          'porque': 'El hombre dice qué va a traer a la clase.',
        },
      ],
    };

/// Completar palabras (parte `p-cp`): cada hueco oculta la segunda mitad.
Doc completarPalabras({String parte = 'p-cp'}) => {
      ..._base('t-cp-0001', parte),
      'nivel': 'B1',
      'variante': 'en-US',
      'estimulo': {
        'tipo': 'texto',
        'texto': 'Every year, a tree adds a new la{yer} of wood under its bark, and the tree '
            'can be se{en} as rings when people cut it down in the cold winter months.',
      },
      'preguntas': [
        {
          'id': 't-cp-0001-a',
          'tipo': 'completar_palabras',
          'habilidad': 'lectura',
          'porque': 'Cada palabra se deduce de su oración y del número de casillas.',
          'pistas': [
            {'palabra': 'layer', 'porque': 'Sustantivo tras new.'},
            {'palabra': 'seen', 'porque': 'Participio tras can be.'},
          ],
        },
      ],
    };

/// Una sesión mínima de curso: una lección con una pregunta y una tarea.
Doc sesion() => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'sesion',
      'id': 't-s01-lun',
      'estado': 'borrador',
      'escalon': 'B1.1',
      'semana': 1,
      'dia': 'lunes',
      'enfoque': 'gramatica_vocabulario',
      'titulo': 'Siempre o solo por ahora',
      'puedo': 'Puedo contar mi rutina.',
      'temas': ['gram.presente_simple_vs_continuo'],
      'bloques': [
        {'tipo': 'repaso', 'minutos': 5},
        {
          'tipo': 'leccion',
          'minutos': 10,
          'explicacion': 'Dos presentes distintos.',
          'ejemplos': [
            {'en': 'I take the bus.', 'es': 'Tomo el autobús.'},
          ],
          'error_comun': {'mal': "I'm knowing it.", 'bien': 'I know it.', 'porque': 'Verbo de estado.'},
          'preguntas': [
            {
              'id': 't-s01-lun-01',
              'tipo': 'opcion_multiple',
              'habilidad': 'gramatica',
              'enunciado': 'Marta ___ in a bank, but this month she ___ from home.',
              'opciones': [
                {'texto': 'works / is working', 'porque': 'Lo permanente va en simple y lo temporal en continuo.'},
                {'texto': 'is working / works', 'porque_no': 'Invierte los usos.'},
                {'texto': 'works / works', 'porque_no': 'This month pide el continuo.'},
              ],
            },
          ],
        },
        {
          'tipo': 'produccion',
          'minutos': 12,
          'tarea': {
            'id': 't-s01-lun-prod',
            'tipo': 'produccion',
            'habilidad': 'escritura',
            'modalidad': 'escritura',
            'consigna': 'Write 80 words about your routine.',
            'extension': {'min': 80, 'max': 100, 'unidad': 'palabras'},
            'puntos_obligatorios': ['Tu rutina normal.'],
            'cotejo': ['Usé presente simple.'],
            'modelo': 'I work nights.',
          },
        },
        {
          'tipo': 'traslado',
          'minutos': 25,
          'audios': ['t-cn-0001'],
          'frases': ['Normally, my days are all the same.'],
        },
      ],
      'tarjetas': [
        {'id': 't-s01-tarjeta-0001', 'en': 'at the moment', 'es': 'en este momento', 'ejemplo': 'At the moment, I am working.'},
      ],
    };

/// Las otras cinco clases de pregunta (ordenar, respuesta corta, repetir,
/// pronunciación y producción) en una unidad suelta (parte `p-om`, sin
/// preguntas de opciones, solo para probar la lectura y V04 y V12).
Doc variadas() => {
      ..._base('t-var-0001', 'p-om'),
      'estimulo': {'tipo': 'ninguno'},
      'preguntas': [
        {
          'id': 't-var-0001-a',
          'tipo': 'ordenar_palabras',
          'habilidad': 'gramatica',
          'palabras': ['do', 'you', 'work', 'here'],
          'aceptadas': ['do you work here'],
          'porque': 'La pregunta en presente simple empieza con el auxiliar.',
        },
        {
          'id': 't-var-0001-b',
          'tipo': 'respuesta_corta',
          'habilidad': 'gramatica',
          'enunciado': 'My brother ___ (speak) three languages.',
          'aceptadas': ['speaks'],
          'porque': 'Hecho permanente con he: presente simple con -s.',
        },
        {
          'id': 't-var-0001-c',
          'tipo': 'repetir',
          'habilidad': 'pronunciacion',
          'frases': ['Normally, my days are all the same.'],
        },
        {
          'id': 't-var-0001-d',
          'tipo': 'pronunciacion',
          'habilidad': 'pronunciacion',
          'foco': 'final -s: /s/, /z/, /ɪz/',
          'elementos': [
            {'texto': 'works', 'nota': 'Termina en /s/.'},
          ],
        },
        {
          'id': 't-var-0001-e',
          'tipo': 'produccion',
          'habilidad': 'escritura',
          'modalidad': 'escritura',
          'consigna': 'Write 80 words about your routine.',
          'extension': {'min': 80, 'max': 100, 'unidad': 'palabras'},
          'puntos_obligatorios': ['Tu rutina normal.'],
          'cotejo': ['Usé presente simple.'],
          'modelo': 'I work nights.',
        },
      ],
    };

/// La sesión con el audio al que remite, listos para validarse juntos.
List<Doc> sesionConAudio() => [sesion(), completarNota()];

/// Un archivo `forma` con una sola sección.
Doc forma({String unidad = 't-om-0001'}) => {
      'esquema': 'gravity-ingles-v1',
      'tipo': 'forma',
      'id': 't-forma-a',
      'estado': 'borrador',
      'formato': 'prueba-examen',
      'uso': 'practica',
      'semilla': 2026111501,
      'secciones': [
        {
          'parte': 'p-om',
          'unidades': [unidad],
        },
      ],
    };

/// Contenido inicial del catálogo (PG-01: datos Dart del dominio).
///
/// **Todo nace `borrador` (PG-25):** el contenido lo redacta una IA y no lo
/// ha validado un profesional. Lo marcado «confirmar» no entra a ningún
/// cálculo (CA-G-04). Sin diagnósticos, tratamientos ni dosis (CA-G-03).
library;

import 'tipos.dart';

/// Versión del catálogo; cada serie guardada anota la de su sesión.
const versionCatalogo = 1;

const _b = RevisionContenido.borrador;

const _marcy = 'marcy_mwm7119';

const _items = <ItemEquipo>[
  ItemEquipo(
    id: _marcy,
    nombre: 'Estación multifuncional Marcy MWM-7119',
    tipo: TipoItem.aparato,
    estado: EstadoDato.delDiseno,
    carga: TipoCarga.pila,
  ),
  ItemEquipo(
    id: 'marcy.press',
    nombre: 'Brazos de press',
    tipo: TipoItem.puesto,
    estado: EstadoDato.delDiseno,
    padre: _marcy,
    carga: TipoCarga.pila,
  ),
  ItemEquipo(
    id: 'marcy.polea_alta',
    nombre: 'Polea alta',
    tipo: TipoItem.puesto,
    estado: EstadoDato.delDiseno,
    padre: _marcy,
    carga: TipoCarga.pila,
  ),
  ItemEquipo(
    id: 'marcy.polea_baja',
    nombre: 'Polea baja',
    tipo: TipoItem.puesto,
    estado: EstadoDato.delDiseno,
    padre: _marcy,
    carga: TipoCarga.pila,
  ),
  ItemEquipo(
    id: 'marcy.cojin_curl',
    nombre: 'Cojín de curl de bíceps',
    tipo: TipoItem.puesto,
    estado: EstadoDato.delDiseno,
    padre: _marcy,
    carga: TipoCarga.pila,
  ),
  ItemEquipo(
    id: 'marcy.otros',
    nombre: 'Otros puestos (por confirmar en el aparato)',
    tipo: TipoItem.puesto,
    estado: EstadoDato.confirmar,
    padre: _marcy,
  ),
  ItemEquipo(
    id: 'banco_inclinado',
    nombre: 'Banco inclinado',
    tipo: TipoItem.aparato,
    estado: EstadoDato.delDiseno,
    carga: TipoCarga.pesoCorporal,
  ),
  ItemEquipo(
    id: 'caminadora',
    nombre: 'Caminadora',
    tipo: TipoItem.aparato,
    estado: EstadoDato.delDiseno,
  ),
  ItemEquipo(
    id: 'bandas',
    nombre: 'Bandas de resistencia',
    tipo: TipoItem.aparato,
    estado: EstadoDato.confirmado,
    carga: TipoCarga.banda,
  ),
  ItemEquipo(
    id: 'ancla_puerta',
    nombre: 'Ancla de puerta para bandas',
    tipo: TipoItem.accesorio,
    estado: EstadoDato.confirmar,
  ),
  ItemEquipo(
    id: 'colchoneta',
    nombre: 'Colchoneta',
    tipo: TipoItem.accesorio,
    estado: EstadoDato.confirmar,
  ),
  ItemEquipo(
    id: 'tobillera_polea',
    nombre: 'Correa o tobillera para la polea',
    tipo: TipoItem.accesorio,
    estado: EstadoDato.confirmar,
  ),
  // Equipo futuro: solo dato (decisión del dueño, 23/nov/2026).
  ItemEquipo(
    id: 'mancuernas',
    nombre: 'Mancuernas',
    tipo: TipoItem.aparato,
    estado: EstadoDato.confirmar,
    soloDato: true,
  ),
];

const _datosAparato = <DatoAparato>[
  DatoAparato(
    id: 'pila_kg_aprox',
    nombre: 'Pila del Marcy (aprox., según el distribuidor)',
    estado: EstadoDato.delDiseno,
    valor: 68,
    unidad: 'kg',
  ),
  DatoAparato(
    id: 'pasos_max',
    nombre: 'Número de pasos (placas) de la pila',
    estado: EstadoDato.confirmar,
  ),
  DatoAparato(
    id: 'kg_por_paso_x10',
    nombre: 'Cuántos kg es un paso (kg por 10)',
    estado: EstadoDato.confirmar,
  ),
  DatoAparato(
    id: 'relacion_polea',
    nombre: 'Relación de la polea (1 para 1:1, 2 para 2:1)',
    estado: EstadoDato.confirmar,
  ),
  DatoAparato(
    id: 'puestos_adicionales',
    nombre: 'Puestos adicionales del Marcy',
    estado: EstadoDato.confirmar,
  ),
  DatoAparato(
    id: 'anclaje_estacion',
    nombre: 'Punto de anclaje seguro para bandas en la estación',
    estado: EstadoDato.confirmar,
  ),
  DatoAparato(
    id: 'banco_plano',
    nombre: 'El banco se ajusta a plano',
    estado: EstadoDato.confirmar,
  ),
  DatoAparato(
    id: 'capacidad_banco_kg',
    nombre: 'Carga máxima que soporta el banco',
    estado: EstadoDato.confirmar,
    unidad: 'kg',
  ),
];

const _ejercicios = <Ejercicio>[
  Ejercicio(
    id: 'press_pecho',
    nombre: 'Press de pecho',
    patron: 'empuje_horizontal',
    gruposPrimarios: [Grupos.pecho, Grupos.hombro, Grupos.triceps],
    zonas: [Zonas.hombro, Zonas.codo],
    explicacion:
        'Empuja al frente con la espalda apoyada y los codos a la '
        'altura del pecho. Sube con control y baja despacio sin soltar la '
        'carga de golpe.',
    errores: [
      'Encoger los hombros hacia las orejas.',
      'Soltar la carga de golpe al volver.',
    ],
    repsMin: 10,
    repsMax: 12,
    variantes: [
      Variante(
        id: 'press_pecho_estacion',
        nombre: 'Press de pecho en la estación',
        requiere: ['marcy.press'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'press_pecho_banda_puerta',
        nombre: 'Press de pecho con banda (ancla de puerta)',
        requiere: ['bandas'],
        ancla: Ancla.puerta,
        carga: TipoCarga.banda,
        nivel: 1,
        revision: _b,
      ),
      Variante(
        id: 'press_pecho_banda_estacion',
        nombre: 'Press de pecho con banda (ancla en la estación)',
        requiere: ['bandas'],
        ancla: Ancla.estacion,
        carga: TipoCarga.banda,
        nivel: 1,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'flexion_inclinada',
    nombre: 'Flexiones inclinadas',
    patron: 'empuje_horizontal',
    gruposPrimarios: [Grupos.pecho, Grupos.hombro, Grupos.triceps],
    zonas: [Zonas.hombro, Zonas.codo, Zonas.muneca],
    explicacion:
        'Manos en el banco, cuerpo en línea recta de la cabeza a los '
        'talones. Baja el pecho hacia el banco y empuja para volver.',
    errores: ['Dejar caer la cadera.', 'Abrir los codos hacia los lados.'],
    repsMin: 8,
    repsMax: 12,
    progresion: TipoProgresion.repeticiones,
    variantes: [
      Variante(
        id: 'flexion_inclinada_banco',
        nombre: 'Flexiones inclinadas con las manos en el banco',
        requiere: ['banco_inclinado'],
        carga: TipoCarga.pesoCorporal,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'elevacion_lateral',
    nombre: 'Elevaciones laterales',
    patron: 'empuje_hombro',
    gruposPrimarios: [Grupos.hombro],
    zonas: [Zonas.hombro, Zonas.cuello],
    explicacion:
        'Con el codo ligeramente flexionado, sube el brazo a un lado '
        'hasta la altura del hombro y baja despacio.',
    errores: [
      'Subir más allá de la altura del hombro.',
      'Balancear el tronco para ayudarte.',
    ],
    repsMin: 12,
    repsMax: 15,
    variantes: [
      Variante(
        id: 'elevacion_lateral_polea_baja',
        nombre: 'Elevaciones laterales en polea baja',
        requiere: ['marcy.polea_baja'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'elevacion_lateral_banda',
        nombre: 'Elevaciones laterales con banda pisada',
        requiere: ['bandas'],
        ancla: Ancla.pisar,
        carga: TipoCarga.banda,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'extension_triceps',
    nombre: 'Extensión de tríceps',
    patron: 'extension_codo',
    gruposPrimarios: [Grupos.triceps],
    zonas: [Zonas.codo, Zonas.hombro],
    explicacion:
        'Con los codos pegados al cuerpo, estira los brazos hacia '
        'abajo y vuelve despacio sin mover los hombros.',
    errores: [
      'Separar los codos del cuerpo.',
      'Usar el peso del tronco para empujar.',
    ],
    repsMin: 10,
    repsMax: 14,
    variantes: [
      Variante(
        id: 'extension_triceps_polea_alta',
        nombre: 'Extensión de tríceps en polea alta',
        requiere: ['marcy.polea_alta'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'extension_triceps_banda_puerta',
        nombre: 'Extensión de tríceps con banda anclada arriba (puerta)',
        requiere: ['bandas'],
        ancla: Ancla.puerta,
        carga: TipoCarga.banda,
        revision: _b,
      ),
      Variante(
        id: 'extension_triceps_banda_estacion',
        nombre: 'Extensión de tríceps con banda anclada arriba (estación)',
        requiere: ['bandas'],
        ancla: Ancla.estacion,
        carga: TipoCarga.banda,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'fondos_banco',
    nombre: 'Fondos en banco',
    patron: 'extension_codo',
    gruposPrimarios: [Grupos.triceps, Grupos.pecho, Grupos.hombro],
    zonas: [Zonas.hombro, Zonas.codo, Zonas.muneca],
    explicacion:
        'Con las manos en el borde del banco, baja el cuerpo '
        'doblando los codos hacia atrás y empuja para subir. Revisa que el '
        'banco esté firme.',
    errores: [
      'Bajar más de lo que tu hombro cómodamente permite.',
      'Despegar la espalda del banco.',
    ],
    repsMin: 8,
    repsMax: 12,
    progresion: TipoProgresion.repeticiones,
    variantes: [
      Variante(
        id: 'fondos_banco_piernas',
        nombre: 'Fondos en banco con peso corporal',
        requiere: ['banco_inclinado'],
        carga: TipoCarga.pesoCorporal,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'fondos_banco_rodillas',
        nombre: 'Fondos en banco con rodillas flexionadas',
        requiere: ['banco_inclinado'],
        carga: TipoCarga.pesoCorporal,
        nivel: 1,
        masDificil: 'fondos_banco_piernas',
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'jalon_pecho',
    nombre: 'Jalón al pecho',
    patron: 'jalon_vertical',
    gruposPrimarios: [Grupos.espalda, Grupos.biceps],
    zonas: [Zonas.hombro, Zonas.codo, Zonas.espaldaAlta],
    explicacion:
        'Tira hacia el pecho llevando los codos hacia abajo y atrás. '
        'Vuelve arriba con control sin dejar que la carga te jale.',
    errores: [
      'Echar el tronco muy hacia atrás.',
      'Jalar con el cuello hacia adelante.',
    ],
    repsMin: 10,
    repsMax: 12,
    variantes: [
      Variante(
        id: 'jalon_polea_alta',
        nombre: 'Jalón al pecho en polea alta',
        requiere: ['marcy.polea_alta'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'jalon_banda_puerta',
        nombre: 'Jalón con banda anclada arriba (puerta)',
        requiere: ['bandas'],
        ancla: Ancla.puerta,
        carga: TipoCarga.banda,
        revision: _b,
      ),
      Variante(
        id: 'jalon_banda_estacion',
        nombre: 'Jalón con banda anclada arriba (estación)',
        requiere: ['bandas'],
        ancla: Ancla.estacion,
        carga: TipoCarga.banda,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'remo_sentado',
    nombre: 'Remo sentado',
    patron: 'remo',
    gruposPrimarios: [Grupos.espalda, Grupos.biceps],
    zonas: [Zonas.espaldaAlta, Zonas.espaldaBaja, Zonas.codo],
    explicacion:
        'Sentado con la espalda recta, tira de las manos hacia el '
        'abdomen juntando los omóplatos. Vuelve despacio.',
    errores: [
      'Redondear la espalda al estirar.',
      'Balancear el tronco para jalar.',
    ],
    repsMin: 10,
    repsMax: 12,
    variantes: [
      Variante(
        id: 'remo_polea_baja',
        nombre: 'Remo sentado en polea baja',
        requiere: ['marcy.polea_baja'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'remo_banda_pisada',
        nombre: 'Remo con banda pisada',
        requiere: ['bandas'],
        ancla: Ancla.pisar,
        carga: TipoCarga.banda,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'face_pull',
    nombre: 'Face pull',
    patron: 'remo',
    gruposPrimarios: [Grupos.hombro, Grupos.espalda],
    zonas: [Zonas.hombro, Zonas.cuello, Zonas.espaldaAlta],
    explicacion:
        'Tira de la cuerda o la banda hacia el rostro abriendo los '
        'codos a los lados. Aprieta atrás un instante y vuelve despacio.',
    errores: [
      'Usar demasiada carga y mover el tronco.',
      'Subir los hombros hacia las orejas.',
    ],
    repsMin: 12,
    repsMax: 15,
    variantes: [
      Variante(
        id: 'face_pull_polea_alta',
        nombre: 'Face pull en polea alta',
        requiere: ['marcy.polea_alta'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'face_pull_banda_puerta',
        nombre: 'Face pull con banda anclada a la altura del rostro (puerta)',
        requiere: ['bandas'],
        ancla: Ancla.puerta,
        carga: TipoCarga.banda,
        revision: _b,
      ),
      Variante(
        id: 'face_pull_banda_estacion',
        nombre: 'Face pull con banda anclada a la altura del rostro (estación)',
        requiere: ['bandas'],
        ancla: Ancla.estacion,
        carga: TipoCarga.banda,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'curl_biceps',
    nombre: 'Curl de bíceps',
    patron: 'flexion_codo',
    gruposPrimarios: [Grupos.biceps],
    zonas: [Zonas.codo, Zonas.muneca],
    explicacion:
        'Con los codos quietos, lleva las manos hacia los hombros '
        'y baja despacio hasta estirar el brazo.',
    errores: [
      'Balancear el cuerpo para subir la carga.',
      'Despegar los codos del cojín o del cuerpo.',
    ],
    repsMin: 10,
    repsMax: 12,
    variantes: [
      Variante(
        id: 'curl_cojin',
        nombre: 'Curl de bíceps en el cojín',
        requiere: ['marcy.cojin_curl'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'curl_polea_baja',
        nombre: 'Curl de bíceps en polea baja',
        requiere: ['marcy.polea_baja'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'curl_banda',
        nombre: 'Curl de bíceps con banda pisada',
        requiere: ['bandas'],
        ancla: Ancla.pisar,
        carga: TipoCarga.banda,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'sentadilla_banco',
    nombre: 'Sentadilla hacia el banco',
    patron: 'sentadilla',
    gruposPrimarios: [Grupos.cuadriceps, Grupos.gluteo],
    zonas: [Zonas.rodilla, Zonas.cadera, Zonas.espaldaBaja],
    explicacion:
        'Pies al ancho de los hombros. Lleva la cadera atrás y baja '
        'hasta rozar el banco; sube empujando el piso con los talones.',
    errores: [
      'Dejar que las rodillas se vayan hacia adentro.',
      'Dejarse caer sobre el banco.',
    ],
    repsMin: 12,
    repsMax: 15,
    progresion: TipoProgresion.repeticiones,
    variantes: [
      Variante(
        id: 'sentadilla_banco_peso',
        nombre: 'Sentadilla hacia el banco con peso corporal',
        requiere: ['banco_inclinado'],
        carga: TipoCarga.pesoCorporal,
        nivel: 1,
        masDificil: 'sentadilla_banco_banda',
        revision: _b,
      ),
      Variante(
        id: 'sentadilla_banco_banda',
        nombre: 'Sentadilla con banda pisada y sobre los hombros',
        requiere: ['bandas'],
        ancla: Ancla.pisar,
        carga: TipoCarga.banda,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'sentadilla_apoyo',
        nombre: 'Sentadilla sin banco, con apoyo en una pared o ancla',
        carga: TipoCarga.pesoCorporal,
        nivel: 1,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'subida_banco',
    nombre: 'Subidas al banco',
    patron: 'subida',
    gruposPrimarios: [Grupos.cuadriceps, Grupos.gluteo],
    zonas: [Zonas.rodilla, Zonas.cadera, Zonas.tobillo],
    explicacion:
        'Sube al banco con una pierna empujando con el talón y baja '
        'con control. Revisa que el banco esté firme. Repite y cambia de '
        'pierna.',
    errores: [
      'Impulsarte con la pierna de abajo.',
      'Dejar caer el cuerpo al bajar.',
    ],
    repsMin: 8,
    repsMax: 12,
    porLado: true,
    progresion: TipoProgresion.repeticiones,
    variantes: [
      Variante(
        id: 'subida_banco_peso',
        nombre: 'Subidas al banco con peso corporal',
        requiere: ['banco_inclinado'],
        carga: TipoCarga.pesoCorporal,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'puente_gluteo',
    nombre: 'Puente de glúteo',
    patron: 'puente',
    gruposPrimarios: [Grupos.gluteo],
    zonas: [Zonas.cadera, Zonas.espaldaBaja],
    explicacion:
        'Con los pies apoyados, sube la cadera apretando los '
        'glúteos hasta formar una línea del hombro a la rodilla y baja '
        'despacio.',
    errores: [
      'Arquear la espalda baja al subir.',
      'Subir con un impulso brusco.',
    ],
    repsMin: 12,
    repsMax: 15,
    progresion: TipoProgresion.repeticiones,
    variantes: [
      Variante(
        id: 'puente_banco',
        nombre: 'Puente de glúteo con apoyo en el banco',
        requiere: ['banco_inclinado'],
        carga: TipoCarga.pesoCorporal,
        masDificil: 'puente_banda',
        revision: _b,
      ),
      Variante(
        id: 'puente_suelo',
        nombre: 'Puente de glúteo en el suelo con colchoneta',
        requiere: ['colchoneta'],
        carga: TipoCarga.pesoCorporal,
        revision: _b,
      ),
      Variante(
        id: 'puente_banda',
        nombre: 'Puente de glúteo con banda sobre las rodillas',
        requiere: ['bandas'],
        carga: TipoCarga.banda,
        nivel: 2,
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'patada_gluteo',
    nombre: 'Patada de glúteo',
    patron: 'patada',
    gruposPrimarios: [Grupos.gluteo],
    zonas: [Zonas.cadera, Zonas.espaldaBaja],
    explicacion:
        'Lleva una pierna hacia atrás con el glúteo apretado, sin '
        'arquear la espalda, y vuelve despacio. Repite y cambia de pierna.',
    errores: [
      'Arquear la espalda baja para subir más la pierna.',
      'Girar la cadera hacia un lado.',
    ],
    repsMin: 10,
    repsMax: 14,
    porLado: true,
    variantes: [
      Variante(
        id: 'patada_polea',
        nombre: 'Patada de glúteo en polea baja con tobillera',
        requiere: ['marcy.polea_baja', 'tobillera_polea'],
        carga: TipoCarga.pila,
        nivel: 2,
        revision: _b,
      ),
      Variante(
        id: 'patada_banda',
        nombre: 'Patada de glúteo con banda en el tobillo',
        requiere: ['bandas'],
        carga: TipoCarga.banda,
        revision: _b,
      ),
      Variante(
        id: 'patada_cuadrupedia',
        nombre: 'Patada de glúteo en cuadrupedia, sin equipo',
        carga: TipoCarga.pesoCorporal,
        zonas: [Zonas.cadera, Zonas.espaldaBaja, Zonas.rodilla, Zonas.muneca],
        revision: _b,
      ),
    ],
    revision: _b,
  ),
  Ejercicio(
    id: 'plancha',
    nombre: 'Plancha',
    patron: 'plancha',
    gruposPrimarios: [Grupos.core],
    zonas: [Zonas.hombro, Zonas.muneca, Zonas.espaldaBaja],
    explicacion:
        'Apoya antebrazos y puntas de los pies, cuerpo en línea '
        'recta. Aprieta abdomen y glúteos y respira con calma.',
    errores: ['Dejar caer la cadera.', 'Subir la cadera hacia el techo.'],
    segundosMin: 30,
    segundosMax: 45,
    progresion: TipoProgresion.tiempo,
    variantes: [
      Variante(id: 'plancha_suelo', nombre: 'Plancha sin equipo', revision: _b),
    ],
    revision: _b,
  ),
];

const _bloques = <BloqueGuiado>[
  BloqueGuiado(
    id: 'caminata_suave',
    nombre: 'Caminata suave en la caminadora',
    instruccion: 'Camina a paso suave, con una respiración cómoda.',
    requiereCaminadora: true,
    sustitutoSinCaminadora: 'marcha_suave',
    revision: _b,
  ),
  BloqueGuiado(
    id: 'marcha_suave',
    nombre: 'Marcha suave al aire libre o en el lugar',
    instruccion: 'Marcha a paso suave, con una respiración cómoda.',
    revision: _b,
  ),
  BloqueGuiado(
    id: 'movilidad_hombros',
    nombre: 'Movilidad de hombros',
    instruccion: 'Círculos lentos con los brazos y apertura de pecho.',
    revision: _b,
  ),
  BloqueGuiado(
    id: 'movilidad_cadera',
    nombre: 'Movilidad de cadera',
    instruccion: 'Círculos de cadera y balanceos suaves de las piernas.',
    revision: _b,
  ),
  BloqueGuiado(
    id: 'movilidad_espalda',
    nombre: 'Movilidad de espalda',
    instruccion: 'Gato y vaca en cuadrupedia, con movimientos lentos.',
    revision: _b,
  ),
  BloqueGuiado(
    id: 'estiramientos',
    nombre: 'Estiramientos guiados',
    instruccion: 'Estira cada zona con calma, sin rebotar y sin forzar.',
    revision: _b,
  ),
  BloqueGuiado(
    id: 'respiracion',
    nombre: 'Respiración',
    instruccion: 'Respira profundo y lento, soltando el aire despacio.',
    revision: _b,
  ),
  BloqueGuiado(
    id: 'respiracion_cierre',
    nombre: 'Respiración y cierre',
    instruccion:
        'Respira con calma. Si quieres, termina con una oración o '
        'tu devocional.',
    revision: _b,
  ),
  BloqueGuiado(
    id: 'estiramiento_cierre',
    nombre: 'Estiramiento de cierre',
    instruccion: 'Estira con calma los músculos que trabajaste.',
    revision: _b,
  ),
];

const _regenerativas = <PlantillaRegenerativa>[
  PlantillaRegenerativa(
    id: 'R1',
    nombre: 'Regenerativa 1',
    bloques: [
      BloqueRegenerativo('caminata_suave', 15),
      BloqueRegenerativo('movilidad_cadera', 5),
      BloqueRegenerativo('movilidad_hombros', 5),
      BloqueRegenerativo('respiracion', 3),
    ],
    revision: _b,
  ),
  PlantillaRegenerativa(
    id: 'R2',
    nombre: 'Regenerativa 2',
    bloques: [
      BloqueRegenerativo('caminata_suave', 20),
      BloqueRegenerativo('movilidad_espalda', 5),
      BloqueRegenerativo('estiramientos', 7),
      BloqueRegenerativo('respiracion_cierre', 5),
    ],
    revision: _b,
  ),
];

const _plantillas = <PlantillaSesion>[
  PlantillaSesion(
    id: 'A',
    nombre: 'Fuerza A · Empuje',
    calentamiento: ['caminata_suave', 'movilidad_hombros'],
    cierre: ['estiramiento_cierre'],
    slots: [
      Slot(
        id: 'A1',
        nombre: 'Press de pecho',
        candidatas: [
          'press_pecho_estacion',
          'press_pecho_banda_puerta',
          'press_pecho_banda_estacion',
          'flexion_inclinada_banco',
        ],
        repsMin: 10,
        repsMax: 12,
      ),
      Slot(
        id: 'A2',
        nombre: 'Elevaciones laterales',
        candidatas: ['elevacion_lateral_polea_baja', 'elevacion_lateral_banda'],
        repsMin: 12,
        repsMax: 15,
      ),
      Slot(
        id: 'A3',
        nombre: 'Extensión de tríceps',
        candidatas: [
          'extension_triceps_polea_alta',
          'extension_triceps_banda_puerta',
          'extension_triceps_banda_estacion',
        ],
        repsMin: 10,
        repsMax: 14,
      ),
      Slot(
        id: 'A4',
        nombre: 'Fondos en banco',
        candidatas: ['fondos_banco_piernas', 'fondos_banco_rodillas'],
        repsMin: 8,
        repsMax: 12,
      ),
      Slot(
        id: 'A5',
        nombre: 'Flexiones inclinadas (extra)',
        candidatas: ['flexion_inclinada_banco'],
        repsMin: 8,
        repsMax: 12,
        extra: true,
        esencial: false,
      ),
      Slot(
        id: 'A6',
        nombre: 'Plancha (extra)',
        candidatas: ['plancha_suelo'],
        segundosMin: 30,
        segundosMax: 30,
        extra: true,
        esencial: false,
      ),
    ],
    revision: _b,
  ),
  PlantillaSesion(
    id: 'B',
    nombre: 'Fuerza B · Tirón',
    calentamiento: ['caminata_suave', 'movilidad_hombros'],
    cierre: ['estiramiento_cierre'],
    slots: [
      Slot(
        id: 'B1',
        nombre: 'Jalón al pecho',
        candidatas: [
          'jalon_polea_alta',
          'jalon_banda_puerta',
          'jalon_banda_estacion',
        ],
        repsMin: 10,
        repsMax: 12,
      ),
      Slot(
        id: 'B2',
        nombre: 'Remo sentado',
        candidatas: ['remo_polea_baja', 'remo_banda_pisada'],
        repsMin: 10,
        repsMax: 12,
      ),
      Slot(
        id: 'B3',
        nombre: 'Face pull',
        candidatas: [
          'face_pull_polea_alta',
          'face_pull_banda_puerta',
          'face_pull_banda_estacion',
        ],
        repsMin: 12,
        repsMax: 15,
      ),
      Slot(
        id: 'B4',
        nombre: 'Curl de bíceps',
        candidatas: ['curl_cojin', 'curl_polea_baja', 'curl_banda'],
        repsMin: 10,
        repsMax: 12,
      ),
      Slot(
        id: 'B5',
        nombre: 'Remo con banda (extra)',
        candidatas: ['remo_banda_pisada'],
        repsMin: 10,
        repsMax: 14,
        extra: true,
        esencial: false,
      ),
      Slot(
        id: 'B6',
        nombre: 'Plancha (extra)',
        candidatas: ['plancha_suelo'],
        segundosMin: 30,
        segundosMax: 30,
        extra: true,
        esencial: false,
      ),
    ],
    revision: _b,
  ),
  PlantillaSesion(
    id: 'C',
    nombre: 'Fuerza C · Pierna y core',
    calentamiento: ['caminata_suave', 'movilidad_cadera'],
    cierre: ['estiramiento_cierre'],
    slots: [
      Slot(
        id: 'C1',
        nombre: 'Sentadilla hacia el banco',
        candidatas: [
          'sentadilla_banco_peso',
          'sentadilla_banco_banda',
          'sentadilla_apoyo',
        ],
        repsMin: 12,
        repsMax: 15,
      ),
      Slot(
        id: 'C2',
        nombre: 'Subidas al banco',
        candidatas: ['subida_banco_peso'],
        repsMin: 8,
        repsMax: 12,
      ),
      Slot(
        id: 'C3',
        nombre: 'Puente de glúteo',
        candidatas: ['puente_banco', 'puente_suelo', 'puente_banda'],
        repsMin: 12,
        repsMax: 15,
      ),
      Slot(
        id: 'C4',
        nombre: 'Patada de glúteo',
        candidatas: ['patada_polea', 'patada_banda', 'patada_cuadrupedia'],
        repsMin: 10,
        repsMax: 14,
        esencial: false,
        omitirEnCorta: true,
      ),
      Slot(
        id: 'C5',
        nombre: 'Plancha',
        candidatas: ['plancha_suelo'],
        segundosMin: 30,
        segundosMax: 45,
      ),
    ],
    revision: _b,
  ),
];

/// El catálogo inicial del gimnasio.
final Catalogo catalogoGimnasio = Catalogo(
  version: versionCatalogo,
  items: _items,
  datosAparato: _datosAparato,
  ejercicios: _ejercicios,
  plantillas: _plantillas,
  regenerativas: _regenerativas,
  bloques: _bloques,
);

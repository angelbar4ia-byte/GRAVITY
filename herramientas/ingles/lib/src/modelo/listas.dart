/// Listas controladas del formato (secciones 3, 4, 5 y 7).
const List<String> tiposArchivo = ['unidad', 'forma', 'sesion', 'formato', 'niveles'];
const List<String> estados = ['borrador', 'validado', 'revisado', 'aprobado', 'retirado'];
const List<String> etapas = ['A1', 'A2', 'B1', 'B2'];
const List<String> variantes = ['en-GB', 'en-US'];
const List<String> tiposEstimulo = ['texto', 'audio', 'imagen', 'consigna', 'ninguno'];
const List<String> voces = ['F1', 'F2', 'M1', 'M2', 'N'];
const List<String> usosForma = ['ubicacion', 'mini', 'escalon', 'etapa', 'simulacro', 'practica'];
const List<String> diasSemana = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes'];
const List<String> tiposBloque = ['repaso', 'leccion', 'pronunciacion', 'produccion', 'traslado'];
const List<String> modalidades = ['escritura', 'habla'];
const List<String> unidadesExtension = ['palabras', 'segundos'];

/// Los 15 tipos de pregunta de la tabla 4.2.
const List<String> tiposPregunta = [
  'opcion_multiple',
  'hueco_opciones',
  'hueco_abierto',
  'formacion_palabra',
  'transformacion',
  'oracion_omitida',
  'correspondencia',
  'emparejar',
  'completar_nota',
  'completar_palabras',
  'ordenar_palabras',
  'respuesta_corta',
  'repetir',
  'pronunciacion',
  'produccion',
];

/// Formato de la sesión del curso: es el único contrato propio que existe
/// como unidad de estímulo (los audios de traslado).
const String formatoSesion = 'gravity-sesion-60';

/// Minúsculas, dígitos y guiones (formato, sección 3).
final RegExp patronId = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

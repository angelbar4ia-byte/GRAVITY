/// Lógica pura del módulo Hábitos de GRAVITY (Dart sin Flutter).
///
/// Base: `docs/specs/fase-3-habitos.md`. Sin dependencias.
library;

export 'src/agenda.dart';
// fechaIso y horaTexto de la bici chocan con los de la app del gimnasio: se
// usan con el prefijo del archivo (src/bici/tipos_bici.dart) si hacen falta.
export 'src/bici/bici.dart' hide fechaIso, horaTexto;
export 'src/carga_dia.dart';
export 'src/documentos_cifrados.dart';
export 'src/edicion.dart';
export 'src/espiritual.dart';
export 'src/fecha.dart';
export 'src/gimnasio/gimnasio.dart';
export 'src/habito_eliminar.dart';
export 'src/hoy.dart';
export 'src/mensajes.dart';
export 'src/objetivos.dart';
export 'src/rachas.dart';
export 'src/revision_semanal.dart';
export 'src/sos.dart';

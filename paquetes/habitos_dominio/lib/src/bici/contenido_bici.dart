/// Revisión automática del contenido de la bicicleta (CA-B-01): ningún texto
/// lleva diagnóstico, tratamiento, medicamento, dosis, litros, gramos,
/// calorías ni nombre de enfermedad, lesión o síntoma. Extiende la lista del
/// gimnasio sin cambiarla.
library;

import '../gimnasio/tipos.dart' show RevisionContenido;
import '../gimnasio/validador.dart';
import 'mantenimiento.dart';
import 'mensajes_bici.dart';
import 'preparacion.dart';

/// Lo que la bicicleta prohíbe además de la lista médica del gimnasio (sin
/// acentos, en minúsculas): cifras de líquidos, comida y calorías, y nombres
/// de síntomas o enfermedades.
const palabrasProhibidasBiciExtra = <String>[
  // medidas de líquidos, comida y energía
  'litro', 'litros', 'ml', 'mililitros', 'gramo', 'gramos', 'kcal', 'caloria',
  'calorias', 'miligramo', 'kilocalorias',
  // síntomas y enfermedades (el texto «si te sientes mal» no los nombra)
  'infarto', 'mareo', 'mareos', 'desmayo', 'desmayos', 'confusion', 'nausea',
  'nauseas', 'dolor', 'dolores', 'taquicardia', 'arritmia', 'deshidratacion',
  'insolacion', 'hipotermia', 'hipertension', 'diabetes', 'asma', 'infeccion',
];

final _cifraConUnidad = RegExp(
  r'\d\s*(ml|mg|g|kg|l|lt|cl|kcal|cal)(?![a-záéíóúñ])',
  caseSensitive: false,
);

String _sinAcentos(String t) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final r in t.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  return b.toString();
}

/// Palabras prohibidas en [texto] (lista vacía = limpio): las del gimnasio,
/// las de la bicicleta y toda cifra pegada a una unidad de líquido, peso o
/// energía («500ml», «30 g»).
List<String> palabrasProhibidasEn(String texto) {
  final r = [...palabrasMedicasEn(texto)];
  final s = _sinAcentos(texto);
  for (final f in s.split(RegExp(r'[^a-z0-9]+'))) {
    if (palabrasProhibidasBiciExtra.contains(f)) r.add(f);
  }
  for (final m in _cifraConUnidad.allMatches(s)) {
    r.add(m.group(0)!);
  }
  return r;
}

/// Problemas de contenido: «texto → palabra» (vacío = limpio).
List<String> validarContenidoBici(Iterable<String> textos) => [
  for (final t in textos)
    for (final p in palabrasProhibidasEn(t)) '"$t" → $p',
];

/// Todo texto del módulo: mensajes, preparación, tareas de mantenimiento y
/// sus orígenes.
List<String> textosDeBici() => [
  ...MensajesBici.todos,
  for (final p in catalogoPreparacion) p.texto,
  for (final t in catalogoMantenimiento) ...[t.nombre, t.origen],
];

/// ¿Queda algo `borrador` en el contenido? Mientras sea `true`, la pantalla
/// dice «Contenido en revisión».
bool contenidoBiciEnRevision() =>
    catalogoPreparacion.any((p) => p.revision == RevisionContenido.borrador) ||
    catalogoMantenimiento.any((t) => t.revision == RevisionContenido.borrador);

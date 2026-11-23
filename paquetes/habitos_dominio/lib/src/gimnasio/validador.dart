/// Validador de integridad del catálogo (CA-G-01) y de contenido (CA-G-03).
library;

import 'mensajes_gimnasio.dart';
import 'tipos.dart';

/// Un problema de integridad del catálogo.
class ErrorCatalogo {
  const ErrorCatalogo(this.codigo, this.detalle);
  final String codigo;
  final String detalle;

  @override
  String toString() => '$codigo: $detalle';
}

final _idValido = RegExp(r'^[a-z0-9_.]+$');

/// Revisa el catálogo y devuelve todos los problemas (lista vacía = íntegro).
List<ErrorCatalogo> validarCatalogo(Catalogo c) {
  final e = <ErrorCatalogo>[];
  void mal(String codigo, String detalle) =>
      e.add(ErrorCatalogo(codigo, detalle));

  // Ids únicos y en minúsculas sin acentos (ámbitos separados: un slot y
  // una variante no comparten espacio de nombres con las plantillas).
  void unicos(String ambito, Iterable<String> ids, {RegExp? patron}) {
    final vistos = <String>{};
    for (final id in ids) {
      if (!(patron ?? _idValido).hasMatch(id)) {
        mal('id_invalido', '$ambito: "$id"');
      }
      if (!vistos.add(id)) mal('id_repetido', '$ambito: "$id"');
    }
  }

  final idsEquipo = c.items.map((i) => i.id).toList();
  final idsVariante = [
    for (final x in c.ejercicios) ...x.variantes.map((v) => v.id),
  ];
  unicos('equipo', idsEquipo);
  unicos('ejercicio', c.ejercicios.map((x) => x.id));
  unicos('variante', idsVariante);
  unicos('plantilla', [
    ...c.plantillas.map((p) => p.id),
    ...c.regenerativas.map((r) => r.id),
  ], patron: _idPlantilla);
  unicos('bloque', c.bloques.map((b) => b.id));
  unicos('dato', c.datosAparato.map((d) => d.id));

  final equipo = c.items.map((i) => i.id).toSet();
  final soloDato = c.items.where((i) => i.soloDato).map((i) => i.id).toSet();
  final variantes = idsVariante.toSet();

  for (final i in c.items) {
    if (i.padre != null && !equipo.contains(i.padre)) {
      mal('padre_inexistente', '${i.id} → ${i.padre}');
    }
  }

  for (final x in c.ejercicios) {
    if (x.variantes.isEmpty) mal('sin_variantes', x.id);
    if (x.revision == null) mal('sin_revision', 'ejercicio ${x.id}');
    for (final g in x.gruposPrimarios) {
      if (!Grupos.todos.contains(g)) mal('grupo_invalido', '${x.id}: $g');
    }
    if (x.gruposPrimarios.isEmpty) mal('sin_grupos', x.id);
    for (final z in x.zonas) {
      if (!Zonas.todas.contains(z)) mal('zona_invalida', '${x.id}: $z');
    }
    if (x.explicacion.length > 280) mal('explicacion_larga', x.id);
    if (x.errores.length > 3) mal('demasiados_errores', x.id);
    for (final er in x.errores) {
      if (er.length > 120) mal('error_largo', x.id);
    }
    _rango(mal, x.id, x.repsMin, x.repsMax, x.segundosMin, x.segundosMax);
    for (final v in x.variantes) {
      if (v.revision == null) mal('sin_revision', 'variante ${v.id}');
      for (final r in v.requiere) {
        if (!equipo.contains(r)) mal('requiere_inexistente', '${v.id} → $r');
        if (soloDato.contains(r)) mal('requiere_equipo_futuro', '${v.id} → $r');
      }
      if (v.ancla != null && !v.requiere.contains('bandas')) {
        mal('ancla_sin_banda', v.id);
      }
      if (v.masDificil != null) {
        if (!x.variantes.any((o) => o.id == v.masDificil)) {
          mal('mas_dificil_inexistente', '${v.id} → ${v.masDificil}');
        }
      }
      for (final z in v.zonas ?? const <String>[]) {
        if (!Zonas.todas.contains(z)) mal('zona_invalida', '${v.id}: $z');
      }
    }
  }

  final bloques = c.bloques.map((b) => b.id).toSet();
  for (final b in c.bloques) {
    if (b.revision == null) mal('sin_revision', 'bloque ${b.id}');
    if (b.sustitutoSinCaminadora != null &&
        !bloques.contains(b.sustitutoSinCaminadora)) {
      mal('sustituto_inexistente', b.id);
    }
  }

  for (final p in c.plantillas) {
    if (p.revision == null) mal('sin_revision', 'plantilla ${p.id}');
    if (p.slots.isEmpty) mal('sin_slots', p.id);
    final idsSlot = <String>{};
    for (final s in p.slots) {
      if (!idsSlot.add(s.id)) mal('slot_repetido', '${p.id}.${s.id}');
      if (s.candidatas.isEmpty) mal('slot_sin_candidatas', '${p.id}.${s.id}');
      for (final k in s.candidatas) {
        if (!variantes.contains(k)) {
          mal('candidata_inexistente', '${s.id} → $k');
        }
      }
      if (s.series < 1) mal('series_invalidas', '${p.id}.${s.id}');
      if (s.esencial && s.omitirEnCorta) {
        mal('esencial_y_omitible', '${p.id}.${s.id}');
      }
      _rango(
        mal,
        '${p.id}.${s.id}',
        s.repsMin,
        s.repsMax,
        s.segundosMin,
        s.segundosMax,
      );
    }
    for (final b in [...p.calentamiento, ...p.cierre]) {
      if (!bloques.contains(b)) mal('bloque_inexistente', '${p.id} → $b');
    }
  }

  for (final r in c.regenerativas) {
    if (r.revision == null) mal('sin_revision', 'regenerativa ${r.id}');
    for (final b in r.bloques) {
      if (!bloques.contains(b.bloqueId)) {
        mal('bloque_inexistente', '${r.id} → ${b.bloqueId}');
      }
    }
    if (r.minutos < 20 || r.minutos > 40) {
      mal('regenerativa_fuera_de_20_40', '${r.id}: ${r.minutos} min');
    }
  }
  return e;
}

// Las plantillas se llaman A, B, C, R1, R2: mayúsculas permitidas.
final _idPlantilla = RegExp(r'^[A-Z][A-Z0-9]*$');

void _rango(
  void Function(String, String) mal,
  String donde,
  int? repsMin,
  int? repsMax,
  int? segMin,
  int? segMax,
) {
  if (repsMin != null || repsMax != null) {
    if (repsMin == null ||
        repsMax == null ||
        repsMin < 1 ||
        repsMin >= repsMax) {
      mal('rango_reps', '$donde: $repsMin–$repsMax');
    }
  }
  if (segMin != null || segMax != null) {
    if (segMin == null || segMax == null || segMin < 1 || segMin > segMax) {
      mal('rango_segundos', '$donde: $segMin–$segMax');
    }
  }
}

// ---------------------------------------------------------------------------
// Contenido médico (CA-G-03)
// ---------------------------------------------------------------------------

/// Palabras que ningún texto del módulo puede llevar, sin acentos y en
/// minúsculas: diagnósticos, tratamientos, medicamentos, dosis y nombres de
/// lesión. («diagnostica» sola está permitida: la usa la frase «Esta guía no
/// diagnostica».)
const palabrasProhibidasMedicas = <String>[
  // diagnóstico
  'diagnostico', 'diagnosticos', 'diagnosticar', 'diagnosticado',
  'diagnosticada',
  // tratamiento
  'tratamiento', 'tratamientos', 'tratar', 'terapia', 'terapias',
  'rehabilitacion', 'cirugia', 'operacion', 'inyeccion', 'infiltracion',
  'receta', 'recetar',
  // medicamentos y dosis
  'medicamento', 'medicamentos', 'medicina', 'pastilla', 'pastillas',
  'ibuprofeno', 'paracetamol', 'naproxeno', 'aspirina', 'diclofenaco',
  'analgesico', 'analgesicos', 'antiinflamatorio', 'antiinflamatorios',
  'dosis', 'miligramos', 'pomada', 'crema',
  // nombres de lesión
  'lesion', 'lesiones', 'tendinitis', 'tendinopatia', 'bursitis', 'esguince',
  'desgarro', 'hernia', 'lumbalgia', 'ciatica', 'contractura', 'fractura',
  'luxacion', 'artritis', 'artrosis', 'escoliosis', 'menisco', 'ligamento',
  'manguito', 'epicondilitis', 'fascitis', 'rotura', 'subluxacion',
];

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

/// Palabras prohibidas que aparecen en [texto] (lista vacía = limpio).
List<String> palabrasMedicasEn(String texto) {
  final fichas = _sinAcentos(texto).split(RegExp(r'[^a-z0-9]+'));
  return [
    for (final f in fichas)
      if (palabrasProhibidasMedicas.contains(f)) f,
  ];
}

/// Todo texto del catálogo y de los mensajes (para la prueba de contenido).
List<String> textosDelModulo(Catalogo c) => [
  for (final i in c.items) i.nombre,
  for (final d in c.datosAparato) d.nombre,
  for (final x in c.ejercicios) ...[
    x.nombre,
    x.explicacion,
    ...x.errores,
    for (final v in x.variantes) v.nombre,
  ],
  for (final p in c.plantillas) ...[
    p.nombre,
    for (final s in p.slots) s.nombre,
  ],
  for (final r in c.regenerativas) r.nombre,
  for (final b in c.bloques) ...[b.nombre, b.instruccion],
  ...MensajesGimnasio.todos,
];

/// Problemas de contenido médico: «texto → palabra».
List<String> validarContenidoMedico(Iterable<String> textos) => [
  for (final t in textos)
    for (final p in palabrasMedicasEn(t)) '"$t" → $p',
];

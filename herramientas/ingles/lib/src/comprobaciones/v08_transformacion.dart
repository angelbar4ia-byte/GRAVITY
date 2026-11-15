import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import '../texto.dart';
import 'comun.dart';

/// Palabras mínimas y máximas de la respuesta si el contrato no las da: la
/// tabla 4.2 del formato dice "de 2 a 5 palabras".
const int _minimoPorDefecto = 2;
const int _maximoPorDefecto = 5;

/// V08 · Transformación: cada aceptada contiene la palabra clave sin cambios
/// y tiene las palabras que pide el contrato; la clave no aparece en `antes`
/// ni en `despues`.
///
/// Se cuentan las palabras de examen (una contracción cuenta dos). Si la
/// parte del contrato trae `palabras_respuesta`, manda; si no, de 2 a 5.
List<Hallazgo> v08(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  var min = _minimoPorDefecto;
  var max = _maximoPorDefecto;
  if (a is Unidad) {
    final p = c.parteDe(a);
    if (p != null && p.tipoPregunta == 'transformacion' && p.palabrasRespuesta != null) {
      min = p.palabrasRespuesta!.min?.toInt() ?? min;
      max = p.palabrasRespuesta!.max?.toInt() ?? max;
    }
  }
  for (final q in preguntasDe(a)) {
    if (q is! Transformacion || q.clave == null) continue;
    final clave = palabrasDeExamen(q.clave!);
    if (clave.length != 1) {
      h.add(error(a, 'V08', 'la palabra clave "${q.clave}" debe ser una sola palabra', id: q.id));
      continue;
    }
    final k = clave.single;
    for (final campo in [('antes', q.antes), ('despues', q.despues)]) {
      if (palabrasDeExamen(campo.$2).contains(k)) {
        h.add(error(a, 'V08', 'la palabra clave "${q.clave}" aparece en "${campo.$1}": debe ir solo dentro de la respuesta', id: q.id));
      }
    }
    for (final r in q.aceptadas) {
      final palabras = palabrasDeExamen(r);
      if (!palabras.contains(k)) {
        h.add(error(a, 'V08', 'la respuesta "$r" no contiene la palabra clave "${q.clave}" sin cambios', id: q.id));
      }
      if (palabras.length < min || palabras.length > max) {
        h.add(error(a, 'V08', 'la respuesta "$r" tiene ${palabras.length} palabras (una contracción cuenta dos) y el contrato pide de $min a $max', id: q.id));
      }
    }
  }
  return h;
}

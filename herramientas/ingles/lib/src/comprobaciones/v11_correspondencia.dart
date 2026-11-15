import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import 'comun.dart';

/// V11 · Correspondencia y emparejar: la respuesta apunta a un texto u opción
/// existente y trae `evidencia`; ninguno concentra más de la mitad de las
/// respuestas (aviso). En `emparejar`, las opciones que sobran llevan
/// `porque_no` (tabla 4.2).
List<Hallazgo> v11(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  if (a is! Unidad) return h;

  final correspondencias = a.preguntas.whereType<Correspondencia>().toList();
  final emparejadas = a.preguntas.whereType<Emparejar>().toList();

  h.addAll(_apuntan(
    a,
    {for (final t in a.textos) t.id},
    'texto',
    [for (final q in correspondencias) (q.id, q.respuesta, q.evidencia)],
    hayLista: a.textos.isNotEmpty,
  ));
  h.addAll(_apuntan(
    a,
    {for (final o in a.opciones) o.id},
    'opción',
    [for (final q in emparejadas) (q.id, q.respuesta, q.evidencia)],
    hayLista: a.opciones.isNotEmpty,
  ));

  final usadas = {for (final q in emparejadas) q.respuesta};
  for (final o in a.opciones) {
    if (emparejadas.isNotEmpty && !usadas.contains(o.id) && (o.porqueNo ?? '').trim().isEmpty) {
      h.add(error(a, 'V11', 'la opción sobrante "${o.id}" debe llevar "porque_no"'));
    }
  }
  return h;
}

List<Hallazgo> _apuntan(
  Archivo a,
  Set<String> ids,
  String que,
  List<(String, String?, String?)> preguntas, {
  required bool hayLista,
}) {
  final h = <Hallazgo>[];
  if (preguntas.isEmpty) return h;
  if (!hayLista) {
    h.add(error(a, 'V11', 'las preguntas apuntan a un $que, pero la unidad no los lista (con "id")'));
    return h;
  }
  final cuentas = <String, int>{};
  for (final (id, respuesta, evidencia) in preguntas) {
    if (respuesta != null) {
      if (!ids.contains(respuesta)) {
        h.add(error(a, 'V11', 'la respuesta "$respuesta" no es un $que de la unidad (${ids.join(', ')})', id: id));
      } else {
        cuentas[respuesta] = (cuentas[respuesta] ?? 0) + 1;
      }
    }
    if ((evidencia ?? '').trim().isEmpty) {
      h.add(error(a, 'V11', 'falta la "evidencia" de la respuesta', id: id));
    }
  }
  for (final e in cuentas.entries) {
    if (e.value * 2 > preguntas.length) {
      h.add(aviso(a, 'V11', 'el $que "${e.key}" concentra ${e.value} de ${preguntas.length} respuestas: más de la mitad'));
    }
  }
  return h;
}

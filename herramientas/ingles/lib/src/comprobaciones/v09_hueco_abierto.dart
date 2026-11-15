import '../contexto.dart';
import '../datos/palabras_gramaticales.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import '../texto.dart';
import 'comun.dart';

/// V09 · Hueco abierto: cada aceptada es una sola palabra; con
/// `clase: gramatical`, pertenece a la lista de palabras gramaticales
/// (`datos/palabras_gramaticales.dart`).
///
/// Una contracción cuenta como dos palabras y no cabe en un hueco. Si un hueco
/// de un formato de Cambridge no declara `clase`, es un aviso: la regla 6 del
/// plan (5.6) pide palabras gramaticales y el contrato no tiene dónde decirlo.
List<Hallazgo> v09(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  for (final q in preguntasDe(a)) {
    if (q is! HuecoAbierto) continue;
    for (final r in q.aceptadas) {
      final palabras = palabrasDeExamen(r);
      if (palabras.length != 1) {
        h.add(error(a, 'V09', 'la respuesta "$r" tiene ${palabras.length} palabras: un hueco abierto lleva una sola', id: q.id));
        continue;
      }
      if (q.clase == 'gramatical' && !palabrasGramaticales.contains(palabras.single)) {
        h.add(error(a, 'V09', 'la respuesta "$r" no está en la lista de palabras gramaticales: el hueco es de clase gramatical', id: q.id));
      }
    }
    if (q.clase == null && a is Unidad && (a.formato ?? '').startsWith('cambridge-')) {
      h.add(aviso(a, 'V09', 'el hueco no declara "clase": en Cambridge se espera "clase: gramatical" (plan, 5.6, regla 6)', id: q.id));
    }
  }
  return h;
}

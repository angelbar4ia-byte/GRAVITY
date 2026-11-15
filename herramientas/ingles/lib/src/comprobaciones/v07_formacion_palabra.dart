import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import '../texto.dart';
import 'comun.dart';

/// V07 · Formación de palabra: ninguna respuesta aceptada es igual a la base
/// (sin distinguir mayúsculas).
List<Hallazgo> v07(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  for (final q in preguntasDe(a)) {
    if (q is! FormacionPalabra || q.base == null) continue;
    final base = normalizarRespuesta(q.base!);
    for (final r in q.aceptadas) {
      if (normalizarRespuesta(r) == base) {
        h.add(error(a, 'V07', 'la respuesta "$r" es igual a la palabra base "${q.base}": no hay formación de palabra', id: q.id));
      }
    }
  }
  return h;
}

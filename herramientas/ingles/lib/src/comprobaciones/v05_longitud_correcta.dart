import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import 'comun.dart';

/// V05 · En partes de 8 preguntas o más, la correcta es la opción más larga
/// en menos de la mitad (aviso).
///
/// Se mide por parte, juntando las unidades del mismo formato y parte; el
/// aviso lo da el primer archivo de la parte (por id) para no repetirlo.
/// "Más larga" es en caracteres, y estrictamente más larga que todas las demás.
List<Hallazgo> v05(Archivo a, Contexto c) {
  if (a is! Unidad || a.formato == null || a.parte == null) return const [];
  final grupo = c.unidadesDeParte(a.formato, a.parte);
  if (grupo.isEmpty || grupo.first != a) return const [];

  var total = 0;
  var masLarga = 0;
  for (final u in grupo) {
    for (final q in u.preguntas) {
      final opciones = switch (q) {
        OpcionMultiple() => q.opciones,
        HuecoOpciones() => q.opciones,
        _ => const <Opcion>[],
      };
      if (opciones.length < 2) continue;
      total++;
      final correcta = opciones.first.texto.length;
      if (opciones.skip(1).every((o) => o.texto.length < correcta)) masLarga++;
    }
  }
  if (total < 8 || masLarga * 2 < total) return const [];
  return [
    aviso(a, 'V05', 'en la parte "${a.parte}" la correcta es la opción más larga en $masLarga de $total preguntas (${(100 * masLarga / total).round()} %): conviene que sea menos de la mitad'),
  ];
}

import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import '../modelo/listas.dart';
import '../texto.dart';
import 'comun.dart';

const int _palabrasMinimas = 6;

/// V12 · `porque` de al menos 6 palabras en toda pregunta objetiva; en el
/// curso, `porque_no` en cada distractor.
///
/// En `opcion_multiple` y `hueco_opciones` el `porque` es el de la primera
/// opción (la ausencia ya la da V04). En `correspondencia` y `emparejar`, la
/// razón es el `porque` de la pregunta o, si no lo hay, su `evidencia`.
/// "Curso" es una sesión o una unidad del formato `gravity-sesion-60`.
List<Hallazgo> v12(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  final curso = a is Sesion || (a is Unidad && a.formato == formatoSesion);
  for (final q in preguntasDe(a)) {
    if (!esObjetiva(q)) continue;
    final String? razon;
    var obligaPresencia = true;
    switch (q) {
      case OpcionMultiple():
        razon = q.opciones.isEmpty ? null : q.opciones.first.porque;
        obligaPresencia = false;
      case HuecoOpciones():
        razon = q.opciones.isEmpty ? null : q.opciones.first.porque;
        obligaPresencia = false;
      case Correspondencia():
        razon = q.porque ?? q.evidencia;
      case Emparejar():
        razon = q.porque ?? q.evidencia;
      default:
        razon = q.porque;
    }
    final texto = (razon ?? '').trim();
    if (texto.isEmpty) {
      if (obligaPresencia) {
        h.add(error(a, 'V12', 'falta "porque" (al menos $_palabrasMinimas palabras)', id: q.id));
      }
    } else if (contarPalabras(texto) < _palabrasMinimas) {
      h.add(error(a, 'V12', '"porque" tiene ${contarPalabras(texto)} palabras y se piden al menos $_palabrasMinimas', id: q.id));
    }
    if (curso) {
      final opciones = switch (q) {
        OpcionMultiple() => q.opciones,
        HuecoOpciones() => q.opciones,
        _ => const <Opcion>[],
      };
      for (var i = 1; i < opciones.length; i++) {
        if ((opciones[i].porqueNo ?? '').trim().isEmpty) {
          h.add(error(a, 'V12', 'en el curso, la opción ${letra(i)} debe llevar "porque_no"', id: q.id));
        }
      }
    }
  }
  return h;
}

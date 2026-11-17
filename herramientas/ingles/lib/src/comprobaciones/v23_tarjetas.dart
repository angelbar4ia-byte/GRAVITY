import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../morfologia.dart';
import 'comun.dart';

/// V23 · Tarjetas de una sesión (formato, sección 11). Es error:
/// - el id es único en todo el curso (también lo dice V02, que mira todos los
///   ids; aquí se dice con el nombre de tarjeta, y solo entre tarjetas);
/// - la traducción (`es`) está presente;
/// - el `ejemplo` contiene la palabra o frase de la tarjeta (`en`) o una forma
///   suya. La forma es una heurística (`morfologia.dart`): sufijos regulares y
///   una tabla de verbos irregulares frecuentes. Lo que lleva `(entre
///   paréntesis)` es opcional y `/` separa alternativas.
List<Hallazgo> v23(Archivo a, Contexto c) {
  if (a is! Sesion) return const [];
  final h = <Hallazgo>[];
  final vistas = <String>{};
  for (final t in a.tarjetas) {
    if (!vistas.add(t.id)) {
      h.add(
        error(
          a,
          'V23',
          'el id de tarjeta "${t.id}" está repetido en esta sesión',
          id: t.id,
        ),
      );
    }
    final otras = {
      for (final o in c.archivos)
        if (o is Sesion &&
            !identical(o, a) &&
            o.estado != Estado.retirado &&
            o.tarjetas.any((x) => x.id == t.id))
          o.ruta,
    };
    if (otras.isNotEmpty) {
      h.add(
        error(
          a,
          'V23',
          'el id de tarjeta "${t.id}" también está en ${otras.join(', ')}: debe ser único en todo el curso',
          id: t.id,
        ),
      );
    }
    if ((t.es ?? '').trim().isEmpty) {
      h.add(error(a, 'V23', 'la tarjeta no trae traducción (es)', id: t.id));
    }
    final en = t.en;
    final ejemplo = t.ejemplo;
    if (en != null &&
        en.trim().isNotEmpty &&
        ejemplo != null &&
        ejemplo.trim().isNotEmpty &&
        !ejemploContiene(en, ejemplo)) {
      h.add(
        error(
          a,
          'V23',
          'el ejemplo "$ejemplo" no contiene "$en" ni una forma suya',
          id: t.id,
        ),
      );
    }
  }
  return h;
}

import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../usos.dart';
import 'comun.dart';

/// V20 · Las unidades de las formas con uso `ubicacion`, `escalon` o `etapa` no
/// se usan en ningún otro lugar: ni en otras formas ni en sesiones. Es error.
///
/// Se reporta en los dos lados, como V02 con los ids:
///
/// - en la forma reservada, que dice quién más usa su unidad;
/// - en la forma o la sesión que la usa, que dice de quién es.
///
/// "Usar en una sesión" es listar la unidad entre los `audios` de su traslado
/// (la única forma en que una sesión remite a una unidad). Dos formas de uso
/// exclusivo que comparten una unidad se reportan entre sí. Las formas y sesiones
/// `retiradas` no cuentan. Lo que no es de uso exclusivo (dos simulacros, un
/// simulacro y la práctica) es de V19, regla c.
List<Hallazgo> v20(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  switch (a) {
    case Forma():
      for (final id in unidadesDeForma(a)) {
        final otrasFormas = [
          for (final g in c.usos.formasDe(id))
            if (!identical(g, a)) g,
        ];
        if (esExclusiva(a)) {
          final donde = [
            for (final g in otrasFormas) 'la forma "${g.id}" (uso: ${g.uso})',
            for (final s in c.usos.sesionesDe(id)) 'la sesión "${s.id}" (su traslado)',
          ];
          if (donde.isNotEmpty) {
            h.add(error(a, 'V20', 'la unidad "$id" es de una forma de uso "${a.uso}" y no se usa en ningún otro lugar, pero también la usa ${donde.join(' y ')}', id: id));
          }
        } else {
          for (final g in otrasFormas.where(esExclusiva)) {
            h.add(error(a, 'V20', 'usa la unidad "$id", reservada para la forma "${g.id}" (uso: ${g.uso}): las unidades de ubicación, escalón y etapa no se usan en ningún otro lugar', id: id));
          }
        }
      }
    case Sesion():
      for (final id in audiosDeSesion(a).toSet()) {
        for (final g in c.usos.formasDe(id).where(esExclusiva)) {
          h.add(error(a, 'V20', 'usa la unidad "$id" en su traslado, reservada para la forma "${g.id}" (uso: ${g.uso}): las unidades de ubicación, escalón y etapa no se usan en ningún otro lugar', id: id));
        }
      }
    default:
      break;
  }
  return h;
}

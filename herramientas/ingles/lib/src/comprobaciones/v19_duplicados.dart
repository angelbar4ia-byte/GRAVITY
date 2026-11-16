import '../contexto.dart';
import '../duplicados.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../usos.dart';
import 'comun.dart';

/// V19 · Duplicados. Es error. Tres reglas:
///
/// - **a · Oraciones.** Una oración de 7 palabras o más, normalizada (en
///   minúsculas y sin puntuación), que está en dos archivos distintos.
/// - **b · Similitud.** Dos estímulos cuyos conjuntos de trigramas de palabras
///   tienen una similitud de Jaccard de 0.85 o más.
/// - **c · Formas.** Una unidad que aparece en dos formas, o dos veces en la
///   misma, o en una forma y en la práctica (una forma de `uso: practica`).
///
/// Las reglas a y b las calcula [IndiceDuplicados] una sola vez para todo el
/// conjunto y se reportan en los dos archivos del par (como hace V02 con los
/// ids): ninguno de los dos puede darse por bueno mientras el otro lo copie.
/// Cuando dos estímulos son casi idénticos, se reporta la regla b (con el
/// número de oraciones que además comparten) y no la a, para no decir dos veces
/// lo mismo. Una oración repetida dentro de un mismo archivo no cuenta.
///
/// La regla c excluye los pares en que alguna de las dos formas es de uso
/// exclusivo (ubicación, escalón o etapa): eso es de V20, que lo dice con su
/// razón.
List<Hallazgo> v19(Archivo a, Contexto c) {
  if (a is Forma) return _formas(a, c);
  if (a is! Unidad && a is! Sesion) return const [];
  return [
    for (final co in c.duplicados.de(a))
      error(a, 'V19', _mensaje(co)),
  ];
}

String _mensaje(Coincidencia co) {
  final otro = '"${co.otro.id}" (${co.otro.ruta})';
  final n = co.oraciones.length;
  if (co.similitud != null) {
    final y = n == 0
        ? ''
        : '; además comparten ${_oraciones(n)} de $oracionMinimaPalabras palabras o más';
    return 'su texto se parece al de $otro: similitud de Jaccard ${co.similitud!.toStringAsFixed(2)} sobre trigramas de palabras, y el límite es ${similitudMinima.toStringAsFixed(2)}$y';
  }
  return 'comparte ${_oraciones(n)} de $oracionMinimaPalabras palabras o más con $otro, por ejemplo «${_resumen(co.oraciones.first)}»';
}

String _oraciones(int n) => n == 1 ? '1 oración' : '$n oraciones';

String _resumen(String texto) =>
    texto.length <= 70 ? texto : '${texto.substring(0, 67)}...';

List<Hallazgo> _formas(Forma f, Contexto c) {
  final h = <Hallazgo>[];
  for (final id in unidadesDeForma(f)) {
    final veces = c.usos.vecesEn(f, id);
    if (veces > 1) {
      h.add(error(f, 'V19', 'la unidad "$id" aparece $veces veces en esta forma: una unidad se usa una sola vez', id: id));
    }
    if (esExclusiva(f)) continue;
    final otras = [
      for (final g in c.usos.formasDe(id))
        if (!identical(g, f) && !esExclusiva(g)) g,
    ];
    if (otras.isNotEmpty) {
      final donde = [
        for (final g in otras) '"${g.id}" (uso: ${g.uso}${g.uso == 'practica' ? ', la práctica' : ''})',
      ].join(', ');
      h.add(error(f, 'V19', 'la unidad "$id" también está en la forma $donde: una unidad no se usa en dos formas ni en una forma y en la práctica', id: id));
    }
  }
  return h;
}

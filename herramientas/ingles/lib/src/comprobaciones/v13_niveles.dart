import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import 'comun.dart';

/// V13 · `nivel`, `habilidad`, `foco` y `temas` pertenecen a `niveles.yaml`.
///
/// Sin `niveles.yaml` se avisa una vez por archivo ("sin niveles"): aviso en
/// borrador, error de validado en adelante. El escalón de una sesión se
/// comprueba solo si `niveles.yaml` lista escalones; las etapas, solo si las
/// lista.
List<Hallazgo> v13(Archivo a, Contexto c) {
  if (a is! Unidad && a is! Sesion) return const [];
  final n = c.niveles;
  if (n == null) {
    return [faltante(a, 'V13', 'sin niveles: no existe niveles.yaml; no se pueden comprobar nivel, habilidad, foco ni temas')];
  }
  final h = <Hallazgo>[];
  void en(Set<String> permitidos, String valor, String campo, String lista, {String? id}) {
    if (!permitidos.contains(valor)) {
      h.add(error(a, 'V13', '$campo "$valor" no está en $lista de niveles.yaml', id: id));
    }
  }

  if (a is Unidad) {
    if (a.nivel != null && n.niveles.isNotEmpty) en(n.niveles, a.nivel!, 'el nivel', 'los niveles');
    for (final t in a.temas) {
      en(n.temas, t, 'el tema', 'los temas');
    }
  }
  if (a is Sesion) {
    if (a.escalon != null && n.escalones.isNotEmpty) en(n.escalones, a.escalon!, 'el escalón', 'los escalones');
    for (final t in a.temas) {
      en(n.temas, t, 'el tema', 'los temas');
    }
  }
  for (final q in preguntasDe(a)) {
    if (q.habilidad != null) en(n.habilidades, q.habilidad!, 'la habilidad', 'las habilidades', id: q.id);
    if (q.foco != null) en(n.focos, q.foco!, 'el foco', 'los focos', id: q.id);
  }
  return h;
}

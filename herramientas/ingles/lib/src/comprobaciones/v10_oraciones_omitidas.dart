import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import 'comun.dart';

/// V10 · Oraciones omitidas: número de oraciones igual a huecos más sobrantes
/// del contrato; `ancla` en cada colocada y `porque_no` en cada sobrante.
///
/// Del contrato de la parte: `preguntas_por_unidad` son los huecos y
/// `opciones`, las oraciones disponibles; los sobrantes son la diferencia.
/// Sin contrato solo se comprueban las anclas y los `porque_no`.
List<Hallazgo> v10(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  if (a is! Unidad) return h;
  final parte = c.parteDe(a);

  var colocadas = 0;
  var sobrantes = 0;
  var hay = false;
  for (final q in a.preguntas) {
    if (q is! OracionOmitidaPregunta) continue;
    hay = true;
    for (var i = 0; i < q.oraciones.length; i++) {
      final o = q.oraciones[i];
      if (o.sobrante) {
        sobrantes++;
        if ((o.porqueNo ?? '').trim().isEmpty) {
          h.add(error(a, 'V10', 'la oración sobrante ${i + 1} debe llevar "porque_no" (por qué no cabe en ningún hueco)', id: q.id));
        }
        if (o.hueco != null) {
          h.add(error(a, 'V10', 'la oración ${i + 1} es sobrante y a la vez tiene hueco ${o.hueco}', id: q.id));
        }
      } else {
        colocadas++;
        if (o.hueco == null) {
          h.add(error(a, 'V10', 'la oración colocada ${i + 1} no dice a qué hueco va', id: q.id));
        }
        if ((o.ancla ?? '').trim().isEmpty) {
          h.add(error(a, 'V10', 'la oración colocada ${i + 1} debe llevar "ancla" (la pista de cohesión que la fija)', id: q.id));
        }
      }
    }
  }
  if (!hay || parte == null) return h;

  final huecos = parte.preguntasPorUnidad;
  final opciones = parte.opciones;
  if (huecos != null && huecos.min != null && huecos.min == huecos.max && colocadas != huecos.min) {
    h.add(error(a, 'V10', 'tiene $colocadas oraciones colocadas y el contrato de "${parte.id}" pide ${huecos.min} huecos'));
  }
  if (opciones != null && colocadas + sobrantes != opciones) {
    h.add(error(a, 'V10', 'tiene ${colocadas + sobrantes} oraciones y el contrato de "${parte.id}" pide $opciones'));
  }
  if (opciones != null && huecos?.min != null && huecos!.min == huecos.max) {
    final esperadas = opciones - huecos.min!.toInt();
    if (sobrantes != esperadas) {
      h.add(error(a, 'V10', 'tiene $sobrantes oraciones sobrantes y el contrato de "${parte.id}" pide $esperadas'));
    }
  }
  return h;
}

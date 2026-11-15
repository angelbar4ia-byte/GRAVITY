import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/formato.dart';
import '../modelo/pregunta.dart';
import '../texto.dart';
import 'comun.dart';

/// V03 · Número de opciones según el contrato de la parte; opciones distintas
/// entre sí (sin contar mayúsculas, espacios ni puntuación).
///
/// Sin contrato (unidad sin formato conocido, o sesión del curso) se aplica el
/// único dato del formato: 3 o 4 opciones (tabla 4.2). Con contrato cuya parte
/// no da el número de opciones (dato pendiente), no se decide nada.
List<Hallazgo> v03(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  final Parte? parte;
  final bool hayContrato;
  switch (a) {
    case Unidad():
      parte = c.parteDe(a);
      hayContrato = c.contrato(a.formato) != null;
    case Sesion():
      parte = null;
      hayContrato = false;
    default:
      return h;
  }

  for (final q in preguntasDe(a)) {
    final opciones = switch (q) {
      OpcionMultiple() => q.opciones,
      HuecoOpciones() => q.opciones,
      _ => null,
    };
    if (opciones == null) continue;
    if (parte != null && parte.opciones != null) {
      if (opciones.length != parte.opciones) {
        h.add(error(a, 'V03', 'tiene ${opciones.length} opciones y el contrato de "${parte.id}" pide ${parte.opciones}', id: q.id));
      }
    } else if (!hayContrato && (opciones.length < 3 || opciones.length > 4)) {
      h.add(error(a, 'V03', 'tiene ${opciones.length} opciones; sin contrato se esperan 3 o 4', id: q.id));
    }
    h.addAll(_repetidas(a, q.id, [for (final o in opciones) o.texto], 'opciones'));
  }

  if (a is Unidad) {
    final tiene = a.preguntas;
    if (tiene.any((q) => q is Correspondencia) && parte?.opciones != null && a.textos.length != parte!.opciones) {
      h.add(error(a, 'V03', 'tiene ${a.textos.length} textos y el contrato de "${parte.id}" pide ${parte.opciones}'));
    }
    if (tiene.any((q) => q is Emparejar)) {
      if (parte?.opciones != null && a.opciones.length != parte!.opciones) {
        h.add(error(a, 'V03', 'tiene ${a.opciones.length} opciones y el contrato de "${parte.id}" pide ${parte.opciones}'));
      }
      h.addAll(_repetidas(a, a.id, [for (final o in a.opciones) o.texto ?? ''], 'opciones de la unidad'));
    }
  }
  return h;
}

List<Hallazgo> _repetidas(Archivo a, String id, List<String> textos, String que) {
  final h = <Hallazgo>[];
  final vistos = <String, int>{};
  for (var i = 0; i < textos.length; i++) {
    final clave = normalizarOpcion(textos[i]);
    final previa = vistos[clave];
    if (previa != null) {
      h.add(error(a, 'V03', 'las $que ${letra(previa)} y ${letra(i)} son iguales ("${textos[i]}")', id: id));
    } else {
      vistos[clave] = i;
    }
  }
  return h;
}

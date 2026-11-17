import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import 'comun.dart';

final RegExp _marca = RegExp(r'\{(\d+)\}');

/// V02 · Identificadores únicos en todo `data/ingles`; el id de cada pregunta
/// empieza con el de su unidad; toda referencia existe.
///
/// "Toda referencia existe" incluye el contrato del formato: si falta, es
/// "sin contrato" (aviso en borrador, error de validado en adelante) y las
/// comprobaciones que dependen de él se saltan sus reglas.
List<Hallazgo> v02(Archivo a, Contexto c) {
  final h = <Hallazgo>[];

  // Únicos.
  final conteoPropio = <String, int>{};
  for (final id in idsDe(a)) {
    conteoPropio[id] = (conteoPropio[id] ?? 0) + 1;
  }
  for (final e in conteoPropio.entries) {
    final fuera = {
      for (final o in c.duenosDe(e.key))
        if (o != a) o.ruta,
    };
    if (e.value > 1) {
      h.add(error(a, 'V02', 'el id "${e.key}" está repetido ${e.value} veces en este archivo', id: e.key));
    }
    if (fuera.isNotEmpty) {
      h.add(error(a, 'V02', 'el id "${e.key}" ya existe en ${fuera.join(', ')}', id: e.key));
    }
  }

  // Prefijo de los ids de pregunta.
  for (final q in preguntasDe(a)) {
    if (!q.id.startsWith('${a.id}-')) {
      h.add(error(a, 'V02', 'el id de la pregunta debe empezar con "${a.id}-"', id: q.id));
    }
  }

  switch (a) {
    case Unidad():
      _unidad(a, c, h);
    case Forma():
      _forma(a, c, h);
    case Sesion():
      _sesion(a, c, h);
    default:
      break;
  }
  return h;
}

void _unidad(Unidad u, Contexto c, List<Hallazgo> h) {
  final contrato = c.contrato(u.formato);
  if (u.formato != null) {
    if (contrato == null) {
      h.add(faltante(u, 'V02', 'sin contrato: no existe el formato "${u.formato}" en formatos/'));
    } else if (u.parte != null && contrato.parte(u.parte) == null) {
      h.add(error(u, 'V02', 'la parte "${u.parte}" no existe en el contrato "${u.formato}"'));
    }
  }

  // Los textos y las opciones con id no se repiten dentro de la unidad.
  for (final lista in [u.textos, u.opciones]) {
    final vistos = <String>{};
    for (final e in lista) {
      if (!vistos.add(e.id)) {
        h.add(error(u, 'V02', 'el id local "${e.id}" está repetido'));
      }
    }
  }

  // Cada hueco numerado tiene su marca en el texto y cada marca, su pregunta.
  final huecos = <int, List<String>>{};
  void anota(int? n, String id) {
    if (n != null) (huecos[n] ??= []).add(id);
  }

  for (final q in u.preguntas) {
    switch (q) {
      case HuecoOpciones():
        anota(q.hueco, q.id);
      case HuecoAbierto():
        anota(q.hueco, q.id);
      case FormacionPalabra():
        anota(q.hueco, q.id);
      case OracionOmitidaPregunta():
        for (final o in q.oraciones) {
          if (!o.sobrante) anota(o.hueco, q.id);
        }
      default:
        break;
    }
  }
  for (final e in huecos.entries) {
    if (e.value.length > 1) {
      h.add(error(u, 'V02', 'el hueco ${e.key} lo usan varias preguntas: ${e.value.join(', ')}'));
    }
  }
  final texto = u.estimulo?.tipo == 'texto' ? u.estimulo?.texto : null;
  if (texto != null && huecos.isNotEmpty) {
    final marcas = {for (final m in _marca.allMatches(texto)) int.parse(m.group(1)!)};
    for (final n in huecos.keys) {
      if (!marcas.contains(n)) {
        h.add(error(u, 'V02', 'el hueco $n no tiene marca {$n} en el texto', id: huecos[n]!.first));
      }
    }
    for (final n in marcas) {
      if (!huecos.containsKey(n)) {
        h.add(error(u, 'V02', 'la marca {$n} del texto no tiene pregunta'));
      }
    }
  }
}

void _forma(Forma f, Contexto c, List<Hallazgo> h) {
  final contrato = c.contrato(f.formato);
  if (f.formato != null && contrato == null) {
    h.add(faltante(f, 'V02', 'sin contrato: no existe el formato "${f.formato}" en formatos/'));
  }
  for (final s in f.secciones) {
    if (contrato != null && s.parte != null && contrato.parte(s.parte) == null) {
      h.add(error(f, 'V02', 'la parte "${s.parte}" no existe en el contrato "${f.formato}"'));
    }
    for (final id in s.unidades) {
      final x = c.archivo(id);
      if (x == null) {
        h.add(error(f, 'V02', 'la unidad "$id" no existe'));
      } else if (x is! Unidad) {
        h.add(error(f, 'V02', '"$id" existe pero es ${x.tipo}, no una unidad'));
      } else {
        // La unidad de una forma es de la parte y del formato de su sección.
        if (x.formato != null && f.formato != null && x.formato != f.formato) {
          h.add(
            error(
              f,
              'V02',
              'la unidad "$id" es del formato "${x.formato}" y la forma es de "${f.formato}"',
            ),
          );
        }
        if (x.parte != null && s.parte != null && x.parte != s.parte) {
          h.add(
            error(
              f,
              'V02',
              'la unidad "$id" es de la parte "${x.parte}" y la sección la usa en "${s.parte}"',
            ),
          );
        }
      }
    }
  }
}

void _sesion(Sesion s, Contexto c, List<Hallazgo> h) {
  if (c.contrato('gravity-sesion-60') == null) {
    h.add(faltante(s, 'V02', 'sin contrato: no existe el formato "gravity-sesion-60" en formatos/'));
  }
  for (final b in s.bloques) {
    // Las formas a las que remiten los bloques de la prueba (formato 0.5, 7.1).
    final (forma, repeticion) = switch (b) {
      BloqueMiniPrueba() => (b.forma, null),
      BloquePruebaUnidad() => (b.forma, b.repeticion),
      BloqueRepeticionPrueba() => (b.forma, null),
      _ => (null, null),
    };
    for (final id in [?forma, ?repeticion]) {
      final x = c.archivo(id);
      if (x == null) {
        h.add(
          error(
            s,
            'V02',
            'el bloque ${b.tipo} remite a la forma "$id", que no existe',
          ),
        );
      } else if (x is! Forma) {
        h.add(
          error(
            s,
            'V02',
            'el bloque ${b.tipo} remite a "$id", que existe pero es ${x.tipo}, no una forma',
          ),
        );
      }
    }
    if (b is! BloqueTraslado) continue;
    for (final id in b.audios) {
      final x = c.archivo(id);
      if (x == null) {
        h.add(error(s, 'V02', 'el audio "$id" no existe'));
      } else if (x is! Unidad || x.estimulo?.tipo != 'audio') {
        h.add(error(s, 'V02', '"$id" existe pero no es una unidad de audio'));
      }
    }
  }
}

import '../contexto.dart';
import '../contenido.dart';
import '../hallazgo.dart';
import '../medidas.dart';
import '../modelo/archivo.dart';
import '../modelo/contrato_sesion.dart';
import '../modelo/datos.dart';
import '../modelo/pregunta.dart';
import '../texto.dart';
import 'comun.dart';
import 'v21_sesion.dart' show dosCifras, ranuraDeEscalon;

/// La parte de la forma de una prueba por unidad (formato 0.5, 5.1). El contrato
/// `gravity-sesion-60` debe traerla (hoy no la trae: ver el reporte de P1.2c-1).
const String parteDePruebaUnidad = 'prueba-unidad';

/// Los tipos de pregunta que admiten estas pruebas: opción múltiple y respuesta
/// corta objetiva; nada que exija juicio humano ni IA (formato 0.5, 5.1, regla 2).
const List<String> tiposAdmitidosEnPruebas = [
  'opcion_multiple',
  'respuesta_corta',
];

/// La habilidad de las preguntas que corresponde a cada grupo de la composición
/// del contrato: el contrato llama `gramatica_del_tema` al grupo que las
/// preguntas etiquetan `gramatica` (lista de habilidades de `niveles.yaml`).
String habilidadDelGrupo(String grupo) =>
    grupo == 'gramatica_del_tema' ? 'gramatica' : grupo;

/// V28 · Pruebas por unidad y mini pruebas (formato 0.5, sección 5.1). Error,
/// salvo lo que depende de cuánto contenido hay escrito (aviso). Las cifras
/// salen del contrato `gravity-sesion-60` (`viernes`).
///
/// Cada forma de uso `prueba_unidad` o `mini`:
/// - es del formato `gravity-sesion-60`, trae `escalon` (de `niveles.yaml`) y su
///   id sigue el patrón (`pu-<escalón>-u<N>-<a|b>` y `mini-<escalón>-s<NN>`, con
///   la unidad y la variante iguales a las de los campos);
/// - la `prueba_unidad` trae `unidad_del_escalon` (de 1 a las que pide el
///   contrato), `variante` (`a` o `b`) y `con_audio`, y una sola sección de la
///   parte `prueba-unidad`;
/// - tiene las preguntas del contrato: 20 con audio (6 de gramática, 4 de
///   vocabulario, 5 de lectura y 5 de escucha) o 15 sin audio; la mini prueba,
///   10 de gramática y vocabulario;
/// - la escucha va en audios con las reproducciones del contrato, y sin audio no
///   hay ninguna;
/// - solo opción múltiple y respuesta corta;
/// - sale del temario del propio escalón (`niveles.yaml`: gramática nueva o
///   retomada de ese escalón);
///
/// Entre formas del mismo escalón: dos formas no ocupan la misma unidad y
/// variante (error); la `b` no comparte unidades, estímulos ni enunciados con la
/// `a`, y las mini pruebas no repiten preguntas de las pruebas por unidad
/// (error); y un escalón con algunas de sus 8 pruebas y 7 mini pruebas pero no
/// todas lo dice (aviso: el contenido se escribe por partes, y el informe cuenta
/// lo que falta).
///
/// Los umbrales (80 % y 8 de 10) viven en el contrato y los contrasta V27.
List<Hallazgo> v28(Archivo a, Contexto c) {
  if (a is! Forma || (a.uso != 'prueba_unidad' && a.uso != 'mini')) {
    return const [];
  }
  final k = c.contratoSesion;
  if (k == null) return const [];
  final h = <Hallazgo>[];
  void err(String m, {String? id}) => h.add(error(a, 'V28', m, id: id));

  if (a.formato != idContratoSesion) {
    err(
      'una forma de uso ${a.uso} es del formato $idContratoSesion, no de "${a.formato}"',
    );
  }
  final escalon = a.escalon;
  final esc = _escalon(c, escalon);
  if (escalon == null) {
    err('falta "escalon"');
  } else if (c.niveles != null &&
      c.niveles!.escalones.isNotEmpty &&
      !c.niveles!.escalones.contains(escalon)) {
    err('el escalón "$escalon" no está en niveles.yaml');
  }
  final ranura = escalon == null ? null : ranuraDeEscalon(escalon);

  // Las unidades de la forma.
  final unidades = <Unidad>[];
  if (a.secciones.length != 1) {
    err('la forma trae ${a.secciones.length} secciones y debe traer una');
  }
  for (final s in a.secciones) {
    for (final id in s.unidades) {
      final u = c.archivo(id);
      if (u is Unidad) {
        unidades.add(u);
        if (u.estado == Estado.retirado) err('la unidad "$id" está retirada');
      }
    }
  }
  final preguntas = [for (final u in unidades) ...u.preguntas];

  // Solo opción múltiple y respuesta corta.
  for (final q in preguntas) {
    if (!tiposAdmitidosEnPruebas.contains(q.tipo)) {
      err(
        'la pregunta es de tipo ${q.tipo} y estas pruebas solo admiten ${tiposAdmitidosEnPruebas.join(' y ')}: nada que exija juicio humano ni IA',
        id: q.id,
      );
    }
  }

  // Del temario del propio escalón.
  if (esc != null) {
    final permitidos = {
      ...?textosEn(esc, 'gramatica_nueva'),
      ...?textosEn(esc, 'gramatica_que_se_retoma'),
    };
    for (final u in unidades) {
      for (final t in u.temas) {
        if (!permitidos.contains(t)) {
          err(
            'el tema $t de la unidad "${u.id}" no es del temario de $escalon (gramática nueva ni retomada)',
          );
        }
      }
    }
  }

  if (a.uso == 'mini') {
    _mini(a, k, ranura, unidades, preguntas, err);
  } else {
    _pruebaUnidad(a, k, ranura, escalon, unidades, preguntas, err);
  }

  _entreFormas(a, c, k, unidades, h);
  return h;
}

Mapa? _escalon(Contexto c, String? id) {
  if (id == null || c.niveles == null) return null;
  for (final e in c.niveles!.escalonesEnOrden) {
    if (e['id'] == id) return e;
  }
  return null;
}

Map<String, int> _porHabilidad(List<Pregunta> qs) {
  final m = <String, int>{};
  for (final q in qs) {
    final hab = q.habilidad;
    if (hab != null) m[hab] = (m[hab] ?? 0) + preguntasQueAporta(q);
  }
  return m;
}

void _mini(
  Forma a,
  ContratoSesion k,
  String? ranura,
  List<Unidad> unidades,
  List<Pregunta> preguntas,
  void Function(String, {String? id}) err,
) {
  final m = RegExp(r'^mini-([a-z0-9]+)-s(\d{2})$').firstMatch(a.id);
  if (m == null) {
    err('el id de una mini prueba es mini-<escalón>-s<NN>, no "${a.id}"');
  } else {
    if (ranura != null && m.group(1) != ranura) {
      err(
        'el id "${a.id}" no es del escalón ${a.escalon} (mini-$ranura-s<NN>)',
      );
    }
    final semana = int.parse(m.group(2)!);
    final semanas = k.semanasDeMiniPrueba;
    if (semanas != null && !semanas.contains(semana)) {
      err(
        'la semana $semana no lleva mini prueba (el contrato la pone en las semanas ${semanas.join(', ')})',
      );
    }
  }
  final pide = k.preguntasDeMiniPrueba;
  final n = unidades.fold(0, (s, u) => s + contarPreguntas(u));
  if (pide != null && n != pide) {
    err('la mini prueba trae $n preguntas y el contrato pide $pide');
  }
  for (final q in preguntas) {
    if (q.habilidad != 'gramatica' && q.habilidad != 'vocabulario') {
      err(
        'la mini prueba es de gramática y vocabulario y esta pregunta es de ${q.habilidad}',
        id: q.id,
      );
    }
  }
  for (final u in unidades) {
    if (u.estimulo?.tipo == 'audio') {
      err('la mini prueba no lleva audio: la unidad "${u.id}" lo trae');
    }
  }
}

void _pruebaUnidad(
  Forma a,
  ContratoSesion k,
  String? ranura,
  String? escalon,
  List<Unidad> unidades,
  List<Pregunta> preguntas,
  void Function(String, {String? id}) err,
) {
  final maxUnidades = k.pruebasPorEscalon;
  final unidad = a.unidadDelEscalon;
  if (unidad == null) {
    err('falta "unidad_del_escalon"');
  } else if (unidad < 1 || (maxUnidades != null && unidad > maxUnidades)) {
    err('unidad_del_escalon $unidad está fuera de 1 a ${maxUnidades ?? '?'}');
  }
  if (a.variante == null) err('falta "variante" (a o b)');
  final conAudio = a.conAudio;
  if (conAudio == null) err('falta "con_audio"');

  final m = RegExp(r'^pu-([a-z0-9]+)-u(\d+)-([ab])$').firstMatch(a.id);
  if (m == null) {
    err(
      'el id de una prueba por unidad es pu-<escalón>-u<N>-<a|b>, no "${a.id}"',
    );
  } else {
    if (ranura != null && m.group(1) != ranura) {
      err('el id "${a.id}" no es del escalón $escalon (pu-$ranura-u<N>-<a|b>)');
    }
    if (unidad != null && int.parse(m.group(2)!) != unidad) {
      err(
        'el id "${a.id}" dice la unidad ${m.group(2)} y unidad_del_escalon es $unidad',
      );
    }
    if (a.variante != null && m.group(3) != a.variante) {
      err(
        'el id "${a.id}" dice la variante ${m.group(3)} y variante es ${a.variante}',
      );
    }
  }

  for (final s in a.secciones) {
    if (s.parte != parteDePruebaUnidad) {
      err(
        'la sección es de la parte "${s.parte}" y debe ser "$parteDePruebaUnidad"',
      );
    }
  }

  // Cuántas preguntas y de qué.
  final total = unidades.fold(0, (s, u) => s + contarPreguntas(u));
  final pide = conAudio == false
      ? k.preguntasDePruebaSinAudio
      : k.preguntasDePruebaConAudio;
  if (conAudio != null && pide != null && total != pide) {
    err(
      'la prueba ${conAudio ? 'con' : 'sin'} audio trae $total preguntas y el contrato pide $pide',
    );
  }
  final comp = k.composicionDePrueba;
  if (conAudio != null && comp.isNotEmpty) {
    final reales = _porHabilidad(preguntas);
    final grupos = {for (final g in comp.keys) habilidadDelGrupo(g)};
    for (final e in comp.entries) {
      final hab = habilidadDelGrupo(e.key);
      final quiere = (!conAudio && e.key == 'escucha') ? 0 : e.value;
      final tiene = reales[hab] ?? 0;
      if (tiene != quiere) {
        err(
          'trae $tiene preguntas de $hab y la composición del contrato pide $quiere',
        );
      }
    }
    for (final e in reales.entries) {
      if (!grupos.contains(e.key)) {
        err(
          'trae ${e.value} preguntas de ${e.key}, que no está en la composición del contrato (${grupos.join(', ')})',
        );
      }
    }
  }

  // El audio.
  final audios = [
    for (final u in unidades)
      if (u.estimulo?.tipo == 'audio') u,
  ];
  if (conAudio == true && audios.isEmpty) {
    err('con_audio es true y ninguna unidad trae audio');
  }
  if (conAudio == false && audios.isNotEmpty) {
    err('con_audio es false y la unidad "${audios.first.id}" trae audio');
  }
  final repro = k.reproduccionesDePrueba;
  for (final u in audios) {
    if (repro != null && u.estimulo!.reproducciones != repro) {
      err(
        'el audio de "${u.id}" se oye ${u.estimulo!.reproducciones} veces y el contrato pide $repro',
      );
    }
  }
  for (final u in unidades) {
    if (u.estimulo?.tipo == 'audio') continue;
    for (final q in u.preguntas) {
      if (q.habilidad == 'escucha') {
        err('la pregunta es de escucha y su unidad no tiene audio', id: q.id);
      }
    }
  }
}

/// Lo que una forma comparte con otras del mismo escalón y lo que le falta al
/// escalón.
void _entreFormas(
  Forma a,
  Contexto c,
  ContratoSesion k,
  List<Unidad> unidades,
  List<Hallazgo> h,
) {
  void err(String m) => h.add(error(a, 'V28', m));
  final mismas = [
    for (final o in c.archivos)
      if (o is Forma &&
          o.estado != Estado.retirado &&
          (o.uso == 'prueba_unidad' || o.uso == 'mini') &&
          o.escalon == a.escalon &&
          a.escalon != null)
        o,
  ];
  if (a.uso == 'prueba_unidad') {
    // Dos formas en la misma unidad y variante.
    for (final o in mismas) {
      if (identical(o, a) || o.uso != 'prueba_unidad') continue;
      if (o.unidadDelEscalon == a.unidadDelEscalon &&
          o.variante == a.variante &&
          a.unidadDelEscalon != null) {
        err(
          '"${o.id}" ocupa la misma unidad (${a.unidadDelEscalon}) y variante (${a.variante}) del escalón ${a.escalon}',
        );
      }
    }
    // La b no comparte nada con la a.
    if (a.variante == 'b') {
      for (final o in mismas) {
        if (o.uso != 'prueba_unidad' ||
            o.variante != 'a' ||
            o.unidadDelEscalon != a.unidadDelEscalon) {
          continue;
        }
        for (final msg in _compartido(a, o, c)) {
          err('la forma b comparte con la a ("${o.id}"): $msg');
        }
      }
    }
  } else {
    // Las mini pruebas no repiten preguntas de las pruebas por unidad.
    for (final o in mismas) {
      if (o.uso != 'prueba_unidad') continue;
      for (final msg in _compartido(a, o, c)) {
        err('la mini prueba repite contenido de la prueba "${o.id}": $msg');
      }
    }
  }

  // Lo que le falta al escalón: un solo aviso, en la primera forma (por ruta).
  if (a.escalon == null) return;
  final primera = ([...mismas]..sort((x, y) => x.ruta.compareTo(y.ruta))).first;
  if (!identical(primera, a)) return;
  final pu = [
    for (final o in mismas)
      if (o.uso == 'prueba_unidad') o,
  ];
  final minis = {
    for (final o in mismas)
      if (o.uso == 'mini') o.id,
  };
  final n = k.pruebasPorEscalon;
  final ranura = ranuraDeEscalon(a.escalon!);
  final faltan = <String>[];
  if (n != null) {
    for (var u = 1; u <= n; u++) {
      for (final v in ['a', 'b']) {
        if (!pu.any((o) => o.unidadDelEscalon == u && o.variante == v)) {
          faltan.add('pu-$ranura-u$u-$v');
        }
      }
    }
  }
  for (final s in k.semanasDeMiniPrueba ?? const <int>[]) {
    final id = 'mini-$ranura-s${dosCifras(s)}';
    if (!minis.contains(id)) faltan.add(id);
  }
  if (faltan.isNotEmpty) {
    h.add(
      aviso(
        a,
        'V28',
        'el escalón ${a.escalon} tiene ${pu.length} de ${(n ?? 0) * 2} pruebas por unidad y ${minis.length} de ${(k.semanasDeMiniPrueba ?? const []).length} mini pruebas; faltan: ${faltan.join(', ')}',
      ),
    );
  }
}

/// Lo que dos formas comparten: una unidad, un estímulo o un enunciado.
List<String> _compartido(Forma x, Forma y, Contexto c) {
  final salida = <String>[];
  final ux = _unidadesDe(x, c);
  final uy = _unidadesDe(y, c);
  final idsY = {for (final u in uy) u.id};
  for (final u in ux) {
    if (idsY.contains(u.id)) salida.add('la unidad "${u.id}"');
  }
  // Estímulos y enunciados iguales (de tres palabras o más, normalizados).
  Map<String, String> claves(List<Unidad> us) => {
    for (final u in us)
      for (final t in textosParaOraciones(u))
        for (final o in dividirOraciones(t))
          if (claveDeOracion(o).split(' ').where((p) => p.isNotEmpty).length >=
              3)
            claveDeOracion(o): u.id,
  };
  final kx = claves(ux);
  final ky = claves(uy);
  for (final e in kx.entries) {
    if (ky.containsKey(e.key)) {
      salida.add('«${e.key}» (en "${e.value}" y en "${ky[e.key]}")');
    }
  }
  // Y lo que V19 ya reconoce como repetido (oraciones largas y textos parecidos).
  for (final u in ux) {
    for (final co in c.duplicados.de(u)) {
      if (idsY.contains(co.otro.id)) {
        salida.add('"${u.id}" se parece a "${co.otro.id}" (V19)');
      }
    }
  }
  return salida.toSet().toList();
}

List<Unidad> _unidadesDe(Forma f, Contexto c) => [
  for (final s in f.secciones)
    for (final id in s.unidades)
      if (c.archivo(id) case final Unidad u) u,
];

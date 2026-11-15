import 'lector.dart';
import 'listas.dart';

/// Una opción de respuesta. La primera de la lista es SIEMPRE la correcta.
class Opcion {
  const Opcion({required this.texto, this.porque, this.porqueNo});
  final String texto;
  final String? porque;
  final String? porqueNo;
}

/// Una oración de una pregunta `oracion_omitida`: colocada (con `hueco` y
/// `ancla`) o sobrante.
class OracionOmitida {
  const OracionOmitida({
    required this.texto,
    this.hueco,
    this.ancla,
    this.sobrante = false,
    this.porqueNo,
  });
  final String texto;
  final int? hueco;
  final String? ancla;
  final bool sobrante;
  final String? porqueNo;
}

/// Una palabra de `completar_palabras`.
class Pista {
  const Pista({required this.palabra, this.porque});
  final String palabra;
  final String? porque;
}

class ErrorTipico {
  const ErrorTipico({required this.mal, required this.bien, this.porque});
  final String mal;
  final String bien;
  final String? porque;
}

class Extension {
  const Extension({this.min, this.max, this.unidad});
  final num? min;
  final num? max;
  final String? unidad;
}

/// Elemento de pronunciación (par mínimo, sílaba tónica, frase con nota).
class ElementoPronunciacion {
  const ElementoPronunciacion({required this.texto, this.nota});
  final String texto;
  final String? nota;
}

/// Una pregunta de cualquiera de los 15 tipos de la tabla 4.2.
sealed class Pregunta {
  const Pregunta({
    required this.id,
    required this.habilidad,
    required this.foco,
    required this.porque,
  });

  final String id;
  final String? habilidad;

  /// Foco controlado (V13). En `pronunciacion` el `foco` es texto libre y no
  /// llena este campo.
  final String? foco;

  /// Razón de la respuesta, a nivel de pregunta. En `opcion_multiple` y
  /// `hueco_opciones` la razón de la correcta va en `opciones.first.porque`.
  final String? porque;

  String get tipo;
}

class OpcionMultiple extends Pregunta {
  const OpcionMultiple({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.enunciado,
    required this.opciones,
    this.ordenFijo = false,
    this.correcta,
  });
  final String? enunciado;
  final List<Opcion> opciones;
  final bool ordenFijo;
  final String? correcta;
  @override
  String get tipo => 'opcion_multiple';
}

class HuecoOpciones extends Pregunta {
  const HuecoOpciones({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.hueco,
    required this.opciones,
    this.ordenFijo = false,
    this.correcta,
  });
  final int? hueco;
  final List<Opcion> opciones;
  final bool ordenFijo;
  final String? correcta;
  @override
  String get tipo => 'hueco_opciones';
}

class HuecoAbierto extends Pregunta {
  const HuecoAbierto({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.hueco,
    required this.aceptadas,
    required this.clase,
  });
  final int? hueco;
  final List<String> aceptadas;
  final String? clase;
  @override
  String get tipo => 'hueco_abierto';
}

class FormacionPalabra extends Pregunta {
  const FormacionPalabra({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.hueco,
    required this.base,
    required this.aceptadas,
  });
  final int? hueco;
  final String? base;
  final List<String> aceptadas;
  @override
  String get tipo => 'formacion_palabra';
}

class Transformacion extends Pregunta {
  const Transformacion({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.original,
    required this.clave,
    required this.antes,
    required this.despues,
    required this.aceptadas,
  });
  final String? original;
  final String? clave;
  final String antes;
  final String despues;
  final List<String> aceptadas;
  @override
  String get tipo => 'transformacion';
}

class OracionOmitidaPregunta extends Pregunta {
  const OracionOmitidaPregunta({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.oraciones,
  });
  final List<OracionOmitida> oraciones;
  @override
  String get tipo => 'oracion_omitida';
}

class Correspondencia extends Pregunta {
  const Correspondencia({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.enunciado,
    required this.respuesta,
    required this.evidencia,
  });
  final String? enunciado;
  final String? respuesta;
  final String? evidencia;
  @override
  String get tipo => 'correspondencia';
}

class Emparejar extends Pregunta {
  const Emparejar({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.elemento,
    required this.respuesta,
    required this.evidencia,
  });
  final String? elemento;
  final String? respuesta;
  final String? evidencia;
  @override
  String get tipo => 'emparejar';
}

class CompletarNota extends Pregunta {
  const CompletarNota({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.hueco,
    required this.aceptadas,
  });
  final int? hueco;
  final List<String> aceptadas;
  @override
  String get tipo => 'completar_nota';
}

class CompletarPalabras extends Pregunta {
  const CompletarPalabras({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.pistas,
  });
  final List<Pista> pistas;
  @override
  String get tipo => 'completar_palabras';
}

class OrdenarPalabras extends Pregunta {
  const OrdenarPalabras({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.palabras,
    required this.aceptadas,
  });
  final List<String> palabras;
  final List<String> aceptadas;
  @override
  String get tipo => 'ordenar_palabras';
}

class RespuestaCorta extends Pregunta {
  const RespuestaCorta({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.enunciado,
    required this.aceptadas,
  });
  final String? enunciado;
  final List<String> aceptadas;
  @override
  String get tipo => 'respuesta_corta';
}

class Repetir extends Pregunta {
  const Repetir({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.frases,
  });
  final List<String> frases;
  @override
  String get tipo => 'repetir';
}

class PronunciacionPregunta extends Pregunta {
  const PronunciacionPregunta({
    required super.id,
    required super.habilidad,
    required super.porque,
    required this.focoTexto,
    required this.elementos,
  }) : super(foco: null);
  final String? focoTexto;
  final List<ElementoPronunciacion> elementos;
  @override
  String get tipo => 'pronunciacion';
}

class Produccion extends Pregunta {
  const Produccion({
    required super.id,
    required super.habilidad,
    required super.foco,
    required super.porque,
    required this.modalidad,
    required this.consigna,
    required this.extension,
    required this.puntosObligatorios,
    required this.cotejo,
    required this.modelo,
    required this.erroresTipicos,
  });
  final String? modalidad;
  final String? consigna;
  final Extension? extension;
  final List<String> puntosObligatorios;
  final List<String> cotejo;
  final String? modelo;
  final List<ErrorTipico> erroresTipicos;
  @override
  String get tipo => 'produccion';
}

// ---------------------------------------------------------------------------
// Lectura

List<Opcion> _opciones(Vista v, String k) {
  final salida = <Opcion>[];
  for (final o in v.mapas(k, noVacia: true)) {
    final texto = o.texto('texto');
    if (texto == null) continue;
    salida.add(Opcion(
      texto: texto,
      porque: o.texto('porque', requerido: false),
      porqueNo: o.texto('porque_no', requerido: false),
    ));
  }
  return salida;
}

/// Lee una pregunta. Devuelve null si el tipo no existe (queda un V01).
Pregunta? leerPregunta(Vista v) {
  final crudo = v.datos['id'];
  final id = crudo is String && crudo.isNotEmpty ? crudo : v.id;
  final q = Vista(v.lector, v.datos, v.ruta, id)..texto('id');
  if (!patronId.hasMatch(id)) {
    q.lector.error('${v.ruta}.id', 'el id "$id" debe llevar solo minúsculas, dígitos y guiones', id: id);
  }
  final tipo = q.texto('tipo', en: tiposPregunta);
  if (tipo == null || !tiposPregunta.contains(tipo)) return null;
  final hab = q.texto('habilidad');
  final porque = q.texto('porque', requerido: false);
  // El foco de `pronunciacion` es texto libre; el resto es controlado.
  final foco = tipo == 'pronunciacion' ? null : q.texto('foco', requerido: false);
  switch (tipo) {
    case 'opcion_multiple':
      return OpcionMultiple(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        enunciado: q.texto('enunciado'),
        opciones: _opciones(q, 'opciones'),
        ordenFijo: q.booleano('orden_fijo') ?? false,
        correcta: q.texto('correcta', requerido: false),
      );
    case 'hueco_opciones':
      return HuecoOpciones(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        hueco: q.entero('hueco', requerido: true),
        opciones: _opciones(q, 'opciones'),
        ordenFijo: q.booleano('orden_fijo') ?? false,
        correcta: q.texto('correcta', requerido: false),
      );
    case 'hueco_abierto':
      return HuecoAbierto(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        hueco: q.entero('hueco', requerido: true),
        aceptadas: q.textos('aceptadas'),
        clase: q.texto('clase', requerido: false, en: const ['gramatical']),
      );
    case 'formacion_palabra':
      return FormacionPalabra(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        hueco: q.entero('hueco', requerido: true),
        base: q.texto('base'),
        aceptadas: q.textos('aceptadas'),
      );
    case 'transformacion':
      return Transformacion(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        original: q.texto('original'),
        clave: q.texto('clave'),
        antes: q.texto('antes', requerido: false) ?? '',
        despues: q.texto('despues', requerido: false) ?? '',
        aceptadas: q.textos('aceptadas'),
      );
    case 'oracion_omitida':
      final oraciones = <OracionOmitida>[];
      for (final o in q.mapas('oraciones', noVacia: true)) {
        final texto = o.texto('texto');
        if (texto == null) continue;
        oraciones.add(OracionOmitida(
          texto: texto,
          hueco: o.entero('hueco'),
          ancla: o.texto('ancla', requerido: false),
          sobrante: o.booleano('sobrante') ?? false,
          porqueNo: o.texto('porque_no', requerido: false),
        ));
      }
      return OracionOmitidaPregunta(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        oraciones: oraciones,
      );
    case 'correspondencia':
      return Correspondencia(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        enunciado: q.texto('enunciado'),
        respuesta: q.texto('respuesta'),
        evidencia: q.texto('evidencia', requerido: false),
      );
    case 'emparejar':
      return Emparejar(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        elemento: q.texto('elemento'),
        respuesta: q.texto('respuesta'),
        evidencia: q.texto('evidencia', requerido: false),
      );
    case 'completar_nota':
      return CompletarNota(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        hueco: q.entero('hueco', requerido: true),
        aceptadas: q.textos('aceptadas'),
      );
    case 'completar_palabras':
      final pistas = <Pista>[];
      for (final p in q.mapas('pistas', noVacia: true)) {
        final palabra = p.texto('palabra');
        if (palabra == null) continue;
        pistas.add(Pista(palabra: palabra, porque: p.texto('porque', requerido: false)));
      }
      return CompletarPalabras(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        pistas: pistas,
      );
    case 'ordenar_palabras':
      return OrdenarPalabras(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        palabras: q.textos('palabras', noVacia: true),
        aceptadas: q.textos('aceptadas'),
      );
    case 'respuesta_corta':
      return RespuestaCorta(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        enunciado: q.texto('enunciado'),
        aceptadas: q.textos('aceptadas'),
      );
    case 'repetir':
      return Repetir(
        id: id,
        habilidad: hab,
        foco: foco,
        porque: porque,
        frases: q.textos('frases', noVacia: true),
      );
    case 'pronunciacion':
      return PronunciacionPregunta(
        id: id,
        habilidad: hab,
        porque: porque,
        focoTexto: q.texto('foco'),
        elementos: leerElementos(q, 'elementos'),
      );
    case 'produccion':
      return leerProduccion(q, id, hab, foco, porque);
  }
  return null;
}

List<ElementoPronunciacion> leerElementos(Vista v, String k) {
  final salida = <ElementoPronunciacion>[];
  for (final e in v.mapas(k, noVacia: true)) {
    final t = e.texto('texto');
    if (t == null) continue;
    salida.add(ElementoPronunciacion(texto: t, nota: e.texto('nota', requerido: false)));
  }
  return salida;
}

Produccion leerProduccion(
  Vista q,
  String id,
  String? hab,
  String? foco,
  String? porque,
) {
  final ext = q.mapa('extension');
  final errores = <ErrorTipico>[];
  for (final e in q.mapas('errores_tipicos', requerido: false)) {
    final mal = e.texto('mal');
    final bien = e.texto('bien');
    if (mal == null || bien == null) continue;
    errores.add(ErrorTipico(mal: mal, bien: bien, porque: e.texto('porque', requerido: false)));
  }
  return Produccion(
    id: id,
    habilidad: hab,
    foco: foco,
    porque: porque,
    modalidad: q.texto('modalidad', en: modalidades),
    consigna: q.texto('consigna'),
    extension: ext == null
        ? null
        : Extension(
            min: ext.numero('min'),
            max: ext.numero('max'),
            unidad: ext.texto('unidad', requerido: false, en: unidadesExtension),
          ),
    puntosObligatorios: q.textos('puntos_obligatorios', noVacia: true),
    cotejo: q.textos('cotejo', noVacia: true),
    modelo: q.texto('modelo'),
    erroresTipicos: errores,
  );
}

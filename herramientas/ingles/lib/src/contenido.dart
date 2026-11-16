/// De dónde saca cada comprobación el texto en inglés de un archivo. Hay una
/// lista por propósito, porque cada regla mira cosas distintas:
///
/// | Función | La usa | Qué junta |
/// |---|---|---|
/// | [enunciadosYOpciones] | V17 (idioma) | enunciados y opciones, por separado |
/// | [textosIngles] | V18 (grafías) | todo lo que se escribe en inglés |
/// | [textosParaOraciones] | V19 (repetidos) | estímulo y enunciados, sin opciones |
/// | [textoParaSimilitud] | V19 (repetidos) | el estímulo de una unidad |
///
/// Nunca entran las explicaciones (`porque`, `porque_no`, `evidencia`,
/// `ancla`, `error_comun.porque`, la explicación de la lección): van en español
/// y a menudo citan las dos grafías o frases del texto. Tampoco las `aceptadas`:
/// pueden listar a propósito las dos variantes.
library;

import 'modelo/archivo.dart';
import 'modelo/pregunta.dart';
import 'medidas.dart';

/// Un texto con el id de lo que lo contiene (la pregunta, o la unidad cuando es
/// de la unidad entera).
class Fragmento {
  const Fragmento(this.id, this.texto);
  final String id;
  final String texto;
}

/// Los textos de una pregunta que se escriben en inglés. Con [opciones], también
/// las opciones de respuesta. El material de lectura (`elemento`, oraciones
/// omitidas) se junta aparte, en [materialDeLectura].
List<String> _textosDePregunta(Pregunta q, {required bool opciones}) {
  switch (q) {
    case OpcionMultiple():
      return [
        if (q.enunciado != null) q.enunciado!,
        if (opciones) for (final o in q.opciones) o.texto,
      ];
    case HuecoOpciones():
      return [if (opciones) for (final o in q.opciones) o.texto];
    case Correspondencia():
      return [if (q.enunciado != null) q.enunciado!];
    case RespuestaCorta():
      return [if (q.enunciado != null) q.enunciado!];
    case Transformacion():
      return [
        if (q.original != null) q.original!,
        if (q.antes.isNotEmpty) q.antes,
        if (q.despues.isNotEmpty) q.despues,
      ];
    case OrdenarPalabras():
      return [q.palabras.join(' ')];
    case Repetir():
      return q.frases;
    case PronunciacionPregunta():
      return [for (final e in q.elementos) e.texto];
    case Produccion():
      return [
        if (q.consigna != null) q.consigna!,
        if (q.modelo != null) q.modelo!,
      ];
    default:
      return const [];
  }
}

/// Los enunciados y las opciones de una unidad, cada uno por separado, para
/// comprobar que están en inglés (V17): enunciados, opciones de respuesta,
/// oraciones de la transformación, oraciones disponibles de unas oraciones
/// omitidas, descripciones de un emparejar y los textos y opciones con id de la
/// unidad. El estímulo no entra: un texto largo con nombres propios españoles
/// sumaría falsas alarmas.
List<Fragmento> enunciadosYOpciones(Unidad u) {
  final salida = <Fragmento>[
    for (final t in u.textos)
      if (t.texto != null) Fragmento(u.id, t.texto!),
    for (final o in u.opciones)
      if (o.texto != null) Fragmento(u.id, o.texto!),
  ];
  for (final q in u.preguntas) {
    for (final t in _textosDePregunta(q, opciones: true)) {
      salida.add(Fragmento(q.id, t));
    }
    if (q is Emparejar && q.elemento != null) {
      salida.add(Fragmento(q.id, q.elemento!));
    }
    if (q is OracionOmitidaPregunta) {
      for (final o in q.oraciones) {
        salida.add(Fragmento(q.id, o.texto));
      }
    }
  }
  return salida;
}

/// Todo lo que una unidad o una sesión escribe en inglés (V18): títulos,
/// estímulo (con la voz del narrador), material de lectura, enunciados,
/// opciones, oraciones, frases, ejemplos y tarjetas.
List<String> textosIngles(Archivo a) {
  switch (a) {
    case Unidad():
      final e = a.estimulo;
      return [
        if (e?.titulo != null) e!.titulo!,
        if (e?.texto != null) e!.texto!,
        if (e != null) for (final t in e.guion) t.texto,
        ...materialDeLectura(a),
        for (final q in a.preguntas) ..._textosDePregunta(q, opciones: true),
      ];
    case Sesion():
      return [
        for (final b in a.bloques) ..._textosDeBloque(b, opciones: true),
        for (final t in a.tarjetas) ...[
          if (t.en != null) t.en!,
          if (t.ejemplo != null) t.ejemplo!,
        ],
      ];
    default:
      return const [];
  }
}

/// Los textos en inglés de un bloque de la sesión.
List<String> _textosDeBloque(Bloque b, {required bool opciones}) {
  switch (b) {
    case BloqueLeccion():
      return [
        for (final e in b.ejemplos)
          if (e.en != null) e.en!,
        if (b.errorComun?.mal != null) b.errorComun!.mal!,
        if (b.errorComun?.bien != null) b.errorComun!.bien!,
        for (final q in b.preguntas) ..._textosDePregunta(q, opciones: opciones),
      ];
    case BloquePronunciacion():
      return [for (final e in b.elementos) e.texto];
    case BloqueProduccion():
      return b.tarea == null ? const [] : _textosDePregunta(b.tarea!, opciones: opciones);
    case BloqueTraslado():
      return b.frases;
    default:
      return const [];
  }
}

/// Los textos de una unidad o una sesión de los que se sacan las oraciones para
/// detectar repeticiones entre archivos (V19, regla a): estímulo (en un audio,
/// solo el habla), material de lectura y enunciados, sin las opciones de
/// respuesta. En una sesión, los ejemplos, enunciados, elementos de
/// pronunciación, tarea, frases del traslado y ejemplos de las tarjetas.
List<String> textosParaOraciones(Archivo a) {
  switch (a) {
    case Unidad():
      return [
        ...piezasDeEstimulo(a),
        ...materialDeLectura(a),
        for (final q in a.preguntas) ..._textosDePregunta(q, opciones: false),
      ];
    case Sesion():
      return [
        for (final b in a.bloques) ..._textosDeBloque(b, opciones: false),
        for (final t in a.tarjetas)
          if (t.ejemplo != null) t.ejemplo!,
      ];
    default:
      return const [];
  }
}

/// El texto de una unidad con el que se mide la similitud (V19, regla b): su
/// estímulo (texto, consigna o habla de un audio). Vacío si no tiene.
String textoParaSimilitud(Unidad u) => piezasDeEstimulo(u).join('\n\n');

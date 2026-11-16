/// Lo que se mide de una unidad frente a su contrato: palabras del estímulo,
/// unidades y preguntas que aporta, y cómo se dice un rango. Lo comparten V15,
/// la fidelidad (`fidelidad.dart`) y el informe (`informe.dart`): hay una sola
/// forma de medir.
library;

import 'modelo/archivo.dart';
import 'modelo/estimulo.dart';
import 'modelo/formato.dart';
import 'modelo/pregunta.dart';
import 'texto.dart';

/// Los turnos de habla de un audio: todos menos los del narrador (`N`), que no
/// cuentan para la longitud (formato, sección 6.2, regla 2).
Iterable<Turno> turnosDeHabla(Estimulo e) =>
    e.guion.where((t) => t.voz != 'N');

/// El material de lectura que cuelga de las preguntas y que el contrato mide
/// como parte del estímulo: los textos y las opciones con id de la unidad (los
/// ocho textos de un emparejar, las secciones de una correspondencia), la
/// descripción de cada persona en un emparejar y las oraciones disponibles de
/// unas oraciones omitidas. No son enunciados ni opciones de pregunta: los
/// contratos los cuentan dentro del estímulo (por ejemplo, "texto 479 palabras
/// más siete oraciones 90").
List<String> materialDeLectura(Unidad u) => [
      for (final t in u.textos)
        if (t.texto != null) t.texto!,
      for (final o in u.opciones)
        if (o.texto != null) o.texto!,
      for (final q in u.preguntas) ...[
        if (q is Emparejar && q.elemento != null) q.elemento!,
        if (q is OracionOmitidaPregunta)
          for (final o in q.oraciones) o.texto,
      ],
    ];

/// Las piezas de texto del estímulo de una unidad, tal como las cuenta el
/// contrato: en un texto o una consigna, su texto más el material de lectura;
/// en un audio, solo los turnos de habla. Imagen y ninguno no tienen piezas.
List<String> piezasDeEstimulo(Unidad u) {
  final e = u.estimulo;
  if (e == null) return const [];
  switch (e.tipo) {
    case 'texto':
    case 'consigna':
      return [if (e.texto != null) e.texto!, ...materialDeLectura(u)];
    case 'audio':
      return [for (final t in turnosDeHabla(e)) t.texto];
  }
  return const [];
}

/// Una medida de longitud: las palabras de un estímulo y el id de lo que se
/// midió (la unidad, o la pregunta cuando la oración original de una
/// transformación hace de estímulo).
class Medida {
  const Medida(this.id, this.palabras);
  final String id;
  final int palabras;
}

/// Las palabras de cada estímulo medible de la unidad (V15):
///
/// - texto o consigna: su texto con los números de hueco, más el material de
///   lectura (ver [materialDeLectura]); las palabras cortadas de
///   `completar_palabras` (`la{yer}`) cuentan una vez;
/// - audio: solo los turnos de habla;
/// - ninguno: la oración original de cada transformación, que es lo que el
///   contrato de B2 First mide ("se midió la primera oración de cada ítem");
/// - imagen: nada que medir.
List<Medida> medidasDeEstimulo(Unidad u) {
  final e = u.estimulo;
  if (e == null) return const [];
  switch (e.tipo) {
    case 'texto':
    case 'consigna':
      return [Medida(u.id, contarPalabrasEstimulo(piezasDeEstimulo(u).join('\n\n')))];
    case 'audio':
      return [Medida(u.id, contarPalabras(piezasDeEstimulo(u).join('\n\n')))];
    case 'ninguno':
      return [
        for (final q in u.preguntas)
          if (q is Transformacion && q.original != null)
            Medida(q.id, contarPalabras(q.original!)),
      ];
  }
  return const [];
}

/// Las preguntas del contrato que aporta una pregunta del archivo. Casi todas
/// aportan una; las que reúnen varios huecos aportan uno por hueco: las
/// oraciones omitidas (una por oración colocada, no por sobrante) y completar
/// palabras (una por pista).
int preguntasQueAporta(Pregunta q) => switch (q) {
      OracionOmitidaPregunta() => q.oraciones.where((o) => !o.sobrante).length,
      CompletarPalabras() => q.pistas.length,
      _ => 1,
    };

/// Las preguntas del contrato que aporta una unidad.
int contarPreguntas(Unidad u) =>
    u.preguntas.fold(0, (suma, q) => suma + preguntasQueAporta(q));

/// Las unidades del contrato que aporta un archivo. Un archivo es una unidad
/// con un solo estímulo; con `estimulo: ninguno` (las transformaciones de B2
/// First, las oraciones sueltas de TOEIC) aporta tantas unidades como
/// preguntas lleve (formato, sección 4.2).
int contarUnidades(Unidad u) =>
    u.estimulo?.tipo == 'ninguno' ? contarPreguntas(u) : 1;

/// Las preguntas que pide el contrato a una parte: `preguntas_total` si lo da;
/// si no, unidades por preguntas por unidad. Null si no se puede saber.
Rango? preguntasQuePide(Parte p) {
  if (p.preguntasTotal != null) return p.preguntasTotal;
  final u = p.unidades;
  final por = p.preguntasPorUnidad;
  if (u == null || por == null) return null;
  return Rango(
    min: por.min == null ? null : por.min! * u,
    max: por.max == null ? null : por.max! * u,
  );
}

/// ¿Está [n] dentro del rango? Un extremo ausente no limita.
bool enRango(num n, Rango r) =>
    (r.min == null || n >= r.min!) && (r.max == null || n <= r.max!);

String _numero(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';

/// Dice un rango en español: `300 a 400`, `250` (si los extremos coinciden),
/// `hasta 250` o `desde 25`.
String describirRango(Rango r) {
  final min = r.min;
  final max = r.max;
  if (min != null && max != null) {
    return min == max ? _numero(min) : '${_numero(min)} a ${_numero(max)}';
  }
  if (max != null) return 'hasta ${_numero(max)}';
  if (min != null) return 'desde ${_numero(min)}';
  return 'sin límite';
}

/// El rango de palabras que la parte declara para el estímulo, o null si no
/// declara ninguno. No mira `pendiente`: eso lo decide quien lo usa (un dato
/// pendiente no decide nada, formato 6.2, regla 4).
Rango? rangoDePalabras(Parte p) {
  final r = p.palabrasEstimulo;
  if (r == null || (r.min == null && r.max == null)) return null;
  return r;
}

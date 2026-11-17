import '../contexto.dart';
import '../hallazgo.dart';
import '../medidas.dart';
import '../modelo/archivo.dart';
import '../modelo/formato.dart';
import 'comun.dart';

/// V15 · Palabras del estímulo dentro del rango del contrato de la parte.
///
/// Cuenta como dice [medidasDeEstimulo]: en un texto, sus palabras con los
/// números de hueco; en un audio, solo los turnos de habla (la voz `N` no
/// cuenta); en unas transformaciones, la oración original de cada una. Fuera de
/// rango es un **aviso** en la unidad (y decide la fidelidad de las formas que
/// la usen: la forma queda `reducida`). Si el contrato marca la parte como
/// `pendiente`, el aviso es de "rango pendiente" aunque la cifra quepa: un dato
/// pendiente no decide nada (formato, 6.2, regla 4).
///
/// Con un contrato propio (`palabras_estimulo.por_nivel`) el rango es el de la
/// etapa de la unidad (`nivel`).
///
/// Sin contrato (o con una parte que no existe en él) no dice nada: V02 ya avisa
/// "sin contrato".
List<Hallazgo> v15(Archivo a, Contexto c) {
  if (a is! Unidad) return const [];
  final parte = c.parteDe(a);
  if (parte == null) return const [];
  final medidas = medidasDeEstimulo(a);
  final rango = rangoDePalabras(parte, nivel: a.nivel);

  if (parte.rangoPendiente) {
    return [
      aviso(
        a,
        'V15',
        'rango pendiente: el contrato marca la parte "${parte.id}" como pendiente y no se puede dar por bueno el largo del estímulo'
        '${_detalle(medidas, rango)}',
      ),
    ];
  }
  if (rango == null) {
    // Un contrato por etapa (los propios) sin rango para la etapa de la unidad:
    // no se puede comprobar, y la unidad lo debe saber.
    if (parte.palabrasPorNivel.isNotEmpty && medidas.isNotEmpty) {
      return [
        aviso(
          a,
          'V15',
          'el contrato de "${parte.id}" da rango de palabras por etapa (${parte.palabrasPorNivel.keys.join(', ')}) y la unidad es de ${a.nivel == null ? 'una etapa sin declarar' : 'la etapa ${a.nivel}'}: no se puede comprobar el largo del estímulo',
        ),
      ];
    }
    return const [];
  }

  return [
    for (final m in medidas)
      if (!enRango(m.palabras, rango))
        aviso(
          a,
          'V15',
          '${m.id == a.id ? 'tiene' : 'la oración original tiene'} ${m.palabras} palabras y el contrato de "${parte.id}" pide ${describirRango(rango)}${_origen(rango)}',
          id: m.id,
        ),
  ];
}

String _origen(Rango r) => r.origen == null ? '' : ' (${r.origen})';

/// Lo que se sabe del estímulo de una unidad en una parte pendiente: sus
/// palabras y el rango provisional, si lo hay.
String _detalle(List<Medida> medidas, Rango? rango) {
  final partes = <String>[];
  if (medidas.isNotEmpty) {
    final cifras = [for (final m in medidas) m.palabras]..sort();
    partes.add(cifras.length == 1
        ? 'tiene ${cifras.single} palabras'
        : 'tiene de ${cifras.first} a ${cifras.last} palabras');
  }
  if (rango != null) partes.add('rango provisional: ${describirRango(rango)}');
  return partes.isEmpty ? '' : ' (${partes.join('; ')})';
}

import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/listas.dart';
import 'comun.dart';

/// V16 · Estímulo de audio: voces declaradas de la lista y `reproducciones`
/// igual a las del contrato. Es error.
///
/// Las voces son las de [voces] (`F1`, `F2`, `M1`, `M2` y `N`, el narrador).
/// Ojo: la lectura del archivo ya deja un V01 por cada `voz` fuera de la lista
/// (es una lista controlada, como `nivel` o `estado`) y V16 la comprueba otra
/// vez con su propio código, porque el catálogo la pone aquí; por eso una voz
/// mal escrita sale dos veces, una como V01 (por turno) y otra como V16 (por
/// audio, con todas las voces malas juntas).
///
/// Las reproducciones se comparan con las del contrato solo si la parte las
/// declara. La mitad de V16 que dice "el cuaderno no imprime el guion" es de
/// `exportar` (P1.2c) y no está aquí.
List<Hallazgo> v16(Archivo a, Contexto c) {
  if (a is! Unidad) return const [];
  final e = a.estimulo;
  if (e == null || e.tipo != 'audio') return const [];
  final h = <Hallazgo>[];

  final malas = <String>{
    for (final t in e.guion)
      if (!voces.contains(t.voz)) t.voz,
  };
  if (malas.isNotEmpty) {
    h.add(error(
      a,
      'V16',
      'el guion usa voces que no están declaradas (${malas.join(', ')}); las voces son ${voces.join(', ')}',
    ));
  }

  final parte = c.parteDe(a);
  final pide = parte?.reproducciones;
  if (pide != null && e.reproducciones != null && e.reproducciones != pide) {
    h.add(error(
      a,
      'V16',
      'tiene reproducciones: ${e.reproducciones} y el contrato de "${parte!.id}" pide $pide',
    ));
  }
  return h;
}

import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import 'comun.dart';

/// V16 · Estímulo de audio: `reproducciones` igual a las del contrato de la
/// parte. Es error.
///
/// Las voces fuera de la lista (`F1`, `F2`, `M1`, `M2` y `N`, el narrador) ya
/// las rechaza V01, una vez por turno, al leer el archivo: es una lista
/// controlada, como `nivel` o `estado`. V16 no las repite (en P1.2b sí, y una
/// voz mal escrita salía dos veces).
///
/// Las reproducciones se comparan con las del contrato solo si la parte las
/// declara. La mitad de V16 que dice "el cuaderno no imprime el guion" es de
/// `exportar` (P1.2c-2) y no está aquí.
List<Hallazgo> v16(Archivo a, Contexto c) {
  if (a is! Unidad) return const [];
  final e = a.estimulo;
  if (e == null || e.tipo != 'audio') return const [];
  final h = <Hallazgo>[];

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

import '../contenido.dart';
import '../contexto.dart';
import '../datos/grafias.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../texto.dart';
import 'comun.dart';

/// V18 · No se mezclan grafías británicas y americanas de la lista de control
/// en una unidad. Es aviso. Además, avisa si la `variante` declarada (`en-GB` o
/// `en-US`) no coincide con la grafía dominante.
///
/// Método: se juntan los textos en inglés del archivo (ver [textosIngles]; no
/// entran las explicaciones ni las `aceptadas`) y se cuentan las palabras que
/// están en la lista de `datos/grafias.dart`: las británicas por un lado y las
/// americanas por otro. Con palabras de las dos, es una mezcla. La grafía
/// dominante es la que tiene más apariciones; con un empate no hay dominante. Una
/// palabra con guion (`colour-blind`) se mira entera y, si no está, por partes.
///
/// Se aplica también a las sesiones del curso, que declaran su `variante`.
List<Hallazgo> v18(Archivo a, Contexto c) {
  if (a is! Unidad && a is! Sesion) return const [];
  final variante = switch (a) {
    Unidad() => a.variante,
    Sesion() => a.variante,
    _ => null,
  };

  final britanicas = <String, int>{};
  final americanas = <String, int>{};
  void cuenta(String palabra) {
    if (formasBritanicas.contains(palabra)) {
      britanicas[palabra] = (britanicas[palabra] ?? 0) + 1;
    } else if (formasAmericanas.contains(palabra)) {
      americanas[palabra] = (americanas[palabra] ?? 0) + 1;
    }
  }

  for (final texto in textosIngles(a)) {
    for (final p in palabrasDe(texto)) {
      if (formasBritanicas.contains(p) || formasAmericanas.contains(p) || !p.contains('-')) {
        cuenta(p);
      } else {
        p.split('-').forEach(cuenta);
      }
    }
  }

  final nB = britanicas.values.fold(0, (s, n) => s + n);
  final nA = americanas.values.fold(0, (s, n) => s + n);
  final h = <Hallazgo>[];
  if (nB > 0 && nA > 0) {
    h.add(aviso(
      a,
      'V18',
      'mezcla grafías británicas (${_lista(britanicas)}) y americanas (${_lista(americanas)}): se usa una sola variante',
    ));
  }
  final dominante = nB > nA ? 'en-GB' : (nA > nB ? 'en-US' : null);
  if (dominante != null && variante != null && dominante != variante) {
    final prueba = dominante == 'en-GB' ? britanicas : americanas;
    h.add(aviso(
      a,
      'V18',
      'declara la variante $variante, pero su grafía es ${dominante == 'en-GB' ? 'británica' : 'americana'} (${_lista(prueba)})',
    ));
  }
  return h;
}

/// Las palabras halladas con su número de apariciones: `colour (2), centre`.
String _lista(Map<String, int> m) {
  final palabras = m.keys.toList()..sort();
  final primeras = palabras.take(4).map((p) => m[p]! > 1 ? '$p (${m[p]})' : p);
  final resto = palabras.length - 4;
  return '${primeras.join(', ')}${resto > 0 ? ' y $resto más' : ''}';
}

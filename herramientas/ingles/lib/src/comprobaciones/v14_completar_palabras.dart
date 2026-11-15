import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import '../texto.dart';
import 'comun.dart';

final RegExp _hueco = RegExp(r'([A-Za-z]*)\{([A-Za-z]+)\}');

const int _ocultasMinimas = 2;
const int _ocultasMaximas = 8;
const int _completasPorHueco = 4;

/// Letras que oculta la regla `segunda_mitad`: la segunda mitad de la palabra,
/// la mayor si el número de letras es impar.
int ocultasSegunMitad(int letras) => (letras + 1) ~/ 2;

/// V14 · Completar palabras: cada hueco oculta la segunda mitad de la palabra
/// (la mayor si el número de letras es impar), de 2 a 8 letras, y hay al menos
/// 4 palabras completas por cada hueco.
///
/// La regla de ocultar sale de `ocultar.regla` de la parte del contrato; sin
/// contrato o sin el campo, rige `segunda_mitad` (tabla 4.2). Si el contrato la
/// marca como `pendiente`, se avisa una vez: el criterio es provisional.
List<Hallazgo> v14(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  if (a is! Unidad) return h;
  final preguntas = a.preguntas.whereType<CompletarPalabras>().toList();
  if (preguntas.isEmpty) return h;

  final ocultar = c.parteDe(a)?.ocultar;
  final regla = ocultar?.regla ?? 'segunda_mitad';
  if (regla != 'segunda_mitad') {
    h.add(aviso(a, 'V14', 'el contrato pide la regla de ocultar "$regla", que esta herramienta no conoce: no se comprueba la mitad oculta'));
  }
  if (ocultar?.pendiente ?? false) {
    h.add(aviso(a, 'V14', 'la regla de ocultar es provisional (pendiente en el contrato): falta ver una muestra oficial'));
  }

  final texto = a.estimulo?.tipo == 'texto' ? a.estimulo?.texto : null;
  if (texto == null) {
    h.add(error(a, 'V14', 'completar_palabras necesita un estímulo de texto con los huecos dentro', id: preguntas.first.id));
    return h;
  }
  final huecos = _hueco.allMatches(texto).toList();
  final pistas = [for (final q in preguntas) ...q.pistas];
  final id = preguntas.first.id;

  if (huecos.length != pistas.length) {
    h.add(error(a, 'V14', 'el texto tiene ${huecos.length} huecos y hay ${pistas.length} pistas', id: id));
  }
  for (var i = 0; i < huecos.length; i++) {
    final inicio = huecos[i].group(1)!;
    final oculta = huecos[i].group(2)!;
    final palabra = '$inicio$oculta';
    final n = i + 1;
    if (oculta.length < _ocultasMinimas || oculta.length > _ocultasMaximas) {
      h.add(error(a, 'V14', 'hueco $n ("$palabra"): oculta ${oculta.length} letras y deben ser de $_ocultasMinimas a $_ocultasMaximas', id: id));
    }
    if (regla == 'segunda_mitad' && oculta.length != ocultasSegunMitad(palabra.length)) {
      h.add(error(a, 'V14', 'hueco $n ("$palabra"): oculta ${oculta.length} letras y la segunda mitad de ${palabra.length} son ${ocultasSegunMitad(palabra.length)}', id: id));
    }
    if (i < pistas.length && pistas[i].palabra.toLowerCase() != palabra.toLowerCase()) {
      h.add(error(a, 'V14', 'hueco $n: el texto dice "$palabra" y la pista dice "${pistas[i].palabra}"', id: id));
    }
  }
  final completas = contarPalabras(texto.replaceAll(_hueco, ' '));
  if (huecos.isNotEmpty && completas < _completasPorHueco * huecos.length) {
    h.add(error(a, 'V14', 'hay $completas palabras completas para ${huecos.length} huecos y se piden al menos ${_completasPorHueco * huecos.length} ($_completasPorHueco por hueco)', id: id));
  }
  return h;
}

import '../contenido.dart';
import '../contexto.dart';
import '../datos/palabras_espanolas.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/listas.dart';
import '../texto.dart';
import 'comun.dart';

/// V17 · En las unidades de examen (el formato que no sea `gravity-sesion-60`),
/// los enunciados y las opciones van en inglés. Es error.
///
/// Método: cada enunciado y cada opción (ver [enunciadosYOpciones]) se parte en
/// palabras y se busca cada una en la lista de palabras funcionales del español
/// (`datos/palabras_espanolas.dart`, que documenta qué entra y qué no). Dos o
/// más palabras DISTINTAS de la lista en un mismo texto son un error; una sola
/// no, porque un nombre propio o un préstamo (`El Paso`, `en route`) trae una.
///
/// Segunda señal: una palabra en minúscula con una letra que el inglés casi no
/// usa (á, é, í, ó, ú, ñ) cuenta también, aunque no esté en la lista. Así se
/// detecta un español hecho de palabras de contenido (`la reparación del
/// coche`). Quedan fuera los nombres propios (`José`, por la mayúscula) y los
/// préstamos de [prestamosConTilde] (`café`, `résumé`).
///
/// Las formas de examen no tienen enunciados propios: sus unidades se comprueban
/// una por una. Las sesiones del curso y los audios de traslado (formato
/// `gravity-sesion-60`) se saltan: mezclan español e inglés a propósito.
List<Hallazgo> v17(Archivo a, Contexto c) {
  if (a is! Unidad || a.formato == null || a.formato == formatoSesion) {
    return const [];
  }
  final h = <Hallazgo>[];
  for (final f in enunciadosYOpciones(a)) {
    final halladas = <String>{
      for (final p in palabrasDe(f.texto))
        if (palabrasEspanolas.contains(p)) p,
      ..._conTildeEspanola(f.texto),
    };
    if (halladas.length < 2) continue;
    h.add(error(
      a,
      'V17',
      '«${_resumen(f.texto)}» lleva palabras en español (${halladas.join(', ')}): los enunciados y las opciones de un examen van en inglés',
      id: f.id,
    ));
  }
  return h;
}

final RegExp _tildeEspanola = RegExp(r'[áéíóúñ]');
final RegExp _secuenciaDePalabra = RegExp(r"[\p{L}\p{N}'’\-]+", unicode: true);

/// Las palabras en minúscula con tilde española o eñe, sin los préstamos.
Set<String> _conTildeEspanola(String texto) => {
      for (final m in _secuenciaDePalabra.allMatches(texto))
        if (_tildeEspanola.hasMatch(m[0]!) && _empiezaEnMinuscula(m[0]!))
          m[0]!.toLowerCase(),
    }.difference(prestamosConTilde);

bool _empiezaEnMinuscula(String palabra) {
  final primera = String.fromCharCode(palabra.runes.first);
  return primera == primera.toLowerCase() && primera != primera.toUpperCase();
}

String _resumen(String texto) {
  final plano = texto.replaceAll(RegExp(r'\s+'), ' ').trim();
  return plano.length <= 60 ? plano : '${plano.substring(0, 57)}...';
}

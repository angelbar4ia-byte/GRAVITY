/// Dónde se usa cada unidad: en qué formas y en qué sesiones. Es lo que miran
/// V19 (una unidad en dos formas) y V20 (las unidades reservadas).
library;

import 'modelo/archivo.dart';

/// Los usos de una forma cuyas unidades no se pueden usar en ningún otro lugar
/// (plan, 3.3 y 3.4: la ubicación y las puertas de escalón y de etapa). V20.
const List<String> usosExclusivos = ['ubicacion', 'escalon', 'etapa'];

/// ¿Es una forma de uso exclusivo (ubicación, escalón o etapa)?
bool esExclusiva(Forma f) => usosExclusivos.contains(f.uso);

/// Las unidades que lista una forma, sin repetir y en orden.
List<String> unidadesDeForma(Forma f) => <String>{
      for (final s in f.secciones) ...s.unidades,
    }.toList();

/// Los audios de traslado que lista una sesión, en orden.
List<String> audiosDeSesion(Sesion s) => [
      for (final b in s.bloques)
        if (b is BloqueTraslado) ...b.audios,
    ];

/// Qué formas y qué sesiones usan cada unidad. Una forma o sesión `retirada` no
/// cuenta: ya no se usa.
class UsoDeUnidades {
  UsoDeUnidades(List<Archivo> archivos) {
    for (final a in archivos) {
      if (a.estado == Estado.retirado) continue;
      if (a is Forma) {
        for (final s in a.secciones) {
          for (final id in s.unidades) {
            (_enFormas[id] ??= []).add(a);
          }
        }
      } else if (a is Sesion) {
        for (final id in audiosDeSesion(a)) {
          (_enSesiones[id] ??= []).add(a);
        }
      }
    }
  }

  /// Una entrada por aparición: una forma que lista dos veces la misma unidad
  /// aparece dos veces.
  final Map<String, List<Forma>> _enFormas = {};
  final Map<String, List<Sesion>> _enSesiones = {};

  /// Las formas que listan la unidad, cada una una sola vez.
  List<Forma> formasDe(String id) => _sinRepetir(_enFormas[id] ?? const []);

  /// Cuántas veces lista la forma esta unidad.
  int vecesEn(Forma f, String id) =>
      (_enFormas[id] ?? const <Forma>[]).where((x) => identical(x, f)).length;

  /// Las sesiones que usan la unidad como audio de traslado, cada una una vez.
  List<Sesion> sesionesDe(String id) =>
      _sinRepetir(_enSesiones[id] ?? const []);
}

/// Los mismos archivos, en el mismo orden y sin repetir el mismo objeto.
List<T> _sinRepetir<T extends Archivo>(List<T> archivos) {
  final salida = <T>[];
  for (final a in archivos) {
    if (!salida.any((x) => identical(x, a))) salida.add(a);
  }
  return salida;
}

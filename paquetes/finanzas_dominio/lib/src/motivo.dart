/// El motivo de un movimiento (libro de papá, anulaciones, ajustes y
/// conciliaciones con diferencia) debe tener **al menos 3 caracteres visibles**
/// (endurecimiento de la Fase 1b, N2): se quitan los espacios, tabuladores,
/// saltos de línea, espacios Unicode y caracteres invisibles, y lo que queda
/// no puede ser de uno o dos caracteres. Es el mismo criterio de
/// `fin_motivo_valido` en el servidor; la app lo valida **antes** de mandar
/// para no recibir un 23514 (y menos con un movimiento en la cola sin conexión,
/// que quedaría "requiere atención").
library;

/// Mínimo de caracteres visibles de un motivo.
const minimoCaracteresDeMotivo = 3;

/// Mínimo de letras o dígitos entre esos caracteres (Fase 4, F4-3.1.3).
const minimoLetrasODigitosDeMotivo = 2;

/// Texto de ayuda para mostrar junto al campo del motivo.
const ayudaDelMotivo =
    'Mínimo 3 caracteres, con al menos 2 letras o números (los espacios no '
    'cuentan).';

/// Mensaje cuando un motivo no alcanza.
const mensajeMotivoCorto =
    'El motivo necesita al menos 3 caracteres visibles, con al menos 2 letras '
    'o números y no todos iguales (los espacios no cuentan).';

bool _invisible(int c) =>
    c <= 0x20 || // controles y espacio
    (c >= 0x7F && c <= 0xA0) || // DEL, controles C1 y espacio de no separación
    c == 0x00AD || // guion blando
    c == 0x061C || // marca de letra árabe
    c == 0x115F ||
    c == 0x1160 || // rellenos hangul
    c == 0x1680 || // espacio ogham
    c == 0x180E ||
    (c >= 0x2000 && c <= 0x200F) || // espacios y marcas de ancho cero
    (c >= 0x2028 && c <= 0x202F) || // separadores y marcas de dirección
    (c >= 0x205F && c <= 0x206F) || // espacio medio y formatos invisibles
    c == 0x2800 || // braille en blanco
    c == 0x3000 || // espacio ideográfico
    c == 0x3164 || // relleno hangul
    c == 0xFEFF || // marca de orden de bytes / espacio de ancho cero
    c == 0xFFA0 || // relleno hangul de ancho medio
    (c >= 0xFFF9 && c <= 0xFFFB); // anotaciones interlineales

/// Cuántos caracteres visibles tiene [texto] (los puntos de código que no son
/// espacios ni invisibles).
int caracteresVisibles(String? texto) {
  if (texto == null) return 0;
  var n = 0;
  for (final c in texto.runes) {
    if (!_invisible(c)) n++;
  }
  return n;
}

final _letraODigito = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Los caracteres visibles de [texto], uno por punto de código.
List<String> _visibles(String? texto) => [
  if (texto != null)
    for (final c in texto.runes)
      if (!_invisible(c)) String.fromCharCode(c),
];

/// Cuántos caracteres visibles de [texto] son letras o dígitos.
int letrasODigitos(String? texto) =>
    _visibles(texto).where(_letraODigito.hasMatch).length;

/// `true` si [motivo] es un motivo válido (Fase 4, F4-3.1.3; es la regla de
/// `fin_motivo_valido` en el servidor):
///
/// - al menos [minimoCaracteresDeMotivo] caracteres visibles,
/// - de ellos, al menos [minimoLetrasODigitosDeMotivo] letras o dígitos
///   (`___`, `...` y `---` no valen) y
/// - no todos iguales (`aaa` no vale).
bool motivoValido(String? motivo) {
  final v = _visibles(motivo);
  if (v.length < minimoCaracteresDeMotivo) return false;
  if (v.where(_letraODigito.hasMatch).length < minimoLetrasODigitosDeMotivo) {
    return false;
  }
  return v.toSet().length > 1;
}

/// Dinero en centavos y reglas de redondeo explícitas.
///
/// Convención de GRAVITY (fase-0, sección 4): el dinero se guarda como
/// **enteros en centavos** (`int`), nunca `double`. Moneda MXN.
///
/// ## Regla de redondeo R1
///
/// Toda división de centavos se redondea **al centavo más cercano** y los
/// **medios centavos se alejan de cero** (para montos positivos: "mitad hacia
/// arriba", el redondeo comercial habitual). Ejemplos: 0.5 → 1, 1.5 → 2,
/// 2.5 → 3, −0.5 → −1.
///
/// ## Regla de redondeo R2 (sumas sin redondeos encadenados)
///
/// Los equivalentes semanales se suman **exactos** (como montos anuales en
/// centavos, ver `Equivalente`) y se redondean **una sola vez**, al final.
/// Cuando hay que mostrar los renglones de un total, se reparten con el
/// **método del mayor resto** ([repartirConMayorResto]) para que los
/// renglones sumen exactamente el total redondeado.
library;

/// Puntos base en un 100 %: 10,000 puntos base = 100.00 %.
const int puntosBaseEnCien = 10000;

/// Divide [numerador] entre [denominador] con la regla de redondeo R1
/// (al entero más cercano; los medios se alejan de cero).
int dividirRedondeando(int numerador, int denominador) {
  if (denominador == 0) {
    throw ArgumentError.value(denominador, 'denominador', 'no puede ser cero');
  }
  var n = numerador;
  var d = denominador;
  if (d < 0) {
    n = -n;
    d = -d;
  }
  final cociente = n ~/ d; // trunca hacia cero
  final resto = n.remainder(d); // mismo signo que n
  if (resto.abs() * 2 >= d) {
    return n >= 0 ? cociente + 1 : cociente - 1;
  }
  return cociente;
}

/// Aplica un porcentaje en puntos base a un monto en centavos (R1).
///
/// `aplicarPorcentaje(738462, 2000)` = 20 % de $7,384.62 = 147692 ($1,476.92).
int aplicarPorcentaje(int montoCentavos, int puntosBase) =>
    dividirRedondeando(montoCentavos * puntosBase, puntosBaseEnCien);

/// Proporción `parte / total` expresada en puntos base, redondeada con R1.
///
/// `proporcionEnPuntosBase(152000, 738462)` = 2058 (20.58 %).
/// Si [total] es cero o negativo, devuelve 0.
int proporcionEnPuntosBase(int parte, int total) {
  if (total <= 0) return 0;
  return dividirRedondeando(parte * puntosBaseEnCien, total);
}

/// Compara la proporción exacta `parte / total` contra un umbral en puntos
/// base, sin redondear: devuelve un número negativo, cero o positivo.
///
/// Sirve para los semáforos: el límite se evalúa con la fracción exacta y no
/// con el porcentaje ya redondeado.
int compararProporcion(int parte, int total, int umbralPuntosBase) {
  if (total <= 0) {
    throw ArgumentError.value(total, 'total', 'debe ser mayor que cero');
  }
  return (parte * puntosBaseEnCien).compareTo(umbralPuntosBase * total);
}

/// Reparte el total de varias fracciones `numerador / denominador` en enteros
/// que **suman exactamente** `dividirRedondeando(Σ numeradores, denominador)`
/// (regla R2, método del mayor resto).
///
/// Cada renglón recibe la parte entera de su fracción; los centavos que faltan
/// para llegar al total redondeado se asignan, uno por renglón, a los de
/// **mayor resto**. Los empates se resuelven por el orden de la lista
/// (primero el que aparece antes), para que el resultado sea determinista.
///
/// Los numeradores deben ser cero o positivos.
List<int> repartirConMayorResto(List<int> numeradores, int denominador) {
  if (denominador <= 0) {
    throw ArgumentError.value(denominador, 'denominador', 'debe ser positivo');
  }
  if (numeradores.any((n) => n < 0)) {
    throw ArgumentError('Los numeradores deben ser cero o positivos');
  }
  final suma = numeradores.fold<int>(0, (a, b) => a + b);
  final objetivo = dividirRedondeando(suma, denominador);
  final enteros = [for (final n in numeradores) n ~/ denominador];
  var faltan = objetivo - enteros.fold<int>(0, (a, b) => a + b);
  final indices = List<int>.generate(numeradores.length, (i) => i)
    ..sort((a, b) {
      final porResto = (numeradores[b] % denominador).compareTo(
        numeradores[a] % denominador,
      );
      return porResto != 0 ? porResto : a.compareTo(b);
    });
  for (final i in indices) {
    if (faltan <= 0) break;
    enteros[i] += 1;
    faltan -= 1;
  }
  return enteros;
}

/// Formato de apoyo para mensajes y pruebas: `152000` → `"1,520.00"`.
///
/// La interfaz usa su propio formato de moneda (es_MX); esto no lo sustituye.
String formatearCentavos(int centavos) {
  final negativo = centavos < 0;
  final absoluto = centavos.abs();
  final pesos = (absoluto ~/ 100).toString();
  final resto = (absoluto % 100).toString().padLeft(2, '0');
  final buffer = StringBuffer();
  for (var i = 0; i < pesos.length; i++) {
    if (i > 0 && (pesos.length - i) % 3 == 0) buffer.write(',');
    buffer.write(pesos[i]);
  }
  return '${negativo ? '-' : ''}$buffer.$resto';
}

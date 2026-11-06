/// PBKDF2-HMAC-SHA256 rápido, en Dart puro (RFC 8018), para estirar el PIN.
///
/// Por qué existe: con el PIN de 6 dígitos hay un millón de combinaciones, así
/// que lo único que frena a quien extraiga el almacenamiento es lo caro que sea
/// cada intento (M9' de la revisión de la Fase 1b). Subir las vueltas de 10 000
/// a 100 000 sin que la tablet se vuelva lenta pide una implementación eficiente:
/// el HMAC de `package:crypto` vuelve a procesar el bloque de la llave
/// (`ipad`/`opad`) en cada vuelta, o sea cuatro compresiones de SHA-256 donde
/// bastan dos. Aquí el estado interno tras ese primer bloque se calcula **una
/// sola vez** y cada vuelta cuesta exactamente dos compresiones.
///
/// Es la misma función: el resultado coincide bit a bit con el de la
/// implementación de referencia (`test/nucleo/seguridad/pbkdf2_test.dart`
/// compara con los vectores conocidos y con `package:crypto` sobre entradas al
/// azar). Los hashes y sobres anteriores, hechos con 10 000 vueltas, siguen
/// verificándose: la cuenta de vueltas viaja en cada hash y en cada sobre.
library;

import 'dart:typed_data';

const int _mascara = 0xFFFFFFFF;

/// Raíz entera de [n] con índice [k] (la mayor `r` con `r^k <= n`).
BigInt _raiz(BigInt n, int k) {
  var bajo = BigInt.zero;
  var alto = BigInt.one << ((n.bitLength ~/ k) + 1);
  while (bajo < alto) {
    final medio = (bajo + alto + BigInt.one) >> 1;
    if (medio.pow(k) <= n) {
      bajo = medio;
    } else {
      alto = medio - BigInt.one;
    }
  }
  return bajo;
}

/// Los primeros 64 primos.
List<int> _primos() {
  final primos = <int>[];
  for (var n = 2; primos.length < 64; n++) {
    if (primos.every((p) => n % p != 0)) primos.add(n);
  }
  return primos;
}

/// Constantes de SHA-256 (FIPS 180-4): partes fraccionarias de las raíces
/// cúbicas (K) y cuadradas (H0) de los primeros primos, calculadas con enteros
/// exactos en lugar de copiadas a mano.
final Uint32List _k = () {
  final k = Uint32List(64);
  final dosA96 = BigInt.one << 96;
  final primos = _primos();
  for (var i = 0; i < 64; i++) {
    k[i] = (_raiz(BigInt.from(primos[i]) * dosA96, 3) & BigInt.from(_mascara))
        .toInt();
  }
  return k;
}();

final Uint32List _estadoInicial = () {
  final h = Uint32List(8);
  final dosA64 = BigInt.one << 64;
  final primos = _primos();
  for (var i = 0; i < 8; i++) {
    h[i] = (_raiz(BigInt.from(primos[i]) * dosA64, 2) & BigInt.from(_mascara))
        .toInt();
  }
  return h;
}();

int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & _mascara;

/// Una compresión de SHA-256: mezcla el bloque [w] (16 palabras ya cargadas en
/// las primeras posiciones; el resto es espacio de trabajo de 64) en [h].
void _comprimir(Uint32List h, Uint32List w) {
  for (var i = 16; i < 64; i++) {
    final w15 = w[i - 15];
    final w2 = w[i - 2];
    final s0 = _rotr(w15, 7) ^ _rotr(w15, 18) ^ (w15 >>> 3);
    final s1 = _rotr(w2, 17) ^ _rotr(w2, 19) ^ (w2 >>> 10);
    w[i] = w[i - 16] + s0 + w[i - 7] + s1; // Uint32List corta a 32 bits
  }
  var a = h[0], b = h[1], c = h[2], d = h[3];
  var e = h[4], f = h[5], g = h[6], hh = h[7];
  for (var i = 0; i < 64; i++) {
    final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
    final ch = (e & f) ^ ((~e & _mascara) & g);
    final t1 = (hh + s1 + ch + _k[i] + w[i]) & _mascara;
    final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
    final maj = (a & b) ^ (a & c) ^ (b & c);
    final t2 = (s0 + maj) & _mascara;
    hh = g;
    g = f;
    f = e;
    e = (d + t1) & _mascara;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & _mascara;
  }
  h[0] += a;
  h[1] += b;
  h[2] += c;
  h[3] += d;
  h[4] += e;
  h[5] += f;
  h[6] += g;
  h[7] += hh;
}

void _cargarBloque(Uint32List w, Uint8List bytes, int desde) {
  for (var i = 0; i < 16; i++) {
    final j = desde + i * 4;
    w[i] =
        (bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3];
  }
}

/// Estado de SHA-256 tras procesar un bloque entero ([bloque], 64 bytes).
Uint32List _estadoTrasBloque(Uint8List bloque) {
  final h = Uint32List.fromList(_estadoInicial);
  final w = Uint32List(64);
  _cargarBloque(w, bloque, 0);
  _comprimir(h, w);
  return h;
}

/// SHA-256 de [mensaje] continuando desde [estado] (que ya procesó
/// [bytesPrevios] bytes, múltiplo de 64). Devuelve los 32 bytes.
Uint8List _terminar(Uint32List estado, int bytesPrevios, Uint8List mensaje) {
  final h = Uint32List.fromList(estado);
  final w = Uint32List(64);
  final largoTotal = bytesPrevios + mensaje.length;
  // Relleno: 0x80, ceros y el largo en bits (64 bits, big endian).
  final relleno = (55 - mensaje.length) % 64;
  final cola = Uint8List(mensaje.length + 1 + relleno + 8)
    ..setRange(0, mensaje.length, mensaje);
  cola[mensaje.length] = 0x80;
  final bits = largoTotal * 8;
  for (var i = 0; i < 8; i++) {
    cola[cola.length - 1 - i] = (bits >> (8 * i)) & 0xFF;
  }
  for (var desde = 0; desde < cola.length; desde += 64) {
    _cargarBloque(w, cola, desde);
    _comprimir(h, w);
  }
  return _enBytes(h);
}

Uint8List _enBytes(Uint32List h) {
  final salida = Uint8List(32);
  for (var i = 0; i < 8; i++) {
    salida[i * 4] = h[i] >>> 24;
    salida[i * 4 + 1] = (h[i] >>> 16) & 0xFF;
    salida[i * 4 + 2] = (h[i] >>> 8) & 0xFF;
    salida[i * 4 + 3] = h[i] & 0xFF;
  }
  return salida;
}

/// SHA-256 de [datos] (para llaves de HMAC más largas que un bloque).
Uint8List _sha256(Uint8List datos) => _terminar(_estadoInicial, 0, datos);

/// PBKDF2-HMAC-SHA256 de [clave] con [sal], [vueltas] y [largo] bytes de salida.
Uint8List pbkdf2HmacSha256(
  List<int> clave,
  List<int> sal,
  int vueltas, {
  int largo = 32,
}) {
  if (vueltas < 1) throw ArgumentError.value(vueltas, 'vueltas', 'Mínimo 1');
  if (largo < 1) throw ArgumentError.value(largo, 'largo', 'Mínimo 1');

  // Llave del HMAC: se rellena con ceros a un bloque (o se resume si es larga).
  var llave = Uint8List.fromList(clave);
  if (llave.length > 64) llave = _sha256(llave);
  final ipad = Uint8List(64)..fillRange(0, 64, 0x36);
  final opad = Uint8List(64)..fillRange(0, 64, 0x5c);
  for (var i = 0; i < llave.length; i++) {
    ipad[i] ^= llave[i];
    opad[i] ^= llave[i];
  }
  // El bloque de la llave se procesa una sola vez.
  final estadoInterno = _estadoTrasBloque(ipad);
  final estadoExterno = _estadoTrasBloque(opad);

  final salida = Uint8List(largo);
  final h = Uint32List(8);
  final w = Uint32List(64);
  final sal2 = Uint8List.fromList(sal);

  Uint8List hmac(Uint8List mensaje) {
    final interno = _terminar(estadoInterno, 64, mensaje);
    return _terminar(estadoExterno, 64, interno);
  }

  // Bloque de relleno para un mensaje de 32 bytes tras el bloque de la llave:
  // 0x80, ceros y el largo (64 + 32) * 8 = 768 bits.
  void rellenarDe32(Uint32List w) {
    w[8] = 0x80000000;
    for (var i = 9; i < 15; i++) {
      w[i] = 0;
    }
    w[15] = 768;
  }

  final bloques = (largo + 31) ~/ 32;
  for (var bloque = 1; bloque <= bloques; bloque++) {
    final indice = Uint8List(4)
      ..[0] = bloque >>> 24
      ..[1] = (bloque >>> 16) & 0xFF
      ..[2] = (bloque >>> 8) & 0xFF
      ..[3] = bloque & 0xFF;
    // U1 = HMAC(clave, sal || INT(bloque))
    var u = hmac(Uint8List.fromList([...sal2, ...indice]));
    final t = Uint8List.fromList(u);
    for (var vuelta = 1; vuelta < vueltas; vuelta++) {
      // U = HMAC(clave, U_anterior): dos compresiones, una por cada estado.
      h.setAll(0, estadoInterno);
      for (var i = 0; i < 8; i++) {
        w[i] = (u[i * 4] << 24) |
            (u[i * 4 + 1] << 16) |
            (u[i * 4 + 2] << 8) |
            u[i * 4 + 3];
      }
      rellenarDe32(w);
      _comprimir(h, w);
      // El resultado interno (8 palabras) es el mensaje del HMAC externo.
      for (var i = 0; i < 8; i++) {
        w[i] = h[i];
      }
      rellenarDe32(w);
      h.setAll(0, estadoExterno);
      _comprimir(h, w);
      u = _enBytes(h);
      for (var i = 0; i < 32; i++) {
        t[i] ^= u[i];
      }
    }
    final desde = (bloque - 1) * 32;
    final cuantos = largo - desde < 32 ? largo - desde : 32;
    salida.setRange(desde, desde + cuantos, t);
  }
  return salida;
}

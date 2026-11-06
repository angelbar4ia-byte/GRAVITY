/// Cifrado de textos con una llave derivada del PIN (AES-256-GCM).
///
/// Lo usa la tablet de la casa (D14, revisión de la Fase 0, I6): la credencial
/// del servidor de cada persona se guarda cifrada con su PIN, dentro del
/// almacenamiento seguro, y solo su PIN la libera. El PIN nunca se guarda.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'pin.dart';

/// Llave derivada de un PIN: se conserva en memoria mientras la persona usa
/// la tablet, para volver a cifrar su credencial cuando el servidor la renueva.
class LlavePin {
  LlavePin._(this.sal, this.iteraciones, this._bytes);

  /// Deriva la llave de [pin] con una sal nueva (o la dada).
  factory LlavePin.derivar(
    String pin, {
    List<int>? sal,
    int? iteraciones,
  }) {
    iteraciones ??= HashPin.iteracionesPorDefecto;
    final salUsada = sal ?? HashPin.salAleatoria();
    return LlavePin._(
      List.unmodifiable(salUsada),
      iteraciones,
      Uint8List.fromList(
        HashPin.derivarLlave(pin, salUsada, iteraciones: iteraciones),
      ),
    );
  }

  /// Como [LlavePin.derivar], sin congelar la pantalla (hilo aparte).
  static Future<LlavePin> derivarAsync(
    String pin, {
    List<int>? sal,
    int? iteraciones,
  }) async {
    iteraciones ??= HashPin.iteracionesPorDefecto;
    final salUsada = sal ?? HashPin.salAleatoria();
    final bytes = await HashPin.derivarLlaveAsync(
      pin,
      salUsada,
      iteraciones: iteraciones,
    );
    return LlavePin._(
      List.unmodifiable(salUsada),
      iteraciones,
      Uint8List.fromList(bytes),
    );
  }

  final List<int> sal;
  final int iteraciones;
  final Uint8List _bytes;

  /// Borra la llave de la memoria (en lo posible).
  void olvidar() => _bytes.fillRange(0, _bytes.length, 0);
}

/// Sobre cifrado: `{"v":1,"sal":…,"it":…,"nonce":…,"datos":…}` (base64).
abstract final class CifradoPin {
  static const version = 1;
  static const _bytesNonce = 12;

  /// Cifra [texto] con [llave]. Cada llamada usa un nonce nuevo.
  static String cifrar(LlavePin llave, String texto) {
    final azar = Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(_bytesNonce, (_) => azar.nextInt(256)),
    );
    final datos = _gcm(true, llave._bytes, nonce).process(
      Uint8List.fromList(utf8.encode(texto)),
    );
    return jsonEncode({
      'v': version,
      'sal': base64Encode(llave.sal),
      'it': llave.iteraciones,
      'nonce': base64Encode(nonce),
      'datos': base64Encode(datos),
    });
  }

  /// Descifra [sobre] con [pin]. Devuelve la llave (para volver a cifrar) y
  /// el texto, o `null` si el PIN no corresponde o el sobre está dañado.
  static (LlavePin, String)? descifrar(String pin, String sobre) {
    try {
      final json = (jsonDecode(sobre) as Map).cast<String, Object?>();
      if (json['v'] != version) return null;
      final llave = LlavePin.derivar(
        pin,
        sal: base64Decode(json['sal']! as String),
        iteraciones: json['it']! as int,
      );
      final nonce = base64Decode(json['nonce']! as String);
      final datos = base64Decode(json['datos']! as String);
      final claro = _gcm(false, llave._bytes, nonce).process(datos);
      return (llave, utf8.decode(claro));
    } on InvalidCipherTextException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Como [descifrar], con la derivación del PIN en un hilo aparte.
  static Future<(LlavePin, String)?> descifrarAsync(
    String pin,
    String sobre,
  ) async {
    try {
      final json = (jsonDecode(sobre) as Map).cast<String, Object?>();
      if (json['v'] != version) return null;
      final llave = await LlavePin.derivarAsync(
        pin,
        sal: base64Decode(json['sal']! as String),
        iteraciones: json['it']! as int,
      );
      final nonce = base64Decode(json['nonce']! as String);
      final datos = base64Decode(json['datos']! as String);
      final claro = _gcm(false, llave._bytes, nonce).process(datos);
      return (llave, utf8.decode(claro));
    } on InvalidCipherTextException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static GCMBlockCipher _gcm(bool cifrar, Uint8List llave, Uint8List nonce) =>
      GCMBlockCipher(AESEngine())..init(
        cifrar,
        AEADParameters(KeyParameter(llave), 128, nonce, Uint8List(0)),
      );
}

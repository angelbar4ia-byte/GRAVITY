/// Primitivas de cifrado de los datos sensibles de Hábitos (Fase 3, D13, D21):
/// AES-256-GCM con datos asociados, HKDF-SHA256 y PBKDF2 (en un hilo aparte).
/// Todo con `pointycastle`, ya en el proyecto, y con vectores de prueba
/// conocidos (`test/nucleo/sensibles/cripto_test.dart`).
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../seguridad/pbkdf2.dart';

/// Bytes aleatorios del sistema.
Uint8List bytesAleatorios(int n, [Random? azar]) {
  final r = azar ?? Random.secure();
  return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
}

/// base64url sin relleno.
String aBase64Url(List<int> bytes) =>
    base64UrlEncode(bytes).replaceAll('=', '');

Uint8List desdeBase64Url(String texto) {
  final relleno = '=' * ((4 - texto.length % 4) % 4);
  return Uint8List.fromList(base64Url.decode('$texto$relleno'));
}

/// HKDF-SHA256 (RFC 5869).
Uint8List hkdfSha256(
  List<int> material, {
  required String info,
  List<int> sal = const [],
  int largo = 32,
}) {
  final derivador = HKDFKeyDerivator(SHA256Digest())
    ..init(
      HkdfParameters(
        Uint8List.fromList(material),
        largo,
        sal.isEmpty ? null : Uint8List.fromList(sal),
        Uint8List.fromList(utf8.encode(info)),
      ),
    );
  final salida = Uint8List(largo);
  derivador.deriveKey(null, 0, salida, 0);
  return salida;
}

/// AES-256-GCM. El formato es el de la especificación (4.2):
/// `versión(1 byte) ‖ nonce(12) ‖ texto cifrado ‖ etiqueta(16)`, en base64url.
abstract final class SobreAes {
  static const version = 1;
  static const bytesNonce = 12;
  static const bytesEtiqueta = 16;

  /// Cifra [claro] con [llave] (32 bytes). [datosAsociados] impiden mover un
  /// sobre de lugar (`gravity-hab-v1|persona|tipo|id|revision`). Un nonce
  /// nuevo en cada llamada ([nonce] solo para vectores de prueba).
  static String cifrar(
    List<int> llave,
    List<int> claro, {
    List<int> datosAsociados = const [],
    List<int>? nonce,
  }) => aBase64Url(
    cifrarBytes(llave, claro, datosAsociados: datosAsociados, nonce: nonce),
  );

  static Uint8List cifrarBytes(
    List<int> llave,
    List<int> claro, {
    List<int> datosAsociados = const [],
    List<int>? nonce,
  }) {
    if (llave.length != 32) throw ArgumentError('La llave es de 32 bytes.');
    final iv = Uint8List.fromList(nonce ?? bytesAleatorios(bytesNonce));
    final cifrado = _gcm(
      true,
      llave,
      iv,
      datosAsociados,
    ).process(Uint8List.fromList(claro));
    return Uint8List.fromList([version, ...iv, ...cifrado]);
  }

  /// Descifra; `null` si la llave no corresponde, los datos asociados cambiaron
  /// o el sobre está dañado. Nunca lanza.
  static Uint8List? descifrar(
    List<int> llave,
    String sobre, {
    List<int> datosAsociados = const [],
  }) {
    try {
      return descifrarBytes(
        llave,
        desdeBase64Url(sobre),
        datosAsociados: datosAsociados,
      );
    } catch (_) {
      return null;
    }
  }

  static Uint8List? descifrarBytes(
    List<int> llave,
    Uint8List bytes, {
    List<int> datosAsociados = const [],
  }) {
    try {
      if (llave.length != 32 ||
          bytes.length < 1 + bytesNonce + bytesEtiqueta ||
          bytes[0] != version) {
        return null;
      }
      final iv = bytes.sublist(1, 1 + bytesNonce);
      final cifrado = bytes.sublist(1 + bytesNonce);
      return _gcm(false, llave, iv, datosAsociados).process(cifrado);
    } catch (_) {
      return null;
    }
  }

  static GCMBlockCipher _gcm(
    bool cifrar,
    List<int> llave,
    Uint8List nonce,
    List<int> aad,
  ) => GCMBlockCipher(AESEngine())
    ..init(
      cifrar,
      AEADParameters(
        KeyParameter(Uint8List.fromList(llave)),
        128,
        nonce,
        Uint8List.fromList(aad),
      ),
    );
}

/// Datos asociados de un sobre (`gravity-hab-v1|persona|tipo|id|revision`).
List<int> datosAsociadosDeSobre({
  required String persona,
  required String tipo,
  required String id,
  required int revision,
}) => utf8.encode('gravity-hab-v1|$persona|$tipo|$id|$revision');

/// PBKDF2-HMAC-SHA256 fuera del hilo de la interfaz: 600 000 vueltas (la
/// frase de recuperación) tardan ~1.8 s en una computadora y no deben congelar
/// la pantalla. El mismo hilo aparte sirve para el PIN (ver `pin.dart`).
Future<Uint8List> pbkdf2EnAislado(
  List<int> clave,
  List<int> sal,
  int vueltas, {
  int largo = 32,
}) {
  final c = Uint8List.fromList(clave);
  final s = Uint8List.fromList(sal);
  return Isolate.run(() => pbkdf2HmacSha256(c, s, vueltas, largo: largo));
}

/// Primitivas reales de cifrado de Hábitos (D13/D21): AES-256-GCM, HKDF-SHA256
/// y HMAC-SHA256 con `pointycastle`. El dominio solo define la interfaz.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:pointycastle/export.dart';

class CifradorReal implements Cifrador {
  CifradorReal({Random? azar}) : _azar = azar ?? Random.secure();

  final Random _azar;
  static const _bytesNonce = 12;

  GCMBlockCipher _gcm(bool cifrar, List<int> llave, Uint8List nonce, List<int> aad) =>
      GCMBlockCipher(AESEngine())..init(
        cifrar,
        AEADParameters(KeyParameter(Uint8List.fromList(llave)), 128, nonce,
            Uint8List.fromList(aad)),
      );

  @override
  List<int> cifrar({
    required List<int> llave,
    required List<int> datos,
    required List<int> aad,
  }) {
    if (llave.length != 32) throw ArgumentError('La llave es de 32 bytes.');
    final nonce = Uint8List.fromList(
        List<int>.generate(_bytesNonce, (_) => _azar.nextInt(256)));
    final ct = _gcm(true, llave, nonce, aad).process(Uint8List.fromList(datos));
    return [...nonce, ...ct];
  }

  @override
  List<int> descifrar({
    required List<int> llave,
    required List<int> sobre,
    required List<int> aad,
  }) {
    if (sobre.length < _bytesNonce + 16) {
      throw const FormatException('Sobre demasiado corto.');
    }
    try {
      final nonce = Uint8List.fromList(sobre.sublist(0, _bytesNonce));
      return _gcm(false, llave, nonce, aad)
          .process(Uint8List.fromList(sobre.sublist(_bytesNonce)));
    } on InvalidCipherTextException {
      throw const FormatException('No se pudo abrir el sobre.');
    }
  }

  @override
  List<int> derivar({required List<int> llave, required String info}) {
    final k = HKDFKeyDerivator(SHA256Digest())
      ..init(HkdfParameters(Uint8List.fromList(llave), 32, null,
          Uint8List.fromList(info.codeUnits)));
    return k.process(Uint8List(0));
  }

  /// HKDF con sal e info en bytes (para los vectores de RFC 5869).
  List<int> hkdf(List<int> ikm, List<int> sal, List<int> info, int largo) {
    final k = HKDFKeyDerivator(SHA256Digest())
      ..init(HkdfParameters(Uint8List.fromList(ikm), largo,
          Uint8List.fromList(sal), Uint8List.fromList(info)));
    return k.process(Uint8List(0));
  }

  @override
  List<int> hmac(List<int> llave, List<int> datos) {
    final m = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(Uint8List.fromList(llave)));
    return m.process(Uint8List.fromList(datos));
  }
}

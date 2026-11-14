/// Sobre sellado: cualquiera con la **llave pública** puede meter un texto,
/// pero solo quien tiene la **llave privada** lo abre (ECIES: ECDH P-256 con
/// una llave efímera, HKDF-SHA256 y AES-256-GCM).
///
/// Lo usa la bandeja de salida de la tablet (D14, decisión del 23/oct/2026):
/// al terminar de subir lo pendiente de una persona, la app no puede cifrar su
/// credencial con su PIN (no lo tiene), pero sí **sellarla** con la llave
/// pública que dejó al salir. La llave privada vive cifrada con su PIN
/// (`cifrado.dart`): solo el PIN de la persona la libera y, con ella, abre la
/// credencial. Así, pasada la subida, la credencial no queda utilizable por
/// nadie que no tenga el PIN.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/ecc/ecc_fp.dart' as fp;
import 'package:pointycastle/export.dart';

/// Un par de llaves: la pública (base64 del punto sin comprimir, 65 bytes) y
/// la privada (32 bytes).
class ParDeLlaves {
  const ParDeLlaves(this.publica, this.privada);

  final String publica;
  final Uint8List privada;
}

abstract final class SobreSellado {
  static const version = 1;
  static const _info = 'gravity.bandeja.v1';
  static const _bytesNonce = 12;

  static final ECDomainParameters _curva = ECDomainParameters('secp256r1');

  static SecureRandom _azar() {
    final semilla = Random.secure();
    return FortunaRandom()..seed(
      KeyParameter(
        Uint8List.fromList(List<int>.generate(32, (_) => semilla.nextInt(256))),
      ),
    );
  }

  static Uint8List _enBytes(BigInt valor, int largo) {
    final salida = Uint8List(largo);
    var resto = valor;
    for (var i = largo - 1; i >= 0; i--) {
      salida[i] = (resto & BigInt.from(0xff)).toInt();
      resto = resto >> 8;
    }
    return salida;
  }

  static BigInt _enNumero(List<int> bytes) {
    var valor = BigInt.zero;
    for (final b in bytes) {
      valor = (valor << 8) | BigInt.from(b);
    }
    return valor;
  }

  /// `true` si [punto] es un punto de verdad de P-256: no es el infinito y
  /// cumple `y² = x³ + ax + b (mod p)`. `decodePoint` de pointycastle no lo
  /// comprueba. P-256 tiene cofactor 1, así que estar en la curva basta.
  static bool _estaEnLaCurva(ECPoint? punto) {
    if (punto == null || punto.isInfinity) return false;
    final x = punto.x?.toBigInteger();
    final y = punto.y?.toBigInteger();
    if (x == null || y == null) return false;
    final curva = _curva.curve as fp.ECCurve;
    final p = curva.q!;
    if (x < BigInt.zero || y < BigInt.zero || x >= p || y >= p) return false;
    final a = curva.a!.toBigInteger()!;
    final b = curva.b!.toBigInteger()!;
    final izquierda = (y * y) % p;
    final derecha = (x * x * x + a * x + b) % p;
    return izquierda == derecha;
  }

  static AsymmetricKeyPair<ECPublicKey, ECPrivateKey> _generar() {
    final generador = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(_curva), _azar()));
    final par = generador.generateKeyPair();
    return AsymmetricKeyPair(par.publicKey, par.privateKey);
  }

  /// Genera un par de llaves nuevo.
  static ParDeLlaves generar() {
    final par = _generar();
    return ParDeLlaves(
      base64Encode(par.publicKey.Q!.getEncoded(false)),
      _enBytes(par.privateKey.d!, 32),
    );
  }

  static Uint8List _llaveSimetrica(BigInt secreto, Uint8List efimera) {
    final derivador = HKDFKeyDerivator(SHA256Digest())
      ..init(
        HkdfParameters(
          _enBytes(secreto, 32),
          32,
          efimera,
          Uint8List.fromList(utf8.encode(_info)),
        ),
      );
    final salida = Uint8List(32);
    derivador.deriveKey(null, 0, salida, 0);
    return salida;
  }

  static GCMBlockCipher _gcm(bool cifrar, Uint8List llave, Uint8List nonce) =>
      GCMBlockCipher(AESEngine())..init(
        cifrar,
        AEADParameters(KeyParameter(llave), 128, nonce, Uint8List(0)),
      );

  /// Sella [texto] para quien tenga la llave privada de [clavePublica].
  /// Cada llamada usa una llave efímera y un nonce nuevos.
  static String sellar(String clavePublica, String texto) {
    final ECPoint? punto;
    try {
      punto = _curva.curve.decodePoint(base64Decode(clavePublica));
    } catch (_) {
      throw ArgumentError('La llave pública no es válida.');
    }
    // Un punto fuera de la curva no es un destino: no se cifra a ciegas para él.
    if (!_estaEnLaCurva(punto)) {
      throw ArgumentError('La llave pública no es válida.');
    }
    final destino = ECPublicKey(punto, _curva);
    final efimera = _generar();
    final secreto = (ECDHBasicAgreement()..init(efimera.privateKey))
        .calculateAgreement(destino);
    final efimeraPublica = efimera.publicKey.Q!.getEncoded(false);
    final llave = _llaveSimetrica(secreto, efimeraPublica);
    final azar = Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(_bytesNonce, (_) => azar.nextInt(256)),
    );
    final datos = _gcm(
      true,
      llave,
      nonce,
    ).process(Uint8List.fromList(utf8.encode(texto)));
    llave.fillRange(0, llave.length, 0);
    return jsonEncode({
      'v': version,
      'e': base64Encode(efimeraPublica),
      'nonce': base64Encode(nonce),
      'datos': base64Encode(datos),
    });
  }

  /// Abre [sobre] con [clavePrivada]. `null` si la llave no corresponde o el
  /// sobre está dañado.
  static String? abrir(Uint8List clavePrivada, String sobre) {
    try {
      final json = (jsonDecode(sobre) as Map).cast<String, Object?>();
      if (json['v'] != version) return null;
      final efimeraPublica = base64Decode(json['e']! as String);
      final punto = _curva.curve.decodePoint(efimeraPublica);
      if (!_estaEnLaCurva(punto)) return null;
      final privada = ECPrivateKey(_enNumero(clavePrivada), _curva);
      final secreto = (ECDHBasicAgreement()..init(privada)).calculateAgreement(
        ECPublicKey(punto, _curva),
      );
      final llave = _llaveSimetrica(
        secreto,
        Uint8List.fromList(efimeraPublica),
      );
      final claro = _gcm(
        false,
        llave,
        base64Decode(json['nonce']! as String),
      ).process(base64Decode(json['datos']! as String));
      llave.fillRange(0, llave.length, 0);
      return utf8.decode(claro);
    } catch (_) {
      // Cualquier fallo (llave que no corresponde, sobre alterado o dañado,
      // llave inválida) es lo mismo para quien llama: no se pudo abrir.
      return null;
    }
  }
}

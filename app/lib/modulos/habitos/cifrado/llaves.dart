/// Llave maestra de Hábitos envuelta con la frase (D21, 4.3 de la
/// especificación). El servidor solo guarda lo envuelto (`hab_llaves`).
library;

import 'dart:convert';
import 'dart:math';

import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../nucleo/seguridad/pbkdf2.dart';
import 'frase.dart';

/// Vueltas de PBKDF2 (a medir en el Galaxy A52; se guardan con la llave).
const vueltasPbkdf2 = 600000;

String _b64(List<int> b) => base64Url.encode(b);
List<int> _deb64(String s) => base64Url.decode(s);

/// Lo que se sube a `hab_guardar_llave`.
class LlaveEnvuelta {
  const LlaveEnvuelta({
    required this.version,
    required this.kdf,
    required this.vueltas,
    required this.sal,
    required this.llaveEnvuelta,
  });
  final int version;
  final String kdf;
  final int vueltas;
  final String sal;
  final String llaveEnvuelta;

  Map<String, Object?> aParametros() => {
        'p_version': version,
        'p_kdf': kdf,
        'p_kdf_params': {'vueltas': vueltas},
        'p_sal': sal,
        'p_llave_envuelta': llaveEnvuelta,
      };
}

List<int> _llaveDeFrase(List<String> frase, List<int> sal, int vueltas) =>
    pbkdf2HmacSha256(utf8.encode(normalizarFrase(frase)), sal, vueltas);

List<int> _aad(String persona, int version) =>
    utf8.encode('gravity-hab-v1|llave|$persona|$version');

/// Envuelve [llaveMaestra] (32 bytes) con [frase].
LlaveEnvuelta envolverLlave(
  Cifrador c, {
  required String persona,
  required List<String> frase,
  required List<int> llaveMaestra,
  int version = 1,
  int vueltas = vueltasPbkdf2,
  Random? azar,
}) {
  final r = azar ?? Random.secure();
  final sal = List<int>.generate(16, (_) => r.nextInt(256));
  final kek = _llaveDeFrase(frase, sal, vueltas);
  final env = c.cifrar(llave: kek, datos: llaveMaestra, aad: _aad(persona, version));
  return LlaveEnvuelta(
    version: version,
    kdf: 'pbkdf2-hmac-sha256',
    vueltas: vueltas,
    sal: _b64(sal),
    llaveEnvuelta: _b64(env),
  );
}

/// Desenvuelve la llave maestra; lanza [FormatException] si la frase no es.
List<int> desenvolverLlave(
  Cifrador c, {
  required String persona,
  required List<String> frase,
  required LlaveEnvuelta envuelta,
}) {
  final kek = _llaveDeFrase(frase, _deb64(envuelta.sal), envuelta.vueltas);
  return c.descifrar(
    llave: kek,
    sobre: _deb64(envuelta.llaveEnvuelta),
    aad: _aad(persona, envuelta.version),
  );
}

/// Llaves derivadas de la maestra: por tipo y para los ids (4.2).
List<int> llaveDelTipo(Cifrador c, List<int> maestra, String tipo) =>
    c.derivar(llave: maestra, info: 'gravity-hab/v1/$tipo');
List<int> llaveDeIds(Cifrador c, List<int> maestra) =>
    c.derivar(llave: maestra, info: 'gravity-hab/v1/ids');

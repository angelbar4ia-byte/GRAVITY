/// Llaves de los datos sensibles de Hábitos (Fase 3, D13, D21): la frase de
/// recuperación, la llave maestra envuelta con ella y el almacén seguro donde
/// viven las llaves del equipo.
///
/// - **Frase de 12 palabras** (BIP-39: 128 bits de aleatoriedad + 4 de
///   verificación), generada en el equipo; se confirma con 3 palabras al azar.
/// - **Llave maestra** de 32 bytes, envuelta con AES-256-GCM bajo una llave
///   derivada de la frase con PBKDF2-HMAC-SHA256 de 600 000 vueltas (los
///   parámetros viajan con la envoltura para poder subirlos). El servidor
///   guarda solo la envoltura (`hab_llaves`): sin la frase no la abre.
/// - **Llave local** de 32 bytes, solo en el equipo (modo `solo_telefono`).
/// - Una **llave por tipo** y una **llave de ids**, derivadas con HKDF de la
///   llave del modo.
///
/// Quién puede tener las llaves: el teléfono, la **tablet personal** (con PIN)
/// y la laptop. La **tablet pública de la casa nunca** ([PermisoDeLlaves]).
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../seguridad/almacen_seguro.dart';
import '../seguridad/cifrado.dart';
import 'cripto.dart';
import 'palabras_es.dart';

/// Los dos tipos sensibles (`hab_modos.tipo`).
enum TipoSensible {
  habitosSensibles('habitos_sensibles'),
  diarioOracion('diario_oracion');

  const TipoSensible(this.valor);

  final String valor;
}

/// Dónde vive un tipo.
enum ModoSensible {
  soloTelefono('solo_telefono'),
  nubeCifrada('nube_cifrada');

  const ModoSensible(this.valor);

  final String valor;
}

// ------------------------------------------------------------------- frase

abstract final class FraseDeRecuperacion {
  static const palabras = 12;

  /// 12 palabras al azar con 4 bits de verificación (SHA-256 de la entropía).
  static List<String> generar({Random? azar}) {
    final entropia = bytesAleatorios(16, azar);
    return desdeEntropia(entropia);
  }

  /// La frase de [entropia] (16 bytes). Pública para los vectores de prueba.
  static List<String> desdeEntropia(List<int> entropia) {
    if (entropia.length != 16) throw ArgumentError('La entropía es de 16 bytes.');
    final bits = StringBuffer();
    for (final b in entropia) {
      bits.write(b.toRadixString(2).padLeft(8, '0'));
    }
    final hash = sha256.convert(entropia).bytes.first;
    bits.write(hash.toRadixString(2).padLeft(8, '0').substring(0, 4));
    final cadena = bits.toString();
    return [
      for (var i = 0; i < palabras; i++)
        palabrasEs[int.parse(cadena.substring(i * 11, i * 11 + 11), radix: 2)],
    ];
  }

  /// Minúsculas, sin espacios de más.
  static List<String> normalizar(String texto) => texto
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();

  /// `true` si son 12 palabras de la lista y la verificación coincide.
  static bool esValida(List<String> frase) {
    if (frase.length != palabras) return false;
    final bits = StringBuffer();
    for (final p in frase) {
      final i = palabrasEs.indexOf(p);
      if (i < 0) return false;
      bits.write(i.toRadixString(2).padLeft(11, '0'));
    }
    final cadena = bits.toString();
    final entropia = [
      for (var i = 0; i < 16; i++) int.parse(cadena.substring(i * 8, i * 8 + 8), radix: 2),
    ];
    final esperado = sha256
        .convert(entropia)
        .bytes
        .first
        .toRadixString(2)
        .padLeft(8, '0')
        .substring(0, 4);
    return cadena.substring(128) == esperado;
  }

  /// Tres posiciones distintas, al azar y en orden, para confirmar que la
  /// persona anotó la frase.
  static List<int> posicionesDeConfirmacion({Random? azar, int cuantas = 3}) {
    final r = azar ?? Random.secure();
    final elegidas = <int>{};
    while (elegidas.length < cuantas) {
      elegidas.add(r.nextInt(palabras));
    }
    return elegidas.toList()..sort();
  }

  /// `true` si [respuestas] son las palabras de [frase] en [posiciones].
  static bool confirma(
    List<String> frase,
    List<int> posiciones,
    List<String> respuestas,
  ) {
    if (respuestas.length != posiciones.length) return false;
    for (var i = 0; i < posiciones.length; i++) {
      if (respuestas[i].trim().toLowerCase() != frase[posiciones[i]]) {
        return false;
      }
    }
    return true;
  }
}

// ---------------------------------------------------------------- envoltura

/// La llave maestra envuelta con la frase (fila de `hab_llaves`).
@immutable
class LlaveEnvuelta {
  const LlaveEnvuelta({
    required this.version,
    required this.kdf,
    required this.vueltas,
    required this.sal,
    required this.llaveEnvuelta,
  });

  static const kdfPbkdf2 = 'pbkdf2-sha256';
  static const vueltasPorOmision = 600000;

  final int version;
  final String kdf;
  final int vueltas;
  final String sal;
  final String llaveEnvuelta;

  Map<String, Object?> aJson() => {
    'version': version,
    'kdf': kdf,
    'kdf_params': {'vueltas': vueltas},
    'sal': sal,
    'llave_envuelta': llaveEnvuelta,
  };

  static LlaveEnvuelta? desdeJson(Map<String, Object?> json) {
    try {
      return LlaveEnvuelta(
        version: json['version']! as int,
        kdf: json['kdf']! as String,
        vueltas: (json['kdf_params']! as Map)['vueltas']! as int,
        sal: json['sal']! as String,
        llaveEnvuelta: json['llave_envuelta']! as String,
      );
    } catch (_) {
      return null;
    }
  }

  static List<int> _aad(int version) => utf8.encode('gravity-hab-llave-v1|$version');

  static List<int> _frase(List<String> frase) => utf8.encode(frase.join(' '));

  /// Envuelve [llaveMaestra] con [frase]. PBKDF2 corre en un hilo aparte.
  static Future<LlaveEnvuelta> envolver(
    List<int> llaveMaestra,
    List<String> frase, {
    int version = 1,
    int vueltas = vueltasPorOmision,
    List<int>? sal,
  }) async {
    final salUsada = sal ?? bytesAleatorios(16);
    final llave = await pbkdf2EnAislado(_frase(frase), salUsada, vueltas);
    final envuelta = SobreAes.cifrar(
      llave,
      llaveMaestra,
      datosAsociados: _aad(version),
    );
    llave.fillRange(0, llave.length, 0);
    return LlaveEnvuelta(
      version: version,
      kdf: kdfPbkdf2,
      vueltas: vueltas,
      sal: aBase64Url(salUsada),
      llaveEnvuelta: envuelta,
    );
  }

  /// La llave maestra, o `null` si la frase no corresponde.
  Future<Uint8List?> desenvolver(List<String> frase) async {
    if (kdf != kdfPbkdf2 || vueltas < 1) return null;
    try {
      final llave = await pbkdf2EnAislado(_frase(frase), desdeBase64Url(sal), vueltas);
      final maestra = SobreAes.descifrar(llave, llaveEnvuelta, datosAsociados: _aad(version));
      llave.fillRange(0, llave.length, 0);
      return maestra;
    } catch (_) {
      return null;
    }
  }
}

// ------------------------------------------------------------------ almacén

/// ¿Este equipo puede tener las llaves de Hábitos? La tablet pública de la casa
/// nunca (regla 105 y 111).
typedef PermisoDeLlaves = bool Function();

class LlaveNoPermitida implements Exception {
  const LlaveNoPermitida();

  @override
  String toString() => 'Este equipo no puede guardar las llaves de Hábitos.';
}

/// La llave está protegida con el PIN y todavía no se ha escrito.
class LlaveBloqueada implements Exception {
  const LlaveBloqueada();

  @override
  String toString() => 'Escribe tu PIN para abrir lo reservado.';
}

class LlavesHabitos {
  LlavesHabitos(
    this._almacen, {
    PermisoDeLlaves? permitido,
    this.protegidaConPin = false,
  }) : _permitido = permitido ?? (() => true);

  final AlmacenSeguro _almacen;
  final PermisoDeLlaves _permitido;

  /// Tablet personal y laptop: las llaves van cifradas con el PIN de la
  /// persona (regla 107) y solo se abren mientras está dentro. En el teléfono,
  /// el Keystore y el bloqueo de la sección reservada bastan.
  final bool protegidaConPin;

  // Lo abierto en memoria: persona → clave del almacén → bytes.
  final Map<String, Uint8List> _enMemoria = {};

  static String _claveLocal(String p) => 'hab.llave_local.$p';
  static String _claveMaestra(String p) => 'hab.llave_maestra.$p';

  void _exigirPermiso() {
    if (!_permitido()) throw const LlaveNoPermitida();
  }

  Future<Uint8List?> _leer(String persona, String clave, [String? pin]) async {
    final memoria = _enMemoria['$persona|$clave'];
    if (memoria != null) return memoria;
    final texto = await _almacen.leer(clave);
    if (texto == null) return null;
    if (!protegidaConPin) {
      final bytes = desdeBase64Url(texto);
      _enMemoria['$persona|$clave'] = bytes;
      return bytes;
    }
    if (pin == null) throw const LlaveBloqueada();
    final abierto = CifradoPin.descifrar(pin, texto);
    if (abierto == null) throw const LlaveBloqueada();
    abierto.$1.olvidar();
    final bytes = desdeBase64Url(abierto.$2);
    _enMemoria['$persona|$clave'] = bytes;
    return bytes;
  }

  Future<void> _guardar(String persona, String clave, Uint8List bytes, String? pin) async {
    if (protegidaConPin) {
      if (pin == null) throw const LlaveBloqueada();
      final llave = LlavePin.derivar(pin);
      await _almacen.escribir(clave, CifradoPin.cifrar(llave, aBase64Url(bytes)));
      llave.olvidar();
    } else {
      await _almacen.escribir(clave, aBase64Url(bytes));
    }
    _enMemoria['$persona|$clave'] = bytes;
  }

  /// Tras escribir el PIN (tablet personal, laptop): abre lo guardado en
  /// memoria. Devuelve `false` si el PIN no abre las llaves.
  Future<bool> liberarConPin(String persona, String pin) async {
    _exigirPermiso();
    try {
      for (final clave in [_claveLocal(persona), _claveMaestra(persona)]) {
        await _leer(persona, clave, pin);
      }
      return true;
    } on LlaveBloqueada {
      return false;
    }
  }

  /// Al salir la persona o volver al reposo: nada queda abierto en memoria.
  void olvidarEnMemoria() {
    for (final bytes in _enMemoria.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _enMemoria.clear();
  }

  /// Llave local de [persona]; la crea la primera vez (con [pin] si va
  /// protegida con el PIN).
  Future<Uint8List> llaveLocal(String persona, {String? pin}) async {
    _exigirPermiso();
    final existente = await _leer(persona, _claveLocal(persona), pin);
    if (existente != null) return existente;
    final nueva = bytesAleatorios(32);
    await _guardar(persona, _claveLocal(persona), nueva, pin);
    return nueva;
  }

  /// La llave maestra, o `null` si este equipo no la tiene.
  Future<Uint8List?> llaveMaestra(String persona, {String? pin}) async {
    _exigirPermiso();
    return _leer(persona, _claveMaestra(persona), pin);
  }

  Future<bool> tieneLlaveMaestra(String persona) async =>
      await _almacen.leer(_claveMaestra(persona)) != null;

  Future<void> guardarLlaveMaestra(
    String persona,
    Uint8List llave, {
    String? pin,
  }) async {
    _exigirPermiso();
    await _guardar(persona, _claveMaestra(persona), llave, pin);
  }

  /// Llave del tipo según su modo: local en `solo_telefono`, maestra en
  /// `nube_cifrada` (`HKDF(llave, "gravity-hab/v1/<tipo>")`).
  Future<Uint8List?> llaveDeTipo(
    String persona,
    TipoSensible tipo,
    ModoSensible modo, {
    String? pin,
  }) async {
    final base = modo == ModoSensible.soloTelefono
        ? await llaveLocal(persona, pin: pin)
        : await llaveMaestra(persona, pin: pin);
    return base == null
        ? null
        : hkdfSha256(base, info: 'gravity-hab/v1/${tipo.valor}');
  }

  /// Llave de ids opacos (`HKDF(…, "gravity-hab/v1/ids")`).
  Future<Uint8List?> llaveDeIds(
    String persona,
    ModoSensible modo, {
    String? pin,
  }) async {
    final base = modo == ModoSensible.soloTelefono
        ? await llaveLocal(persona, pin: pin)
        : await llaveMaestra(persona, pin: pin);
    return base == null ? null : hkdfSha256(base, info: 'gravity-hab/v1/ids');
  }

  /// Id opaco de un sobre: primeros 16 bytes de `HMAC-SHA256(llave_de_ids,
  /// tipo ‖ clave_doc)` como uuid. El servidor no puede ligarlo a una fecha.
  static String idOpaco(List<int> llaveDeIds, TipoSensible tipo, String claveDoc) {
    final mac = Hmac(sha256, llaveDeIds).convert(utf8.encode('${tipo.valor}$claveDoc')).bytes;
    final h = mac.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Borra las llaves de [persona] de este equipo (borrar mis datos, baja).
  Future<void> borrar(String persona) async {
    await _almacen.borrar(_claveLocal(persona));
    await _almacen.borrar(_claveMaestra(persona));
    _enMemoria.removeWhere((k, v) => k.startsWith('$persona|'));
  }
}

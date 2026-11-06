/// Sobres cifrados de Hábitos (Fase 3, 4.2): lo único que se guarda en el
/// equipo, en la cola y en el servidor de los datos sensibles. Un sobre es un
/// documento (`config`, `dia:AAAA-MM-DD`, `peticiones:AAAA`…) cifrado con
/// AES-256-GCM; el servidor ve el tipo, el tamaño y la hora de subida, nada más.
///
/// **Nada de texto claro llega a disco, a la cola ni a los registros**: el
/// documento se cifra en memoria ([cifrarDocumento]) y solo el sobre sale de
/// aquí.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../seguridad/almacen_seguro.dart';
import 'cripto.dart';
import 'llaves_habitos.dart';

/// Máximo de un documento cifrado (regla del servidor).
const maximoBytesDeSobre = 64 * 1024;

/// Hasta cuántos sobres lleva una llamada a `hab_subir_sobres`.
const maximoSobresPorLlamada = 50;

@immutable
class Sobre {
  const Sobre({
    required this.id,
    required this.tipo,
    required this.revision,
    required this.cifrado,
    this.llaveVersion = 1,
    this.eliminado = false,
  });

  /// Opaco (HMAC de la llave de ids).
  final String id;
  final TipoSensible tipo;

  /// Sube de 1 en 1 con cada versión.
  final int revision;

  /// base64url de `versión ‖ nonce ‖ cifrado ‖ etiqueta`.
  final String cifrado;
  final int llaveVersion;

  /// Tumba.
  final bool eliminado;

  Map<String, Object?> aJson() => {
    'id': id,
    'tipo': tipo.valor,
    'revision': revision,
    'cifrado': cifrado,
    'llave_version': llaveVersion,
    'eliminado': eliminado,
  };

  static Sobre? desdeJson(Map<String, Object?> json) {
    try {
      final tipo = TipoSensible.values.firstWhere(
        (t) => t.valor == json['tipo'],
      );
      return Sobre(
        id: json['id']! as String,
        tipo: tipo,
        revision: json['revision']! as int,
        cifrado: json['cifrado']! as String,
        llaveVersion: (json['llave_version'] as int?) ?? 1,
        eliminado: (json['eliminado'] as bool?) ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Cifra el [documento] (JSON) de [claveDoc] como la siguiente revisión.
/// Lanza [ArgumentError] si pasa de [maximoBytesDeSobre] (hay que partirlo).
Sobre cifrarDocumento({
  required Uint8List llaveDeTipo,
  required Uint8List llaveDeIds,
  required String persona,
  required TipoSensible tipo,
  required String claveDoc,
  required Map<String, Object?> documento,
  int revisionAnterior = 0,
  int llaveVersion = 1,
}) {
  final id = LlavesHabitos.idOpaco(llaveDeIds, tipo, claveDoc);
  final revision = revisionAnterior + 1;
  final cifrado = SobreAes.cifrar(
    llaveDeTipo,
    utf8.encode(jsonEncode(documento)),
    datosAsociados: datosAsociadosDeSobre(
      persona: persona,
      tipo: tipo.valor,
      id: id,
      revision: revision,
    ),
  );
  if (cifrado.length * 3 ~/ 4 > maximoBytesDeSobre) {
    throw ArgumentError('El documento pasa de 64 KB: hay que partirlo.');
  }
  return Sobre(
    id: id,
    tipo: tipo,
    revision: revision,
    cifrado: cifrado,
    llaveVersion: llaveVersion,
  );
}

/// El documento de [sobre], o `null` si la llave no corresponde, el sobre se
/// movió de lugar o está dañado.
Map<String, Object?>? descifrarDocumento({
  required Uint8List llaveDeTipo,
  required String persona,
  required Sobre sobre,
}) {
  final claro = SobreAes.descifrar(
    llaveDeTipo,
    sobre.cifrado,
    datosAsociados: datosAsociadosDeSobre(
      persona: persona,
      tipo: sobre.tipo.valor,
      id: sobre.id,
      revision: sobre.revision,
    ),
  );
  if (claro == null) return null;
  try {
    return (jsonDecode(utf8.decode(claro)) as Map).cast<String, Object?>();
  } catch (_) {
    return null;
  }
}

/// Los sobres guardados en este equipo (almacenamiento seguro), ya cifrados.
class AlmacenDeSobres {
  AlmacenDeSobres(this._almacen);

  final AlmacenSeguro _almacen;

  static String _prefijo(String persona) => 'hab.sobre.$persona.';
  static String _claveSubidos(String persona) => 'hab.sobres_subidos.$persona';

  Future<void> guardar(String persona, Sobre sobre) => _almacen.escribir(
    '${_prefijo(persona)}${sobre.id}',
    jsonEncode(sobre.aJson()),
  );

  Future<Sobre?> leer(String persona, String id) async {
    final texto = await _almacen.leer('${_prefijo(persona)}$id');
    if (texto == null) return null;
    try {
      return Sobre.desdeJson(
        (jsonDecode(texto) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Sobre>> todos(String persona, {TipoSensible? tipo}) async {
    final lista = <Sobre>[];
    for (final clave in await _almacen.claves()) {
      if (!clave.startsWith(_prefijo(persona))) continue;
      final sobre = await leer(
        persona,
        clave.substring(_prefijo(persona).length),
      );
      if (sobre != null && (tipo == null || sobre.tipo == tipo))
        lista.add(sobre);
    }
    return lista..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Borra los sobres de [persona] (de un [tipo] o todos) de este equipo.
  Future<int> borrar(String persona, {TipoSensible? tipo}) async {
    final borrados = await todos(persona, tipo: tipo);
    for (final sobre in borrados) {
      await _almacen.borrar('${_prefijo(persona)}${sobre.id}');
    }
    final subidos = await _subidos(persona);
    for (final sobre in borrados) {
      subidos.remove(sobre.id);
    }
    await _escribirSubidos(persona, subidos);
    return borrados.length;
  }

  // --- Qué ya se encoló para subir (revisión por sobre).

  Future<Map<String, int>> _subidos(String persona) async {
    final texto = await _almacen.leer(_claveSubidos(persona));
    if (texto == null) return {};
    try {
      return {
        for (final e in (jsonDecode(texto) as Map).entries)
          '${e.key}': e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _escribirSubidos(String persona, Map<String, int> mapa) =>
      mapa.isEmpty
      ? _almacen.borrar(_claveSubidos(persona))
      : _almacen.escribir(_claveSubidos(persona), jsonEncode(mapa));

  /// Los sobres de [tipo] cuya revisión es mayor que la última encolada.
  Future<List<Sobre>> porSubir(String persona, TipoSensible tipo) async {
    final subidos = await _subidos(persona);
    return [
      for (final s in await todos(persona, tipo: tipo))
        if ((subidos[s.id] ?? 0) < s.revision) s,
    ];
  }

  Future<void> marcarEncolados(String persona, List<Sobre> sobres) async {
    final subidos = await _subidos(persona);
    for (final s in sobres) {
      subidos[s.id] = s.revision;
    }
    await _escribirSubidos(persona, subidos);
  }

  /// Olvida lo encolado (p. ej. al cambiar de modo: todo debe volver a subir).
  Future<void> olvidarEncolados(String persona) =>
      _almacen.borrar(_claveSubidos(persona));
}

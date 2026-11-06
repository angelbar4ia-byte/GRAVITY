/// Dónde se guarda el PIN **propio** con el que se vuelven a ver los montos
/// (decisión del 23/oct/2026), compartido entre el controlador de los montos y
/// el del bloqueo del teléfono: al quitar el bloqueo, su PIN pasa a ser el
/// propio de los montos (revisión de la Fase 1b, P1), así que el bloqueo tiene
/// que poder escribirlo sin importar el controlador de los montos (que a su vez
/// depende del bloqueo).
///
/// Va en el almacenamiento seguro, en `montos.config.<personaId>`, junto con el
/// tiempo sin uso (`ocultar_tras_segundos`). Nunca se guarda el PIN, solo su
/// hash con sal.
library;

import 'dart:convert';

import 'almacen_seguro.dart';

/// Clave de la configuración de los montos de [personaId].
String claveConfiguracionMontos(String personaId) => 'montos.config.$personaId';

Map<String, Object?> _leer(String? texto) {
  if (texto == null) return {};
  try {
    return (jsonDecode(texto) as Map).cast<String, Object?>();
  } catch (_) {
    return {};
  }
}

/// Hash del PIN propio de los montos de [personaId], o `null` si no tiene.
Future<String?> leerPinPropioDeMontos(
  AlmacenSeguro almacen,
  String personaId,
) async {
  final hash = _leer(await almacen.leer(claveConfiguracionMontos(personaId)))['hash_pin'];
  return hash is String ? hash : null;
}

/// Guarda (o con `null`, quita) el hash del PIN propio de los montos de
/// [personaId], sin tocar el resto de su configuración.
Future<void> guardarPinPropioDeMontos(
  AlmacenSeguro almacen,
  String personaId,
  String? hash,
) async {
  final clave = claveConfiguracionMontos(personaId);
  final json = _leer(await almacen.leer(clave));
  hash == null ? json.remove('hash_pin') : json['hash_pin'] = hash;
  await almacen.escribir(clave, jsonEncode(json));
}

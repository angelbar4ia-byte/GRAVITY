/// Almacenamiento seguro de llaves, sesiones y PIN (con hash). Se abstrae para
/// poder probarlo sin el dispositivo.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AlmacenSeguro {
  Future<String?> leer(String clave);

  Future<void> escribir(String clave, String valor);

  Future<void> borrar(String clave);

  /// Las claves guardadas (para barrer las copias locales de una baja, ver
  /// `limpieza_local.dart`).
  Future<List<String>> claves();
}

/// Almacén del dispositivo (Keystore en Android, DPAPI en Windows).
class AlmacenSeguroDispositivo implements AlmacenSeguro {
  AlmacenSeguroDispositivo([FlutterSecureStorage? almacen])
    : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  @override
  Future<String?> leer(String clave) => _almacen.read(key: clave);

  @override
  Future<void> escribir(String clave, String valor) =>
      _almacen.write(key: clave, value: valor);

  @override
  Future<void> borrar(String clave) => _almacen.delete(key: clave);

  @override
  Future<List<String>> claves() async => [...(await _almacen.readAll()).keys];
}

/// Almacén en memoria, para pruebas y para el modo demostración.
class AlmacenSeguroEnMemoria implements AlmacenSeguro {
  AlmacenSeguroEnMemoria([Map<String, String>? datos]) : datos = datos ?? {};

  final Map<String, String> datos;

  @override
  Future<String?> leer(String clave) async => datos[clave];

  @override
  Future<void> escribir(String clave, String valor) async =>
      datos[clave] = valor;

  @override
  Future<void> borrar(String clave) async => datos.remove(clave);

  @override
  Future<List<String>> claves() async => [...datos.keys];
}

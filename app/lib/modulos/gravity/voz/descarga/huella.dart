/// sha256 de un archivo, calculado en otro `Isolate` (spec 4.2.2, punto 5):
/// 63 MB de modelo no deben ocupar el hilo de la pantalla.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;

/// Calcula el sha256 (hexadecimal en minúscula) del archivo de [ruta].
typedef CalculadoraDeHuella = Future<String> Function(String ruta);

/// Lee el archivo por trozos (sin cargarlo entero en memoria).
Future<String> huellaSha256(String ruta) async {
  final digest = await crypto.sha256.bind(File(ruta).openRead()).first;
  return digest.toString();
}

/// La de la app: el cálculo corre en un `Isolate`.
Future<String> huellaSha256EnIsolate(String ruta) =>
    Isolate.run(() => huellaSha256(ruta));

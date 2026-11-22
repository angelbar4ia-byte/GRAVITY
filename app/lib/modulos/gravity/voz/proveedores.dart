/// Proveedores del motor de voz: qué fuentes hay en este equipo y el motor.
///
/// La reproducción vive en el proveedor, no en una pantalla (spec 3.4, punto
/// 6): salir de una pantalla no la detiene a menos que la pantalla lo pida.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fuente_de_voz.dart';
import 'fuentes/dispositivo/fuente_dispositivo.dart';
import 'fuentes/dispositivo/puerto_tts.dart';
import 'motor.dart';
import 'preferencias.dart';

/// `true` si este equipo puede usar la voz del dispositivo: Android (teléfono y
/// tablets) y Windows (laptop). En las pruebas (Linux) no hay ninguna fuente y
/// el motor no toca ningún plugin.
bool plataformaConVozDelDispositivo() =>
    !kIsWeb && (Platform.isAndroid || Platform.isWindows);

/// Las fuentes de este equipo. Hoy solo la A; B y C se suman en P3.2a-2 y
/// P3.2a-3. Se sustituye en las pruebas.
final fuentesDeVozProvider = Provider<List<FuenteDeVoz>>(
  (ref) => [
    if (plataformaConVozDelDispositivo()) FuenteDispositivo(PuertoTtsFlutter()),
  ],
);

final motorVozProvider = Provider<MotorVoz>((ref) {
  final motor = MotorDeVoz(
    fuentes: ref.watch(fuentesDeVozProvider),
    // Se lee en cada reproducción: cambiar de persona o de preferencia no
    // reinicia el motor.
    preferencias: () => ref.read(preferenciasVozProvider),
  );
  ref.onDispose(motor.cerrar);
  return motor;
});

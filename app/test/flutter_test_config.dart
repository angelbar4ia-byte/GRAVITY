// Configuración común de las pruebas de la app.
//
// El PIN se estira con 100 000 vueltas de PBKDF2 (M9' de la revisión de la
// Fase 1b), unos 0.3 s por PIN: en las pruebas, que crean cientos, se bajan a 50
// (lo mismo que usan los ayudantes `hashDePrueba` y `almacenConPersonas`). Las
// pruebas que miden el valor de verdad lo piden con
// `HashPin.iteracionesActuales`.
import 'dart:async';

import 'package:gravity/nucleo/seguridad/pin.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HashPin.iteracionesPorDefecto = 50;
  await testMain();
}

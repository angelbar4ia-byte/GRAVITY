/// Una verificación de PIN a la vez.
///
/// Con la derivación en un hilo aparte (D22, 600 000 vueltas), dos toques
/// seguidos al botón "Entrar" empezarían dos verificaciones en paralelo y
/// podrían saltarse la cuenta de intentos fallidos (el bloqueo se revisa antes
/// de calcular). Aquí se ponen en fila: cada una revisa el bloqueo cuando le
/// toca, con los fallos de la anterior ya anotados.
library;

import 'dart:async';

class SerieDePin {
  Future<void> _fila = Future<void>.value();

  /// Corre [accion] cuando terminen las anteriores. Un error no rompe la fila.
  Future<T> correr<T>(Future<T> Function() accion) {
    final resultado = _fila.then((_) => accion());
    _fila = resultado.then<void>((_) {}, onError: (Object _) {});
    return resultado;
  }
}

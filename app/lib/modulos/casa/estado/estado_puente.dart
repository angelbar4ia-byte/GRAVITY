/// Estado del puente de casa (D9) tal como lo ve la app.
///
/// La app **no habla con Home Assistant**: el puente corre en el equipo de la
/// casa, con el token de Home Assistant como secreto de ese equipo, y la app
/// nunca lo conoce (`docs/modulos/casa-puente.md`, sección 4). Lo único que la
/// app puede mostrar es lo que el puente le reporte. Hoy no hay ningún canal
/// de reporte definido (ver la pregunta 1 del reporte F8-7.1), así que la
/// fuente por omisión dice "no configurado" y la pantalla lo muestra sin
/// inventar nada. Cuando exista el canal, se conecta cambiando
/// [fuentePuenteProvider]; la pantalla no cambia.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// En qué punto está el puente.
enum EstadoDelPuente {
  /// Nadie ha configurado el puente (no hay Home Assistant conectado).
  noConfigurado,

  /// Está configurado pero no contesta (apagado, fuera del Wi-Fi de la casa).
  sinRespuesta,

  /// Contesta.
  conectado,
}

/// Lo que se sabe del puente en un momento.
final class InformePuente {
  const InformePuente(this.estado, {this.ultimaRespuesta});

  const InformePuente.noConfigurado()
    : estado = EstadoDelPuente.noConfigurado,
      ultimaRespuesta = null;

  final EstadoDelPuente estado;

  /// Cuándo contestó por última vez (solo si [estado] no es `noConfigurado`).
  final DateTime? ultimaRespuesta;
}

/// De dónde sale el estado del puente. Interfaz para poder simularla.
abstract interface class FuentePuente {
  Future<InformePuente> consultar();
}

/// Por omisión: no hay puente configurado.
final class FuentePuenteNoConfigurada implements FuentePuente {
  const FuentePuenteNoConfigurada();

  @override
  Future<InformePuente> consultar() async =>
      const InformePuente.noConfigurado();
}

/// En memoria, para pruebas y demostraciones: devuelve el informe que se le
/// indique. No toca la red.
final class FuentePuenteEnMemoria implements FuentePuente {
  FuentePuenteEnMemoria(this.informe);

  InformePuente informe;

  @override
  Future<InformePuente> consultar() async => informe;
}

final fuentePuenteProvider = Provider<FuentePuente>(
  (ref) => const FuentePuenteNoConfigurada(),
);

final estadoPuenteProvider = FutureProvider.autoDispose<InformePuente>(
  (ref) => ref.watch(fuentePuenteProvider).consultar(),
);

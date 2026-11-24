/// B1.4 · Clima en cinco casillas (4.3, PB-09). Sin red y sin servicio: la
/// persona abre su app de clima y marca una casilla de un toque. **Ninguna
/// casilla bloquea nada** y el enlace de clima **no** se guarda en la salida
/// (puede incluir un lugar).
library;

import 'mensajes_bici.dart';
import 'tipos_bici.dart';

class RespuestaClima {
  const RespuestaClima({
    required this.clima,
    required this.casilla,
    required this.texto,
    required this.sugiere,
  });

  final ClimaSalida clima;

  /// Etiqueta de la casilla en pantalla.
  final String casilla;

  /// Texto fijo de respuesta.
  final String texto;

  /// «Posible lluvia» y «Mucho calor» sugieren cambiar algo; no obligan.
  final bool sugiere;

  /// Ninguna casilla bloquea nada.
  bool get bloquea => false;
}

/// La respuesta fija de cada casilla (CA-B-09).
RespuestaClima respuestaClima(ClimaSalida c) => switch (c) {
  ClimaSalida.despejado => const RespuestaClima(
    clima: ClimaSalida.despejado,
    casilla: MensajesBici.casillaDespejado,
    texto: MensajesBici.climaBuenDia,
    sugiere: false,
  ),
  ClimaSalida.nublado => const RespuestaClima(
    clima: ClimaSalida.nublado,
    casilla: MensajesBici.casillaNublado,
    texto: MensajesBici.climaBuenDia,
    sugiere: false,
  ),
  ClimaSalida.lluvia => const RespuestaClima(
    clima: ClimaSalida.lluvia,
    casilla: MensajesBici.casillaLluvia,
    texto: MensajesBici.climaLluvia,
    sugiere: true,
  ),
  ClimaSalida.calor => const RespuestaClima(
    clima: ClimaSalida.calor,
    casilla: MensajesBici.casillaCalor,
    texto: MensajesBici.climaCalor,
    sugiere: true,
  ),
  ClimaSalida.frio => const RespuestaClima(
    clima: ClimaSalida.frio,
    casilla: MensajesBici.casillaFrio,
    texto: MensajesBici.climaFrio,
    sugiere: false,
  ),
};

/// Las cinco casillas, en orden.
List<RespuestaClima> casillasDeClima() => [
  for (final c in ClimaSalida.values) respuestaClima(c),
];

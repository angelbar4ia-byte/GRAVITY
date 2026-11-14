/// Coordina traducción, confirmación, ejecución y bitácora.
library;

import 'acciones.dart';
import 'bitacora.dart';
import 'ejecutor.dart';

/// Pide confirmación explícita en pantalla. Devuelve true solo si la persona
/// aceptó.
typedef Confirmador = Future<bool> Function(Accion accion);

class ControlLaptop {
  ControlLaptop({
    required this.ejecutor,
    required this.bitacora,
    required this.confirmar,
    required this.quien,
    this.config = const ConfigControlLaptop(),
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final EjecutorLaptop ejecutor;
  final BitacoraLaptop bitacora;
  final Confirmador confirmar;
  final String quien;
  final ConfigControlLaptop config;
  final DateTime Function() _ahora;

  void _log(String accion, ResultadoBitacora r) => bitacora.registrar(
    EntradaBitacora(
      quien: quien,
      cuando: _ahora(),
      accion: accion,
      resultado: r,
    ),
  );

  /// Procesa una orden. Devuelve null si no se ejecutó.
  Future<ResultadoEjecucion?> procesar(OrdenAsistente orden) async {
    final t = traducirOrden(orden, config: config);
    switch (t) {
      case NoPermitida():
        _log(orden.herramienta, ResultadoBitacora.noPermitida);
        return null;
      case Vetada():
        _log(orden.herramienta, ResultadoBitacora.vetada);
        return null;
      case Permitida(:final accion):
        if (accion.requiereConfirmacion && !await confirmar(accion)) {
          _log(accion.tipo, ResultadoBitacora.noConfirmada);
          return null;
        }
        final r = await ejecutor.ejecutar(accion);
        _log(
          accion.tipo,
          r.exito ? ResultadoBitacora.ejecutada : ResultadoBitacora.fallida,
        );
        return r;
    }
  }
}

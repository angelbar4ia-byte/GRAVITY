/// Proveedores de Riverpod para la sesión.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sesion.dart';

/// Servicio de sesión. Se fija en el arranque (`app/arranque.dart`) y en las
/// pruebas con `servicioSesionProvider.overrideWithValue(...)`.
final servicioSesionProvider = Provider<ServicioSesion>(
  (ref) => throw UnimplementedError(
    'servicioSesionProvider se configura en el arranque o en la prueba',
  ),
);

/// Sesión abierta en el dispositivo (o `null`).
final sesionActualProvider = NotifierProvider<NotificadorSesion, Sesion?>(
  NotificadorSesion.new,
);

class NotificadorSesion extends Notifier<Sesion?> {
  @override
  Sesion? build() {
    final servicio = ref.watch(servicioSesionProvider);
    final suscripcion = servicio.cambios.listen((sesion) => state = sesion);
    ref.onDispose(suscripcion.cancel);
    return servicio.sesionActual;
  }
}

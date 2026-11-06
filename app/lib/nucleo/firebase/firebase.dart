/// Firebase (D7): solo en Android y solo si el dueño agregó
/// `android/app/google-services.json` (ignorado por git). Sin configuración
/// no se inicializa y la app sigue normal.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EstadoFirebase {
  /// No es Android (laptop Windows): Firebase no se usa.
  noAplica,

  /// Android sin `google-services.json`: avisos, fallas y reparto apagados.
  sinConfiguracion,

  /// Inicializado.
  activo,
}

/// Inicializa Firebase si aplica. [inicializar] se inyecta en las pruebas.
Future<EstadoFirebase> prepararFirebase({
  required TargetPlatform plataforma,
  Future<void> Function()? inicializar,
}) async {
  if (plataforma != TargetPlatform.android) return EstadoFirebase.noAplica;
  try {
    await (inicializar ?? Firebase.initializeApp)();
    return EstadoFirebase.activo;
  } catch (error) {
    debugPrint('Firebase sin configuración; sigue apagado: $error');
    return EstadoFirebase.sinConfiguracion;
  }
}

/// Estado de Firebase tras el arranque (se muestra en Ajustes › Notificaciones).
final estadoFirebaseProvider = Provider<EstadoFirebase>(
  (ref) => EstadoFirebase.noAplica,
);

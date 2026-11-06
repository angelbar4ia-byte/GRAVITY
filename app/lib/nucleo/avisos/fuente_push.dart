/// Lo que la app necesita de Firebase Cloud Messaging, detrás de una interfaz.
/// Fase 2, D20: por Firebase solo viaja `{v, id}` (un identificador opaco).
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Un mensaje de FCM ya validado: la versión y el id del aviso.
@immutable
class MensajePush {
  const MensajePush(this.id);

  final String id;

  /// Acepta solo `{v: "1", id: <uuid>}`. Cualquier otra cosa se ignora: nunca
  /// se confía en texto que llegue por la red para mostrarlo.
  static MensajePush? desdeDatos(Map<String, Object?> datos) {
    if ('${datos['v']}' != '1') return null;
    final id = datos['id'];
    if (id is! String) return null;
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuid.hasMatch(id) ? MensajePush(id) : null;
  }
}

abstract interface class FuentePush {
  /// Token de este equipo, o `null` si no hay (sin Firebase o sin permiso).
  Future<String?> token();

  /// Cuando Firebase cambia el token.
  Stream<String> get renovaciones;

  /// Mensajes con la app abierta.
  Stream<MensajePush> get mensajes;

  /// Mensaje que abrió la app al tocar una notificación del sistema.
  Future<MensajePush?> mensajeInicial();

  /// Borra el token (al cerrar sesión): deja de recibir.
  Future<void> olvidarToken();
}

/// Sin Firebase (laptop, o Android sin configuración): no hay push.
class FuentePushNula implements FuentePush {
  const FuentePushNula();

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get renovaciones => const Stream.empty();

  @override
  Stream<MensajePush> get mensajes => const Stream.empty();

  @override
  Future<MensajePush?> mensajeInicial() async => null;

  @override
  Future<void> olvidarToken() async {}
}

/// Simulada para las pruebas.
class FuentePushFalsa implements FuentePush {
  String? tokenActual = 'token-de-prueba';
  final _renovaciones = StreamController<String>.broadcast();
  final _mensajes = StreamController<MensajePush>.broadcast();
  MensajePush? inicial;
  int vecesOlvidar = 0;

  void renovar(String token) {
    tokenActual = token;
    _renovaciones.add(token);
  }

  /// Entrega un mensaje con los datos tal cual llegarían de FCM.
  void recibir(Map<String, Object?> datos) {
    final mensaje = MensajePush.desdeDatos(datos);
    if (mensaje != null) _mensajes.add(mensaje);
  }

  @override
  Future<String?> token() async => tokenActual;

  @override
  Stream<String> get renovaciones => _renovaciones.stream;

  @override
  Stream<MensajePush> get mensajes => _mensajes.stream;

  @override
  Future<MensajePush?> mensajeInicial() async => inicial;

  @override
  Future<void> olvidarToken() async {
    vecesOlvidar++;
    tokenActual = null;
  }
}

/// FCM de verdad (solo Android con `google-services.json`). No se puede probar
/// sin dispositivo.
///
/// Usa `getToken`/`onTokenRefresh`/`deleteToken`, que `firebase_messaging` 17
/// marca como obsoletos a favor de `register()` y `onRegistered` (que entregan
/// un *Firebase Installation ID* para envío directo). La Edge Function
/// `enviar-avisos` manda por FCM HTTP v1 a un **token de registro**, así que
/// se queda con lo que ese envío entiende. Pregunta abierta para backend:
/// si el envío acepta el FID, se cambia aquí y en ningún otro lado.
class FuentePushFirebase implements FuentePush {
  FuentePushFirebase({FirebaseMessaging? mensajeria})
    : _fcm = mensajeria ?? FirebaseMessaging.instance;

  final FirebaseMessaging _fcm;

  @override
  Future<String?> token() async {
    try {
      // ignore: deprecated_member_use
      return await _fcm.getToken();
    } catch (error) {
      debugPrint('Sin token de FCM: $error');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get renovaciones => _fcm.onTokenRefresh;

  @override
  Stream<MensajePush> get mensajes => FirebaseMessaging.onMessage
      .map((m) => MensajePush.desdeDatos(m.data.cast<String, Object?>()))
      .where((m) => m != null)
      .cast<MensajePush>();

  @override
  Future<MensajePush?> mensajeInicial() async {
    final inicial = await _fcm.getInitialMessage();
    return inicial == null
        ? null
        : MensajePush.desdeDatos(inicial.data.cast<String, Object?>());
  }

  @override
  Future<void> olvidarToken() async {
    try {
      // ignore: deprecated_member_use
      await _fcm.deleteToken();
    } catch (error) {
      debugPrint('No se pudo borrar el token de FCM: $error');
    }
  }
}

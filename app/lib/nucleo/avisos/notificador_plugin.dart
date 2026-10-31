/// [NotificadorLocal] con `flutter_local_notifications` (Android y Windows).
///
/// No se puede probar sin un dispositivo: las pruebas usan
/// [NotificadorEnMemoria]. Aquí solo hay traducción a la biblioteca.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdatos;
import 'package:timezone/timezone.dart' as tz;

import 'catalogo_avisos.dart';
import 'notificador.dart';

/// Identificador de la app para el aviso de Windows (laptop). Fijo: lo usa el
/// sistema para agrupar las notificaciones de GRAVITY.
const _appUserModelId = 'mx.segundocerebro.Gravity';
const _guidWindows = '5e1c0a37-8b6f-4f0d-9a41-3c6b7d2e9a10';

class NotificadorPlugin implements NotificadorLocal {
  NotificadorPlugin({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _listo = false;

  @override
  Future<void> iniciar({void Function(String? carga)? alTocar}) async {
    if (_listo) return;
    tzdatos.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: 'GRAVITY',
          appUserModelId: _appUserModelId,
          guid: _guidWindows,
        ),
      ),
      onDidReceiveNotificationResponse: (respuesta) =>
          alTocar?.call(respuesta.payload),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      for (final canal in CanalAviso.values) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            canal.id,
            canal.nombre,
            importance: switch (canal) {
              CanalAviso.urgentes || CanalAviso.avisos => Importance.high,
              CanalAviso.informativos => Importance.defaultImportance,
              CanalAviso.resumen => Importance.low,
            },
            playSound: canal != CanalAviso.informativos &&
                canal != CanalAviso.resumen,
            enableVibration: canal == CanalAviso.urgentes ||
                canal == CanalAviso.avisos,
            // Vibración doble larga (urgentes) y corta (avisos).
            vibrationPattern: switch (canal) {
              CanalAviso.urgentes => Int64List.fromList([0, 600, 200, 600]),
              CanalAviso.avisos => Int64List.fromList([0, 250]),
              _ => null,
            },
          ),
        );
      }
    }
    _listo = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> permisoConcedido() async {
    final android = _android;
    if (android == null) return true; // Windows no pide permiso.
    return await android.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> pedirPermiso() async {
    final android = _android;
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  NotificationDetails _detalles(NotificacionLocal n) => NotificationDetails(
    android: AndroidNotificationDetails(
      n.canal.id,
      n.canal.nombre,
      importance: n.canal == CanalAviso.resumen
          ? Importance.low
          : Importance.high,
      priority: Priority.high,
      playSound: n.sonar,
      enableVibration: n.sonar,
      // Pantalla bloqueada PRIVATE: los equipos que la respetan ven la versión
      // pública y no el título (regla 46).
      visibility: NotificationVisibility.private,
      ticker: textoAvisoPublico,
    ),
    windows: const WindowsNotificationDetails(),
  );

  @override
  Future<void> mostrar(NotificacionLocal notificacion) => _plugin.show(
    id: notificacion.id,
    title: notificacion.titulo,
    body: notificacion.cuerpo.isEmpty ? null : notificacion.cuerpo,
    notificationDetails: _detalles(notificacion),
    payload: notificacion.carga,
  );

  @override
  Future<void> programar(
    NotificacionLocal notificacion,
    DateTime cuando, {
    required String zona,
  }) async {
    final ubicacion = tz.getLocation(zona);
    final fecha = tz.TZDateTime.from(cuando, ubicacion);
    if (!fecha.isAfter(tz.TZDateTime.now(ubicacion))) return;
    await _plugin.zonedSchedule(
      id: notificacion.id,
      title: notificacion.titulo,
      scheduledDate: fecha,
      notificationDetails: _detalles(notificacion),
      // Inexacta: no se pide el permiso de alarmas exactas (regla 45).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notificacion.carga,
    );
  }

  @override
  Future<void> cancelar(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelarProgramadas() => _plugin.cancelAllPendingNotifications();
}

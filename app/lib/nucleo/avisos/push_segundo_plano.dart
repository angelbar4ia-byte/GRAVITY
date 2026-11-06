/// Mensaje de FCM con la app cerrada o en segundo plano (Android).
///
/// Corre en un *isolate* aparte, sin la sesión ni Riverpod de la app: ahí solo
/// se puede mostrar el aviso **genérico** (*"Tienes un aviso de GRAVITY"*),
/// que es lo que prevé la regla 43 cuando no se puede leer el aviso. Al abrir
/// la app, la bandeja trae el aviso real y los recordatorios locales cubren los
/// vencimientos con su texto de catálogo. Leer el aviso desde aquí exigiría
/// reiniciar Supabase en el isolate con la sesión guardada; queda como mejora.
///
/// No se puede probar sin dispositivo.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'catalogo_avisos.dart';
import 'fuente_push.dart';
import 'notificador.dart';
import 'notificador_plugin.dart';

@pragma('vm:entry-point')
Future<void> manejadorPushSegundoPlano(RemoteMessage mensaje) async {
  // Solo se atiende lo que tiene la forma `{v, id}`; nada más se muestra.
  if (MensajePush.desdeDatos(mensaje.data.cast<String, Object?>()) == null) {
    return;
  }
  try {
    await Firebase.initializeApp();
    final notificador = NotificadorPlugin();
    await notificador.iniciar();
    if (!await notificador.permisoConcedido()) return;
    await notificador.mostrar(
      NotificacionLocal(
        id: idNotificacionGenerica,
        titulo: textoAvisoGenerico,
        canal: CanalAviso.avisos,
      ),
    );
  } catch (error) {
    debugPrint('Aviso en segundo plano: $error');
  }
}

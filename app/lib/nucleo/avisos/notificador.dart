/// Notificaciones del sistema (Android y Windows) detrás de una interfaz, para
/// poder simularlas en las pruebas. Fase 2, D20.
library;

import 'package:flutter/foundation.dart';

import 'catalogo_avisos.dart';

/// Una notificación local. El cuerpo va **siempre vacío** (regla 42): el
/// detalle solo está dentro de la app.
@immutable
class NotificacionLocal {
  const NotificacionLocal({
    required this.id,
    required this.titulo,
    required this.canal,
    this.sonar = true,
    this.carga,
  }) : cuerpo = '';

  /// Hash de la `clave` del aviso ([idDeNotificacion]).
  final int id;
  final String titulo;
  final String cuerpo;
  final CanalAviso canal;

  /// `false` en las horas silenciosas y en lo agrupado: llega sin sonido ni
  /// vibración.
  final bool sonar;

  /// Qué abrir al tocarla (el id del aviso), nunca texto del aviso.
  final String? carga;
}

abstract interface class NotificadorLocal {
  /// Prepara los canales y la devolución de llamada al tocar una notificación
  /// ([alTocar] recibe la `carga`).
  Future<void> iniciar({void Function(String? carga)? alTocar});

  /// `true` si el sistema deja mostrar notificaciones (Android 13 o más pide
  /// `POST_NOTIFICATIONS`).
  Future<bool> permisoConcedido();

  /// Pide el permiso. Solo se llama **al activar los avisos**, tras explicarlo.
  Future<bool> pedirPermiso();

  /// Muestra ya. Si ya hay una con el mismo id, la reemplaza.
  Future<void> mostrar(NotificacionLocal notificacion);

  /// Programa para [cuando] (alarma inexacta: no pide permiso de alarmas
  /// exactas). [zona] es el nombre IANA de la zona horaria de la persona.
  Future<void> programar(
    NotificacionLocal notificacion,
    DateTime cuando, {
    required String zona,
  });

  Future<void> cancelar(int id);

  /// Cancela todo lo programado (se reprograma desde cero).
  Future<void> cancelarProgramadas();
}

/// Registro de lo que se pidió mostrar o programar (pruebas y modo demostración).
class NotificadorEnMemoria implements NotificadorLocal {
  NotificadorEnMemoria({this.permiso = true});

  bool permiso;
  int vecesPedirPermiso = 0;
  void Function(String? carga)? _alTocar;

  /// Lo visible ahora, por id (mostrar con el mismo id reemplaza).
  final Map<int, NotificacionLocal> visibles = {};

  /// Todo lo que se mandó mostrar, en orden.
  final List<NotificacionLocal> historial = [];

  /// Lo programado, por id.
  final Map<int, ({NotificacionLocal notificacion, DateTime cuando})> programadas =
      {};

  /// Simula que la persona toca una notificación.
  void tocar(String? carga) => _alTocar?.call(carga);

  @override
  Future<void> iniciar({void Function(String? carga)? alTocar}) async =>
      _alTocar = alTocar;

  @override
  Future<bool> permisoConcedido() async => permiso;

  @override
  Future<bool> pedirPermiso() async {
    vecesPedirPermiso++;
    return permiso;
  }

  @override
  Future<void> mostrar(NotificacionLocal notificacion) async {
    if (!permiso) return;
    historial.add(notificacion);
    visibles[notificacion.id] = notificacion;
  }

  @override
  Future<void> programar(
    NotificacionLocal notificacion,
    DateTime cuando, {
    required String zona,
  }) async {
    programadas[notificacion.id] = (notificacion: notificacion, cuando: cuando);
  }

  @override
  Future<void> cancelar(int id) async {
    visibles.remove(id);
    programadas.remove(id);
  }

  @override
  Future<void> cancelarProgramadas() async => programadas.clear();
}

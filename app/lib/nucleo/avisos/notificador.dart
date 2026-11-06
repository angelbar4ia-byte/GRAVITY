/// Notificaciones del sistema (Android y Windows) detrás de una interfaz, para
/// poder simularlas en las pruebas. Fase 2, D20.
library;

import 'package:flutter/foundation.dart';

import 'catalogo_avisos.dart';

/// Botones de una notificación de recordatorio (Hábitos, regla 113).
enum AccionDeNotificacion {
  hecho('hecho', 'Hecho'),
  posponer10('posponer10', 'Posponer 10 min'),
  omitir('omitir', 'Omitir');

  const AccionDeNotificacion(this.id, this.etiqueta);

  final String id;
  final String etiqueta;

  static AccionDeNotificacion? desdeId(String? id) {
    for (final a in values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

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
    this.acciones = const [],
  }) : cuerpo = '';

  /// Botones. Lo sensible solo ofrece *Posponer 10 min*: ninguna acción
  /// escribe un dato sensible desde la pantalla bloqueada.
  final List<AccionDeNotificacion> acciones;

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
  ///
  /// [alAccion] recibe el botón que se pulsó (*Hecho*, *Posponer 10 min*,
  /// *Omitir*) con la `carga` de la notificación.
  Future<void> iniciar({
    void Function(String? carga)? alTocar,
    void Function(String? carga, AccionDeNotificacion accion)? alAccion,
  });

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
  void Function(String? carga, AccionDeNotificacion accion)? _alAccion;

  /// Lo visible ahora, por id (mostrar con el mismo id reemplaza).
  final Map<int, NotificacionLocal> visibles = {};

  /// Todo lo que se mandó mostrar, en orden.
  final List<NotificacionLocal> historial = [];

  /// Lo programado, por id.
  final Map<int, ({NotificacionLocal notificacion, DateTime cuando})> programadas =
      {};

  /// Simula que la persona toca una notificación.
  void tocar(String? carga) => _alTocar?.call(carga);

  /// Simula que la persona pulsa un botón de la notificación.
  void pulsar(String? carga, AccionDeNotificacion accion) =>
      _alAccion?.call(carga, accion);

  @override
  Future<void> iniciar({
    void Function(String? carga)? alTocar,
    void Function(String? carga, AccionDeNotificacion accion)? alAccion,
  }) async {
    _alTocar = alTocar;
    _alAccion = alAccion;
  }

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

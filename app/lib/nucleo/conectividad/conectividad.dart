/// Conexión real del equipo (E1 de la Fase 4, D22): lo que dice el indicador
/// "En línea" de la pantalla principal.
///
/// Antes `enLinea` valía `true` fijo: una pantalla que dice "en línea" sin
/// estarlo es peor que no decir nada. Ahora el estado sale de una
/// [FuenteConectividad] (en la app, `connectivity_plus`; en las pruebas, una
/// falsa) y de la bandeja de la cola sin conexión.
///
/// Estados que muestra el indicador ([EstadoConexion]): en línea, sin conexión,
/// sincronizando (hay registros por subir y sí hay señal) y "N por subir"
/// (hay registros por subir y no hay señal).
///
/// Ojo: que el sistema diga "hay red" no es que el servidor responda. Este
/// proveedor solo conoce lo primero; un fallo de red al subir lo dice la cola
/// (los registros siguen "por subir"), y por eso el estado "sincronizando"
/// solo aparece mientras queda algo por subir.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cola/proveedores_cola.dart';

/// De dónde sale "hay red". Se sustituye en el arranque y en las pruebas.
abstract interface class FuenteConectividad {
  /// Si hay red ahora.
  Future<bool> hayRed();

  /// Avisa cada vez que cambia (`true`: hay red).
  Stream<bool> get cambios;
}

/// Siempre hay red (valor por omisión: pruebas y modo demostración).
class FuenteConectividadSiempre implements FuenteConectividad {
  const FuenteConectividadSiempre();

  @override
  Future<bool> hayRed() async => true;

  @override
  Stream<bool> get cambios => const Stream<bool>.empty();
}

/// Red simulada para pruebas: se cambia con [poner].
class FuenteConectividadFalsa implements FuenteConectividad {
  FuenteConectividadFalsa({bool hayRed = true}) : _hayRed = hayRed;

  bool _hayRed;
  final _controlador = StreamController<bool>.broadcast();

  @override
  Future<bool> hayRed() async => _hayRed;

  @override
  Stream<bool> get cambios => _controlador.stream;

  /// Cambia la red y avisa.
  void poner(bool hayRed) {
    _hayRed = hayRed;
    _controlador.add(hayRed);
  }

  Future<void> cerrar() => _controlador.close();
}

/// Fuente del equipo. El arranque la sustituye por la de `connectivity_plus`.
final fuenteConectividadProvider = Provider<FuenteConectividad>(
  (ref) => const FuenteConectividadSiempre(),
);

/// `true` si el sistema dice que hay red. Empieza en `true` mientras se
/// consulta (no se asusta a nadie por una lectura que tarda milisegundos) y se
/// corrige en cuanto responde la fuente.
final hayRedProvider = NotifierProvider<NotificadorHayRed, bool>(
  NotificadorHayRed.new,
);

class NotificadorHayRed extends Notifier<bool> {
  @override
  bool build() {
    final fuente = ref.watch(fuenteConectividadProvider);
    final suscripcion = fuente.cambios.listen(
      (hay) => state = hay,
      onError: (Object error) => debugPrint('Conectividad: $error'),
    );
    ref.onDispose(suscripcion.cancel);
    fuente
        .hayRed()
        .then((hay) {
          if (ref.mounted) state = hay;
        })
        .catchError((Object error) {
          debugPrint('Conectividad: $error');
        });
    return true;
  }
}

/// Lo que dice el indicador.
enum EstadoConexion {
  /// Hay red y nada por subir.
  enLinea,

  /// Hay red y quedan registros por subir.
  sincronizando,

  /// No hay red y nada por subir.
  sinConexion,

  /// No hay red y hay registros por subir ([ResumenConexion.porSubir]).
  porSubir,
}

@immutable
class ResumenConexion {
  const ResumenConexion({required this.hayRed, required this.porSubir});

  final bool hayRed;

  /// Registros de la cola que aún no suben.
  final int porSubir;

  EstadoConexion get estado => switch ((hayRed, porSubir > 0)) {
    (true, false) => EstadoConexion.enLinea,
    (true, true) => EstadoConexion.sincronizando,
    (false, false) => EstadoConexion.sinConexion,
    (false, true) => EstadoConexion.porSubir,
  };

  /// `true` si el indicador debe decir "En línea" (hay red; sincronizando
  /// también cuenta como conectado).
  bool get enLinea => hayRed;

  /// Texto corto del indicador.
  String get texto => switch (estado) {
    EstadoConexion.enLinea => 'En línea',
    EstadoConexion.sincronizando => 'Sincronizando',
    EstadoConexion.sinConexion => 'Sin conexión',
    EstadoConexion.porSubir =>
      porSubir == 1 ? '1 por subir' : '$porSubir por subir',
  };

  @override
  bool operator ==(Object other) =>
      other is ResumenConexion &&
      other.hayRed == hayRed &&
      other.porSubir == porSubir;

  @override
  int get hashCode => Object.hash(hayRed, porSubir);
}

/// Registros por subir de la cola (0 si la cola aún no está lista).
final porSubirProvider = StreamProvider<int>(
  (ref) => ref.watch(colaSinConexionProvider).vigilarPendientes(),
);

/// Estado de la conexión para el indicador de la pantalla principal.
final estadoConexionProvider = Provider<ResumenConexion>(
  (ref) => ResumenConexion(
    hayRed: ref.watch(hayRedProvider),
    porSubir: ref.watch(porSubirProvider).value ?? 0,
  ),
);

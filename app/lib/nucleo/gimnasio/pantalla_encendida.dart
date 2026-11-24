/// **Mantener la pantalla encendida** durante la sesión de gimnasio (spec 7.2,
/// 12 y 22; H-14).
///
/// El dueño aprobó el 24/nov/2026 un **canal nativo** (sin paquete nuevo y sin
/// permisos): en Android, `MainActivity` pone o quita
/// `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON` en la ventana, con el mismo
/// patrón que `FLAG_SECURE` (`nucleo/seguridad/pantalla_segura.dart`). Esa
/// bandera no pide ningún permiso y la mantiene la ventana: si la app muere, el
/// sistema la suelta sola.
///
/// - **Solo Android.** En Windows y en las pruebas de Dart puro el proveedor
///   entrega [PantallaEncendidaNula] (no hace nada, `disponible` falso). El
///   arranque pone [PantallaEncendidaAndroid] solo en Android.
/// - **Contador de pedidos.** Dos pantallas pueden pedirla a la vez (la sesión
///   y, digamos, un temporizador): [PantallaEncendida.pedir] devuelve lo que
///   hay que llamar para soltar **su** pedido; la pantalla se apaga cuando
///   suelta el último. [PantallaEncendida.mantener] es el atajo de un solo
///   pedido por este objeto (idempotente: llamarlo de más no cuenta de más).
/// - **Segundo plano.** Al pasar a segundo plano se devuelve el control al
///   sistema aunque haya pedidos; al volver se vuelve a pedir lo que siga
///   pedido.
/// - **Nada depende de ella.** Si el canal falla ([MissingPluginException] o
///   [PlatformException]) se anota y se sigue: la sesión guarda igual.
///
/// Quién la pide durante la sesión: `pantallaEncendidaDeLaSesionProvider`
/// (`app/gimnasio/proveedores_gimnasio.dart`), que sigue a
/// `sesionGimnasioEnCursoProvider`; la pantalla de la sesión (G5) solo llama a
/// `iniciar(persona)` y `terminar()` de ese proveedor.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class PantallaEncendida {
  /// `true` si este equipo puede mantener la pantalla encendida (Android con
  /// la parte nativa; en cualquier otro caso, falso).
  bool get disponible;

  /// Pide mantener la pantalla encendida ([encendida] `true`) o soltar ese
  /// pedido (`false`). Es **un solo pedido por este objeto**: pedir dos veces no
  /// cuenta dos, y soltar de más (o sin haber pedido) no hace nada. Devuelve
  /// `true` si el sistema quedó como se pidió: con `true`, la pantalla quedó
  /// encendida; con `false`, el sistema quedó acorde con los pedidos que
  /// siguen (otra pantalla puede tenerla aún encendida).
  Future<bool> mantener(bool encendida);

  /// Un pedido propio, contado: devuelve lo que hay que llamar para soltarlo
  /// (una sola vez; llamarlo de más no hace nada). La pantalla vuelve al
  /// sistema cuando se sueltan todos.
  VoidCallback pedir();
}

/// La de Windows y la de las pruebas: no hace nada y lo dice.
class PantallaEncendidaNula implements PantallaEncendida {
  const PantallaEncendidaNula();

  @override
  bool get disponible => false;

  @override
  Future<bool> mantener(bool encendida) async => false;

  @override
  VoidCallback pedir() => _nada;

  static void _nada() {}
}

/// Android: `FLAG_KEEP_SCREEN_ON` por un `MethodChannel` pequeño que atiende
/// `MainActivity` (`android/app/src/main/kotlin/…/MainActivity.kt`).
class PantallaEncendidaAndroid
    with WidgetsBindingObserver
    implements PantallaEncendida {
  PantallaEncendidaAndroid([MethodChannel? canal])
    : _canal = canal ?? const MethodChannel(canalDelSistema);

  /// Mismo nombre que en `MainActivity.kt` (una prueba vigila que coincidan).
  static const canalDelSistema = 'mx.segundocerebro.gravity/pantalla_encendida';

  final MethodChannel _canal;

  int _pedidos = 0;
  // Sube al cerrar: soltar un pedido viejo no toca los de una vida nueva.
  int _epoca = 0;
  VoidCallback? _pedidoUnico;
  bool _enPrimerPlano = true;
  bool _nativoDisponible = true;
  bool _escuchando = false;

  /// Lo último que el sistema confirmó; `null` si aún no se ha mandado nada.
  bool? _aplicada;
  Future<void> _fila = Future.value();

  @override
  bool get disponible => _nativoDisponible;

  /// `true` si hay al menos un pedido vigente (aunque la app esté en segundo
  /// plano y el sistema ya la haya soltado).
  bool get pedida => _pedidos > 0;

  /// `true` si el sistema confirmó la pantalla encendida.
  bool get encendidaEnElSistema => _aplicada == true;

  bool get _quiere => _pedidos > 0 && _enPrimerPlano;

  @override
  VoidCallback pedir() {
    final epoca = _epoca;
    _pedidos++;
    _aplicar();
    var soltado = false;
    return () {
      if (soltado || epoca != _epoca) return;
      soltado = true;
      _pedidos--;
      _aplicar();
    };
  }

  @override
  Future<bool> mantener(bool encendida) async {
    if (encendida) {
      _pedidoUnico ??= pedir();
    } else {
      _pedidoUnico?.call();
      _pedidoUnico = null;
    }
    await _fila;
    if (encendida) return _aplicada == true;
    return !_nativoDisponible || (_aplicada ?? false) == _quiere;
  }

  /// Termina cuando se aplicaron los cambios pedidos hasta ahora.
  Future<void> get aplicado => _fila;

  /// Empieza a seguir el ciclo de vida de la app (segundo plano). Sin el motor
  /// de Flutter (pruebas de Dart puro) no hace nada.
  void escuchar() {
    if (_escuchando) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _escuchando = true;
    } catch (_) {
      // Sin el motor de Flutter: nada que escuchar.
    }
  }

  /// Suelta todos los pedidos y deja de escuchar (se acaba el proveedor).
  void cerrar() {
    if (_escuchando) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _escuchando = false;
    }
    _epoca++;
    _pedidos = 0;
    _pedidoUnico = null;
    _aplicar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      alCambiarElCicloDeVida(state);

  /// En segundo plano (`paused`, `hidden`, `detached`) se devuelve el control
  /// al sistema; al volver (`resumed`) se vuelve a pedir lo que siga pedido.
  /// `inactive` (la cortina de notificaciones, un permiso) no cambia nada.
  @visibleForTesting
  void alCambiarElCicloDeVida(AppLifecycleState state) {
    final primerPlano = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => _enPrimerPlano,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
    };
    if (primerPlano == _enPrimerPlano) {
      // Al volver, se reintenta lo que falló antes (canal caído).
      if (state == AppLifecycleState.resumed) _aplicar();
      return;
    }
    _enPrimerPlano = primerPlano;
    _aplicar();
  }

  void _aplicar() {
    // Una llamada tras otra, en el orden en que se pidieron; cada una manda lo
    // que toca *al ejecutarse* (gana lo último) y nunca lanza.
    _fila = _fila.then((_) => _enviar()).catchError((Object error) {
      debugPrint('Pantalla encendida: $error');
    });
  }

  Future<void> _enviar() async {
    if (!_nativoDisponible) return;
    final quiere = _quiere;
    if (quiere == _aplicada) return;
    // Soltar sin haber pedido nunca (arranque en frío): nada que mandar.
    if (!quiere && _aplicada == null) return;
    try {
      await _canal.invokeMethod<void>('establecer', {'encendida': quiere});
      _aplicada = quiere;
    } on MissingPluginException {
      // Sin la parte nativa (otra plataforma o aparato sin ella).
      _nativoDisponible = false;
    } on PlatformException catch (error) {
      // Se queda como estaba: el siguiente cambio o el regreso al primer plano
      // lo reintenta.
      debugPrint('No se pudo cambiar la pantalla encendida: $error');
    }
  }
}

/// Se fija en el arranque: en Android, [PantallaEncendidaAndroid].
final pantallaEncendidaProvider = Provider<PantallaEncendida>(
  (ref) => const PantallaEncendidaNula(),
);

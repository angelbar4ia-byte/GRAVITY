/// Pantalla protegida contra capturas (I11, revisión de la Fase 1; M9 de la
/// Fase 0).
///
/// En Android, `FLAG_SECURE` impide capturas de pantalla y grabaciones y hace
/// que el selector de apps ("recientes") muestre la ventana en blanco: es la
/// cubierta al pasar a segundo plano. Se activa **solo mientras hay pantallas
/// con dinero (Finanzas) o datos clínicos (Cuidados) a la vista**; el resto de
/// la app se puede capturar. En Windows lo hace `SetWindowDisplayAffinity`
/// ([ProtectorDePantallaWindows], activo por omisión y editable en Ajustes ›
/// Privacidad: [capturasBloqueadasProvider]).
///
/// Varias pantallas pueden pedirlo a la vez (la pantalla del módulo y una
/// hoja encima): el protector se enciende con la primera y se apaga cuando
/// suelta la última ([ControladorPantallaSegura]).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'protector_windows.dart';

/// Pone o quita la protección de la ventana.
abstract interface class ProtectorDePantalla {
  Future<void> establecer({required bool segura});
}

/// Sin protección (Windows, pruebas): no hace nada.
class ProtectorDePantallaNulo implements ProtectorDePantalla {
  const ProtectorDePantallaNulo();

  @override
  Future<void> establecer({required bool segura}) async {}
}

/// Android: `FLAG_SECURE` en la ventana, por un `MethodChannel` pequeño que
/// atiende `MainActivity` (`android/app/src/main/kotlin/…/MainActivity.kt`).
class ProtectorDePantallaAndroid implements ProtectorDePantalla {
  const ProtectorDePantallaAndroid([this._canal = canal]);

  /// Mismo nombre que en `MainActivity.kt` (una prueba vigila que coincidan).
  static const canalDelSistema = 'mx.segundocerebro.gravity/pantalla_segura';
  static const canal = MethodChannel(canalDelSistema);

  final MethodChannel _canal;

  @override
  Future<void> establecer({required bool segura}) async {
    try {
      await _canal.invokeMethod<void>('establecer', {'segura': segura});
    } on MissingPluginException {
      // Sin la parte nativa (otra plataforma): nada que proteger.
    } on PlatformException catch (error) {
      debugPrint('No se pudo cambiar la protección de la pantalla: $error');
    }
  }
}

/// Lleva la cuenta de quién pide la protección y la aplica al cambiar entre
/// "nadie la pide" y "alguien la pide".
class ControladorPantallaSegura {
  ControladorPantallaSegura(this._protector, {bool Function()? habilitado})
    : _habilitado = habilitado ?? (() => true);

  final ProtectorDePantalla _protector;

  /// Si la persona apagó el bloqueo (Windows, Ajustes › Privacidad), no se
  /// protege nada aunque haya pantallas que lo pidan.
  final bool Function() _habilitado;
  int _pedidos = 0;
  bool _aplicada = false;
  Future<void> _fila = Future.value();

  /// `true` si hay al menos una pantalla que la pide.
  bool get segura => _pedidos > 0;

  /// Vuelve a aplicar lo que toca (la persona cambió el ajuste).
  void reaplicar() {
    _aplicada = !_queSeAplica();
    _aplicar();
  }

  bool _queSeAplica() => segura && _habilitado();

  /// Alguien pide la protección. Devuelve lo que hay que llamar para soltarla
  /// (una sola vez).
  VoidCallback pedir() {
    _pedidos++;
    _aplicar();
    var soltado = false;
    return () {
      if (soltado) return;
      soltado = true;
      _pedidos--;
      _aplicar();
    };
  }

  void _aplicar() {
    final quiere = _queSeAplica();
    if (quiere == _aplicada) return;
    _aplicada = quiere;
    // Una llamada tras otra, en el orden en que se pidieron.
    _fila = _fila.then((_) => _protector.establecer(segura: quiere)).catchError(
      (Object error) {
        debugPrint('Protección de pantalla: $error');
      },
    );
  }

  /// Termina cuando se aplicaron los cambios pedidos hasta ahora.
  Future<void> get aplicado => _fila;
}

/// Se fija en el arranque: en Android, [ProtectorDePantallaAndroid].
final protectorDePantallaProvider = Provider<ProtectorDePantalla>(
  (ref) => const ProtectorDePantallaNulo(),
);

final controladorPantallaSeguraProvider = Provider<ControladorPantallaSegura>((
  ref,
) {
  final controlador = ControladorPantallaSegura(
    ref.watch(protectorDePantallaProvider),
    habilitado: () => ref.read(capturasBloqueadasProvider),
  );
  ref.listen(capturasBloqueadasProvider, (_, _) => controlador.reaplicar());
  // F4-W1: al volver al primer plano se vuelve a aplicar (en Windows la
  // ventana pudo no estar activa cuando se pidió la primera vez).
  try {
    final observador = _AlVolver(() {
      if (controlador.segura) controlador.reaplicar();
    });
    WidgetsBinding.instance.addObserver(observador);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observador));
  } catch (_) {
    // Sin el motor de Flutter (pruebas de Dart puro): nada que escuchar.
  }
  return controlador;
});

class _AlVolver with WidgetsBindingObserver {
  _AlVolver(this._alVolver);

  final VoidCallback _alVolver;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _alVolver();
  }
}

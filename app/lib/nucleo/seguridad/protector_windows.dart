/// Bloqueo de capturas y miniaturas en Windows (E15 de la Fase 4, P7 del
/// dueño, D22): `SetWindowDisplayAffinity` con `WDA_EXCLUDEFROMCAPTURE`. La
/// ventana no sale en capturas de pantalla, grabaciones, compartir pantalla ni
/// en la vista previa de la barra de tareas. En Android ya lo hace `FLAG_SECURE`
/// ([ProtectorDePantallaAndroid]).
///
/// Va **activo por omisión** y la persona lo apaga en *Ajustes › Privacidad*
/// ([capturasBloqueadasProvider]). Como en Android, solo se aplica mientras hay
/// pantallas con dinero o datos clínicos a la vista (el controlador de
/// `pantalla_segura.dart` lleva la cuenta).
///
/// Si la llamada nativa no existe (Windows anterior a 10 versión 2004 no
/// conoce `WDA_EXCLUDEFROMCAPTURE`), se prueba `WDA_MONITOR` (la ventana sale
/// en negro en las capturas).
library;

import 'dart:async';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pantalla_segura.dart';
import 'proveedores_seguridad.dart';

/// Valores de `SetWindowDisplayAffinity`.
const int wdaNinguna = 0x0;
const int wdaMonitor = 0x1;
const int wdaExcluirDeCaptura = 0x11;

/// Aplica una afinidad a la ventana de la app; `true` si Windows la aceptó.
typedef AplicarAfinidad = bool Function(int afinidad);

/// ¿La app tiene una ventana activa ahora? `GetActiveWindow` devuelve 0 si la
/// ventana aún no existe o no está activa (F4-W1): entonces no hay a quién
/// aplicarle la afinidad y hay que reintentar.
typedef HayVentanaActiva = bool Function();

bool hayVentanaActivaNativa() {
  final user32 = DynamicLibrary.open('user32.dll');
  final ventanaActiva = user32
      .lookupFunction<IntPtr Function(), int Function()>('GetActiveWindow');
  return ventanaActiva() != 0;
}

/// Llamada real a `user32.dll` (solo existe en Windows).
bool aplicarAfinidadNativa(int afinidad) {
  final user32 = DynamicLibrary.open('user32.dll');
  final ventanaActiva = user32
      .lookupFunction<IntPtr Function(), int Function()>('GetActiveWindow');
  final fijar = user32
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetWindowDisplayAffinity',
      );
  final ventana = ventanaActiva();
  if (ventana == 0) return false;
  return fijar(ventana, afinidad) != 0;
}

class ProtectorDePantallaWindows implements ProtectorDePantalla {
  ProtectorDePantallaWindows({
    AplicarAfinidad? aplicar,
    HayVentanaActiva? hayVentana,
    this.intentos = 10,
    this.espera = const Duration(milliseconds: 500),
  }) : _aplicar = aplicar ?? aplicarAfinidadNativa,
       _hayVentana = hayVentana ?? (aplicar == null ? hayVentanaActivaNativa : null);

  final AplicarAfinidad _aplicar;
  final HayVentanaActiva? _hayVentana;

  /// Cuántas veces se espera la ventana activa (F4-W1) y cada cuánto.
  final int intentos;
  final Duration espera;

  /// Espera a que la ventana de la app esté activa. Sin ventana no hay nada
  /// que proteger todavía; si nunca aparece, queda para el próximo
  /// `reaplicar` (al volver al primer plano).
  Future<bool> _esperarVentana() async {
    final hay = _hayVentana;
    if (hay == null) return true;
    for (var i = 0; i < intentos; i++) {
      if (hay()) return true;
      await Future<void>.delayed(espera);
    }
    debugPrint('Bloqueo de capturas: la ventana no estuvo activa; se '
        'reintenta al volver al primer plano.');
    return false;
  }

  @override
  Future<void> establecer({required bool segura}) async {
    try {
      if (!segura) {
        _aplicar(wdaNinguna);
        return;
      }
      if (!await _esperarVentana()) return;
      if (!_aplicar(wdaExcluirDeCaptura)) {
        // Windows viejo: al menos que salga en negro.
        _aplicar(wdaMonitor);
      }
    } catch (error) {
      debugPrint('No se pudo cambiar el bloqueo de capturas: $error');
    }
  }
}

/// ¿Bloquear las capturas en Windows? Activo por omisión; se guarda en el
/// almacén seguro de este equipo (es de la ventana, no de la persona).
final capturasBloqueadasProvider = NotifierProvider<CapturasBloqueadas, bool>(
  CapturasBloqueadas.new,
);

class CapturasBloqueadas extends Notifier<bool> {
  static const clave = 'privacidad.bloqueo_capturas_windows';

  Future<void>? _carga;

  /// Termina cuando se leyó lo guardado.
  Future<void> get listo => _carga ?? Future.value();

  @override
  bool build() {
    _carga = _leer();
    return true;
  }

  Future<void> _leer() async {
    try {
      final guardado = await ref.read(almacenSeguroProvider).leer(clave);
      if (ref.mounted && guardado == 'no') state = false;
    } catch (error) {
      debugPrint('Bloqueo de capturas: $error');
    }
  }

  Future<void> fijar(bool activo) async {
    await listo;
    state = activo;
    try {
      await ref
          .read(almacenSeguroProvider)
          .escribir(clave, activo ? 'si' : 'no');
    } catch (error) {
      debugPrint('Bloqueo de capturas: $error');
    }
  }
}

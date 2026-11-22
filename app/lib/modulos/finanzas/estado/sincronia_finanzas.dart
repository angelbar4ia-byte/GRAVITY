/// Cuándo se vuelve a pedir lo de Finanzas al servidor sin que la persona lo
/// pida (F8-6.6, `docs/specs/fase-8-finanzas-realtime.md`).
///
/// - **Realtime** (camino principal): un aviso sin datos de «el libro X cambió»
///   → se espera [espera] (debounce, 1.5 s) y se recarga **una sola vez**.
/// - **Al entrar o volver** a Finanzas, al volver de segundo plano y al
///   reconectar el canal: se recarga si pasaron al menos [minimoEntreRefrescos]
///   (20 s) desde el último refresco. Si no, se omite (lo cargado es reciente).
///   Al reconectar tras una caída el mínimo es solo [minimoReconexion] (3 s, para
///   que varios canales que vuelven a la vez den una sola recarga): pudo
///   perderse un aviso y un refresco de hace segundos no lo trae.
/// - **Sin temporizador periódico.** El único temporizador vivo con el módulo
///   quieto es el del aplazamiento por una hoja abierta, y solo mientras hay una
///   recarga pendiente.
/// - **Sin pisar una hoja**: con una hoja o un cuadro de diálogo abierto, la
///   recarga se aplaza hasta cerrarlo ([reintentoHoja]).
///
/// Es Dart puro (sin Flutter ni Riverpod) para probarlo con una fuente falsa y
/// un reloj controlado. La cola sin conexión no se toca aquí: `recargar` vuelve
/// a pedir al repositorio, que mezcla lo pendiente de la cola con lo del
/// servidor.
library;

import 'dart:async';

import '../datos/fuente_cambios_finanzas.dart';

class ServicioSincroniaFinanzas {
  ServicioSincroniaFinanzas({
    required this.fuente,
    required this.recargar,
    DateTime Function()? ahora,
    this.espera = const Duration(milliseconds: 1500),
    this.minimoEntreRefrescos = const Duration(seconds: 20),
    this.minimoReconexion = const Duration(seconds: 3),
    this.reintentoHoja = const Duration(seconds: 1),
  }) : _ahora = ahora ?? DateTime.now;

  /// `null` sin servidor (demostración): solo quedan entrar, volver y manual.
  final FuenteCambiosFinanzas? fuente;

  /// Vuelve a pedir todo. No debe lanzar (si falla, se conserva lo cargado).
  final Future<void> Function() recargar;
  final DateTime Function() _ahora;

  /// Espera tras un aviso antes de recargar (junta ráfagas en una sola recarga).
  final Duration espera;

  /// Mínimo entre dos refrescos automáticos de entrar, volver y reconectar.
  final Duration minimoEntreRefrescos;

  /// Mínimo al reconectar el canal tras una caída (junta las reconexiones
  /// simultáneas de varios canales en una sola recarga).
  final Duration minimoReconexion;

  /// Cada cuánto se revisa si ya se cerró la hoja que aplazó la recarga.
  final Duration reintentoHoja;

  bool Function() _hojaAbierta = () => false;
  Set<String> _libros = const {};
  StreamSubscription<EventoSincronia>? _suscripcion;
  Timer? _temporizadorAviso;
  Timer? _temporizadorHoja;
  /// El cierre se difiere a un microtask (no a un Timer): al cambiar de sección una
  /// pantalla sale y otra entra en el mismo cuadro, y un Timer pendiente deja
  /// colgado cualquier árbol que se desmonte al terminar (p. ej. las pruebas).
  bool _cierrePendiente = false;
  DateTime? _ultimoRefresco;
  int _abiertos = 0;
  bool _activo = false;
  bool _recargando = false;
  bool _otraVez = false;

  /// Hay una recarga que espera a que se cierre una hoja.
  bool get pendientePorHoja => _temporizadorHoja != null;

  /// El módulo está abierto (hay al menos una pantalla de Finanzas montada).
  bool get activo => _activo;

  /// Libros por los que se escucha ahora.
  Set<String> get libros => _libros;

  /// Lo cargado cuenta como refresco (la carga inicial o una recarga manual):
  /// evita recargar de nuevo en los siguientes [minimoEntreRefrescos].
  void marcarRefresco() => _ultimoRefresco = _ahora();

  /// Una pantalla de Finanzas se montó. [hojaAbierta] dice si hay una hoja o un
  /// diálogo encima. La primera pantalla abre el módulo: se suscribe y refresca
  /// (con el mínimo de 20 s).
  void abrir({required bool Function() hojaAbierta}) {
    _hojaAbierta = hojaAbierta;
    _abiertos++;
    if (_abiertos == 1 && !_activo) {
      _activo = true;
      _suscribir();
      _refrescarConMinimo();
    }
  }

  /// Una pantalla de Finanzas se desmontó. Al cambiar de sección una sale y otra
  /// entra: el cierre espera un instante para no soltar el canal en vano.
  void cerrar() {
    if (_abiertos > 0) _abiertos--;
    if (_abiertos > 0) return;
    if (_cierrePendiente) return;
    _cierrePendiente = true;
    scheduleMicrotask(() {
      _cierrePendiente = false;
      if (_abiertos == 0) _detener();
    });
  }

  /// Los libros por los que se escucha (los de la persona). Solo vuelve a
  /// suscribirse si cambian.
  void actualizarLibros(Set<String> libros) {
    if (_libros.length == libros.length && _libros.containsAll(libros)) return;
    _libros = Set.unmodifiable(libros);
    if (_activo) _suscribir();
  }

  /// La app volvió de segundo plano.
  void alVolver() => _refrescarConMinimo();

  /// «Actualizar» o deslizar para actualizar: siempre recarga, sin mínimo.
  Future<void> actualizarAhora() => _ejecutar();

  void _suscribir() {
    _suscripcion?.cancel();
    _suscripcion = null;
    final f = fuente;
    if (f == null || _libros.isEmpty || !_activo) return;
    _suscripcion = f.escuchar(_libros).listen(_alEvento, onError: (_) {});
  }

  void _alEvento(EventoSincronia evento) {
    if (!_activo) return;
    switch (evento) {
      case CambioDeLibro():
        // Un aviso por ráfaga: los siguientes dentro de la espera se absorben.
        _temporizadorAviso ??= Timer(espera, _alVencerEspera);
      case CanalReconectado():
        _refrescarConMinimo(minimoReconexion);
    }
  }

  void _alVencerEspera() {
    _temporizadorAviso = null;
    if (!_activo) return;
    if (_hojaAbierta()) {
      _aplazarPorHoja();
      return;
    }
    unawaited(_ejecutar());
  }

  void _refrescarConMinimo([Duration? minimo]) {
    if (!_activo) return;
    final ultimo = _ultimoRefresco;
    if (ultimo != null &&
        _ahora().difference(ultimo) < (minimo ?? minimoEntreRefrescos)) {
      return;
    }
    if (_hojaAbierta()) {
      _aplazarPorHoja();
      return;
    }
    unawaited(_ejecutar());
  }

  void _aplazarPorHoja() {
    _temporizadorHoja ??= Timer(reintentoHoja, () {
      _temporizadorHoja = null;
      if (!_activo) return;
      if (_hojaAbierta()) {
        _aplazarPorHoja();
      } else {
        unawaited(_ejecutar());
      }
    });
  }

  Future<void> _ejecutar() async {
    if (_recargando) {
      // Llegó otro aviso mientras se recargaba: una más al terminar.
      _otraVez = true;
      return;
    }
    _recargando = true;
    try {
      await recargar();
    } catch (_) {
      // Sin señal se queda con lo último que se cargó.
    } finally {
      _ultimoRefresco = _ahora();
      _recargando = false;
    }
    if (_otraVez) {
      _otraVez = false;
      if (_activo) _temporizadorAviso ??= Timer(espera, _alVencerEspera);
    }
  }

  void _detener() {
    _activo = false;
    _suscripcion?.cancel();
    _suscripcion = null;
    _temporizadorAviso?.cancel();
    _temporizadorAviso = null;
    _temporizadorHoja?.cancel();
    _temporizadorHoja = null;
    _hojaAbierta = () => false;
    _otraVez = false;
  }

  /// Para quien dispone del servicio (cierra todo).
  void liberar() {
    _abiertos = 0;
    _cierrePendiente = false;
    _detener();
  }
}

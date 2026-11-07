/// Control del esmerilado de los paneles de vidrio (estilo Glass, D27).
///
/// El esmerilado (`BackdropFilter`) es lo más caro que dibuja la app, así que:
/// - se permite un **máximo de 3 capas a la vez** ([GestorEsmerilado.maximoCapas]);
///   un panel que llega cuando ya hay 3 se dibuja en su versión translúcida
///   sólida, sin esmerilar;
/// - si la app va lenta (los cuadros tardan más de 22.2 ms de promedio, o sea
///   menos de 45 por segundo, durante 5 segundos), el esmerilado se **apaga
///   solo** ([MonitorRendimiento]) y *Ajustes › Apariencia* lo avisa y deja
///   volver a probar.
library;

import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Mide el rendimiento por ventanas de tiempo. Es puro: la duración y la marca
/// de cada cuadro entran como parámetros.
class MonitorRendimiento {
  MonitorRendimiento({
    this.umbral = const Duration(microseconds: 22222),
    this.ventana = const Duration(seconds: 5),
    this.minimoCuadros = 30,
  });

  /// Duración promedio de cuadro a partir de la cual se considera lenta
  /// (22.2 ms equivalen a 45 cuadros por segundo).
  final Duration umbral;

  /// Lo que dura una medición.
  final Duration ventana;

  /// Cuadros mínimos para que una ventana cuente (una app quieta no mide nada).
  final int minimoCuadros;

  Duration _inicio = Duration.zero;
  int _suma = 0;
  int _cuadros = 0;

  /// Anota un cuadro que tardó [duracion] y terminó en [marca]. Regresa `true`
  /// cuando una ventana completa salió lenta: hay que apagar el esmerilado.
  bool cuadro(Duration duracion, Duration marca) {
    if (_cuadros == 0) _inicio = marca;
    _suma += duracion.inMicroseconds;
    _cuadros++;
    if (marca - _inicio < ventana) return false;
    final promedio = _suma ~/ _cuadros;
    final lenta = _cuadros >= minimoCuadros && promedio > umbral.inMicroseconds;
    _suma = 0;
    _cuadros = 0;
    return lenta;
  }
}

/// Lleva la cuenta de las capas esmeriladas y apaga el esmerilado si hace
/// falta. Hay uno solo para toda la app ([instancia]); las pruebas crean el suyo
/// o lo reinician.
class GestorEsmerilado extends ChangeNotifier {
  GestorEsmerilado({this.maximoCapas = 3});

  /// El gestor de la app.
  static final GestorEsmerilado instancia = GestorEsmerilado();

  /// Capas esmeriladas visibles a la vez.
  final int maximoCapas;

  final Set<Object> _capas = {};
  bool _apagadoAutomatico = false;
  bool _monitorIniciado = false;

  /// Si el esmerilado se apagó solo por rendimiento.
  bool get apagadoAutomatico => _apagadoAutomatico;

  /// Cuántas capas esmeriladas hay ahora.
  int get capasActivas => _capas.length;

  /// Pide una capa de esmerilado para [dueno]. Es idempotente. Regresa `false`
  /// si el esmerilado está apagado o ya hay [maximoCapas] (el panel se dibuja
  /// entonces en su versión translúcida sólida).
  bool solicitar(Object dueno) {
    if (_apagadoAutomatico) return false;
    if (_capas.contains(dueno)) return true;
    if (_capas.length >= maximoCapas) return false;
    _capas.add(dueno);
    return true;
  }

  /// Devuelve la capa de [dueno].
  void liberar(Object dueno) => _capas.remove(dueno);

  /// Apaga el esmerilado (se llama cuando [MonitorRendimiento] lo pide).
  void apagarPorRendimiento() {
    if (_apagadoAutomatico) return;
    _apagadoAutomatico = true;
    _capas.clear();
    notifyListeners();
  }

  /// Vuelve a permitir el esmerilado ("Volver a probar" en Apariencia).
  void reactivar() {
    if (!_apagadoAutomatico) return;
    _apagadoAutomatico = false;
    notifyListeners();
  }

  /// Empieza a medir los cuadros de la app (una sola vez).
  void iniciarMonitor([MonitorRendimiento? monitor]) {
    if (_monitorIniciado) return;
    _monitorIniciado = true;
    final medidor = monitor ?? MonitorRendimiento();
    SchedulerBinding.instance.addTimingsCallback((cuadros) {
      for (final c in cuadros) {
        final marca = Duration(
          microseconds: c.timestampInMicroseconds(FramePhase.rasterFinish),
        );
        if (medidor.cuadro(c.totalSpan, marca)) {
          apagarPorRendimiento();
          return;
        }
      }
    });
  }

  /// Para las pruebas: deja el gestor como nuevo (sin capas, encendido).
  @visibleForTesting
  void reiniciar() {
    _capas.clear();
    _apagadoAutomatico = false;
    notifyListeners();
  }
}

/// Avisa cuando pasa [DetectorInactividad.tiempo] sin tocar la pantalla ni
/// el teclado (tablet: regreso al modo Casa, D14).
///
/// Cuenta los toques de **toda** la app, también los de hojas y diálogos, y al
/// volver de segundo plano compara con el último toque: si ya pasó el tiempo,
/// avisa en ese momento (revisión de la Fase 0, M9).
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class DetectorInactividad extends StatefulWidget {
  const DetectorInactividad({
    super.key,
    required this.activo,
    required this.tiempo,
    required this.alVencer,
    required this.child,
    this.reloj,
  });

  /// Solo cuenta mientras está activo (alguien entró con su PIN).
  final bool activo;
  final Duration tiempo;
  final VoidCallback alVencer;
  final Widget child;

  /// Reloj para comparar al volver de segundo plano (pruebas).
  final DateTime Function()? reloj;

  @override
  State<DetectorInactividad> createState() => _DetectorInactividadState();
}

class _DetectorInactividadState extends State<DetectorInactividad>
    with WidgetsBindingObserver {
  Timer? _temporizador;
  DateTime? _ultimaActividad;

  DateTime _ahora() => (widget.reloj ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_alPresionarTecla);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_alPuntero);
    WidgetsBinding.instance.addObserver(this);
    _programar();
  }

  @override
  void didUpdateWidget(DetectorInactividad anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.activo != widget.activo || anterior.tiempo != widget.tiempo) {
      _programar();
    }
  }

  void _programar() {
    _temporizador?.cancel();
    _ultimaActividad = _ahora();
    _temporizador = widget.activo ? Timer(widget.tiempo, _vencer) : null;
  }

  void _vencer() {
    _temporizador?.cancel();
    _temporizador = null;
    if (mounted && widget.activo) widget.alVencer();
  }

  void _actividad() {
    if (widget.activo) _programar();
  }

  void _alPuntero(PointerEvent evento) {
    if (evento is PointerDownEvent ||
        evento is PointerMoveEvent ||
        evento is PointerSignalEvent) {
      _actividad();
    }
  }

  bool _alPresionarTecla(KeyEvent evento) {
    _actividad();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed || !widget.activo) return;
    final ultima = _ultimaActividad;
    if (ultima != null && _ahora().difference(ultima) >= widget.tiempo) {
      _vencer();
    }
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_alPuntero);
    HardwareKeyboard.instance.removeHandler(_alPresionarTecla);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

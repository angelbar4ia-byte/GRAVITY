/// Avisa cuando pasa [DetectorInactividad.tiempo] sin tocar la pantalla ni
/// el teclado (tablet: regreso al modo Casa, D14).
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class DetectorInactividad extends StatefulWidget {
  const DetectorInactividad({
    super.key,
    required this.activo,
    required this.tiempo,
    required this.alVencer,
    required this.child,
  });

  /// Solo cuenta mientras está activo (alguien entró con PIN o huella).
  final bool activo;
  final Duration tiempo;
  final VoidCallback alVencer;
  final Widget child;

  @override
  State<DetectorInactividad> createState() => _DetectorInactividadState();
}

class _DetectorInactividadState extends State<DetectorInactividad> {
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_alPresionarTecla);
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
    _temporizador = widget.activo ? Timer(widget.tiempo, _vencer) : null;
  }

  void _vencer() {
    _temporizador = null;
    if (mounted && widget.activo) widget.alVencer();
  }

  void _actividad([Object? _]) {
    if (widget.activo) _programar();
  }

  bool _alPresionarTecla(KeyEvent evento) {
    _actividad();
    return false;
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    HardwareKeyboard.instance.removeHandler(_alPresionarTecla);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _actividad,
    onPointerMove: _actividad,
    onPointerSignal: _actividad,
    child: widget.child,
  );
}

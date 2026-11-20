/// Lo que mantiene Finanzas al día entre dispositivos mientras el módulo está
/// abierto (F8-6.6, `docs/specs/fase-8-finanzas-realtime.md`): el anfitrión que
/// abre y cierra el servicio, el botón «Actualizar» y el atajo F5 de la laptop.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/proveedores.dart';
import '../estado/sincronia_finanzas.dart';

/// ¿Hay una hoja o un cuadro de diálogo abierto encima de la pantalla? Las
/// hojas y los diálogos de la app se abren en el navegador raíz
/// (`showModalBottomSheet`, `showDialog`): mientras haya uno, ese navegador
/// puede retroceder. Una recarga no debe pisar lo que la persona está editando.
bool hayHojaAbierta(BuildContext context) =>
    context.mounted &&
    (Navigator.maybeOf(context, rootNavigator: true)?.canPop() ?? false);

/// Envuelve las pantallas de Finanzas: mientras alguna esté montada, el
/// servicio escucha los avisos de cambios, y al volver de segundo plano pide
/// lo de Finanzas de nuevo (con el mínimo de 20 s entre refrescos).
class AnfitrionSincroniaFinanzas extends ConsumerStatefulWidget {
  const AnfitrionSincroniaFinanzas({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AnfitrionSincroniaFinanzas> createState() => _EstadoAnfitrion();
}

class _EstadoAnfitrion extends ConsumerState<AnfitrionSincroniaFinanzas>
    with WidgetsBindingObserver {
  // El servicio con el que se abrió: se cierra el mismo aunque la persona cambie.
  late final ServicioSincroniaFinanzas _servicio;

  @override
  void initState() {
    super.initState();
    _servicio = ref.read(sincroniaFinanzasProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<Set<String>>(
      librosParaSincroniaProvider,
      (_, libros) => _servicio.actualizarLibros(libros),
      fireImmediately: true,
    );
    _servicio.abrir(hojaAbierta: () => hayHojaAbierta(context));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _servicio.alVolver();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _servicio.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Botón discreto «Actualizar» (laptop) y atajo **F5**.
class BotonActualizarFinanzas extends ConsumerStatefulWidget {
  const BotonActualizarFinanzas({super.key});

  @override
  ConsumerState<BotonActualizarFinanzas> createState() => _EstadoBoton();
}

class _EstadoBoton extends ConsumerState<BotonActualizarFinanzas> {
  bool _actualizando = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_alTecla);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_alTecla);
    super.dispose();
  }

  bool _alTecla(KeyEvent evento) {
    if (evento is! KeyDownEvent || evento.logicalKey != LogicalKeyboardKey.f5) {
      return false;
    }
    // Con una hoja o un diálogo abierto, F5 no hace nada (no pisa lo que se edita).
    if (!hayHojaAbierta(context)) unawaited(_actualizar());
    return true;
  }

  Future<void> _actualizar() async {
    if (_actualizando) return;
    setState(() => _actualizando = true);
    try {
      await ref.read(sincroniaFinanzasProvider).actualizarAhora();
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('finanzas-actualizar'),
    tooltip: 'Actualizar (F5)',
    onPressed: _actualizando ? null : _actualizar,
    icon: const Icon(Icons.refresh),
  );
}

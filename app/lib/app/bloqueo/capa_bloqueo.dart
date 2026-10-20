/// Bloqueo del teléfono (revisión de la Fase 0, I8): si la persona lo activó
/// en Ajustes › Privacidad, la app pide su PIN (o huella) al abrir y al volver
/// de segundo plano tras el tiempo elegido. Va encima de todo, también de
/// hojas y diálogos. Solo en el teléfono: la tablet de la casa usa el PIN de
/// cada persona y la laptop, la cuenta de Windows.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/seguridad/bloqueo.dart';
import '../../nucleo/seguridad/intentos.dart';
import '../../nucleo/seguridad/proveedores_seguridad.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../dispositivo.dart';

class CapaBloqueo extends ConsumerWidget {
  const CapaBloqueo({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(tipoDispositivoProvider) != TipoDispositivo.telefono) {
      return child;
    }
    return _CapaBloqueoTelefono(child: child);
  }
}

class _CapaBloqueoTelefono extends ConsumerStatefulWidget {
  const _CapaBloqueoTelefono({required this.child});

  final Widget child;

  @override
  ConsumerState<_CapaBloqueoTelefono> createState() =>
      _CapaBloqueoTelefonoState();
}

class _CapaBloqueoTelefonoState extends ConsumerState<_CapaBloqueoTelefono>
    with WidgetsBindingObserver {
  final _claveOverlay = GlobalKey<OverlayState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final controlador = ref.read(controladorBloqueoProvider.notifier);
    switch (estado) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        controlador.alIrASegundoPlano();
      case AppLifecycleState.resumed:
        controlador.alVolver();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(controladorBloqueoProvider);
    final hayPersona = ref.watch(sesionActualProvider) != null;
    // Mientras se lee la configuración no se muestra nada de la persona.
    final cubrir = hayPersona && (!estado.cargado || estado.bloqueado);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: cubrir,
          child: ExcludeSemantics(
            excluding: cubrir,
            child: IgnorePointer(
              ignoring: cubrir,
              child: TickerMode(enabled: !cubrir, child: widget.child),
            ),
          ),
        ),
        if (cubrir)
          Overlay(
            key: _claveOverlay,
            initialEntries: [
              OverlayEntry(
                builder: (_) => estado.cargado
                    ? const PantallaBloqueo()
                    : const ColoredBox(color: Colors.black),
              ),
            ],
          ),
      ],
    );
  }
}

/// Pantalla para desbloquear el teléfono.
class PantallaBloqueo extends ConsumerStatefulWidget {
  const PantallaBloqueo({super.key});

  @override
  ConsumerState<PantallaBloqueo> createState() => _PantallaBloqueoState();
}

class _PantallaBloqueoState extends ConsumerState<PantallaBloqueo> {
  final _pin = TextEditingController();
  String? _error;
  bool _hayHuella = false;
  bool _olvido = false;

  @override
  void initState() {
    super.initState();
    ref.read(biometriaProvider).disponible().then((hay) {
      if (mounted) setState(() => _hayHuella = hay);
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _mostrar(ResultadoBloqueo resultado) {
    if (resultado == ResultadoBloqueo.abierto) return;
    final controlador = ref.read(controladorBloqueoProvider.notifier);
    _pin.clear();
    setState(
      () => _error = switch (resultado) {
        ResultadoBloqueo.pinIncorrecto => 'PIN incorrecto.',
        ResultadoBloqueo.bloqueado =>
          'Demasiados intentos. Espera '
              '${textoEspera(controlador.esperaRestante() ?? const Duration(seconds: 30))}.',
        ResultadoBloqueo.huellaFallida => 'No se reconoció la huella.',
        ResultadoBloqueo.abierto => null,
      },
    );
  }

  void _desbloquear() => _mostrar(
    ref.read(controladorBloqueoProvider.notifier).desbloquearConPin(_pin.text),
  );

  Future<void> _conHuella() async {
    final resultado = await ref
        .read(controladorBloqueoProvider.notifier)
        .desbloquearConHuella();
    if (mounted) _mostrar(resultado);
  }

  /// Olvidó su PIN: se quita el bloqueo y se cierra la sesión; vuelve a
  /// entrar con su correo y contraseña.
  Future<void> _salirSinPin() async {
    await ref.read(controladorBloqueoProvider.notifier).quitarBloqueo();
    await ref.read(servicioSesionProvider).salir();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final configuracion = ref.watch(controladorBloqueoProvider).configuracion;
    final conHuella = (configuracion?.huella ?? false) && _hayHuella;
    final sesion = ref.watch(sesionActualProvider);
    return Material(
      key: const ValueKey('pantalla-bloqueo'),
      color: tema.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'GRAVITY está bloqueado',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall,
                  ),
                  if (sesion != null)
                    Text(
                      sesion.persona.nombre,
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodyLarge,
                    ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('campo-pin-bloqueo'),
                    controller: _pin,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _desbloquear(),
                    style: const TextStyle(fontSize: 28, letterSpacing: 8),
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _desbloquear,
                      child: const Text('Desbloquear'),
                    ),
                  ),
                  if (conHuella) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _conHuella,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Usar huella'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!_olvido)
                    TextButton(
                      onPressed: () => setState(() => _olvido = true),
                      child: const Text('Olvidé mi PIN'),
                    )
                  else ...[
                    const Text(
                      'Se cierra tu sesión en este teléfono y se quita el '
                      'bloqueo. Entra de nuevo con tu correo y contraseña.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _olvido = false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _salirSinPin,
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

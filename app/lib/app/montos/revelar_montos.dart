/// Volver a ver los montos (decisión del 23/oct/2026): se ocultan solos tras
/// unos minutos sin uso y para verlos se pide el PIN (en el teléfono, también
/// la huella). Si no hay ningún PIN para pedir, la primera vez se crea uno
/// propio (no triviales). Quien ve dinero usa un PIN de 6 dígitos: si el suyo
/// es más corto, el mismo diálogo le pide uno nuevo antes de mostrar los
/// montos.
///
/// En la tablet, la persona que entra con su PIN ve sus montos de una vez y no
/// pasa por aquí (`montos_al_entrar.dart`); este diálogo es para volver a
/// verlos tras el tiempo sin uso.
///
/// El sistema de diseño dibuja los montos ocultos y llama a
/// `revelarMontosProvider`; aquí está lo que hace la plataforma
/// ([revelarMontos], conectado en `conexionesDeLaApp`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diseno/proveedores.dart' show modoPrivadoProvider, montosVisiblesProvider;
import '../../nucleo/seguridad/intentos.dart';
import '../../nucleo/seguridad/montos.dart';
import '../../nucleo/seguridad/pin.dart';
import '../pin/campos_pin_nuevo.dart';

/// Pide el PIN (o la huella) y, si es correcto, muestra los montos. Devuelve
/// `true` si se mostraron. Con el modo privado activo no hace nada: para ver
/// los montos se quita el modo privado.
Future<bool> revelarMontos(BuildContext context) async {
  final contenedor = ProviderScope.containerOf(context, listen: false);
  if (contenedor.read(modoPrivadoProvider)) return false;
  await contenedor.read(controladorMontosProvider.notifier).listo;
  if (!context.mounted) return false;
  final mostrar = await showDialog<bool>(
    context: context,
    builder: (contexto) => const DialogoRevelarMontos(),
  );
  if (mostrar != true) return false;
  contenedor.read(montosVisiblesProvider.notifier).fijar(true);
  return true;
}

/// Mensaje para la persona según el resultado de pedir ver los montos.
String? mensajeRevelar(ResultadoRevelar resultado, {Duration? espera}) =>
    switch (resultado) {
      ResultadoRevelar.revelado => null,
      ResultadoRevelar.pinIncorrecto => 'PIN incorrecto.',
      ResultadoRevelar.bloqueado =>
        'Demasiados intentos. Espera ${textoEspera(espera ?? const Duration(seconds: 30))}.',
      ResultadoRevelar.faltaPin => 'Primero crea tu PIN para ver los montos.',
      ResultadoRevelar.huellaFallida =>
        'No se reconoció la huella. Escribe tu PIN.',
      ResultadoRevelar.debeCambiarPin => avisoPinCortoConDinero,
    };

class DialogoRevelarMontos extends ConsumerStatefulWidget {
  const DialogoRevelarMontos({super.key});

  @override
  ConsumerState<DialogoRevelarMontos> createState() =>
      _DialogoRevelarMontosState();
}

class _DialogoRevelarMontosState extends ConsumerState<DialogoRevelarMontos> {
  final _pin = TextEditingController();
  final _confirmacion = TextEditingController();
  late final bool _crear;
  String? _error;
  bool _huella = false;
  bool _trabajando = false;

  /// El PIN era el correcto pero corto, y quien lo usa ve dinero: elige uno de
  /// 6 dígitos. [_pinActual] es el que acaba de escribir.
  bool _cambiando = false;
  String _pinActual = '';

  @override
  void initState() {
    super.initState();
    final controlador = ref.read(controladorMontosProvider.notifier);
    _crear = controlador.hayQueCrearPin;
    if (!_crear) {
      controlador.huellaDisponible().then((hay) {
        if (mounted) setState(() => _huella = hay);
      });
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _aceptar() async {
    if (_trabajando) return;
    final controlador = ref.read(controladorMontosProvider.notifier);
    if (_crear) {
      final error = errorDePinNuevoConfirmado(
        _pin.text,
        _confirmacion.text,
        rol: controlador.rol,
      );
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      setState(() => _trabajando = true);
      await controlador.crearPin(_pin.text);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    if (_cambiando) {
      await _guardarNuevo(controlador);
      return;
    }
    setState(() {
      _trabajando = true;
      _error = null;
    });
    final resultado = await controlador.verificar(_pin.text);
    if (!mounted) return;
    if (resultado == ResultadoRevelar.revelado) {
      Navigator.of(context).pop(true);
      return;
    }
    if (resultado == ResultadoRevelar.debeCambiarPin) {
      _pinActual = _pin.text;
      _pin.clear();
      setState(() {
        _cambiando = true;
        _trabajando = false;
        _error = null;
      });
      return;
    }
    _pin.clear();
    setState(() {
      _trabajando = false;
      _error = mensajeRevelar(resultado, espera: controlador.esperaRestante());
    });
  }

  /// Guarda el PIN de 6 dígitos (donde corresponda) y muestra los montos.
  Future<void> _guardarNuevo(ControladorMontos controlador) async {
    final error = errorDePinNuevoConfirmado(
      _pin.text,
      _confirmacion.text,
      rol: controlador.rol,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _trabajando = true);
    final resultado = await controlador.cambiarPin(_pinActual, _pin.text);
    if (!mounted) return;
    if (resultado == ResultadoRevelar.revelado) {
      Navigator.of(context).pop(true);
      return;
    }
    _pin.clear();
    _confirmacion.clear();
    setState(() {
      _trabajando = false;
      _cambiando = false;
      _error = mensajeRevelar(resultado, espera: controlador.esperaRestante());
    });
  }

  Future<void> _conHuella() async {
    if (_trabajando) return;
    setState(() => _trabajando = true);
    final resultado = await ref
        .read(controladorMontosProvider.notifier)
        .verificarConHuella();
    if (!mounted) return;
    if (resultado == ResultadoRevelar.revelado) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _trabajando = false;
      _error = mensajeRevelar(resultado);
    });
  }

  Widget _campo(TextEditingController control, String etiqueta, Key llave) =>
      TextField(
        key: llave,
        controller: control,
        enabled: !_trabajando,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _aceptar(),
        decoration: InputDecoration(labelText: etiqueta),
      );

  @override
  Widget build(BuildContext context) {
    final rol = ref.read(controladorMontosProvider.notifier).rol;
    return AlertDialog(
      key: const ValueKey('dialogo-revelar-montos'),
      title: Text(
        _crear
            ? 'Crea tu PIN para ver los montos'
            : (_cambiando ? 'Elige tu PIN de 6 dígitos' : 'Ver los montos'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_cambiando) const AvisoPinCorto(),
          if (!_cambiando)
            Text(
              _crear
                  ? 'Los montos se ocultan solos tras unos minutos sin uso. '
                        'Elige un PIN de ${textoDelLargoDelPin(rol)} (no uno '
                        'fácil como 1234) para volver a verlos.'
                  : 'Los montos se ocultaron por falta de uso. Escribe tu PIN '
                        'para verlos.',
            ),
          const SizedBox(height: 12),
          _campo(
            _pin,
            _crear || _cambiando
                ? 'PIN nuevo (${textoDelLargoDelPin(rol)})'
                : 'PIN',
            const Key('revelar-pin'),
          ),
          if (_crear || _cambiando)
            _campo(
              _confirmacion,
              'Repite el PIN',
              const Key('revelar-confirmacion'),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: const ValueKey('revelar-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        if (_huella && !_cambiando)
          TextButton.icon(
            key: const ValueKey('revelar-huella'),
            onPressed: _trabajando ? null : _conHuella,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Usar huella'),
          ),
        FilledButton(
          key: const ValueKey('revelar-aceptar'),
          onPressed: _trabajando ? null : _aceptar,
          child: Text(
            _crear ? 'Guardar y ver' : (_cambiando ? 'Guardar y ver' : 'Ver'),
          ),
        ),
      ],
    );
  }
}

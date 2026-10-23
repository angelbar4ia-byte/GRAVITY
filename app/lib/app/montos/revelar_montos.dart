/// Volver a ver los montos (decisión del 23/oct/2026): se ocultan solos tras
/// unos minutos sin uso y para verlos se pide el PIN (en el teléfono, también
/// la huella). Si no hay ningún PIN para pedir, la primera vez se crea uno
/// propio (no triviales).
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
      final error = errorDePinNuevo(_pin.text);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      if (_pin.text != _confirmacion.text) {
        setState(() => _error = 'Los PIN no coinciden.');
        return;
      }
      setState(() => _trabajando = true);
      await controlador.crearPin(_pin.text);
      if (mounted) Navigator.of(context).pop(true);
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
    _pin.clear();
    setState(() {
      _trabajando = false;
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
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('dialogo-revelar-montos'),
    title: Text(_crear ? 'Crea tu PIN para ver los montos' : 'Ver los montos'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _crear
              ? 'Los montos se ocultan solos tras unos minutos sin uso. Elige '
                    'un PIN de 4 a 6 dígitos (no uno fácil como 1234) para '
                    'volver a verlos.'
              : 'Los montos se ocultaron por falta de uso. Escribe tu PIN para '
                    'verlos.',
        ),
        const SizedBox(height: 12),
        _campo(
          _pin,
          _crear ? 'PIN nuevo (4 a 6 dígitos)' : 'PIN',
          const Key('revelar-pin'),
        ),
        if (_crear)
          _campo(_confirmacion, 'Repite el PIN', const Key('revelar-confirmacion')),
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
      if (_huella)
        TextButton.icon(
          key: const ValueKey('revelar-huella'),
          onPressed: _trabajando ? null : _conHuella,
          icon: const Icon(Icons.fingerprint),
          label: const Text('Usar huella'),
        ),
      FilledButton(
        key: const ValueKey('revelar-aceptar'),
        onPressed: _trabajando ? null : _aceptar,
        child: Text(_crear ? 'Guardar y ver' : 'Ver'),
      ),
    ],
  );
}

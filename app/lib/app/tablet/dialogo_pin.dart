/// Entrar como una persona en la tablet: PIN de 4 a 6 dígitos o huella.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../../nucleo/tablet/usuarios_tablet.dart';

/// Devuelve `true` si la persona entró.
Future<bool> mostrarDialogoPin(BuildContext context, UsuarioTablet usuario) async =>
    await showDialog<bool>(
      context: context,
      builder: (contexto) => DialogoPin(usuario: usuario),
    ) ??
    false;

class DialogoPin extends ConsumerStatefulWidget {
  const DialogoPin({super.key, required this.usuario});

  final UsuarioTablet usuario;

  @override
  ConsumerState<DialogoPin> createState() => _DialogoPinState();
}

class _DialogoPinState extends ConsumerState<DialogoPin> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _mostrar(ResultadoDesbloqueo resultado) {
    if (resultado == ResultadoDesbloqueo.abierto) {
      Navigator.of(context).pop(true);
      return;
    }
    _pin.clear();
    setState(
      () => _error = switch (resultado) {
        ResultadoDesbloqueo.pinIncorrecto => 'PIN incorrecto.',
        ResultadoDesbloqueo.bloqueado =>
          'Demasiados intentos. Espera 30 segundos.',
        ResultadoDesbloqueo.huellaNoDisponible =>
          'La huella no está disponible. Usa tu PIN.',
        ResultadoDesbloqueo.huellaFallida => 'No se reconoció la huella.',
        ResultadoDesbloqueo.noExiste => 'Esta persona ya no está en la tablet.',
        ResultadoDesbloqueo.abierto => null,
      },
    );
  }

  void _entrarConPin() => _mostrar(
    ref
        .read(controladorTabletProvider.notifier)
        .desbloquearConPin(widget.usuario.personaId, _pin.text),
  );

  Future<void> _entrarConHuella() async {
    final resultado = await ref
        .read(controladorTabletProvider.notifier)
        .desbloquearConHuella(widget.usuario.personaId);
    if (mounted) _mostrar(resultado);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Hola, ${widget.usuario.nombre}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombreRol(widget.usuario.rol)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo-pin'),
          controller: _pin,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _entrarConPin(),
          style: const TextStyle(fontSize: 28, letterSpacing: 8),
          decoration: InputDecoration(
            labelText: 'PIN',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      if (widget.usuario.huella)
        TextButton.icon(
          onPressed: _entrarConHuella,
          icon: const Icon(Icons.fingerprint),
          label: const Text('Usar huella'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _entrarConPin, child: const Text('Entrar')),
    ],
  );
}

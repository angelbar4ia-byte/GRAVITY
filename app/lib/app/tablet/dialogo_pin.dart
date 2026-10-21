/// Entrar como una persona en la tablet: solo con su PIN de 4 a 6 dígitos.
///
/// La huella no abre la tablet compartida (revisión de la Fase 0, B3): Android
/// acepta cualquier dedo registrado en el equipo y no dice de quién es.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/seguridad/intentos.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../../nucleo/tablet/usuarios_tablet.dart';

/// Devuelve `true` si la persona entró. Con [paraAccion] (tablet pública)
/// entra solo para una acción personal y la pantalla sigue en el modo Casa.
Future<bool> mostrarDialogoPin(
  BuildContext context,
  UsuarioTablet usuario, {
  bool paraAccion = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (contexto) =>
          DialogoPin(usuario: usuario, paraAccion: paraAccion),
    ) ??
    false;

/// Mensaje para la persona según el resultado de entrar.
String? mensajeDesbloqueo(ResultadoDesbloqueo resultado, {Duration? espera}) =>
    switch (resultado) {
      ResultadoDesbloqueo.abierto || ResultadoDesbloqueo.cancelado => null,
      ResultadoDesbloqueo.pinIncorrecto => 'PIN incorrecto.',
      ResultadoDesbloqueo.bloqueado =>
        'Demasiados intentos. Espera ${textoEspera(espera ?? ControladorTablet.duracionBloqueo)}.',
      ResultadoDesbloqueo.huellaNoDisponible =>
        'En la tablet de la casa se entra con el PIN.',
      ResultadoDesbloqueo.faltaCuenta =>
        'Falta tu cuenta en esta tablet: pide que te agreguen de nuevo con tu '
            'correo y contraseña.',
      ResultadoDesbloqueo.sinAcceso =>
        'Tu cuenta ya no tiene acceso a esta casa. Se quitó de la tablet.',
      ResultadoDesbloqueo.requiereCuentaCasa =>
        'La tablet debe tener abierta la cuenta Casa.',
      ResultadoDesbloqueo.error =>
        'No se pudo comprobar tu cuenta. Intenta de nuevo.',
      ResultadoDesbloqueo.noExiste => 'Esta persona ya no está en la tablet.',
      ResultadoDesbloqueo.noPermitida =>
        'Esta tablet es personal y no estás entre las personas permitidas.',
    };

class DialogoPin extends ConsumerStatefulWidget {
  const DialogoPin({super.key, required this.usuario, this.paraAccion = false});

  final UsuarioTablet usuario;

  /// Entra solo para una acción (tablet pública, D14).
  final bool paraAccion;

  @override
  ConsumerState<DialogoPin> createState() => _DialogoPinState();
}

class _DialogoPinState extends ConsumerState<DialogoPin> {
  final _pin = TextEditingController();
  String? _error;
  bool _entrando = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _entrarConPin() async {
    if (_entrando) return;
    final controlador = ref.read(controladorTabletProvider.notifier);
    final personaId = widget.usuario.personaId;
    setState(() {
      _entrando = true;
      _error = null;
    });
    final resultado = widget.paraAccion
        ? await controlador.entrarParaAccion(personaId, _pin.text)
        : await controlador.entrarConPin(personaId, _pin.text);
    // Al entrar, el cascarón ya cerró este diálogo (B2): no se cierra dos
    // veces (se cerraría la pantalla de abajo).
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (resultado == ResultadoDesbloqueo.abierto) {
      Navigator.of(context).pop(true);
      return;
    }
    _pin.clear();
    setState(() {
      _entrando = false;
      _error = mensajeDesbloqueo(
        resultado,
        espera: controlador.esperaRestante(personaId),
      );
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Hola, ${widget.usuario.nombre}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.paraAccion
              ? '${nombreRol(widget.usuario.rol)} · solo para esta acción'
              : nombreRol(widget.usuario.rol),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo-pin'),
          controller: _pin,
          autofocus: true,
          enabled: !_entrando,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _entrarConPin(),
          style: const TextStyle(fontSize: 28, letterSpacing: 8),
          decoration: InputDecoration(
            labelText: 'PIN',
            errorText: _error,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _entrando ? null : _entrarConPin,
        child: _entrando
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Entrar'),
      ),
    ],
  );
}

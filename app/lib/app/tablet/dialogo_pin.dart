/// Entrar como una persona en la tablet: solo con su PIN (6 dígitos si ve
/// dinero; de 4 a 6 si no).
///
/// La huella no abre la tablet compartida (revisión de la Fase 0, B3): Android
/// acepta cualquier dedo registrado en el equipo y no dice de quién es.
///
/// Quien ve dinero y todavía tiene un PIN más corto (D18, 23/oct) escribe el
/// suyo, el diálogo le pide uno nuevo de 6 dígitos y, al guardarlo, entra: su
/// cuenta guardada y lo que tenga por subir se conservan (se vuelven a cifrar
/// con el PIN nuevo).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/seguridad/intentos.dart';
import '../../nucleo/seguridad/pin.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../../nucleo/tablet/usuarios_tablet.dart';
import '../pin/campos_pin_nuevo.dart';

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
        'La tablet debe tener abierta la cuenta Hogar.',
      ResultadoDesbloqueo.error =>
        'No se pudo comprobar tu cuenta. Intenta de nuevo.',
      ResultadoDesbloqueo.noExiste => 'Esta persona ya no está en la tablet.',
      ResultadoDesbloqueo.noPermitida =>
        'Esta tablet es personal y no estás entre las personas permitidas.',
      ResultadoDesbloqueo.debeCambiarPin => avisoPinCortoConDinero,
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
  final _nuevo = TextEditingController();
  final _confirmacion = TextEditingController();
  String? _error;
  bool _entrando = false;

  /// El PIN que escribió era correcto pero corto: ahora elige uno de 6
  /// dígitos ([_pinActual] es el que acaba de escribir).
  bool _cambiando = false;
  String _pinActual = '';

  @override
  void dispose() {
    _pin.dispose();
    _nuevo.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  /// Termina de entrar (o de intentarlo) con lo que respondió el controlador.
  void _alResultado(ResultadoDesbloqueo resultado) {
    final controlador = ref.read(controladorTabletProvider.notifier);
    final personaId = widget.usuario.personaId;
    // Al entrar, el cascarón ya cerró este diálogo (B2): no se cierra dos
    // veces (se cerraría la pantalla de abajo).
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (resultado == ResultadoDesbloqueo.abierto) {
      Navigator.of(context).pop(true);
      return;
    }
    final aCambiar = resultado == ResultadoDesbloqueo.debeCambiarPin;
    if (aCambiar) _pinActual = _pin.text;
    _pin.clear();
    _nuevo.clear();
    _confirmacion.clear();
    setState(() {
      _entrando = false;
      _cambiando = aCambiar;
      _error = aCambiar
          ? null
          : mensajeDesbloqueo(
              resultado,
              espera: controlador.esperaRestante(personaId),
            );
    });
  }

  Future<void> _entrarConPin() async {
    if (_entrando) return;
    final controlador = ref.read(controladorTabletProvider.notifier);
    final personaId = widget.usuario.personaId;
    setState(() {
      _entrando = true;
      _error = null;
    });
    _alResultado(
      widget.paraAccion
          ? await controlador.entrarParaAccion(personaId, _pin.text)
          : await controlador.entrarConPin(personaId, _pin.text),
    );
  }

  /// Guarda el PIN de 6 dígitos y entra.
  Future<void> _guardarNuevoYEntrar() async {
    if (_entrando) return;
    final error = errorDePinNuevoConfirmado(
      _nuevo.text,
      _confirmacion.text,
      rol: widget.usuario.rol,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _entrando = true;
      _error = null;
    });
    try {
      _alResultado(
        await ref
            .read(controladorTabletProvider.notifier)
            .cambiarPinYEntrar(
              widget.usuario.personaId,
              pinActual: _pinActual,
              pinNuevo: _nuevo.text,
              paraAccion: widget.paraAccion,
            ),
      );
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() {
          _entrando = false;
          _error = '${e.message}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: _cambiando ? const ValueKey('dialogo-cambiar-pin-al-entrar') : null,
    title: Text(
      _cambiando
          ? 'Elige tu PIN de 6 dígitos'
          : 'Hola, ${widget.usuario.nombre}',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_cambiando) ...[
          const AvisoPinCorto(),
          CamposPinNuevo(
            pin: _nuevo,
            confirmacion: _confirmacion,
            rol: widget.usuario.rol,
            habilitado: !_entrando,
            alEnviar: _guardarNuevoYEntrar,
            errorText: _error,
          ),
        ] else ...[
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
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: _cambiando ? const ValueKey('guardar-pin-y-entrar') : null,
        onPressed: _entrando
            ? null
            : (_cambiando ? _guardarNuevoYEntrar : _entrarConPin),
        child: _entrando
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_cambiando ? 'Guardar y entrar' : 'Entrar'),
      ),
    ],
  );
}

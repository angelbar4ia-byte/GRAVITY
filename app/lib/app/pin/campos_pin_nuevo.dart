/// Los dos campos con los que se elige un PIN nuevo (el PIN y repetirlo), y el
/// aviso que se muestra cuando alguien que ve dinero debe pasar de un PIN corto
/// a uno de 6 dígitos (decisión del dueño, 23/oct/2026, D18).
///
/// Lo usan los cuatro lugares donde se teclea un PIN y puede aparecer el
/// cambio: entrar en la tablet, el bloqueo del teléfono, ver los montos y
/// Ajustes › Privacidad. Cada uno decide qué hacer con el PIN nuevo; esto solo
/// pinta los campos y valida con las mismas reglas ([errorDePinNuevoConfirmado]).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../nucleo/contratos/roles.dart';
import '../../nucleo/seguridad/pin.dart';

/// Campos "PIN nuevo" y "Repite el PIN". Las llaves de prueba son
/// `Key('$prefijo')` y `Key('$prefijo-confirmacion')`.
class CamposPinNuevo extends StatelessWidget {
  const CamposPinNuevo({
    super.key,
    required this.pin,
    required this.confirmacion,
    required this.rol,
    this.prefijo = 'pin-nuevo-cambio',
    this.habilitado = true,
    this.alEnviar,
    this.errorText,
  });

  final TextEditingController pin;
  final TextEditingController confirmacion;

  /// Rol de quien elige el PIN: de él depende el largo.
  final Rol? rol;
  final String prefijo;
  final bool habilitado;
  final VoidCallback? alEnviar;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _campo(
        Key(prefijo),
        pin,
        'PIN nuevo (${textoDelLargoDelPin(rol)})',
        autofocus: true,
      ),
      _campo(
        Key('$prefijo-confirmacion'),
        confirmacion,
        'Repite el PIN',
        error: errorText,
      ),
    ],
  );

  Widget _campo(
    Key llave,
    TextEditingController control,
    String etiqueta, {
    bool autofocus = false,
    String? error,
  }) => TextField(
    key: llave,
    controller: control,
    autofocus: autofocus,
    enabled: habilitado,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSubmitted: alEnviar == null ? null : (_) => alEnviar!(),
    decoration: InputDecoration(
      labelText: etiqueta,
      errorText: error,
      errorMaxLines: 3,
    ),
  );
}

/// El aviso de por qué se pide un PIN nuevo (llave `aviso-pin-corto`).
class AvisoPinCorto extends StatelessWidget {
  const AvisoPinCorto({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(avisoPinCortoConDinero, key: ValueKey('aviso-pin-corto')),
  );
}

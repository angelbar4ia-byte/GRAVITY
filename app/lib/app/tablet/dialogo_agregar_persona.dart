/// Agregar a una persona a la tablet: su correo y contraseña (se comprueban
/// en el servidor, así el rol es el real) y un PIN nuevo de 4 a 6 dígitos. Su
/// sesión del servidor queda guardada, cifrada con ese PIN, para que al entrar
/// las peticiones salgan con su identidad (revisión de la Fase 0, I6).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/seguridad/pin.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/sesion/sesion.dart';
import '../../nucleo/tablet/controlador_tablet.dart';

/// Devuelve `true` si se agregó.
Future<bool> mostrarDialogoAgregarPersona(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (contexto) => const DialogoAgregarPersona(),
    ) ??
    false;

class DialogoAgregarPersona extends ConsumerStatefulWidget {
  const DialogoAgregarPersona({super.key});

  @override
  ConsumerState<DialogoAgregarPersona> createState() =>
      _DialogoAgregarPersonaState();
}

class _DialogoAgregarPersonaState extends ConsumerState<DialogoAgregarPersona> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _pin = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _pin.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(controladorTabletProvider.notifier)
          .agregarConCredenciales(
            correo: _correo.text,
            contrasena: _contrasena.text,
            pin: _pin.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ErrorSesion catch (error) {
      if (mounted) setState(() => _error = error.mensaje);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = '${error.message}');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demostracion = ref.watch(servicioSesionProvider).esDemostracion;
    return AlertDialog(
      title: const Text('Agregar persona a la tablet'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formulario,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  demostracion
                      ? 'Demostración: el rol sale del correo '
                            '(pareja@, familiar@, cuidador@; cualquier otro '
                            'es Dueño). Cualquier contraseña sirve.'
                      : 'La persona escribe su correo y contraseña una sola '
                            'vez y elige su PIN. En la tablet de la casa se '
                            'entra solo con el PIN.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('agregar-correo'),
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Escribe el correo.' : null,
                ),
                TextFormField(
                  key: const Key('agregar-contrasena'),
                  controller: _contrasena,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Escribe la contraseña.' : null,
                ),
                TextFormField(
                  key: const Key('agregar-pin'),
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'PIN nuevo (4 a 6 dígitos)',
                  ),
                  validator: (v) => errorDePinNuevo(v ?? ''),
                ),
                TextFormField(
                  key: const Key('agregar-confirmacion'),
                  controller: _confirmacion,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Repite el PIN'),
                  validator: (v) =>
                      v == _pin.text ? null : 'Los PIN no coinciden.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

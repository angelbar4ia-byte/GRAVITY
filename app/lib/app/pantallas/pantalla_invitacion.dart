/// "Tengo una invitación" (E3 de la Fase 4): quien recibió el código del dueño
/// crea su cuenta (o entra con la que ya tiene) y el servidor la une al hogar
/// con el rol invitado (`aceptar_invitacion`).
///
/// - El dueño entrega el código **en persona**; el servidor no manda correo con
///   él. La cuenta se crea con **el mismo correo** de la invitación.
/// - Si el servidor pide confirmar el correo, se confirma con el enlace que
///   llega y se vuelve a esta pantalla con "Ya tengo cuenta": el código sigue
///   valiendo hasta que venza.
/// - Funciona sin sesión; con sesión abierta el router lleva al inicio.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/sesion/sesion.dart';

final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Largo mínimo de la contraseña al crear una cuenta (el servidor puede pedir
/// más).
const largoMinimoContrasena = 8;

class PantallaInvitacion extends ConsumerStatefulWidget {
  const PantallaInvitacion({super.key});

  @override
  ConsumerState<PantallaInvitacion> createState() => _PantallaInvitacionState();
}

class _PantallaInvitacionState extends ConsumerState<PantallaInvitacion> {
  final _formulario = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _cuentaNueva = true;
  bool _verContrasena = false;
  bool _trabajando = false;
  String? _error;
  String? _aviso;

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _aceptar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    final servicio = ref.read(servicioSesionProvider);
    if (servicio is! AceptaInvitaciones) {
      setState(() => _error = 'Las invitaciones no están disponibles aquí.');
      return;
    }
    setState(() {
      _trabajando = true;
      _error = null;
      _aviso = null;
    });
    try {
      final resultado = await (servicio as AceptaInvitaciones)
          .aceptarInvitacion(
            token: _codigo.text,
            correo: _correo.text,
            contrasena: _contrasena.text,
            nombre: _nombre.text,
            cuentaNueva: _cuentaNueva,
          );
      if (!mounted) return;
      if (resultado.faltaConfirmarCorreo) {
        setState(() {
          _cuentaNueva = false;
          _aviso =
              'Te mandamos un correo para confirmar tu dirección. Ábrelo y '
              'vuelve aquí: elige "Ya tengo cuenta" y escribe tu contraseña. '
              'El código sigue valiendo.';
        });
      }
      // Con la sesión abierta, el router lleva a la pantalla de inicio del rol.
    } on ErrorSesion catch (error) {
      if (mounted) setState(() => _error = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo aceptar la invitación. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tengo una invitación'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Rutas.entrar),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Quien administra el hogar te dio un código. Úsalo con '
                      'el mismo correo con el que te invitó.',
                      style: tema.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      key: const ValueKey('invitacion-modo'),
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Crear mi cuenta'),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Ya tengo cuenta'),
                        ),
                      ],
                      selected: {_cuentaNueva},
                      onSelectionChanged: _trabajando
                          ? null
                          : (valor) =>
                                setState(() => _cuentaNueva = valor.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('invitacion-codigo'),
                      controller: _codigo,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Código de la invitación',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Escribe el código que te dieron.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (_cuentaNueva) ...[
                      TextFormField(
                        key: const ValueKey('invitacion-nombre'),
                        controller: _nombre,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Tu nombre',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Escribe tu nombre.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const ValueKey('invitacion-correo'),
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo de la invitación',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _correoValido.hasMatch((v ?? '').trim())
                          ? null
                          : 'Escribe tu correo.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('invitacion-contrasena'),
                      controller: _contrasena,
                      obscureText: !_verContrasena,
                      autofillHints: [
                        _cuentaNueva
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) => _aceptar(),
                      decoration: InputDecoration(
                        labelText: _cuentaNueva
                            ? 'Contraseña (mínimo $largoMinimoContrasena)'
                            : 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _verContrasena
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          icon: Icon(
                            _verContrasena
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _verContrasena = !_verContrasena),
                        ),
                      ),
                      validator: (v) {
                        final texto = v ?? '';
                        if (texto.isEmpty) return 'Escribe tu contraseña.';
                        if (_cuentaNueva &&
                            texto.length < largoMinimoContrasena) {
                          return 'Usa al menos $largoMinimoContrasena caracteres.';
                        }
                        return null;
                      },
                    ),
                    if (_aviso != null) ...[
                      const SizedBox(height: 12),
                      Text(_aviso!, key: const ValueKey('invitacion-aviso')),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const ValueKey('invitacion-error'),
                        style: TextStyle(color: tema.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const ValueKey('invitacion-aceptar'),
                        onPressed: _trabajando ? null : _aceptar,
                        child: _trabajando
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _cuentaNueva
                                    ? 'Crear cuenta y unirme'
                                    : 'Entrar y unirme',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

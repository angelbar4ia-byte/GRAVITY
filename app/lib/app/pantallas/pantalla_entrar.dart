/// Entrar con correo y contraseña (Fase 0). Sin servidor configurado se
/// muestra el modo demostración con un selector de rol.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/sesion/sesion.dart';
import '../dispositivo.dart';
import '../navegacion.dart' show RutasApp;
import '../sesion_efectiva.dart';

class PantallaEntrar extends ConsumerStatefulWidget {
  const PantallaEntrar({super.key});

  @override
  ConsumerState<PantallaEntrar> createState() => _PantallaEntrarState();
}

class _PantallaEntrarState extends ConsumerState<PantallaEntrar> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _cargando = false;
  bool _verContrasena = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _intentar(Future<Sesion> Function() entrar) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await entrar();
      // El router lleva a la pantalla de inicio del rol.
    } on ErrorSesion catch (error) {
      if (mounted) setState(() => _error = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo entrar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _entrar() {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    _intentar(
      () => ref
          .read(servicioSesionProvider)
          .entrar(correo: _correo.text, contrasena: _contrasena.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ref.watch(servicioSesionProvider);
    final demostracion = servicio is EntradaDeDemostracion
        ? servicio as EntradaDeDemostracion
        : null;
    final esTablet =
        ref.watch(tipoDispositivoProvider) == TipoDispositivo.tablet;
    // D14 (revisión de la Fase 0, I6): la tablet de la casa trabaja con la
    // cuenta de rol Casa. Con otra cuenta, se pide la de la casa.
    final cuentaAjena = ref.watch(tabletSinCuentaCasaProvider)
        ? ref.watch(sesionActualProvider)
        : null;
    final tema = Theme.of(context);
    return Scaffold(
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
                    Icon(
                      Icons.blur_circular,
                      size: 64,
                      color: tema.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'GRAVITY',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      esTablet
                          ? 'Entra con la cuenta Hogar'
                          : 'Entra con tu cuenta',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodyLarge,
                    ),
                    if (cuentaAjena != null) ...[
                      const SizedBox(height: 16),
                      _AvisoCuentaCasa(
                        sesion: cuentaAjena,
                        alCerrar: _cargando
                            ? null
                            : () => ref.read(servicioSesionProvider).salir(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        border: OutlineInputBorder(),
                      ),
                      validator: (valor) =>
                          (valor == null || !valor.contains('@'))
                          ? 'Escribe tu correo.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contrasena,
                      obscureText: !_verContrasena,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
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
                      validator: (valor) => (valor == null || valor.isEmpty)
                          ? 'Escribe tu contraseña.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: tema.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _cargando ? null : _entrar,
                        child: _cargando
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                    ),
                    // E3 (Fase 4): quien recibió un código del dueño crea su
                    // cuenta y entra al hogar. La tablet de la casa no: allí
                    // solo entra la cuenta Hogar.
                    if (!esTablet && servicio is AceptaInvitaciones) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        key: const ValueKey('tengo-invitacion'),
                        onPressed: _cargando
                            ? null
                            : () => context.go(RutasApp.invitacion),
                        child: const Text('Tengo una invitación'),
                      ),
                    ],
                    if (demostracion != null) ...[
                      const SizedBox(height: 32),
                      _ModoDemostracion(
                        roles: esTablet
                            ? const [Rol.casa]
                            : demostracion.rolesDisponibles,
                        habilitado: !_cargando,
                        alElegir: (rol) =>
                            _intentar(() => demostracion.entrarComo(rol)),
                      ),
                    ],
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

/// La tablet tiene abierta la cuenta de una persona: se explica que en la
/// tablet de la casa cada quien entra con su PIN desde el modo Casa.
class _AvisoCuentaCasa extends StatelessWidget {
  const _AvisoCuentaCasa({required this.sesion, required this.alCerrar});

  final Sesion sesion;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: const ValueKey('aviso-cuenta-casa'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Esta es la tablet de la casa',
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Está abierta la cuenta de ${sesion.persona.nombre} '
              '(${nombreRol(sesion.rol)}). La tablet trabaja con la cuenta '
              'Casa; cada persona entra después con su PIN desde el modo Casa.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: alCerrar,
                icon: const Icon(Icons.logout),
                label: Text('Cerrar la cuenta de ${sesion.persona.nombre}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModoDemostracion extends StatelessWidget {
  const _ModoDemostracion({
    required this.roles,
    required this.habilitado,
    required this.alElegir,
  });

  final List<Rol> roles;
  final bool habilitado;
  final ValueChanged<Rol> alElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modo demostración', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'No hay servidor configurado: se usan personas de ejemplo. '
              'Elige un rol para probar la app.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rol in roles)
                  FilledButton.tonal(
                    onPressed: habilitado ? () => alElegir(rol) : null,
                    child: Text('Entrar como ${nombreRol(rol)}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

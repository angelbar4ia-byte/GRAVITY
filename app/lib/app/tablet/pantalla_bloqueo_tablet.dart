/// Reposo de la tablet **personal** (D14, 21/oct/2026): pantalla de bloqueo
/// con los perfiles permitidos (dueño y pareja). Cada quien entra con su PIN;
/// no hay modo Casa ni nada de la casa a la vista.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../../nucleo/tablet/usuarios_tablet.dart';
import 'dialogo_agregar_persona.dart';
import 'dialogo_pin.dart';

class PantallaBloqueoTablet extends ConsumerWidget {
  const PantallaBloqueoTablet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(controladorTabletProvider);
    final perfiles = estado.usuariosQuePuedenEntrar;
    final demostracion = ref.watch(servicioSesionProvider).esDemostracion;
    final tema = Theme.of(context);
    return Scaffold(
      key: const ValueKey('bloqueo-tablet-personal'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text('GRAVITY', style: tema.textTheme.headlineMedium),
                  Text(
                    'Tablet personal · toca tu nombre y escribe tu PIN',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyLarge,
                  ),
                  if (demostracion)
                    Text(
                      'Demostración: el PIN es '
                      '${ControladorTablet.pinDeDemostracion}.',
                      style: tema.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 32),
                  if (!estado.cargado)
                    const CircularProgressIndicator()
                  else if (perfiles.isEmpty)
                    const _SinPerfiles()
                  else
                    Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final usuario in perfiles)
                          _Perfil(usuario: usuario),
                      ],
                    ),
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: () => mostrarDialogoAgregarPersona(context),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Agregar persona'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Perfil extends StatelessWidget {
  const _Perfil({required this.usuario});

  final UsuarioTablet usuario;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return InkWell(
      key: ValueKey('perfil-${usuario.personaId}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => mostrarDialogoPin(context, usuario),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 120,
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                child: Text(
                  usuario.nombre.characters.first.toUpperCase(),
                  style: tema.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                usuario.nombre,
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium,
              ),
              Text(nombreRol(usuario.rol), style: tema.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nadie puede entrar (p. ej. se quitó a todas las personas permitidas): se
/// ofrece volver a la tablet de la casa para no dejarla inservible.
class _SinPerfiles extends ConsumerWidget {
  const _SinPerfiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      const Text(
        'No hay personas permitidas en esta tablet. Agrega al dueño o a la '
        'pareja con su correo y contraseña, o úsala como tablet de la casa.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => ref
            .read(controladorTabletProvider.notifier)
            .elegirTipo(TipoTablet.publica),
        icon: const Icon(Icons.home_outlined),
        label: const Text('Usar como tablet de la casa'),
      ),
    ],
  );
}

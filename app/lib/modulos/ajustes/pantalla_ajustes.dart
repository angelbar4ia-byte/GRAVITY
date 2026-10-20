/// Ajustes: lista de secciones según el rol y el dispositivo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dispositivo.dart';
import '../../app/pantallas/marco_pantalla.dart';
import '../../app/pantallas_externas.dart';
import '../../app/sesion_efectiva.dart';
import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import 'apariencia/pantalla_apariencia.dart';
import 'copias/pantalla_copias.dart';
import 'notificaciones/pantalla_notificaciones.dart';
import 'personas/pantalla_personas.dart';
import 'privacidad/pantalla_privacidad.dart';
import 'secciones_ajustes.dart';
import 'voz/pantalla_voz.dart';

/// Pantalla de cada sección (Desarrollador la construye el agente asistente).
Widget pantallaDeSeccion(SeccionAjustes seccion) => switch (seccion) {
  SeccionAjustes.apariencia => const PantallaApariencia(),
  SeccionAjustes.voz => const PantallaVoz(),
  SeccionAjustes.personas => const PantallaPersonas(),
  SeccionAjustes.privacidad => const PantallaPrivacidad(),
  SeccionAjustes.copias => const PantallaCopias(),
  SeccionAjustes.notificaciones => const PantallaNotificaciones(),
  SeccionAjustes.desarrollador => MarcoPantalla(
    titulo: infoSecciones[SeccionAjustes.desarrollador]!.titulo,
    rutaAnterior: Rutas.ajustes,
    cuerpo: pantallaDesarrollador(),
  ),
};

class PantallaAjustes extends ConsumerWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionEfectivaProvider);
    if (sesion == null) return const SizedBox.shrink();
    final dispositivo = ref.watch(tipoDispositivoProvider);
    final esTablet = dispositivo == TipoDispositivo.tablet;
    return MarcoPantalla(
      titulo: 'Ajustes',
      cuerpo: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(sesion.persona.nombre),
            subtitle: Text(nombreRol(sesion.rol)),
          ),
          const Divider(),
          for (final seccion in seccionesVisibles(sesion.rol, dispositivo))
            ListTile(
              leading: Icon(infoSecciones[seccion]!.icono),
              title: Text(infoSecciones[seccion]!.titulo),
              subtitle: Text(infoSecciones[seccion]!.descripcion),
              minTileHeight: 64,
              onTap: () => context.go(rutaSeccion(seccion)),
            ),
          const Divider(),
          if (esTablet) ...[
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Volver al modo Casa'),
              onTap: () =>
                  ref.read(controladorTabletProvider.notifier).volverAModoCasa(),
            ),
            if (puede(sesion.rol, Modulo.ajustes, Accion.administrar))
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar la sesión de la tablet'),
                subtitle: const Text('Para entrar con otra cuenta de la casa'),
                onTap: () => _confirmarSalida(context, ref),
              ),
          ] else
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Salir'),
              onTap: () => ref.read(servicioSesionProvider).salir(),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmarSalida(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Cerrar la sesión de la tablet?'),
        content: const Text(
          'La tablet pedirá entrar de nuevo con una cuenta. Las personas y sus '
          'PIN se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmado ?? false) await ref.read(servicioSesionProvider).salir();
  }
}

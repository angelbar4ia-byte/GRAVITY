/// "Más" del teléfono y de la tablet: los módulos sin pestaña propia,
/// Ajustes y salir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../dispositivo.dart';
import '../navegacion.dart';
import '../sesion_efectiva.dart';
import 'acceso_instrucciones_cuidados.dart';
import 'acceso_vista_papa.dart';
import 'marco_pantalla.dart';

class PantallaMas extends ConsumerWidget {
  const PantallaMas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null) return const SizedBox.shrink();
    final esTablet =
        ref.watch(tipoDispositivoProvider) == TipoDispositivo.tablet;
    return MarcoPantalla(
      titulo: 'Más',
      cuerpo: ListView(
        children: [
          for (final modulo in modulosEnMas(rol))
            ListTile(
              leading: Icon(iconoDeModulo(modulo)),
              title: Text(nombreModulo(modulo)),
              subtitle: Text(permisoDe(rol, modulo).descripcion),
              minTileHeight: 56,
              onTap: () => context.go(rutaDeModulo(modulo)),
            ),
          if (rol == Rol.familiar) const AccesoPedirVistaPapa(),
          const AccesosInstruccionesCuidados(),
          if (puedeAbrir(rol, Modulo.ajustes)) ...[
            const Divider(),
            ListTile(
              leading: Icon(iconoDeModulo(Modulo.ajustes)),
              title: const Text('Ajustes'),
              minTileHeight: 56,
              onTap: () => context.go(Rutas.ajustes),
            ),
          ],
          const Divider(),
          if (esTablet && rol != Rol.casa)
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Volver al modo Casa'),
              minTileHeight: 56,
              onTap: () => ref
                  .read(controladorTabletProvider.notifier)
                  .volverAModoCasa(),
            )
          else if (!esTablet)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Salir'),
              minTileHeight: 56,
              onTap: () => ref.read(servicioSesionProvider).salir(),
            ),
        ],
      ),
    );
  }
}

/// Cascarón de la tablet de la casa (D14): modo Casa por omisión; quien entra
/// con su PIN ve sus pantallas con riel lateral, y tras el tiempo sin uso
/// (2 min por omisión) la tablet regresa sola al modo Casa.
///
/// Al cambiar de persona (entrar, salir o vencer el tiempo) se cierran todas
/// las hojas, diálogos y menús que quedaron abiertos (revisión de la Fase 0,
/// B2): nada de una persona queda al alcance de la siguiente.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../../nucleo/tablet/usuarios_tablet.dart';
import '../navegacion.dart';
import '../pantallas/hoja_registrar.dart';
import '../pantallas/registros_atencion.dart';
import '../router.dart';
import '../sesion_efectiva.dart';
import '../tablet/detector_inactividad.dart';

class CascaronTablet extends ConsumerWidget {
  const CascaronTablet({
    super.key,
    required this.ubicacion,
    required this.child,
  });

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Al entrar alguien o al volver al modo Casa, se va a su inicio.
    ref.listen<UsuarioTablet?>(
      controladorTabletProvider.select((estado) => estado.usuarioActivo),
      (anterior, actual) {
        if (anterior?.personaId == actual?.personaId) return;
        cerrarLoQueEstaEncima(context);
        context.go(actual == null ? Rutas.inicio : inicioDe(actual.rol));
      },
    );
    final estado = ref.watch(controladorTabletProvider);
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null) return child;
    final destinos = destinosDe(rol);
    final enInicioCasa = estado.enModoCasa && ubicacion == Rutas.inicio;

    return DetectorInactividad(
      activo: !estado.enModoCasa,
      tiempo: estado.configuracion.regresoModoCasa,
      alVencer: () =>
          ref.read(controladorTabletProvider.notifier).volverAModoCasa(),
      child: enInicioCasa || destinos.length < 2
          ? child
          : Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: indiceDestino(ubicacion, destinos),
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (indice) {
                        final destino = destinos[indice];
                        if (destino.esRegistrar) {
                          mostrarHojaRegistrar(context, rol);
                        } else if (destino.ruta != null) {
                          context.go(destino.ruta!);
                        }
                      },
                      trailing: estado.enModoCasa
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: IconButton.filledTonal(
                                tooltip: 'Volver al modo Casa',
                                icon: const Icon(Icons.home_outlined),
                                onPressed: () => ref
                                    .read(controladorTabletProvider.notifier)
                                    .volverAModoCasa(),
                              ),
                            ),
                      destinations: [
                        for (final destino in destinos)
                          NavigationRailDestination(
                            icon: Icon(destino.icono),
                            label: Text(destino.etiqueta),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: ConAvisoAtencion(child: child)),
                  ],
                ),
              ),
            ),
    );
  }
}

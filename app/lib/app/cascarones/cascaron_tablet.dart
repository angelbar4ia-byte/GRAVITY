/// Cascarón de las tablets (D14): en reposo, modo Casa (tablet pública) o la
/// pantalla de bloqueo con los perfiles permitidos (tablet personal); quien
/// entra con su PIN ve sus pantallas con riel lateral, y tras el tiempo sin
/// uso (2 min por omisión) la tablet regresa sola al reposo. En la pública,
/// quien entra solo para una acción personal sigue viendo el modo Casa.
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
import '../tablet/pantalla_bloqueo_tablet.dart';

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
    // Al entrar alguien o al volver al reposo, se va a su inicio. Quien entra
    // solo para una acción en la tablet pública se queda en el modo Casa.
    ref.listen<(UsuarioTablet?, bool)>(
      controladorTabletProvider.select(
        (estado) => (estado.usuarioActivo, estado.soloAccion),
      ),
      (anterior, actual) {
        final (antes, _) = anterior ?? (null, false);
        final (ahora, soloAccion) = actual;
        if (antes?.personaId == ahora?.personaId) return;
        if (ahora != null && soloAccion) return;
        cerrarLoQueEstaEncima(context);
        context.go(ahora == null ? Rutas.inicio : inicioDe(ahora.rol));
      },
    );
    final estado = ref.watch(controladorTabletProvider);
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null) return child;
    // Mientras se lee la configuración no se sabe si es personal: nada.
    if (!estado.cargado) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }
    final destinos = destinosDe(rol);
    final enInicioCasa = estado.muestraModoCasa && ubicacion == Rutas.inicio;
    final personal = estado.configuracion.esPersonal;

    return DetectorInactividad(
      activo: !estado.enModoCasa,
      tiempo: estado.configuracion.regresoModoCasa,
      alVencer: () =>
          ref.read(controladorTabletProvider.notifier).volverAlReposo(),
      child: estado.bloqueada
          ? const PantallaBloqueoTablet()
          : enInicioCasa || destinos.length < 2
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
                                tooltip: personal
                                    ? 'Bloquear la tablet'
                                    : 'Volver al modo Casa',
                                icon: Icon(
                                  personal
                                      ? Icons.lock_outline
                                      : Icons.home_outlined,
                                ),
                                onPressed: () => ref
                                    .read(controladorTabletProvider.notifier)
                                    .volverAlReposo(),
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

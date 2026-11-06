/// Inicio (`/`) según el dispositivo y el rol: pantalla principal de GRAVITY
/// en la laptop, modo Casa en la tablet y "Hoy" en el teléfono.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../dispositivo.dart';
import '../pantallas_externas.dart';
import '../sesion_efectiva.dart';
import '../tablet/pantalla_modo_casa.dart';
import 'marco_pantalla.dart';

class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null) return const SizedBox.shrink();
    // Tablet pública: durante una acción personal la pantalla sigue en el
    // modo Casa (D14).
    final modoCasa = ref.watch(
      controladorTabletProvider.select((e) => e.muestraModoCasa),
    );
    return switch (ref.watch(tipoDispositivoProvider)) {
      TipoDispositivo.laptop => pantallaPrincipalGravity(
        barraOrdenes: barraOrdenes(
          rol: rol,
          onNavegar: (ruta) => context.go(ruta),
          dispositivo: TipoDispositivo.laptop,
        ),
      ),
      TipoDispositivo.tablet when rol == Rol.casa || modoCasa =>
        const PantallaModoCasa(),
      _ => MarcoPantalla(titulo: 'Hoy', cuerpo: pantallaHoyTelefono()),
    };
  }
}

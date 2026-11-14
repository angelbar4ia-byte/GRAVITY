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
import '../../modulos/finanzas/pantallas/vista_papa/tarjeta_vista_papa_dueno.dart';
import 'acceso_instrucciones_cuidados.dart';
import 'acceso_vista_papa.dart';
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
      TipoDispositivo.laptop => _ConAccesosVistaPapa(
        rol: rol,
        enLaptop: true,
        hijo: pantallaPrincipalGravity(
          barraOrdenes: barraOrdenes(
            rol: rol,
            onNavegar: (ruta) => context.go(ruta),
            dispositivo: TipoDispositivo.laptop,
          ),
        ),
      ),
      TipoDispositivo.tablet when rol == Rol.casa || modoCasa =>
        const PantallaModoCasa(),
      _ => MarcoPantalla(
        titulo: 'Hoy',
        cuerpo: _ConAccesosVistaPapa(rol: rol, hijo: pantallaHoyTelefono()),
      ),
    };
  }
}

/// D24: solo el dueño ve la tarjeta de solicitudes de vista (autoriza,
/// rechaza o cancela). El acceso del familiar vive en "Más" y, en la laptop
/// (que no tiene "Más"), en una franja al pie de GRAVITY.
class _ConAccesosVistaPapa extends StatelessWidget {
  const _ConAccesosVistaPapa({
    required this.rol,
    required this.hijo,
    this.enLaptop = false,
  });

  final Rol rol;
  final Widget hijo;
  final bool enLaptop;

  @override
  Widget build(BuildContext context) {
    if (rol == Rol.dueno) {
      return Column(
        children: [
          const TarjetaVistaPapaDueno(),
          Expanded(child: hijo),
          if (enLaptop) const Material(child: AccesosInstruccionesCuidados()),
        ],
      );
    }
    if (rol == Rol.coadministrador && enLaptop) {
      return Column(
        children: [
          Expanded(child: hijo),
          const Material(child: AccesosInstruccionesCuidados()),
        ],
      );
    }
    if (rol == Rol.familiar && enLaptop) {
      return Column(
        children: [
          Expanded(child: hijo),
          const Material(child: AccesoPedirVistaPapa()),
        ],
      );
    }
    return hijo;
  }
}

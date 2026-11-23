/// Protege la pantalla de **molestias** (E9, spec 9 y CA-G-36): `FLAG_SECURE`,
/// modo privado y equipos que no las admiten.
///
/// - **`FLAG_SECURE`** (sin capturas ni vista previa en «recientes») mientras la
///   pantalla está a la vista, con el mismo mecanismo de Finanzas y de lo
///   reservado ([PantallaSegura]).
/// - **Modo privado** (laptop y todos): oculta el contenido.
/// - **Equipos que no las admiten** (la tablet pública de la casa y la laptop):
///   **no muestra ni guarda nada**; dice «Las molestias están solo en tu
///   teléfono; aquí no se tienen en cuenta». Ni siquiera construye la pantalla
///   real.
///
/// Es solo el envoltorio: la pantalla la hace G5.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diseno/gimnasio/textos_gimnasio.dart';
import '../../diseno/proveedores.dart' show modoPrivadoProvider;
import '../../nucleo/gimnasio/molestias_locales.dart';
import '../avisos/con_avisos.dart' show tipoEquipoAvisosProvider;
import '../pantalla_segura.dart';

/// Texto del modo privado sobre las molestias.
const textoMolestiasOcultas = 'Contenido oculto por el modo privado.';

class ProtegerMolestias extends ConsumerWidget {
  const ProtegerMolestias({super.key, required this.child});

  /// La pantalla de molestias. Solo se construye donde se admiten.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admite = equipoAdmiteMolestias(ref.watch(tipoEquipoAvisosProvider));
    if (!admite) {
      return const _Aviso(
        clave: 'molestias-otro-equipo',
        texto: TextosGimnasio.molestiaOtroEquipo,
        icono: Icons.phone_android_outlined,
      );
    }
    final privado = ref.watch(modoPrivadoProvider);
    return PantallaSegura(
      activa: true,
      child: privado
          ? const _Aviso(
              clave: 'molestias-privado',
              texto: textoMolestiasOcultas,
              icono: Icons.lock_outline,
            )
          : child,
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.clave, required this.texto, required this.icono});

  final String clave;
  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Center(
    key: ValueKey(clave),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono),
          const SizedBox(width: 8),
          Flexible(child: Text(texto)),
        ],
      ),
    ),
  );
}

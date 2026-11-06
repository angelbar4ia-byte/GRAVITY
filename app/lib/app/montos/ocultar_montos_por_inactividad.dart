/// Oculta los montos solos tras unos minutos sin tocar la pantalla ni el
/// teclado (2 por omisión; editable en Ajustes › Privacidad). Cuenta los
/// toques de toda la app, también los de hojas y diálogos, y al volver de
/// segundo plano compara con el último toque ([DetectorInactividad]).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diseno/proveedores.dart' show montosVisiblesProvider;
import '../../nucleo/seguridad/montos.dart';
import '../tablet/detector_inactividad.dart';

class OcultarMontosPorInactividad extends ConsumerWidget {
  const OcultarMontosPorInactividad({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibles = ref.watch(montosVisiblesProvider);
    final tras = ref.watch(
      controladorMontosProvider.select((e) => e.ocultarTras),
    );
    return DetectorInactividad(
      // Solo mientras los montos están a la vista.
      activo: visibles,
      tiempo: tras,
      alVencer: () => ref.read(montosVisiblesProvider.notifier).fijar(false),
      reloj: () => ref.read(relojMontosProvider)(),
      child: child,
    );
  }
}

/// Reloj con el que se compara al volver de segundo plano (pruebas).
final relojMontosProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

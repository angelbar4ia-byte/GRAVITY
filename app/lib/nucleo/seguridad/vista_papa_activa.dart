/// Vista temporal de Finanzas de Papá para el familiar (D24, Fase 4).
///
/// Mientras la vista esté autorizada y vigente, la ventana queda protegida
/// contra capturas con el mismo mecanismo de `pantalla_segura.dart`
/// (Android: FLAG_SECURE; Windows: el protector existente). Al cerrarse, se
/// libera. Finanzas enciende el proveedor al abrir la vista y lo apaga al
/// vencer o cancelarse; [GuardiaDePantallaSegura] lo respeta en todo el
/// cascarón, y [VistaPapaSegura] sirve para envolver la pantalla.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/pantalla_segura.dart' show PantallaSegura;

/// `true` mientras la vista temporal de Papá está vigente.
final vistaPapaActivaProvider = NotifierProvider<VistaPapaActiva, bool>(
  VistaPapaActiva.new,
);

class VistaPapaActiva extends Notifier<bool> {
  @override
  bool build() => false;

  /// La vista quedó autorizada y vigente.
  void abrir() => state = true;

  /// Venció, el dueño la canceló o el familiar salió.
  void cerrar() => state = false;
}

/// Envuelve la pantalla de la vista: protegida mientras el proveedor esté
/// activo y el widget en el árbol.
class VistaPapaSegura extends ConsumerWidget {
  const VistaPapaSegura({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      PantallaSegura(activa: ref.watch(vistaPapaActivaProvider), child: child);
}

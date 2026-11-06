/// Aplica la personalidad de un módulo o submódulo a todo lo que tenga debajo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/contratos/roles.dart';
import 'personalidad_modulo.dart';
import 'proveedores.dart';
import 'tema.dart';

/// Envuelve las pantallas de un módulo con su personalidad (capa 3).
///
/// ```dart
/// TemaModulo(modulo: Modulo.finanzas, child: PantallaSemana())
/// TemaModulo(modulo: Modulo.habitos, submodulo: Submodulo.bici, child: ...)
/// ```
class TemaModulo extends ConsumerWidget {
  const TemaModulo({
    super.key,
    required this.modulo,
    this.submodulo,
    required this.child,
  });

  final Modulo modulo;
  final Submodulo? submodulo;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = submodulo;
    assert(
      sub == null || sub.modulo == modulo,
      'El submódulo no es de $modulo',
    );
    final personalidad = sub != null
        ? ref.watch(personalidadSubmoduloProvider(sub))
        : ref.watch(personalidadProvider(modulo));
    final tema = temaPara(
      estilo: ref.watch(estiloProvider),
      brillo: brilloGlobal(context, ref),
      personalidad: personalidad,
      densidadBase: ref.watch(densidadBaseProvider),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return Theme(data: tema, child: child);
    }
    return AnimatedTheme(
      data: tema,
      duration: duracionCambioTema,
      child: child,
    );
  }
}

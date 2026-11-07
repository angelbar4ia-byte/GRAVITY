import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../esmerilado.dart';
import '../valores_diseno.dart';

/// La superficie de una tarjeta o panel: lo que cambia entre estilos.
///
/// - **Estilos normales:** un `Material` con el color del panel y su borde.
/// - **Glass en laptop y tablet:** vidrio esmerilado (`BackdropFilter`) con el
///   color translúcido del panel; máximo 3 capas a la vez
///   ([GestorEsmerilado]) y apagado automático si la app va lenta.
/// - **Glass en el teléfono** (o sin capas libres, o apagado): la versión
///   translúcida **sólida**, el color opaco del panel. Nada se difumina.
///
/// Un panel esmerilado **no** deja ver lo que hay detrás de otras capas de la
/// interfaz como si fuera transparente para contenido oculto: lo oculto se
/// sustituye por otro texto, nunca por un desenfoque (convención 8).
class SuperficiePanel extends StatefulWidget {
  const SuperficiePanel({
    super.key,
    required this.radio,
    required this.child,
    this.gestor,
  });

  final BorderRadius radio;
  final Widget child;

  /// Gestor de esmerilado; por omisión el de la app. Las pruebas pasan el suyo.
  final GestorEsmerilado? gestor;

  @override
  State<SuperficiePanel> createState() => _SuperficiePanelState();
}

class _SuperficiePanelState extends State<SuperficiePanel> {
  GestorEsmerilado get _gestor => widget.gestor ?? GestorEsmerilado.instancia;

  @override
  void dispose() {
    _gestor.liberar(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final forma = RoundedRectangleBorder(
      borderRadius: widget.radio,
      side: BorderSide(color: v.borde, width: v.grosorBorde),
    );
    final vidrio = v.esmerilado > 0 && v.panelTranslucido != null;
    if (!vidrio) {
      _gestor.liberar(this);
      return Material(
        color: v.panel,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: widget.child,
      );
    }
    _gestor.iniciarMonitor();
    return ListenableBuilder(
      listenable: _gestor,
      builder: (context, _) {
        if (!_gestor.solicitar(this)) {
          // Sin capa libre o apagado: translúcido sólido, sin esmerilar.
          return Material(
            color: v.panel,
            shape: forma,
            clipBehavior: Clip.antiAlias,
            child: widget.child,
          );
        }
        return ClipRRect(
          borderRadius: widget.radio,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: v.esmerilado,
              sigmaY: v.esmerilado,
            ),
            child: Material(
              color: v.panelTranslucido,
              shape: forma,
              clipBehavior: Clip.antiAlias,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

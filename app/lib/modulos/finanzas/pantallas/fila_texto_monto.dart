/// Una línea «texto … monto» que no se desborda con letra grande: el texto
/// toma el espacio y se parte en dos líneas, y el monto se encoge en vez de
/// empujar al resto (mismo criterio que `FilaMovimiento`, I6 de la revisión
/// de la Fase 1).
library;

import 'package:flutter/material.dart';

class FilaTextoMonto extends StatelessWidget {
  const FilaTextoMonto({
    super.key,
    required this.texto,
    required this.monto,
    this.estilo,
  });

  final String texto;

  /// Normalmente un `Monto`, que respeta el modo privado.
  final Widget monto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          texto,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: estilo,
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerEnd,
          child: monto,
        ),
      ),
    ],
  );
}

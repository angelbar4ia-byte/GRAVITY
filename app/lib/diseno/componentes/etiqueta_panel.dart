import 'package:flutter/material.dart';

import '../valores_diseno.dart';

/// Etiqueta de panel en mayúsculas con letra de ancho fijo ("HOY · AGENDA").
class EtiquetaPanel extends StatelessWidget {
  const EtiquetaPanel(this.texto, {super.key, this.color, this.tamano = 12});

  final String texto;
  final Color? color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Text(
      texto.toUpperCase(),
      style: v.etiquetaPanel(tamano: tamano, color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

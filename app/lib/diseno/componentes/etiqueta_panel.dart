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
    final sticker = v.etiquetaSticker && v.decoracion;
    final etiqueta = Text(
      texto.toUpperCase(),
      style: v.etiquetaPanel(
        tamano: tamano,
        color: sticker ? v.sobreAcento : color,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (!sticker) return etiqueta;
    // Estilo Swagger: etiqueta tipo sticker, con el relleno del acento.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: v.acento,
        borderRadius: BorderRadius.circular(v.radioChico),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: v.espacio, vertical: 2),
        child: etiqueta,
      ),
    );
  }
}

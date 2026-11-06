import 'package:flutter/material.dart';

import '../valores_diseno.dart';

/// Nivel de una alerta (Fase 2, regla 32). El rojo es solo para las críticas.
enum NivelAlerta {
  critica('Crítica', Icons.notification_important_outlined),
  importante('Importante', Icons.warning_amber_rounded),
  informativa('Informativa', Icons.info_outline);

  const NivelAlerta(this.etiqueta, this.icono);

  /// Texto del nivel: nunca depende solo del color.
  final String etiqueta;

  /// Icono de línea con forma distinta por nivel.
  final IconData icono;

  Color color(ValoresDiseno v) => switch (this) {
    NivelAlerta.critica => v.peligro,
    NivelAlerta.importante => v.alerta,
    NivelAlerta.informativa => v.acento,
  };
}

/// Chip del nivel de una alerta: **icono y texto** ("⚠ Importante"), con el
/// borde y el icono del color del nivel y el texto en el color de lectura
/// (contraste de 4.5:1 garantizado).
class ChipNivelAlerta extends StatelessWidget {
  const ChipNivelAlerta({super.key, required this.nivel});

  final NivelAlerta nivel;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final color = nivel.color(v);
    return Semantics(
      label: 'Nivel: ${nivel.etiqueta}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.12), v.panel),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(v.radioGrande * 2),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: v.espacio * 1.25,
            vertical: v.espacio * 0.5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(nivel.icono, size: 14, color: color),
              SizedBox(width: v.espacio * 0.5),
              Flexible(
                child: Text(
                  nivel.etiqueta,
                  style: v.lectura(
                    tamano: 12,
                    peso: FontWeight.w600,
                    color: v.textoFuerte,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

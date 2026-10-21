import 'package:flutter/material.dart';

import '../valores_diseno.dart';

/// Estados del semáforo de dinero y medicamentos (sección 18). El rojo es solo
/// para alertas reales.
enum EstadoSemaforo {
  verde('En verde'),
  ambar('En ámbar'),
  rojo('En rojo');

  const EstadoSemaforo(this.etiqueta);

  /// Texto por defecto: el estado nunca depende solo del color.
  final String etiqueta;

  /// Color del estado según los valores de diseño.
  Color color(ValoresDiseno v) => switch (this) {
    EstadoSemaforo.verde => v.exito,
    EstadoSemaforo.ambar => v.alerta,
    EstadoSemaforo.rojo => v.peligro,
  };

  /// Icono de línea con forma distinta por estado (palomita, triángulo,
  /// círculo con signo): se distingue aunque no se vean los colores.
  IconData get icono => switch (this) {
    EstadoSemaforo.verde => Icons.check_circle_outline,
    EstadoSemaforo.ambar => Icons.warning_amber_rounded,
    EstadoSemaforo.rojo => Icons.error_outline,
  };
}

/// Semáforo con su texto ("● En verde"). Nunca depende solo del color:
///
/// - Por defecto, punto de color y texto.
/// - Con [conIcono], el punto se cambia por el icono del estado.
/// - Con [soloIcono], solo el icono (celdas estrechas, teléfono); el texto
///   queda para el lector de pantalla y como texto emergente.
class Semaforo extends StatelessWidget {
  const Semaforo({
    super.key,
    required this.estado,
    this.etiqueta,
    this.tamanoTexto = 14,
    this.conIcono = false,
    this.soloIcono = false,
  });

  final EstadoSemaforo estado;

  /// Texto propio; por defecto, el del estado.
  final String? etiqueta;
  final double tamanoTexto;

  /// Icono del estado en lugar del punto.
  final bool conIcono;

  /// Solo el icono, sin texto visible.
  final bool soloIcono;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final color = estado.color(v);
    final texto = etiqueta ?? estado.etiqueta;

    if (soloIcono) {
      return Semantics(
        label: 'Semáforo: $texto',
        excludeSemantics: true,
        child: Tooltip(
          message: texto,
          child: Icon(estado.icono, size: tamanoTexto * 1.3, color: color),
        ),
      );
    }

    return Semantics(
      label: 'Semáforo: $texto',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (conIcono)
            Icon(estado.icono, size: tamanoTexto * 1.15, color: color)
          else
            Container(
              width: tamanoTexto * 0.7,
              height: tamanoTexto * 0.7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          SizedBox(width: v.espacio),
          Flexible(
            child: Text(
              texto,
              style: v.lectura(
                tamano: tamanoTexto,
                peso: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

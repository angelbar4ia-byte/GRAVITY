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
}

/// Punto de color con su texto ("● En verde").
class Semaforo extends StatelessWidget {
  const Semaforo({
    super.key,
    required this.estado,
    this.etiqueta,
    this.tamanoTexto = 14,
  });

  final EstadoSemaforo estado;

  /// Texto propio; por defecto, el del estado.
  final String? etiqueta;
  final double tamanoTexto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final color = estado.color(v);
    final texto = etiqueta ?? estado.etiqueta;
    return Semantics(
      label: 'Semáforo: $texto',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

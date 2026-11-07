import 'package:flutter/material.dart';

import '../superficies.dart';
import '../valores_diseno.dart';

/// Fondo de la pantalla según el estilo: liso, o (estilos de vidrio) un
/// degradado del color del fondo a su segundo color con dos manchas de color
/// difuminadas, que es lo que el vidrio esmerila.
///
/// Las manchas nunca pasan del color [SuperficiesDiseno.manchaFondo], el más
/// extremo del fondo: las pruebas de contraste lo toman como el peor caso.
class FondoEstilo extends StatelessWidget {
  const FondoEstilo({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final fin = v.fondoFin;
    if (fin == null) return ColoredBox(color: v.fondo, child: child);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [v.fondo, fin],
            ),
          ),
        ),
        ExcludeSemantics(child: CustomPaint(painter: _Manchas(v.manchaFondo))),
        child,
      ],
    );
  }
}

class _Manchas extends CustomPainter {
  const _Manchas(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    void mancha(Offset centro, double radio) {
      canvas.drawCircle(
        centro,
        radio,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: centro, radius: radio)),
      );
    }

    final lado = size.shortestSide;
    mancha(Offset(size.width * 0.15, size.height * 0.2), lado * 0.7);
    mancha(Offset(size.width * 0.9, size.height * 0.85), lado * 0.8);
  }

  @override
  bool shouldRepaint(_Manchas old) => old.color != color;
}

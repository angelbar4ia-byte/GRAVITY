import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../valores_diseno.dart';

/// Estado de GRAVITY que muestra el núcleo (sección 7).
enum EstadoNucleo {
  enEspera('En espera', 1, 0.2),
  escuchando('Escuchando', 2, 0.35),
  pensando('Pensando', 3, 0.2),
  hablando('Hablando', 2, 0.4);

  const EstadoNucleo(this.etiqueta, this.velocidad, this.pulso);

  /// Texto visible y para el lector de pantalla.
  final String etiqueta;

  /// Multiplicador del giro de los anillos.
  final int velocidad;

  /// Amplitud del pulso del círculo interior (0 a 1).
  final double pulso;
}

/// Núcleo de GRAVITY: anillos que giran (estilo Futurista).
///
/// La animación se detiene si el sistema pide reducir movimiento
/// (`MediaQuery.disableAnimations`) o si la personalidad va sin animación.
class NucleoGravity extends StatefulWidget {
  const NucleoGravity({
    super.key,
    this.tamano = 300,
    this.estado = EstadoNucleo.enEspera,
  });

  final double tamano;
  final EstadoNucleo estado;

  /// Un ciclo completo: el anillo exterior da 7 vueltas (40 s cada una), el
  /// interior 4 en sentido contrario (70 s) y el pulso 80 latidos (3.5 s), así
  /// el ciclo se repite sin saltos.
  static const Duration ciclo = Duration(seconds: 280);

  @override
  State<NucleoGravity> createState() => _NucleoGravityState();
}

class _NucleoGravityState extends State<NucleoGravity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: NucleoGravity.ciclo,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizar();
  }

  @override
  void didUpdateWidget(NucleoGravity oldWidget) {
    super.didUpdateWidget(oldWidget);
    _actualizar();
  }

  void _actualizar() {
    final v = ValoresDiseno.de(context);
    final detener = MediaQuery.disableAnimationsOf(context) || !v.animado;
    if (detener) {
      _control.stop();
      return;
    }
    final duracion = NucleoGravity.ciclo ~/ widget.estado.velocidad;
    if (_control.duration != duracion || !_control.isAnimating) {
      _control
        ..duration = duracion
        ..repeat();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Semantics(
      label: 'Núcleo de GRAVITY: ${widget.estado.etiqueta.toLowerCase()}',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.tamano),
          painter: PintorNucleo(
            animacion: _control,
            acento: v.acento,
            borde: v.borde,
            panel: v.panel,
            pulso: widget.estado.pulso,
            variante: v.nucleo,
          ),
        ),
      ),
    );
  }
}

/// Dibuja los anillos del núcleo. Se repinta con la animación sin reconstruir
/// el árbol de widgets.
class PintorNucleo extends CustomPainter {
  PintorNucleo({
    required this.animacion,
    required this.acento,
    required this.borde,
    required this.panel,
    required this.pulso,
    this.variante = VarianteNucleo.anillos,
  }) : super(repaint: animacion);

  final Animation<double> animacion;
  final Color acento;
  final Color borde;
  final Color panel;
  final double pulso;

  /// Cada estilo trae su variante del núcleo (P14).
  final VarianteNucleo variante;

  @override
  void paint(Canvas canvas, Size size) {
    switch (variante) {
      case VarianteNucleo.pulso:
        _pintarPulso(canvas, size);
      case VarianteNucleo.orbe:
        _pintarOrbe(canvas, size);
      case VarianteNucleo.anillos:
      case VarianteNucleo.cristal:
        _pintarAnillos(canvas, size);
    }
  }

  /// Swagger: tres ondas gruesas que se abren desde el centro, como un sonar,
  /// sobre un disco central que late.
  void _pintarPulso(Canvas canvas, Size size) {
    final t = animacion.value;
    final c = size.center(Offset.zero);
    final s = size.shortestSide / 320;
    final latido = (1 + math.sin(2 * math.pi * 80 * t)) / 2;
    final opacidadPulso = 1 - pulso + pulso * latido;

    canvas.drawCircle(
      c,
      152 * s,
      Paint()
        ..color = borde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s.clamp(0.6, 2.0),
    );
    // Cada onda hace 14 ciclos por vuelta del reloj del núcleo.
    for (var i = 0; i < 3; i++) {
      final fase = (t * 14 + i / 3) % 1.0;
      final radio = (40 + 100 * fase) * s;
      canvas.drawCircle(
        c,
        radio,
        Paint()
          ..color = acento.withValues(alpha: (1 - fase) * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * s.clamp(0.6, 2.0),
      );
    }
    canvas.drawCircle(
      c,
      (34 + 6 * latido * pulso) * s,
      Paint()..color = acento.withValues(alpha: 0.6 + 0.4 * opacidadPulso),
    );
    canvas.drawCircle(
      c,
      34 * s,
      Paint()
        ..color = panel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s.clamp(0.6, 2.0),
    );
  }

  /// Bento: tres círculos rellenos y suaves que respiran, uno dentro de otro.
  void _pintarOrbe(Canvas canvas, Size size) {
    final t = animacion.value;
    final c = size.center(Offset.zero);
    final s = size.shortestSide / 320;
    final respiro = (1 + math.sin(2 * math.pi * 80 * t)) / 2;
    final amplitud = 0.04 + 0.06 * pulso;
    for (var i = 0; i < 3; i++) {
      final base = (140 - 44 * i) * s;
      final radio = base * (1 + amplitud * respiro * (1 - i * 0.3));
      canvas.drawCircle(
        c,
        radio,
        Paint()
          ..color = Color.lerp(
            panel,
            acento,
            0.10 + 0.14 * i,
          )!.withValues(alpha: 0.9),
      );
    }
    canvas.drawCircle(
      c,
      150 * s,
      Paint()
        ..color = borde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s.clamp(0.6, 2.0),
    );
    canvas.drawCircle(c, 22 * s, Paint()..color = acento);
  }

  void _pintarAnillos(Canvas canvas, Size size) {
    final t = animacion.value;
    final c = size.center(Offset.zero);
    // Las medidas siguen al boceto (lienzo de 320).
    final s = size.shortestSide / 320;
    final giroExterior = 2 * math.pi * 7 * t;
    final giroInterior = -2 * math.pi * 4 * t;
    final latido = (1 + math.sin(2 * math.pi * 80 * t)) / 2;
    final opacidadPulso = 1 - pulso + pulso * latido;

    Paint trazo(Color color, double ancho) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ancho * s.clamp(0.6, 2.0);

    canvas.drawCircle(c, 152 * s, trazo(borde, 1));
    _anilloPunteado(
      canvas,
      c,
      134 * s,
      [3 * s, 9 * s],
      giroExterior,
      trazo(acento.withValues(alpha: 0.7), 2),
    );
    _anilloPunteado(
      canvas,
      c,
      114 * s,
      [120 * s, 40 * s, 30 * s, 40 * s],
      giroInterior,
      trazo(acento.withValues(alpha: 0.9), 1.5),
    );
    canvas.drawCircle(c, 88 * s, trazo(Color.lerp(borde, acento, 0.3)!, 1));
    canvas.drawCircle(
      c,
      56 * s,
      Paint()
        ..color = Color.lerp(
          panel,
          acento,
          0.14,
        )!.withValues(alpha: opacidadPulso),
    );
    canvas.drawCircle(
      c,
      56 * s,
      trazo(acento.withValues(alpha: opacidadPulso), 2),
    );
    canvas.drawCircle(
      c,
      20 * s,
      Paint()..color = acento.withValues(alpha: 0.85),
    );
  }

  /// Dibuja un anillo con un patrón de trazo y espacio que gira [giro] radianes.
  void _anilloPunteado(
    Canvas canvas,
    Offset centro,
    double radio,
    List<double> patron,
    double giro,
    Paint paint,
  ) {
    if (radio <= 0) return;
    final rect = Rect.fromCircle(center: centro, radius: radio);
    final circunferencia = 2 * math.pi * radio;
    var recorrido = 0.0;
    var i = 0;
    while (recorrido < circunferencia) {
      final largo = math.min(
        patron[i % patron.length],
        circunferencia - recorrido,
      );
      if (i.isEven) {
        canvas.drawArc(
          rect,
          giro + recorrido / radio,
          largo / radio,
          false,
          paint,
        );
      }
      recorrido += largo;
      i++;
    }
  }

  @override
  bool shouldRepaint(PintorNucleo oldDelegate) =>
      oldDelegate.acento != acento ||
      oldDelegate.borde != borde ||
      oldDelegate.panel != panel ||
      oldDelegate.pulso != pulso ||
      oldDelegate.variante != variante ||
      oldDelegate.animacion != animacion;
}

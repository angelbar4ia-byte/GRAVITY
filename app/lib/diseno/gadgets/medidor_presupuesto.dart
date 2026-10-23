import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../componentes/monto_ocultable.dart';
import '../proveedores.dart';
import '../componentes/semaforo.dart';
import '../superficies.dart';
import '../valores_diseno.dart';
import 'uso_presupuesto.dart';

/// Gadget **Medidor de presupuesto** (DISENO_UX_UI, sección 6): "¿Cuánto llevo
/// gastado y cuánto me queda?".
///
/// Semicírculo con el porcentaje usado, cuánto queda (o por cuánto se excedió)
/// y el semáforo **con texto** ("Bien", "Cerca del límite", "Excedido"): el
/// estado nunca depende solo del color. Con [montosOcultos] **o** con los montos
/// ocultos de la app ([montosOcultosProvider]), el porcentaje se sigue viendo y
/// los pesos no.
///
/// Los umbrales por defecto son los de la partida en `finanzas_dominio`
/// (`Umbrales.partidaAmbarDesde` y `partidaRojoArribaDe`); pásalos si el dueño
/// los editó.
class MedidorPresupuesto extends ConsumerWidget {
  const MedidorPresupuesto({
    super.key,
    required this.asignadoCentavos,
    required this.gastadoCentavos,
    this.etiqueta,
    this.montosOcultos = false,
    this.ambarDesdePuntosBase = 8000,
    this.rojoArribaDePuntosBase = 10000,
  });

  /// Lo asignado a la partida (con su arrastre), en centavos.
  final int asignadoCentavos;

  /// Lo gastado en el periodo, en centavos.
  final int gastadoCentavos;

  /// Nombre de la partida ("Alimentación"); `null` no dibuja título.
  final String? etiqueta;

  /// Modo privado: oculta los pesos.
  final bool montosOcultos;

  final int ambarDesdePuntosBase;
  final int rojoArribaDePuntosBase;

  /// El cálculo que dibuja el medidor.
  UsoPresupuesto get uso => UsoPresupuesto(
    asignadoCentavos: asignadoCentavos,
    gastadoCentavos: gastadoCentavos,
    ambarDesdePuntosBase: ambarDesdePuntosBase,
    rojoArribaDePuntosBase: rojoArribaDePuntosBase,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final montosOcultos =
        this.montosOcultos || ref.watch(montosOcultosProvider);
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final uso = this.uso;
    final colorEstado = uso.estado.color(v);
    final animar = v.animado && !MediaQuery.disableAnimationsOf(context);
    final restante = uso.restanteCentavos;
    final textoRestante = uso.excedido ? 'Excedido por' : 'Quedan';
    final montoLeido = montosOcultos
        ? 'monto oculto'
        : formatearCentavos(restante.abs());
    final sinPresupuesto = !uso.conPresupuesto;

    final valorSemantico = [
      sinPresupuesto ? 'Sin presupuesto asignado' : '${uso.porcentaje} % usado',
      '$textoRestante $montoLeido',
      uso.textoEstado,
    ].join('. ');

    return Semantics(
      container: true,
      label: etiqueta == null
          ? 'Medidor de presupuesto'
          : 'Medidor de presupuesto: $etiqueta',
      value: valorSemantico,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, limites) {
          final ancho = limites.maxWidth.isFinite ? limites.maxWidth : 240.0;
          final diametro = math.max(96.0, math.min(ancho, 240.0));
          final grosor = (diametro * 0.075).clamp(8.0, 18.0);
          final altoArco = diametro / 2 + grosor / 2;
          final interior = diametro - grosor * 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (etiqueta != null) ...[
                Text(
                  etiqueta!,
                  style: v.lectura(
                    tamano: 14,
                    peso: FontWeight.w600,
                    color: v.textoFuerte,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: e),
              ],
              Center(
                child: SizedBox(
                  width: diametro,
                  height: altoArco,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: uso.fraccion),
                          duration: animar
                              ? v.duracionAnimacion * 2
                              : Duration.zero,
                          curve: Curves.easeOutCubic,
                          builder: (context, t, _) => CustomPaint(
                            painter: PintorArcoMedidor(
                              fraccion: t,
                              pista: v.pista,
                              color: colorEstado,
                              grosor: grosor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: interior * 0.8,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            sinPresupuesto ? '—' : '${uso.porcentaje} %',
                            style: v.numero(
                              tamano: (diametro * 0.15).clamp(20.0, 34.0),
                              peso: FontWeight.w600,
                              color: v.textoFuerte,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: e * 0.5),
              Text(
                sinPresupuesto
                    ? 'Sin presupuesto asignado'
                    : 'del presupuesto usado',
                textAlign: TextAlign.center,
                style: v.lectura(tamano: 13, color: v.textoTenue),
              ),
              SizedBox(height: e),
              Center(
                child: Semaforo(
                  estado: uso.estado,
                  etiqueta: uso.textoEstado,
                  tamanoTexto: 14,
                ),
              ),
              SizedBox(height: e * 1.5),
              // "Quedan … $680.00" en una línea si cabe; si no, el monto baja.
              // Un monto nunca se corta: si no cabe ni solo, se reduce.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: e,
                runSpacing: e * 0.5,
                children: [
                  Text(
                    textoRestante,
                    style: v.lectura(tamano: 14, color: v.textoTenue),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ancho),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: MontoOcultable(
                        centavos: restante.abs(),
                        oculto: montosOcultos,
                        estilo: v.numero(
                          tamano: 15,
                          peso: FontWeight.w600,
                          // En modo privado el color no delata el exceso.
                          color: uso.excedido && !montosOcultos
                              ? v.peligro
                              : v.textoFuerte,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dibuja el semicírculo del medidor: la pista completa y, encima, la parte
/// usada en el color del semáforo. Público para que las pruebas revisen que
/// toma sus colores de los valores de diseño.
class PintorArcoMedidor extends CustomPainter {
  const PintorArcoMedidor({
    required this.fraccion,
    required this.pista,
    required this.color,
    required this.grosor,
  });

  /// Parte usada, de 0 a 1.
  final double fraccion;
  final Color pista;
  final Color color;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final radio = math.max(0.0, (size.width - grosor) / 2);
    final centro = Offset(size.width / 2, radio + grosor / 2);
    final rect = Rect.fromCircle(center: centro, radius: radio);
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, trazo..color = pista);
    final f = fraccion.clamp(0.0, 1.0);
    if (f > 0) {
      canvas.drawArc(rect, math.pi, math.pi * f, false, trazo..color = color);
    }
  }

  @override
  bool shouldRepaint(PintorArcoMedidor anterior) =>
      anterior.fraccion != fraccion ||
      anterior.pista != pista ||
      anterior.color != color ||
      anterior.grosor != grosor;
}

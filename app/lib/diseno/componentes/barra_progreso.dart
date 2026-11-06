import 'package:flutter/material.dart';

import '../superficies.dart';
import '../valores_diseno.dart';

/// Barra de avance fina (sección 19). [valor] va de 0 a 1.
class BarraProgreso extends StatelessWidget {
  const BarraProgreso({
    super.key,
    required this.valor,
    this.etiqueta,
    this.textoValor,
    this.color,
    this.alto = 6,
  });

  final double valor;

  /// Texto a la izquierda, arriba de la barra ("Presupuesto usado").
  final String? etiqueta;

  /// Texto a la derecha; por defecto el porcentaje ("62 %").
  final String? textoValor;

  /// Color del avance; por defecto, el acento.
  final Color? color;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final avance = valor.isNaN ? 0.0 : valor.clamp(0.0, 1.0);
    final porcentaje = '${(avance * 100).round()} %';
    final pista = v.pista;
    final relleno = color ?? v.acento;
    final animar = v.animado && !MediaQuery.disableAnimationsOf(context);

    final barra = ClipRRect(
      borderRadius: BorderRadius.circular(alto / 2),
      child: SizedBox(
        height: alto,
        child: ColoredBox(
          color: pista,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: avance),
            duration: animar ? v.duracionAnimacion * 2 : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: t,
              heightFactor: 1,
              child: ColoredBox(color: relleno),
            ),
          ),
        ),
      ),
    );

    final conTextos = etiqueta == null && textoValor == null
        ? barra
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (etiqueta != null)
                    Expanded(
                      child: Text(
                        etiqueta!,
                        style: v.lectura(tamano: 13, color: v.textoTenue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  Flexible(
                    child: Text(
                      textoValor ?? porcentaje,
                      textAlign: TextAlign.end,
                      style: v.numero(tamano: 13, color: v.textoTenue),
                    ),
                  ),
                ],
              ),
              SizedBox(height: v.espacio * 0.75),
              barra,
            ],
          );

    return Semantics(
      label: etiqueta ?? 'Avance',
      value: textoValor ?? porcentaje,
      excludeSemantics: true,
      child: conTextos,
    );
  }
}

import 'package:flutter/material.dart';

import '../valores_diseno.dart';

/// Una tesela de la cuadrícula bento: ocupa [columnas] columnas de la
/// cuadrícula y, como mínimo, [filas] filas de alto.
///
/// En la cuadrícula de 2 columnas (teléfono), una tesela de 2 o más columnas
/// ocupa todo el ancho; en la de 4 (tablet y laptop), 2 columnas son la mitad.
class TeselaBento extends StatelessWidget {
  const TeselaBento({
    super.key,
    required this.child,
    this.columnas = 2,
    this.filas = 1,
  });

  final Widget child;
  final int columnas;
  final int filas;

  @override
  Widget build(BuildContext context) => child;
}

/// La altura mínima que la cuadrícula pide a la tarjeta de una tesela
/// (`TarjetaModulo` la lee para llenar su tesela).
class AlturaTesela extends InheritedWidget {
  const AlturaTesela({super.key, required this.alto, required super.child});

  final double alto;

  /// Altura mínima de la tesela donde está [context], o cero fuera de una.
  static double de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AlturaTesela>()?.alto ?? 0;

  @override
  bool updateShouldNotify(AlturaTesela old) => old.alto != alto;
}

/// Cuadrícula tipo bento: tarjetas de distintos tamaños acomodadas en 2
/// columnas en el teléfono y en 4 desde 600 dp de ancho. Con letra grande en
/// una pantalla angosta pasa a una sola columna para que nada se corte.
class CuadriculaBento extends StatelessWidget {
  const CuadriculaBento({super.key, required this.teselas, this.alturaFila});

  final List<TeselaBento> teselas;

  /// Alto de una fila de la cuadrícula; por omisión, 120 dp que crecen con la
  /// letra del sistema.
  final double? alturaFila;

  static int columnasPara(double ancho, double escalaLetra) {
    if (ancho >= 600) return 4;
    return escalaLetra > 1.3 ? 1 : 2;
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final hueco = v.espacio * 1.5;
    final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = columnasPara(c.maxWidth, escala);
        final unidad = (c.maxWidth - hueco * (columnas - 1)) / columnas;
        final altoFila = (alturaFila ?? 120) * (escala > 1 ? escala : 1);
        // Se acomodan por filas; las teselas de una misma fila se estiran al
        // alto de la más alta, como en un bento.
        final filas = <List<(TeselaBento, int)>>[];
        var fila = <(TeselaBento, int)>[];
        var usadas = 0;
        for (final t in teselas) {
          // En 4 columnas, 2 son la mitad; en 2 o 1, 2 o más son todo el ancho.
          final ancho = columnas == 4
              ? t.columnas.clamp(1, 4)
              : (t.columnas >= 2 ? columnas : 1);
          if (usadas + ancho > columnas && fila.isNotEmpty) {
            filas.add(fila);
            fila = [];
            usadas = 0;
          }
          fila.add((t, ancho));
          usadas += ancho;
        }
        if (fila.isNotEmpty) filas.add(fila);

        Widget tesela((TeselaBento, int) par) {
          final (t, ancho) = par;
          return SizedBox(
            width: ancho * unidad + (ancho - 1) * hueco,
            child: AlturaTesela(
              alto: t.filas * altoFila + (t.filas - 1) * hueco,
              child: t,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0) SizedBox(height: hueco),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < filas[i].length; j++) ...[
                      if (j > 0) SizedBox(width: hueco),
                      tesela(filas[i][j]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

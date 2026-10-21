import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../componentes/monto_ocultable.dart';
import '../superficies.dart';
import '../valores_diseno.dart';

/// Tono de un escalón de la cascada. Lo decide Finanzas (p. ej. el remanente
/// en verde o un presupuesto excedido en rojo). Los tonos que no son neutros
/// llevan icono y lo dicen al lector de pantalla: nunca dependen solo del color.
enum TonoEscalon {
  neutro,
  exito,
  alerta,
  peligro;

  /// Color del tono según los valores de diseño (neutro = acento del módulo).
  Color color(ValoresDiseno v) => switch (this) {
    TonoEscalon.neutro => v.acento,
    TonoEscalon.exito => v.exito,
    TonoEscalon.alerta => v.alerta,
    TonoEscalon.peligro => v.peligro,
  };

  /// Icono de línea que acompaña al color; `null` en el neutro.
  IconData? get icono => switch (this) {
    TonoEscalon.neutro => null,
    TonoEscalon.exito => Icons.check_circle_outline,
    TonoEscalon.alerta => Icons.warning_amber_rounded,
    TonoEscalon.peligro => Icons.error_outline,
  };

  /// Lo que dice el lector de pantalla; `null` en el neutro.
  String? get texto => switch (this) {
    TonoEscalon.neutro => null,
    TonoEscalon.exito => 'en verde',
    TonoEscalon.alerta => 'en ámbar',
    TonoEscalon.peligro => 'en rojo',
  };
}

/// Un escalón de la cascada: ingreso, presupuesto, deuda o remanente.
@immutable
class EscalonCascada {
  const EscalonCascada({
    required this.etiqueta,
    required this.planeadoCentavos,
    this.realCentavos,
    this.tono = TonoEscalon.neutro,
  });

  /// "Ingreso", "Presupuesto", "Deuda", "Remanente → abono extra".
  final String etiqueta;

  /// Lo planeado, en centavos.
  final int planeadoCentavos;

  /// Lo real, en centavos; `null` si todavía no hay (o no se compara).
  final int? realCentavos;

  final TonoEscalon tono;

  @override
  bool operator ==(Object other) =>
      other is EscalonCascada &&
      other.etiqueta == etiqueta &&
      other.planeadoCentavos == planeadoCentavos &&
      other.realCentavos == realCentavos &&
      other.tono == tono;

  @override
  int get hashCode =>
      Object.hash(etiqueta, planeadoCentavos, realCentavos, tono);
}

/// Gadget **Cascada** (DISENO_UX_UI, sección 6; FINANZAS 5.6 bis punto 4):
/// "¿A dónde va el ingreso de la semana?". Ingreso → presupuesto → deuda →
/// remanente, planeado contra real.
///
/// Cada escalón es una barra a la misma escala (la cifra mayor de la cascada).
/// Sin real, la barra es sólida y se ve el monto planeado. Con real, lo
/// planeado es el contorno y lo real la barra sólida, con el texto
/// "*real* de *planeado*" y una leyenda al pie. Los negativos (un déficit)
/// miden por su valor absoluto y el monto lleva su signo.
///
/// Con [montosOcultos] se ven las barras y no los pesos.
class GadgetCascada extends StatelessWidget {
  const GadgetCascada({
    super.key,
    required this.escalones,
    this.montosOcultos = false,
  });

  final List<EscalonCascada> escalones;
  final bool montosOcultos;

  /// Si algún escalón trae real: entonces todos se dibujan comparando.
  bool get comparaReal => escalones.any((e) => e.realCentavos != null);

  /// La cifra mayor (en valor absoluto): el 100 % de las barras.
  int get escala => escalones.fold(
    0,
    (mayor, e) => math.max(
      mayor,
      math.max(e.planeadoCentavos.abs(), (e.realCentavos ?? 0).abs()),
    ),
  );

  /// Ancho de los montos de un escalón, medido con el estilo más ancho.
  double _anchoMontos(
    BuildContext context,
    ValoresDiseno v,
    EscalonCascada escalon,
    bool comparar,
  ) {
    String monto(int centavos) =>
        montosOcultos ? montoOculto : formatearCentavos(centavos);
    final real = escalon.realCentavos;
    final texto = !comparar
        ? monto(escalon.planeadoCentavos)
        : real != null
        ? '${monto(real)} de ${monto(escalon.planeadoCentavos)}'
        : 'Plan ${monto(escalon.planeadoCentavos)}';
    final medida = TextPainter(
      text: TextSpan(
        text: texto,
        style: v.numero(tamano: 14, peso: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final ancho = medida.width;
    medida.dispose();
    return ancho;
  }

  @override
  Widget build(BuildContext context) {
    if (escalones.isEmpty) return const SizedBox.shrink();
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final comparar = comparaReal;
    final escala = this.escala;

    return Semantics(
      container: true,
      label: 'Cascada',
      child: LayoutBuilder(
        builder: (context, limites) {
          // Si la etiqueta (al menos 120 dp) y los montos no caben en una
          // línea, todas las filas se apilan: etiqueta arriba, montos abajo.
          final anchoMontos = escalones
              .map((escalon) => _anchoMontos(context, v, escalon, comparar))
              .reduce(math.max);
          final angosto = limites.maxWidth < 120 + e * 1.5 + anchoMontos;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < escalones.length; i++) ...[
                if (i > 0) SizedBox(height: e * 1.75),
                _FilaEscalon(
                  escalon: escalones[i],
                  escala: escala,
                  comparar: comparar,
                  oculto: montosOcultos,
                  angosto: angosto,
                ),
              ],
              if (comparar) ...[SizedBox(height: e * 2), const _Leyenda()],
            ],
          );
        },
      ),
    );
  }
}

class _FilaEscalon extends StatelessWidget {
  const _FilaEscalon({
    required this.escalon,
    required this.escala,
    required this.comparar,
    required this.oculto,
    required this.angosto,
  });

  final EscalonCascada escalon;
  final int escala;
  final bool comparar;
  final bool oculto;
  final bool angosto;

  String _leido(int centavos) =>
      oculto ? 'monto oculto' : formatearCentavos(centavos);

  String get _textoSemantico {
    final real = escalon.realCentavos;
    final partes = <String>[
      if (!comparar)
        _leido(escalon.planeadoCentavos)
      else if (real != null)
        'real ${_leido(real)} de ${_leido(escalon.planeadoCentavos)} planeado'
      else
        'planeado ${_leido(escalon.planeadoCentavos)}, sin real',
      ?escalon.tono.texto,
    ];
    return '${escalon.etiqueta}: ${partes.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final color = escalon.tono.color(v);
    final icono = escalon.tono.icono;

    final etiqueta = Row(
      children: [
        if (icono != null) ...[
          Icon(icono, size: 16, color: color),
          SizedBox(width: e * 0.75),
        ],
        Expanded(
          child: Text(
            escalon.etiqueta,
            style: v.lectura(tamano: 14),
            maxLines: angosto ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final montos = _Montos(
      escalon: escalon,
      comparar: comparar,
      oculto: oculto,
    );

    return Semantics(
      container: true,
      label: _textoSemantico,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (angosto) ...[
            etiqueta,
            SizedBox(height: e * 0.5),
            // Un monto nunca se corta: si no cabe ni solo, se reduce.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FittedBox(fit: BoxFit.scaleDown, child: montos),
            ),
          ] else
            Row(
              children: [
                Expanded(child: etiqueta),
                SizedBox(width: e * 1.5),
                montos,
              ],
            ),
          SizedBox(height: e * 0.75),
          _Barra(
            planeado: _fraccion(escalon.planeadoCentavos),
            real: escalon.realCentavos == null
                ? null
                : _fraccion(escalon.realCentavos!),
            comparar: comparar,
            color: color,
          ),
        ],
      ),
    );
  }

  double _fraccion(int centavos) =>
      escala == 0 ? 0 : (centavos.abs() / escala).clamp(0.0, 1.0);
}

/// "$6,500.00 de $7,384.62" (con real), "Plan $392.31" (comparando, sin real)
/// o solo el planeado.
class _Montos extends StatelessWidget {
  const _Montos({
    required this.escalon,
    required this.comparar,
    required this.oculto,
  });

  final EscalonCascada escalon;
  final bool comparar;
  final bool oculto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final fuerte = v.numero(
      tamano: 14,
      peso: FontWeight.w600,
      color: v.textoFuerte,
    );
    final tenue = v.numero(tamano: 13, color: v.textoTenue);
    final conector = v.lectura(tamano: 13, color: v.textoTenue);
    final real = escalon.realCentavos;

    if (!comparar) {
      return MontoOcultable(
        centavos: escalon.planeadoCentavos,
        oculto: oculto,
        estilo: fuerte,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (real != null) ...[
          MontoOcultable(centavos: real, oculto: oculto, estilo: fuerte),
          Text(' de ', style: conector),
        ] else
          Text('Plan ', style: conector),
        MontoOcultable(
          centavos: escalon.planeadoCentavos,
          oculto: oculto,
          estilo: tenue,
        ),
      ],
    );
  }
}

/// Barra del escalón. Sin comparar: sólida. Comparando: lo planeado es un
/// contorno con relleno suave y lo real una barra sólida más delgada; el
/// contorno se dibuja encima para que el fin de lo planeado siempre se vea.
class _Barra extends StatelessWidget {
  const _Barra({
    required this.planeado,
    required this.real,
    required this.comparar,
    required this.color,
  });

  final double planeado;
  final double? real;
  final bool comparar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final alto = switch (v.densidad) {
      Densidad.compacta => 10.0,
      Densidad.comoda => 12.0,
      Densidad.grande => 16.0,
    };
    final radio = BorderRadius.circular(math.min(v.radioChico, alto / 2));
    final animar = v.animado && !MediaQuery.disableAnimationsOf(context);
    final duracion = animar ? v.duracionAnimacion * 2 : Duration.zero;

    Widget segmento(double fraccion, Widget hijo) =>
        TweenAnimationBuilder<double>(
          tween: Tween(end: fraccion),
          duration: duracion,
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: t,
            heightFactor: 1,
            child: hijo,
          ),
        );

    final capas = <Widget>[
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(color: v.pista, borderRadius: radio),
        ),
      ),
    ];
    if (!comparar) {
      capas.add(
        Positioned.fill(
          child: segmento(
            planeado,
            DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: radio),
            ),
          ),
        ),
      );
    } else {
      capas
        ..add(
          Positioned.fill(
            child: segmento(
              planeado,
              DecoratedBox(
                decoration: BoxDecoration(
                  color: v.rellenoPlaneado(color),
                  borderRadius: radio,
                ),
              ),
            ),
          ),
        )
        ..add(
          Positioned.fill(
            top: alto * 0.2,
            bottom: alto * 0.2,
            child: segmento(
              real ?? 0,
              DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radio),
              ),
            ),
          ),
        )
        ..add(
          Positioned.fill(
            child: segmento(
              planeado,
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 1.5),
                  borderRadius: radio,
                ),
              ),
            ),
          ),
        );
    }
    return SizedBox(
      height: alto,
      child: Stack(children: capas),
    );
  }
}

/// "▮ Real   ▯ Plan".
class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final estilo = v.lectura(tamano: 12, color: v.textoTenue);
    final radio = BorderRadius.circular(v.radioChico / 2);
    Widget muestra(BoxDecoration d) =>
        SizedBox(width: 16, height: 10, child: DecoratedBox(decoration: d));
    return ExcludeSemantics(
      child: Wrap(
        spacing: e * 2,
        runSpacing: e,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              muestra(BoxDecoration(color: v.acento, borderRadius: radio)),
              SizedBox(width: e * 0.75),
              Text('Real', style: estilo),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              muestra(
                BoxDecoration(
                  color: v.rellenoPlaneado(v.acento),
                  border: Border.all(color: v.acento, width: 1.5),
                  borderRadius: radio,
                ),
              ),
              SizedBox(width: e * 0.75),
              Text('Planeado', style: estilo),
            ],
          ),
        ],
      ),
    );
  }
}

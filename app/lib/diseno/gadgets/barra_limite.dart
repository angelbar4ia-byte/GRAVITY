import 'package:flutter/material.dart';

import '../componentes/monto_ocultable.dart';
import '../componentes/semaforo.dart';
import '../superficies.dart';
import '../valores_diseno.dart';

/// Cuánto del límite de una tarjeta está usado y en qué semáforo (Fase 2,
/// regla 7): verde por debajo de 30 %, ámbar de 30 a 60 %, rojo arriba de 60 %.
///
/// Lógica de presentación pura. Compara la **fracción exacta** (convención 4
/// de la Fase 1), nunca el porcentaje redondeado. `usadoCentavos` es el saldo
/// de la tarjeta más el pendiente de sus MSI (lo calcula Finanzas).
@immutable
class UsoLimite {
  const UsoLimite({required this.usadoCentavos, required this.limiteCentavos});

  final int usadoCentavos;

  /// `null` o cero: la tarjeta no tiene límite capturado.
  final int? limiteCentavos;

  /// Marcas de la barra, en porcentaje.
  static const int marcaAmbar = 30;
  static const int marcaRojo = 60;

  bool get conLimite => (limiteCentavos ?? 0) > 0;

  /// Porcentaje usado redondeado **hacia arriba** (nunca se ve por debajo de un
  /// umbral que ya se cruzó). `null` sin límite.
  int? get porcentaje {
    if (!conLimite) return null;
    if (usadoCentavos <= 0) return 0;
    final limite = limiteCentavos!;
    return (usadoCentavos * 100 + limite - 1) ~/ limite;
  }

  /// Parte llena de la barra, de 0 a 1.
  double get fraccion {
    if (!conLimite || usadoCentavos <= 0) return 0;
    return (usadoCentavos / limiteCentavos!).clamp(0.0, 1.0);
  }

  /// Semáforo; `null` sin límite capturado (no se calcula con un supuesto).
  EstadoSemaforo? get estado {
    if (!conLimite) return null;
    final limite = limiteCentavos!;
    if (usadoCentavos * 100 > limite * marcaRojo) return EstadoSemaforo.rojo;
    if (usadoCentavos * 100 >= limite * marcaAmbar) return EstadoSemaforo.ambar;
    return EstadoSemaforo.verde;
  }

  /// Texto del semáforo: el estado nunca depende solo del color.
  String? get textoEstado => switch (estado) {
    EstadoSemaforo.verde => 'Uso bajo',
    EstadoSemaforo.ambar => 'Uso medio',
    EstadoSemaforo.rojo => 'Uso alto',
    null => null,
  };
}

/// Gadget **Barra de límite** (Fase 2, sección 8): uso del límite de una
/// tarjeta con semáforo **con texto**, marcas en 30 y 60 % y los montos
/// ocultables. El porcentaje siempre se ve.
///
/// Sin límite capturado no calcula nada: dice "Captura el límite de esta
/// tarjeta" y, si hay [alCapturarLimite], ofrece el botón.
class BarraLimite extends StatelessWidget {
  const BarraLimite({
    super.key,
    required this.usadoCentavos,
    required this.limiteCentavos,
    this.etiqueta,
    this.alCapturarLimite,
  });

  final int usadoCentavos;
  final int? limiteCentavos;

  /// Nombre de la tarjeta; `null` no dibuja título.
  final String? etiqueta;

  /// Acción cuando falta el límite.
  final VoidCallback? alCapturarLimite;

  UsoLimite get uso =>
      UsoLimite(usadoCentavos: usadoCentavos, limiteCentavos: limiteCentavos);

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final uso = this.uso;
    final titulo = etiqueta == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(bottom: e),
            child: Text(
              etiqueta!,
              style: v.lectura(
                tamano: 14,
                peso: FontWeight.w600,
                color: v.textoFuerte,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );

    if (!uso.conLimite) {
      return Semantics(
        container: true,
        label: etiqueta == null
            ? 'Uso del límite'
            : 'Uso del límite: $etiqueta',
        value: 'Captura el límite de esta tarjeta',
        excludeSemantics: alCapturarLimite == null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            titulo,
            Text(
              'Captura el límite de esta tarjeta',
              style: v.lectura(tamano: 14, color: v.textoTenue),
            ),
            if (alCapturarLimite != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: alCapturarLimite,
                  child: const Text('Capturar límite'),
                ),
              ),
          ],
        ),
      );
    }

    final estado = uso.estado!;
    final color = estado.color(v);
    final animar = v.animado && !MediaQuery.disableAnimationsOf(context);
    final porcentaje = uso.porcentaje!;

    final barra = SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, limites) {
          final ancho = limites.maxWidth;
          Widget marca(int pct) => Positioned(
            left: ancho * pct / 100 - 1,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 2,
              child: ColoredBox(color: v.textoTenue.withValues(alpha: 0.7)),
            ),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: ColoredBox(
                    color: v.pista,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: uso.fraccion),
                      duration: animar
                          ? v.duracionAnimacion * 2
                          : Duration.zero,
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: t,
                        heightFactor: 1,
                        child: ColoredBox(color: color),
                      ),
                    ),
                  ),
                ),
              ),
              marca(UsoLimite.marcaAmbar),
              marca(UsoLimite.marcaRojo),
            ],
          );
        },
      ),
    );

    final valorSemantico = '$porcentaje % usado. ${uso.textoEstado}';
    return Semantics(
      container: true,
      label: etiqueta == null ? 'Uso del límite' : 'Uso del límite: $etiqueta',
      value: valorSemantico,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          titulo,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: e,
            runSpacing: e * 0.5,
            children: [
              Text(
                '$porcentaje % del límite',
                style: v.numero(
                  tamano: 18,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
              Semaforo(
                estado: estado,
                etiqueta: uso.textoEstado,
                conIcono: true,
                tamanoTexto: 13,
              ),
            ],
          ),
          SizedBox(height: e),
          barra,
          SizedBox(height: e * 0.75),
          Wrap(
            spacing: e,
            runSpacing: e * 0.25,
            children: [
              _MontoDe(etiqueta: 'Usado', centavos: usadoCentavos, v: v),
              _MontoDe(etiqueta: 'Límite', centavos: limiteCentavos!, v: v),
            ],
          ),
        ],
      ),
    );
  }
}

class _MontoDe extends StatelessWidget {
  const _MontoDe({
    required this.etiqueta,
    required this.centavos,
    required this.v,
  });

  final String etiqueta;
  final int centavos;
  final ValoresDiseno v;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$etiqueta ', style: v.lectura(tamano: 13, color: v.textoTenue)),
        Flexible(
          child: MontoOcultable(
            centavos: centavos,
            estilo: v.numero(tamano: 13, peso: FontWeight.w600, color: v.texto),
          ),
        ),
      ],
    );
  }
}

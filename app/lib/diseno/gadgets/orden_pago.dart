import 'package:flutter/material.dart';

import '../componentes/monto_ocultable.dart';
import '../tema.dart';
import '../valores_diseno.dart';

/// Un lugar del orden de pago (Fase 2, regla 5).
@immutable
class LugarOrdenPago {
  const LugarOrdenPago({
    required this.acreedor,
    required this.motivo,
    this.abonoCentavos,
    this.fijo = false,
  });

  /// "Tarjeta B", "Caja Popular".
  final String acreedor;

  /// Por qué ocupa ese lugar: "manual", "grupo, lugar 2", "tasa 60 %",
  /// "familiar: al final", "MSI: no recibe extra".
  final String motivo;

  /// Lo que se abona en la semana, si ya se calculó.
  final int? abonoCentavos;

  /// No se puede mover a mano (MSI y familiares).
  final bool fijo;
}

/// Gadget **Orden de pago** (Fase 2, sección 8): lista numerada con el **motivo
/// de cada lugar**. Con [alSubir] y [alBajar] cada lugar se mueve con botones
/// de 48 dp (como el grupo prioritario de la Fase 1); sin ellos es solo lectura.
/// Los montos se ocultan solos.
class OrdenPago extends StatelessWidget {
  const OrdenPago({
    super.key,
    required this.lugares,
    this.alSubir,
    this.alBajar,
  });

  final List<LugarOrdenPago> lugares;

  /// Recibe la posición (desde 0) del lugar que sube.
  final ValueChanged<int>? alSubir;
  final ValueChanged<int>? alBajar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (lugares.isEmpty) {
      return Text(
        'Sin deudas que ordenar',
        style: v.lectura(tamano: 14, color: v.textoTenue),
      );
    }
    return Semantics(
      container: true,
      label: 'Orden de pago',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lugares.length; i++)
            _Lugar(
              posicion: i,
              lugar: lugares[i],
              total: lugares.length,
              alSubir: alSubir,
              alBajar: alBajar,
              separacion: e,
            ),
        ],
      ),
    );
  }
}

class _Lugar extends StatelessWidget {
  const _Lugar({
    required this.posicion,
    required this.lugar,
    required this.total,
    required this.alSubir,
    required this.alBajar,
    required this.separacion,
  });

  final int posicion;
  final LugarOrdenPago lugar;
  final int total;
  final ValueChanged<int>? alSubir;
  final ValueChanged<int>? alBajar;
  final double separacion;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = separacion;
    final movible = !lugar.fijo && (alSubir != null || alBajar != null);
    final puedeSubir = movible && alSubir != null && posicion > 0;
    final puedeBajar = movible && alBajar != null && posicion < total - 1;
    return Padding(
      padding: EdgeInsets.only(bottom: e * 0.75),
      child: Semantics(
        container: true,
        label: 'Lugar ${posicion + 1}: ${lugar.acreedor}, ${lugar.motivo}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: v.panel,
            border: Border.all(color: v.borde, width: v.grosorBorde),
            borderRadius: BorderRadius.circular(v.radioMediano),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: e, vertical: e * 0.5),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: 28,
                    child: Text(
                      '${posicion + 1}',
                      textAlign: TextAlign.center,
                      style: v.numero(
                        tamano: 18,
                        peso: FontWeight.w700,
                        color: v.acento,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: e),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lugar.acreedor,
                          style: v.lectura(
                            tamano: 14,
                            peso: FontWeight.w600,
                            color: v.textoFuerte,
                          ),
                        ),
                        Text(
                          lugar.motivo,
                          style: v.lectura(tamano: 12.5, color: v.textoTenue),
                        ),
                        if (lugar.abonoCentavos != null)
                          MontoOcultable(
                            centavos: lugar.abonoCentavos!,
                            estilo: v.numero(
                              tamano: 13,
                              peso: FontWeight.w600,
                              color: v.texto,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (movible) ...[
                  IconButton(
                    tooltip: 'Subir ${lugar.acreedor}',
                    constraints: const BoxConstraints(
                      minWidth: zonaTactilMinima,
                      minHeight: zonaTactilMinima,
                    ),
                    onPressed: puedeSubir ? () => alSubir!(posicion) : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Bajar ${lugar.acreedor}',
                    constraints: const BoxConstraints(
                      minWidth: zonaTactilMinima,
                      minHeight: zonaTactilMinima,
                    ),
                    onPressed: puedeBajar ? () => alBajar!(posicion) : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ] else if (lugar.fijo)
                  Tooltip(
                    message: 'No se mueve a mano',
                    child: Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: v.textoTenue,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

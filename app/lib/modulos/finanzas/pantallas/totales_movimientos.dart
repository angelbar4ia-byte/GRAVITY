/// Totales por tipo de movimiento y periodo (teléfono y laptop): cuánto
/// ingresó, cuánto se gastó, pagos de deuda, transferencias, ahorro, intereses
/// y cargos, con el neto. El cálculo vive en el dominio ([totalesPorTipo]);
/// aquí solo se muestra. Especificación:
/// `docs/specs/fase-8-finanzas-movimientos-y-pagos.md`.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';

import '../../../diseno/diseno.dart';
import 'comunes.dart';

/// Periodos que se pueden elegir al filtrar movimientos.
enum RangoMovimientos {
  semana('Esta semana'),
  semanaPasada('Semana pasada'),
  mes('Este mes'),
  todo('Todo');

  const RangoMovimientos(this.etiqueta);

  final String etiqueta;

  /// El periodo respecto de [hoy] (semana en lunes); `null` = todas las fechas.
  Periodo? periodo(Fecha hoy) => switch (this) {
    RangoMovimientos.semana => Periodo.semana(hoy),
    RangoMovimientos.semanaPasada => Periodo.semana(hoy.sumarDias(-7)),
    RangoMovimientos.mes => Periodo.mes(hoy),
    RangoMovimientos.todo => null,
  };
}

/// Nombre corto de un grupo del resumen.
String nombreTipoResumen(TipoResumen t) => switch (t) {
  TipoResumen.ingresos => 'Ingresos',
  TipoResumen.gastos => 'Gastos',
  TipoResumen.reembolsos => 'Reembolsos',
  TipoResumen.pagosDeuda => 'Pagos de deuda',
  TipoResumen.transferencias => 'Transferencias',
  TipoResumen.ahorro => 'Ahorro',
  TipoResumen.interesesYCargos => 'Intereses y cargos',
};

/// Tira de totales: un cuadro por tipo y el neto. Con [alElegir] cada cuadro
/// se puede tocar para filtrar la lista por ese tipo; tocar el elegido otra
/// vez quita el filtro. Se parte en líneas si no cabe (letra grande).
class TiraTotales extends StatelessWidget {
  const TiraTotales({
    super.key,
    required this.totales,
    this.seleccionado,
    this.alElegir,
  });

  final TotalesPorTipo totales;
  final TipoResumen? seleccionado;

  /// Recibe el tipo tocado, o `null` para quitar el filtro.
  final ValueChanged<TipoResumen?>? alElegir;

  @override
  Widget build(BuildContext context) {
    final tipos = [
      for (final t in TipoResumen.values)
        // Los reembolsos solo se muestran si los hay (son poco frecuentes).
        if (t != TipoResumen.reembolsos || totales.cantidadDe(t) > 0) t,
    ];
    return Wrap(
      key: const ValueKey('totales-tira'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in tipos)
          _CuadroTotal(
            key: ValueKey('totales-${t.name}'),
            etiqueta: nombreTipoResumen(t),
            centavos: totales.centavosDe(t),
            cantidad: totales.cantidadDe(t),
            elegido: seleccionado == t,
            alTocar: alElegir == null
                ? null
                : () => alElegir!(seleccionado == t ? null : t),
          ),
        _CuadroTotal(
          key: const ValueKey('totales-neto'),
          etiqueta: 'Neto',
          centavos: totales.neto,
          conSigno: true,
          destacado: true,
        ),
      ],
    );
  }
}

class _CuadroTotal extends StatelessWidget {
  const _CuadroTotal({
    super.key,
    required this.etiqueta,
    required this.centavos,
    this.cantidad,
    this.elegido = false,
    this.destacado = false,
    this.conSigno = false,
    this.alTocar,
  });

  final String etiqueta;
  final int centavos;
  final int? cantidad;
  final bool elegido;
  final bool destacado;
  final bool conSigno;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final v = ValoresDiseno.de(context);
    final color = elegido
        ? tema.colorScheme.secondaryContainer
        : tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    return Semantics(
      container: true,
      button: alTocar != null,
      selected: elegido,
      label: etiqueta,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: tema.textTheme.bodySmall?.copyWith(
                      fontWeight: destacado ? FontWeight.w700 : null,
                    ),
                  ),
                  Monto(
                    centavos,
                    signo: conSigno,
                    estilo: v.numero(
                      tamano: 15,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

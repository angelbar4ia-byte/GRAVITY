/// Totales por tipo de movimiento de un periodo (Fase 8, especificación
/// `fase-8-finanzas-movimientos-y-pagos.md`): cuánto ingresó, cuánto se gastó,
/// cuánto se pagó a deudas, cuánto se movió entre cuentas, cuánto se ahorró y
/// cuánto costaron los intereses y cargos.
///
/// Solo lee la vista de **un** libro (D19) y nunca sale de la app (D3). Dinero
/// en centavos, sin redondeos. No duplica reglas del libro: usa
/// [LibroMovimientos.estaAnulado] y [LibroMovimientos.estadoDe].
library;

import 'libro.dart';
import 'semana.dart';

/// Cómo se clasifica un movimiento en el resumen. Los grupos no se solapan: un
/// movimiento cae en uno solo (o en ninguno).
enum TipoResumen {
  /// Sueldo, extras y demás entradas de dinero.
  ingresos,

  /// Gastos de categoría. El pago de deuda **no** es gasto.
  gastos,

  /// Devoluciones de gastos (bajan el gasto; no son ingreso).
  reembolsos,

  /// Pago de capital a una tarjeta, préstamo o deuda.
  pagosDeuda,

  /// Movimientos entre cuentas propias (y aportaciones entre libros), sin
  /// contar lo que va a una cuenta de ahorro.
  transferencias,

  /// Lo que entra a cuentas de ahorro desde una cuenta que no es de ahorro.
  ahorro,

  /// Intereses y cargos: gasto hacia una cuenta de gasto financiero.
  interesesYCargos,
}

/// Clasifica [m] para el resumen, o `null` si no cuenta (saldos iniciales,
/// ajustes, reclasificaciones y anulaciones).
///
/// No mira el estado ni la anulación: eso lo decide [totalesPorTipo] y
/// [cuentaEnResumen].
TipoResumen? tipoResumenDe(Movimiento m, LibroMovimientos vista) {
  TipoCuenta? tipoDe(String id) {
    for (final c in vista.cuentas) {
      if (c.id == id) return c.tipo;
    }
    return null;
  }

  switch (m.tipo) {
    case TipoMovimiento.ingreso:
      return TipoResumen.ingresos;
    case TipoMovimiento.gasto:
      return tipoDe(m.cuentaDestinoId) == TipoCuenta.gastoFinanciero
          ? TipoResumen.interesesYCargos
          : TipoResumen.gastos;
    case TipoMovimiento.reembolso:
      return TipoResumen.reembolsos;
    case TipoMovimiento.pagoDeuda:
      return TipoResumen.pagosDeuda;
    case TipoMovimiento.transferencia:
      return tipoDe(m.cuentaDestinoId) == TipoCuenta.ahorro &&
              tipoDe(m.cuentaOrigenId) != TipoCuenta.ahorro
          ? TipoResumen.ahorro
          : TipoResumen.transferencias;
    case TipoMovimiento.apertura:
    case TipoMovimiento.reclasificacion:
    case TipoMovimiento.ajuste:
    case TipoMovimiento.anulacion:
      return null;
  }
}

/// `true` si [m] cuenta en el resumen: confirmado, no anulado y no es un
/// contraasiento.
bool cuentaEnResumen(Movimiento m, LibroMovimientos vista) =>
    m.tipo != TipoMovimiento.anulacion &&
    vista.estadoDe(m.id) == EstadoMovimiento.confirmado &&
    !vista.estaAnulado(m.id);

/// Totales de un periodo, en centavos.
class TotalesPorTipo {
  const TotalesPorTipo({
    required this.periodo,
    required this.porTipoCentavos,
    required this.porTipoCantidad,
  });

  /// `null` = todas las fechas.
  final Periodo? periodo;

  /// Centavos por tipo (los tipos sin movimientos no aparecen).
  final Map<TipoResumen, int> porTipoCentavos;

  /// Cantidad de movimientos por tipo.
  final Map<TipoResumen, int> porTipoCantidad;

  int centavosDe(TipoResumen t) => porTipoCentavos[t] ?? 0;

  /// Cuántos movimientos sumaron en [t].
  int cantidadDe(TipoResumen t) => porTipoCantidad[t] ?? 0;

  int get ingresos => centavosDe(TipoResumen.ingresos);
  int get gastos => centavosDe(TipoResumen.gastos);
  int get reembolsos => centavosDe(TipoResumen.reembolsos);
  int get pagosDeuda => centavosDe(TipoResumen.pagosDeuda);
  int get transferencias => centavosDe(TipoResumen.transferencias);
  int get ahorro => centavosDe(TipoResumen.ahorro);
  int get interesesYCargos => centavosDe(TipoResumen.interesesYCargos);

  /// Resultado del periodo: ingresos + reembolsos − gastos − intereses y
  /// cargos. Los pagos de deuda, las transferencias y el ahorro **no** entran:
  /// mueven dinero entre cuentas, no lo gastan (el capital de una deuda ya se
  /// gastó cuando se compró). Coincide con `EstadoResultados.resultado`.
  int get neto => ingresos + reembolsos - gastos - interesesYCargos;

  /// Cantidad total de movimientos que cuentan.
  int get cantidadTotal => porTipoCantidad.values.fold(0, (a, b) => a + b);
}

/// Totales por tipo de lo que hay en [vista] dentro de [periodo] (`null` =
/// todas las fechas), contando solo lo **confirmado** y **no anulado** ([
/// cuentaEnResumen]).
///
/// [incluir] permite acotar más (por ejemplo, una cuenta o una categoría); se
/// aplica además de las reglas anteriores.
TotalesPorTipo totalesPorTipo(
  LibroMovimientos vista,
  Periodo? periodo, {
  bool Function(Movimiento m)? incluir,
}) {
  final centavos = <TipoResumen, int>{};
  final cantidad = <TipoResumen, int>{};
  for (final m in vista.movimientos) {
    if (periodo != null && !periodo.contiene(m.fecha)) continue;
    if (incluir != null && !incluir(m)) continue;
    if (!cuentaEnResumen(m, vista)) continue;
    final t = tipoResumenDe(m, vista);
    if (t == null) continue;
    centavos[t] = (centavos[t] ?? 0) + m.monto;
    cantidad[t] = (cantidad[t] ?? 0) + 1;
  }
  return TotalesPorTipo(
    periodo: periodo,
    porTipoCentavos: Map.unmodifiable(centavos),
    porTipoCantidad: Map.unmodifiable(cantidad),
  );
}

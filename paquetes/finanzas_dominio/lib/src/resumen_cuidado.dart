import 'libro.dart';

/// Una línea del resumen mensual: un rubro de gasto y su total neto.
class LineaResumenCuidado {
  /// Nombre del rubro (la cuenta de gasto del hogar: "Salud", "Alimentación"…).
  final String categoria;

  /// Centavos netos del mes (gastos menos reembolsos).
  final int centavos;

  const LineaResumenCuidado(this.categoria, this.centavos);

  @override
  String toString() => '$categoria $centavos';
}

/// Resumen mensual del costo del cuidado y de los gastos de la casa (Fase 5,
/// sección 4 y criterio 3). **No lleva personas ni libros**: solo rubros y
/// montos, para que quien lo lee no pueda deducir de quién es cada gasto.
class ResumenMensualCuidado {
  final int anio;
  final int mes;

  /// Rubros con monto distinto de cero, del mayor al menor (empate por
  /// nombre).
  final List<LineaResumenCuidado> lineas;

  /// Suma de [lineas], en centavos.
  final int totalCentavos;

  ResumenMensualCuidado({
    required this.anio,
    required this.mes,
    required List<LineaResumenCuidado> lineas,
  }) : lineas = List.unmodifiable(lineas),
       totalCentavos = lineas.fold(0, (a, l) => a + l.centavos);

  bool get vacio => lineas.isEmpty;
}

/// Calcula el resumen del mes [anio]-[mes] con lo que está **confirmado** y
/// **no anulado** en [libro] (normalmente `datos.libroHogar`).
///
/// El dominio no conoce roles: quién puede ver el resumen y qué se excluye
/// llegan como parámetros.
///
/// - [librosIncluidos]: ids de los libros cuyos gastos cuentan (el de Papá y
///   "Gastos de la casa"). Un gasto se asigna al libro de la cuenta con la
///   que se pagó; si esa cuenta es desconocida o virtual (libro que no se
///   ve), **no cuenta**.
/// - [personasExcluidas]: personas cuyo gasto no entra (la pareja y el dueño).
///   Se compara con `realizadoPor` (de quién es el gasto). Lo que el albacea
///   registra en nombre de Papá lleva a Papá como `realizadoPor`, así que
///   cuenta aunque lo haya capturado el dueño.
///
/// Suma en centavos, sin redondeos: cada gasto suma a su rubro (cuenta de
/// gasto destino); un reembolso resta del rubro de origen. Los ingresos,
/// transferencias, pagos de deuda, ajustes y reclasificaciones no cuentan (una
/// reclasificación no dice de qué libro viene y podría revelar un gasto
/// excluido; el monto queda en "Por clasificar").
ResumenMensualCuidado resumenMensualCuidado({
  required int anio,
  required int mes,
  required LibroMovimientos libro,
  required Set<String> librosIncluidos,
  required Set<String> personasExcluidas,
}) {
  final cuentas = {for (final c in libro.cuentas) c.id: c};
  final porRubro = <String, int>{};

  void sumar(String? cuentaId, int centavos) {
    final c = cuentaId == null ? null : cuentas[cuentaId];
    if (c == null || c.clase != ClaseCuenta.gasto) return;
    porRubro.update(c.nombre, (v) => v + centavos, ifAbsent: () => centavos);
  }

  for (final m in libro.movimientos) {
    if (m.fecha.anio != anio || m.fecha.mes != mes) continue;
    if (m.tipo == TipoMovimiento.anulacion) continue;
    if (m.tipo != TipoMovimiento.gasto && m.tipo != TipoMovimiento.reembolso) {
      continue;
    }
    if (libro.estadoDe(m.id) != EstadoMovimiento.confirmado) continue;
    if (libro.estaAnulado(m.id)) continue;
    if (personasExcluidas.contains(m.realizadoPor)) continue;
    // Libro de la cuenta de pago (gasto) o del activo que recibe (reembolso).
    final pago =
        cuentas[m.tipo == TipoMovimiento.gasto
            ? m.cuentaOrigenId
            : m.cuentaDestinoId];
    final libroDelPago = pago?.libroId;
    if (libroDelPago == null || !librosIncluidos.contains(libroDelPago)) {
      continue;
    }
    sumar(m.cuentaDestinoId, m.monto);
    sumar(m.cuentaOrigenId, -m.monto);
  }

  final lineas =
      [
        for (final e in porRubro.entries)
          if (e.value != 0) LineaResumenCuidado(e.key, e.value),
      ]..sort((a, b) {
        final c = b.centavos.compareTo(a.centavos);
        return c != 0 ? c : a.categoria.compareTo(b.categoria);
      });
  return ResumenMensualCuidado(anio: anio, mes: mes, lineas: lineas);
}

/// Reportes puros del libro (Fase 8, bloque 4): gasto por categoría por mes y
/// por un periodo configurable. Solo lee el libro que se pide (D19) y nunca
/// sale de la app (D3). Dinero en centavos; los porcentajes, en puntos base
/// con redondeo explícito (hacia abajo; el sobrante no se reparte).
library;

import 'categorias.dart';
import 'datos_finanzas.dart';
import 'fecha.dart';
import 'libro.dart';

/// Periodo de un reporte: del [desde] al [hasta], ambos incluidos.
class RangoReporte {
  RangoReporte(this.desde, this.hasta) {
    if (desde.despuesDe(hasta)) {
      throw ArgumentError('El periodo empieza después de terminar');
    }
  }

  /// El mes calendario completo.
  factory RangoReporte.mes(int anio, int mes) => RangoReporte(
    Fecha(anio, mes, 1),
    Fecha(anio, mes, Fecha.diasDelMes(anio, mes)),
  );

  /// El mes que contiene a [dia].
  factory RangoReporte.delMesDe(Fecha dia) =>
      RangoReporte(dia.primerDiaDelMes, dia.ultimoDiaDelMes);

  final Fecha desde;
  final Fecha hasta;

  bool contiene(Fecha f) => !f.antesDe(desde) && !f.despuesDe(hasta);

  @override
  bool operator ==(Object other) =>
      other is RangoReporte && other.desde == desde && other.hasta == hasta;

  @override
  int get hashCode => Object.hash(desde, hasta);
}

/// Una categoría (de nivel 1) con lo gastado en el periodo.
class LineaGastoCategoria {
  const LineaGastoCategoria({
    required this.categoriaId,
    required this.nombre,
    required this.centavos,
    required this.partePb,
  });

  /// `null` = gastos sin categoría ("Por clasificar").
  final String? categoriaId;
  final String nombre;
  final int centavos;

  /// Parte del total en puntos base (10000 = 100%), redondeada hacia abajo.
  final int partePb;
}

class ReporteGastoCategoria {
  const ReporteGastoCategoria({
    required this.rango,
    required this.lineas,
    required this.totalCentavos,
  });

  final RangoReporte rango;

  /// De mayor a menor gasto (a igual gasto, por nombre).
  final List<LineaGastoCategoria> lineas;
  final int totalCentavos;
}

/// Nombre con el que se muestra el gasto sin categoría.
const String nombreSinCategoria = 'Por clasificar';

/// Gastos **confirmados** del [libroId] en [rango], agrupados por categoría de
/// nivel 1, sin los anulados ni los contraasientos. Los gastos de otros libros
/// que haya en [datos] (cuenta maestra, compartidos) no cuentan.
ReporteGastoCategoria gastoPorCategoria(
  DatosFinanzas datos,
  String libroId,
  RangoReporte rango,
) {
  final cuentasDelLibro = {
    for (final c in datos.cuentas)
      if (c.libroId == libroId) c.id,
  };
  final anulados = {
    for (final m in datos.movimientos)
      if (m.tipo == TipoMovimiento.anulacion && m.anulaA != null) m.anulaA!,
  };
  final porCategoria = <String?, int>{};
  var total = 0;
  for (final m in datos.movimientos) {
    if (m.tipo != TipoMovimiento.gasto) continue;
    if (m.estadoInicial != EstadoMovimiento.confirmado) continue;
    if (anulados.contains(m.id)) continue;
    if (!cuentasDelLibro.contains(m.cuentaOrigenId)) continue;
    if (!rango.contiene(m.fecha)) continue;
    final raiz = m.categoriaId == null
        ? null
        : datos.arbol.raiz(m.categoriaId!)?.id;
    porCategoria[raiz] = (porCategoria[raiz] ?? 0) + m.monto;
    total += m.monto;
  }
  final lineas =
      [
        for (final e in porCategoria.entries)
          LineaGastoCategoria(
            categoriaId: e.key,
            nombre: e.key == null
                ? nombreSinCategoria
                : (datos.arbol.porId(e.key)?.nombre ?? nombreSinCategoria),
            centavos: e.value,
            partePb: total == 0 ? 0 : e.value * 10000 ~/ total,
          ),
      ]..sort((a, b) {
        final porMonto = b.centavos.compareTo(a.centavos);
        return porMonto != 0 ? porMonto : a.nombre.compareTo(b.nombre);
      });
  return ReporteGastoCategoria(
    rango: rango,
    lineas: lineas,
    totalCentavos: total,
  );
}

/// Gasto total de un mes.
class GastoDelMes {
  const GastoDelMes(this.anio, this.mes, this.centavos);
  final int anio;
  final int mes;
  final int centavos;
}

/// El gasto de los últimos [meses] meses (el de [hoy] incluido), del más
/// antiguo al más reciente.
List<GastoDelMes> gastoPorMes(
  DatosFinanzas datos,
  String libroId,
  Fecha hoy, {
  int meses = 6,
}) {
  if (meses < 1) throw ArgumentError('Pide al menos un mes');
  final resultado = <GastoDelMes>[];
  for (var i = meses - 1; i >= 0; i--) {
    final indice = hoy.anio * 12 + (hoy.mes - 1) - i;
    final anio = indice ~/ 12;
    final mes = indice % 12 + 1;
    resultado.add(
      GastoDelMes(
        anio,
        mes,
        gastoPorCategoria(
          datos,
          libroId,
          RangoReporte.mes(anio, mes),
        ).totalCentavos,
      ),
    );
  }
  return resultado;
}

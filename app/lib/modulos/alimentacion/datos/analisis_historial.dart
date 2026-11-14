/// Análisis del historial de compra (Fase 8, sección 1): cuatro ejes
/// combinables (tiempo, precio, producto y tienda) sobre compras **reales**.
///
/// Funciones puras. El precio base de supuesto nunca llega aquí: una
/// [CompraPrecio] solo nace de una compra que captura una persona. Todo eje
/// suma el mismo total que las compras filtradas (cuadre): el total sale de
/// los centavos pagados, nunca de promedios.
library;

import 'historial_precios.dart';

/// Escala de tiempo, igual que el periodo de la aportación.
enum EscalaTiempo {
  semana('Semana'),
  mes('Mes'),
  bimestre('Bimestre'),
  semestre('Semestre'),
  ano('Año');

  const EscalaTiempo(this.etiqueta);
  final String etiqueta;
}

/// Valor de [FiltroHistorial.tienda] para las compras anteriores a la captura
/// de tienda.
const filtroSinTienda = '';

/// Etiqueta de las compras sin tienda.
const etiquetaSinTienda = 'sin tienda';

/// Primer día (00:00) del periodo de [f] en la [escala]; la semana empieza en
/// lunes.
DateTime inicioDePeriodo(DateTime f, EscalaTiempo escala) {
  final d = DateTime(f.year, f.month, f.day);
  return switch (escala) {
    EscalaTiempo.semana => d.subtract(Duration(days: d.weekday - 1)),
    EscalaTiempo.mes => DateTime(d.year, d.month),
    EscalaTiempo.bimestre => DateTime(d.year, ((d.month - 1) ~/ 2) * 2 + 1),
    EscalaTiempo.semestre => DateTime(d.year, d.month <= 6 ? 1 : 7),
    EscalaTiempo.ano => DateTime(d.year),
  };
}

const _mesesCorto = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

String etiquetaPeriodo(DateTime inicio, EscalaTiempo escala) =>
    switch (escala) {
      EscalaTiempo.semana =>
        'Semana del ${inicio.day.toString().padLeft(2, '0')}/'
            '${inicio.month.toString().padLeft(2, '0')}/${inicio.year}',
      EscalaTiempo.mes => '${_mesesCorto[inicio.month - 1]} ${inicio.year}',
      EscalaTiempo.bimestre =>
        '${_mesesCorto[inicio.month - 1]}-${_mesesCorto[inicio.month]} '
            '${inicio.year}',
      EscalaTiempo.semestre =>
        '${inicio.month == 1 ? '1.er' : '2.º'} semestre ${inicio.year}',
      EscalaTiempo.ano => '${inicio.year}',
    };

/// Filtros combinables. Todo lo que es `null` no filtra.
class FiltroHistorial {
  const FiltroHistorial({
    this.escala = EscalaTiempo.mes,
    this.claveProducto,
    this.tienda,
    this.unitarioMinCentavos,
    this.unitarioMaxCentavos,
    this.desde,
    this.hasta,
  });

  final EscalaTiempo escala;

  /// `claveCompra` del producto.
  final String? claveProducto;

  /// Id de tienda, o [filtroSinTienda] para las compras sin tienda.
  final String? tienda;

  /// Rango del precio unitario (centavos por unidad), ambos extremos incluidos.
  final double? unitarioMinCentavos;
  final double? unitarioMaxCentavos;

  /// Rango de fechas (por día, ambos extremos incluidos).
  final DateTime? desde;
  final DateTime? hasta;

  bool admite(CompraPrecio c) {
    if (claveProducto != null && c.clave != claveProducto) return false;
    if (tienda != null && (c.tiendaId ?? filtroSinTienda) != tienda) {
      return false;
    }
    final u = c.unitarioCentavos;
    if (unitarioMinCentavos != null && u < unitarioMinCentavos!) return false;
    if (unitarioMaxCentavos != null && u > unitarioMaxCentavos!) return false;
    final dia = DateTime(c.fecha.year, c.fecha.month, c.fecha.day);
    if (desde != null &&
        dia.isBefore(DateTime(desde!.year, desde!.month, desde!.day))) {
      return false;
    }
    if (hasta != null &&
        dia.isAfter(DateTime(hasta!.year, hasta!.month, hasta!.day))) {
      return false;
    }
    return true;
  }
}

class FilaPeriodo {
  const FilaPeriodo({
    required this.inicio,
    required this.etiqueta,
    required this.compras,
    required this.totalCentavos,
  });
  final DateTime inicio;
  final String etiqueta;
  final int compras;
  final int totalCentavos;
}

class FilaProducto {
  const FilaProducto({
    required this.clave,
    required this.nombre,
    required this.unidad,
    required this.compras,
    required this.cantidad,
    required this.totalCentavos,
    required this.primerUnitario,
    required this.ultimoUnitario,
    required this.minUnitario,
    required this.maxUnitario,
    this.tiendaMasBarata,
  });
  final String clave;
  final String nombre;
  final String unidad;
  final int compras;
  final double cantidad;
  final int totalCentavos;

  /// Precio unitario (centavos) de la compra más antigua y de la más reciente.
  final double primerUnitario;
  final double ultimoUnitario;
  final double minUnitario;
  final double maxUnitario;

  /// Tienda con el menor precio unitario ponderado, solo si el producto se
  /// compró en dos tiendas o más (si no, no hay con qué comparar).
  final String? tiendaMasBarata;

  /// Cuánto subió (+) o bajó (-) el precio, en porcentaje redondeado, de la
  /// primera a la última compra. `null` con una sola compra.
  int? get variacionPorcentaje => compras < 2
      ? null
      : ((ultimoUnitario / primerUnitario - 1) * 100).round();
}

class FilaTienda {
  const FilaTienda({
    required this.tiendaId,
    required this.nombre,
    required this.compras,
    required this.totalCentavos,
  });

  /// `null`: compras sin tienda.
  final String? tiendaId;
  final String nombre;
  final int compras;
  final int totalCentavos;
}

class ResumenHistorial {
  const ResumenHistorial({
    required this.totalCentavos,
    required this.compras,
    required this.porPeriodo,
    required this.porProducto,
    required this.porTienda,
  });
  final int totalCentavos;
  final int compras;

  /// Del periodo más reciente al más antiguo.
  final List<FilaPeriodo> porPeriodo;

  /// De mayor a menor gasto.
  final List<FilaProducto> porProducto;

  /// De mayor a menor gasto; "sin tienda" al final.
  final List<FilaTienda> porTienda;
}

/// Compras que pasan el [filtro], de la más reciente a la más antigua.
List<CompraPrecio> filtrarHistorial(
  Iterable<CompraPrecio> todas,
  FiltroHistorial filtro,
) => todas.where((c) => !c.revertida && filtro.admite(c)).toList()
  ..sort((a, b) => b.fecha.compareTo(a.fecha));

/// Resumen por los cuatro ejes. Cada eje suma [ResumenHistorial.totalCentavos].
ResumenHistorial resumirHistorial(
  Iterable<CompraPrecio> todas,
  FiltroHistorial filtro,
) {
  final compras = filtrarHistorial(todas, filtro);
  final total = compras.fold<int>(0, (a, c) => a + c.totalCentavos);

  final periodos = <DateTime, List<CompraPrecio>>{};
  final productos = <String, List<CompraPrecio>>{};
  final tiendas = <String?, List<CompraPrecio>>{};
  for (final c in compras) {
    (periodos[inicioDePeriodo(c.fecha, filtro.escala)] ??= []).add(c);
    (productos[c.clave] ??= []).add(c);
    (tiendas[c.tiendaId] ??= []).add(c);
  }
  int suma(List<CompraPrecio> l) => l.fold(0, (a, c) => a + c.totalCentavos);

  final porPeriodo = [
    for (final e in periodos.entries)
      FilaPeriodo(
        inicio: e.key,
        etiqueta: etiquetaPeriodo(e.key, filtro.escala),
        compras: e.value.length,
        totalCentavos: suma(e.value),
      ),
  ]..sort((a, b) => b.inicio.compareTo(a.inicio));

  final porProducto = [
    for (final e in productos.entries) _filaProducto(e.key, e.value),
  ]..sort((a, b) => b.totalCentavos.compareTo(a.totalCentavos));

  final porTienda = [
    for (final e in tiendas.entries)
      FilaTienda(
        tiendaId: e.key,
        nombre: e.key == null
            ? etiquetaSinTienda
            : (e.value.first.tienda ?? etiquetaSinTienda),
        compras: e.value.length,
        totalCentavos: suma(e.value),
      ),
  ]..sort((a, b) {
      if (a.tiendaId == null) return b.tiendaId == null ? 0 : 1;
      if (b.tiendaId == null) return -1;
      return b.totalCentavos.compareTo(a.totalCentavos);
    });

  return ResumenHistorial(
    totalCentavos: total,
    compras: compras.length,
    porPeriodo: porPeriodo,
    porProducto: porProducto,
    porTienda: porTienda,
  );
}

FilaProducto _filaProducto(String clave, List<CompraPrecio> lista) {
  // `lista` viene de la más reciente a la más antigua.
  final unitarios = [for (final c in lista) c.unitarioCentavos];
  final porTienda = <String, ({double total, double cantidad})>{};
  for (final c in lista) {
    final t = c.tiendaId == null ? null : (c.tienda ?? etiquetaSinTienda);
    if (t == null) continue;
    final p = porTienda[t] ?? (total: 0.0, cantidad: 0.0);
    porTienda[t] = (
      total: p.total + c.totalCentavos,
      cantidad: p.cantidad + c.cantidad,
    );
  }
  String? barata;
  if (porTienda.length >= 2) {
    double? mejor;
    for (final e in porTienda.entries) {
      final u = e.value.total / e.value.cantidad;
      if (mejor == null || u < mejor) {
        mejor = u;
        barata = e.key;
      }
    }
  }
  return FilaProducto(
    clave: clave,
    nombre: lista.first.nombre,
    unidad: lista.first.unidad,
    compras: lista.length,
    cantidad: lista.fold(0.0, (a, c) => a + c.cantidad),
    totalCentavos: lista.fold(0, (a, c) => a + c.totalCentavos),
    primerUnitario: unitarios.last,
    ultimoUnitario: unitarios.first,
    minUnitario: unitarios.reduce((a, b) => a < b ? a : b),
    maxUnitario: unitarios.reduce((a, b) => a > b ? a : b),
    tiendaMasBarata: barata,
  );
}

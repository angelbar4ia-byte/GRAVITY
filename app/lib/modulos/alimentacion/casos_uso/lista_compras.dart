/// Lista de compras derivada del menú: suma por nombre y unidad, agrupada por
/// pasillo. Con [precios] cada renglón trae su costo; sin precio no hay costo
/// (nunca se inventa uno).
library;

import '../datos/modelos.dart';

List<ItemCompra> generarListaCompras({
  required List<EntradaMenu> menu,
  required List<Platillo> platillos,
  Set<String> comprados = const {},
  Map<String, PrecioIngrediente> precios = const {},
}) {
  final porId = {for (final p in platillos) p.id: p};
  final acum = <String, ({Ingrediente base, double total})>{};
  for (final e in menu) {
    final p = porId[e.platilloId];
    if (p == null) continue;
    for (final i in p.ingredientes) {
      final k = claveCompra(i.nombre, i.unidad);
      final previo = acum[k];
      acum[k] = (base: i, total: (previo?.total ?? 0) + i.cantidad);
    }
  }
  final items =
      [
        for (final e in acum.entries)
          ItemCompra(
            nombre: e.value.base.nombre,
            cantidad: e.value.total,
            unidad: e.value.base.unidad,
            seccion: e.value.base.seccion,
            comprado: comprados.contains(e.key),
            precio: precios[e.key],
          ),
      ]..sort((a, b) {
        final s = a.seccion.index.compareTo(b.seccion.index);
        return s != 0
            ? s
            : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
  return items;
}

Map<SeccionCompra, List<ItemCompra>> agruparPorSeccion(List<ItemCompra> items) {
  final r = <SeccionCompra, List<ItemCompra>>{};
  for (final i in items) {
    (r[i.seccion] ??= []).add(i);
  }
  return r;
}

/// Resumen del costo de una lista: suma solo lo que tiene precio.
class CostoLista {
  const CostoLista({
    required this.centavos,
    required this.estimado,
    required this.sinPrecio,
  });

  /// Suma de los renglones con precio.
  final int centavos;

  /// `true` si al menos un renglón sumado usa un precio base supuesto: el
  /// total entero se muestra como estimado.
  final bool estimado;

  /// Renglones sin precio (no entran en la suma).
  final int sinPrecio;
}

/// `null` si ningún renglón tiene precio (no se calcula costo).
CostoLista? costoDeLista(List<ItemCompra> items) {
  var total = 0;
  var conPrecio = 0;
  var estimado = false;
  for (final i in items) {
    final c = i.costoCentavos;
    if (c == null) continue;
    total += c;
    conPrecio++;
    if (i.costoEstimado) estimado = true;
  }
  if (conPrecio == 0) return null;
  return CostoLista(
    centavos: total,
    estimado: estimado,
    sinPrecio: items.length - conPrecio,
  );
}

/// Precio **real** que deja una compra: reemplaza al base y a la compra
/// anterior. [totalCentavos] > 0 y [cantidadComprada] > 0.
PrecioIngrediente precioDeCompra({
  required String clave,
  required int totalCentavos,
  required double cantidadComprada,
}) {
  if (totalCentavos <= 0 || cantidadComprada <= 0) {
    throw ArgumentError('La compra necesita precio y cantidad mayores que cero.');
  }
  return PrecioIngrediente.deCompra(
    clave: clave,
    totalCentavos: totalCentavos,
    cantidadComprada: cantidadComprada,
  );
}

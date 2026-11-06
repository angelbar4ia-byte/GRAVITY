/// Lista de compras derivada del menú: suma por nombre y unidad, agrupada por
/// sección. Sin precios.
library;

import '../datos/modelos.dart';

List<ItemCompra> generarListaCompras({
  required List<EntradaMenu> menu,
  required List<Platillo> platillos,
  Set<String> comprados = const {},
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
  final items = [
    for (final e in acum.entries)
      ItemCompra(
        nombre: e.value.base.nombre,
        cantidad: e.value.total,
        unidad: e.value.base.unidad,
        seccion: e.value.base.seccion,
        comprado: comprados.contains(e.key),
      ),
  ]..sort((a, b) {
      final s = a.seccion.index.compareTo(b.seccion.index);
      return s != 0 ? s : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
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

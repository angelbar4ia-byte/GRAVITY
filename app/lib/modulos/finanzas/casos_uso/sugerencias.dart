/// Sugerencias del registro rápido (F1): la última categoría y la última
/// cuenta que usó la persona, y 5 categorías sugeridas (las más usadas en los
/// últimos 60 días del libro; si no hay, las de la plantilla).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

class SugerenciasGasto {
  const SugerenciasGasto({
    this.ultimaCategoriaId,
    this.ultimaCuentaId,
    this.categorias = const [],
    this.cuentas = const [],
  });

  final String? ultimaCategoriaId;
  final String? ultimaCuentaId;

  /// Hasta 6 categorías: la última primero y 5 sugeridas.
  final List<Categoria> categorias;

  /// Cuentas con las que se puede pagar (efectivo, banco, tarjeta…).
  final List<Cuenta> cuentas;
}

/// Cuentas del libro con las que se paga un gasto, en orden de uso.
List<Cuenta> cuentasParaPagar(DatosFinanzas d, String libroId) {
  final orden = {
    TipoCuenta.efectivo: 0,
    TipoCuenta.banco: 1,
    TipoCuenta.tarjeta: 2,
    TipoCuenta.ahorro: 3,
    TipoCuenta.prestamo: 4,
    TipoCuenta.inversion: 5,
    TipoCuenta.porCobrar: 6,
  };
  return d
      .cuentasDe(libroId)
      .where(
        (c) => c.estado == EstadoCuenta.activa && orden.containsKey(c.tipo),
      )
      .toList()
    ..sort((a, b) {
      final t = orden[a.tipo]!.compareTo(orden[b.tipo]!);
      return t != 0 ? t : a.nombre.compareTo(b.nombre);
    });
}

/// Cuentas del libro donde entra dinero (activos líquidos y ahorro).
List<Cuenta> cuentasParaRecibir(DatosFinanzas d, String libroId) => d
    .cuentasDe(libroId)
    .where(
      (c) =>
          c.estado == EstadoCuenta.activa &&
          c.clase == ClaseCuenta.activo,
    )
    .toList()
  ..sort((a, b) {
    final t = (a.tipo.liquida ? 0 : 1).compareTo(b.tipo.liquida ? 0 : 1);
    return t != 0 ? t : a.nombre.compareTo(b.nombre);
  });

SugerenciasGasto sugerenciasDeGasto(
  DatosFinanzas d, {
  required String libroId,
  required String personaId,
  required Fecha hoy,
}) {
  final cuentas = cuentasParaPagar(d, libroId);
  final idsCuentas = {for (final c in cuentas) c.id};
  final desde = hoy.sumarDias(-60);
  final gastos = d.movimientos
      .where(
        (m) =>
            m.tipo == TipoMovimiento.gasto &&
            idsCuentas.contains(m.cuentaOrigenId),
      )
      .toList()
    ..sort((a, b) => b.registradoEn.compareTo(a.registradoEn));
  final mios = gastos.where((m) => m.registradoPor == personaId);
  final ultimo = mios.firstOrNull ?? gastos.firstOrNull;
  final usables = {
    for (final c in d.categorias)
      if (c.visible) c.id: c,
  };
  final cuenta = <String, int>{};
  for (final m in gastos) {
    final cat = m.categoriaId;
    if (cat == null || !usables.containsKey(cat)) continue;
    if (m.fecha.antesDe(desde)) continue;
    cuenta[cat] = (cuenta[cat] ?? 0) + 1;
  }
  final ordenadas = cuenta.keys.toList()
    ..sort((a, b) {
      final c = cuenta[b]!.compareTo(cuenta[a]!);
      return c != 0 ? c : usables[a]!.nombre.compareTo(usables[b]!.nombre);
    });
  final ultimaCategoria = ultimo?.categoriaId != null &&
          usables.containsKey(ultimo!.categoriaId)
      ? ultimo.categoriaId
      : null;
  final elegidas = <String>[
    ?ultimaCategoria,
    for (final id in ordenadas)
      if (id != ultimaCategoria) id,
  ];
  // Si no hay historial suficiente: subcategorías de los sobres del libro y
  // luego las de nivel 2 más comunes de la plantilla.
  if (elegidas.length < 6) {
    final sobres = {for (final s in d.sobresDe(libroId)) s.cuentaGastoId};
    final relleno = [
      for (final c in d.categorias)
        if (c.visible &&
            c.nivel == 2 &&
            sobres.contains(d.arbol.cuentaGastoDe(c.id)))
          c.id,
      for (final c in d.categorias)
        if (c.visible && c.nivel == 2) c.id,
    ];
    for (final id in relleno) {
      if (elegidas.length >= 6) break;
      if (!elegidas.contains(id)) elegidas.add(id);
    }
  }
  final ultimaCuenta =
      ultimo != null && idsCuentas.contains(ultimo.cuentaOrigenId)
      ? ultimo.cuentaOrigenId
      : cuentas.firstOrNull?.id;
  return SugerenciasGasto(
    ultimaCategoriaId: ultimaCategoria,
    ultimaCuentaId: ultimaCuenta,
    categorias: [for (final id in elegidas.take(6)) usables[id]!],
    cuentas: cuentas,
  );
}

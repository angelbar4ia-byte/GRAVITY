/// Reglas de Alimentación (D23): quién ve y quién edita cada menú.
library;

import '../../../nucleo/contratos/roles.dart';
import '../datos/lector_codigo.dart';
import '../datos/modelos.dart';
import '../datos/perfiles.dart';
import '../datos/repositorio.dart';
import 'importar_recetas.dart';
import 'lista_compras.dart';

export '../datos/modelos.dart' show ComidaDelDia;

/// "¿Hay presupuesto para comprar?": dueño, pareja y familiar. La cuidadora
/// no, ni la cuenta maestra, ni Casa. Solo sí o no, nunca cifras.
bool puedeVerHayPresupuesto(Rol rol, {bool esMaestra = false}) =>
    !esMaestra &&
    (rol == Rol.dueno || rol == Rol.coadministrador || rol == Rol.familiar);

class PermisoDenegado implements Exception {
  const PermisoDenegado();
  @override
  String toString() => 'Tu rol no tiene permiso para esto en Alimentación.';
}

bool _duenos(Rol r) => r == Rol.dueno || r == Rol.coadministrador;

/// Dueño y pareja editan los dos menús, sus suplementos y marcan "comprado".
/// La cuenta maestra (D19) solo lee.
bool puedeEditarAlimentacion(Rol rol, {bool esMaestra = false}) =>
    !esMaestra && _duenos(rol);

/// Quién cambia los platillos de [menu]: dueño y pareja en los dos; el
/// familiar solo en el de Papá (ajuste del 6/nov). La cuidadora solo lee.
bool puedeEditarMenu(Rol rol, MenuId menu, {bool esMaestra = false}) =>
    puedeEditarAlimentacion(rol, esMaestra: esMaestra) ||
    (!esMaestra && rol == Rol.familiar && menu == MenuId.papa);

/// Menú de Papá: dueño, pareja, cuidador y familiar (y la maestra, solo
/// lectura). Menú de la pareja: dueño, pareja y la maestra. La cuenta Casa
/// (tablet pública) no ve ninguno: el menú de Papá lleva su perfil clínico.
bool puedeVerMenu(Rol rol, MenuId menu, {bool esMaestra = false}) {
  if (_duenos(rol) || esMaestra) return true;
  return menu == MenuId.papa && (rol == Rol.familiar || rol == Rol.cuidador);
}

/// Lista de compras: como el menú, pero el familiar no ve la de Papá (propuesta
/// pendiente de confirmar con el dueño).
bool puedeVerCompras(Rol rol, MenuId menu, {bool esMaestra = false}) =>
    puedeVerMenu(rol, menu, esMaestra: esMaestra) &&
    !(rol == Rol.familiar && !esMaestra);

/// Cuenta de compra por omisión según el rol de quien compra (no hay reglas
/// nuevas: la pareja compra de la suya, el dueño de la suya, Casa de la casa y
/// el resto de lo de Papá). Quien compra puede elegir otra.
CuentaCompra cuentaPorOmision(Rol rol, MenuId menu) {
  if (menu == MenuId.papa) return CuentaCompra.papa;
  return switch (rol) {
    Rol.coadministrador => CuentaCompra.pareja,
    Rol.casa => CuentaCompra.casa,
    _ => CuentaCompra.dueno,
  };
}

/// Lo que devuelve [ServicioAlimentacion.registrarCompra].
class RegistroCompra {
  const RegistroCompra({this.alerta, this.pendienteAlbacea = false});
  final AlertaPrecio? alerta;

  /// Compra de Papá sin cuenta de pago: queda la solicitud al albacea.
  final bool pendienteAlbacea;
}

class ServicioAlimentacion {
  ServicioAlimentacion(
    this._repo, {
    required this.rol,
    this.esMaestra = false,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;
  final DateTime Function() _ahora;
  final RepositorioAlimentacion _repo;
  final Rol rol;
  final bool esMaestra;

  bool get puedeVerPresupuesto =>
      puedeVerHayPresupuesto(rol, esMaestra: esMaestra);

  /// Sí o no (sin saldos, cuentas ni montos). `null` = sin respuesta aún.
  /// Con [montoCentavos] pregunta por ese monto (el total de la lista).
  Future<bool?> hayPresupuesto({int? montoCentavos}) async {
    if (!puedeVerPresupuesto) throw const PermisoDenegado();
    return montoCentavos == null
        ? _repo.hayPresupuesto()
        : _repo.hayPresupuestoPara(montoCentavos);
  }

  bool get puedeEditar => puedeEditarAlimentacion(rol, esMaestra: esMaestra);
  List<MenuId> get menusVisibles => [
    for (final m in MenuId.values)
      if (puedeVerMenu(rol, m, esMaestra: esMaestra)) m,
  ];
  List<MenuId> get menusConCompras => [
    for (final m in MenuId.values)
      if (puedeVerCompras(rol, m, esMaestra: esMaestra)) m,
  ];

  bool puedeEditarMenuDe(MenuId m) =>
      puedeEditarMenu(rol, m, esMaestra: esMaestra);

  void _exigirEdicion() {
    if (!puedeEditar) throw const PermisoDenegado();
  }

  void _exigirVer(MenuId m) {
    if (!puedeVerMenu(rol, m, esMaestra: esMaestra)) {
      throw const PermisoDenegado();
    }
  }

  PerfilMenu perfil(MenuId m) {
    _exigirVer(m);
    return perfilDe(m);
  }

  /// El catálogo se lee con permiso de lectura de algún menú (Casa no lo lee).
  Future<List<Platillo>> platillos() async {
    if (menusVisibles.isEmpty) {
      throw const PermisoDenegado();
    }
    return _repo.platillos();
  }

  Future<List<EntradaMenu>> menu(MenuId m, DateTime semana) async {
    _exigirVer(m);
    return _repo.menu(m, lunesDe(semana));
  }

  /// Devuelve el platillo anterior de la celda (para deshacer).
  Future<String?> asignar(
    MenuId m,
    DateTime semana,
    int dia,
    TiempoComida t,
    String? platilloId,
  ) async {
    if (!puedeEditarMenuDe(m)) throw const PermisoDenegado();
    final lunes = lunesDe(semana);
    final antes = (await _repo.menu(m, lunes))
        .where((e) => e.dia == dia && e.tiempo == t)
        .map((e) => e.platilloId)
        .firstOrNull;
    await _repo.asignar(m, lunes, dia, t, platilloId);
    return antes;
  }

  Future<List<ItemCompra>> listaCompras(MenuId m, DateTime semana) async {
    if (!puedeVerCompras(rol, m, esMaestra: esMaestra)) {
      throw const PermisoDenegado();
    }
    final lunes = lunesDe(semana);
    final precios = await _repo.precios();
    final delServidor = await _repo.comprasLista(m, lunes);
    final marcados = {
      ...await _repo.comprados(m, lunes),
      for (final c in delServidor)
        if (c.comprada) c.clave,
    };
    final items = generarListaCompras(
      menu: await _repo.menu(m, lunes),
      platillos: await _repo.platillos(),
      comprados: marcados,
      precios: precios,
    );
    // Lo que está en `ali_compras` y el menú no trae (solicitudes) se suma.
    final claves = {for (final i in items) i.clave};
    final extra = <String, CompraLista>{};
    for (final c in delServidor) {
      if (!claves.contains(c.clave)) extra[c.clave] = c;
    }
    if (extra.isEmpty) return items;
    return [
      ...items,
      for (final c in extra.values)
        ItemCompra(
          nombre: c.nombre,
          cantidad: c.cantidad,
          unidad: c.unidad,
          seccion: c.seccion,
          comprado: c.comprada,
          precio: precios[c.clave],
          pendienteAlbacea: c.pendienteAlbacea,
        ),
    ]..sort((a, b) {
        final x = a.seccion.index.compareTo(b.seccion.index);
        return x != 0
            ? x
            : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
  }

  /// Guarda las recetas de una importación ya validada y revisada (dueño y
  /// pareja). Reemplaza por id las que ya existían.
  Future<int> importarRecetas(ResultadoImportacion r) async {
    _exigirEdicion();
    if (!r.valido) throw ArgumentError('La importación tiene errores.');
    await _repo.guardarPlatillos([for (final x in r.recetas) x.platillo]);
    return r.recetas.length;
  }

  /// Registra una compra real con precio: el precio pagado reemplaza al base
  /// (o al de la compra anterior) y el renglón queda comprado.
  ///
  /// Devuelve la alerta de precio si el precio unitario quedó más de 20% arriba
  /// de la última compra **real** del ingrediente (nunca contra el precio base).
  ///
  /// Con servidor, el precio real, la fila de la compra y el movimiento los
  /// escribe `ali_marcar_comprada`; la app no toca tablas de dinero. [cuenta]:
  /// quien compra la elige; por omisión sale de su rol.
  Future<RegistroCompra> registrarCompra(
    MenuId m,
    DateTime semana,
    String clave, {
    required double cantidadComprada,
    required int totalCentavos,
    String? nombre,
    String? unidad,
    CuentaCompra? cuenta,
  }) async {
    _exigirEdicion();
    if (!puedeVerCompras(rol, m, esMaestra: esMaestra)) {
      throw const PermisoDenegado();
    }
    // Valida primero (ArgumentError) antes de armar la compra del historial.
    final precio = precioDeCompra(
      clave: clave,
      totalCentavos: totalCentavos,
      cantidadComprada: cantidadComprada,
    );
    final partes = clave.split('|');
    final compra = CompraPrecio(
      clave: clave,
      nombre: nombre ?? partes.first,
      unidad: unidad ?? (partes.length > 1 ? partes.last : ''),
      totalCentavos: totalCentavos,
      cantidad: cantidadComprada,
      fecha: _ahora(),
    );
    final previas = historialDe(await _repo.historialCompras(), clave);
    final alerta = calcularAlerta(previas.isEmpty ? null : previas.first, compra);
    final r = await _repo.registrarCompraReal(
      menu: m,
      lunes: lunesDe(semana),
      compra: compra,
      precio: precio,
      cuenta: cuenta ?? cuentaPorOmision(rol, m),
    );
    return RegistroCompra(
      alerta: alerta,
      pendienteAlbacea: r.pendienteAlbacea,
    );
  }

  /// Compras reales de un ingrediente, de la más reciente a la más antigua.
  Future<List<CompraPrecio>> historialPrecios(String clave) async =>
      historialDe(await _repo.historialCompras(), clave);

  /// Ingredientes con compras reales, con sus compras (para el historial).
  Future<Map<String, List<CompraPrecio>>> historialPorIngrediente() async {
    final r = <String, List<CompraPrecio>>{};
    for (final c in await _repo.historialCompras()) {
      (r[c.clave] ??= []).add(c);
    }
    for (final l in r.values) {
      l.sort((a, b) => b.fecha.compareTo(a.fecha));
    }
    return r;
  }

  /// Catálogo local con código de barras: ingredientes de los platillos y los
  /// capturados a mano.
  Future<List<Ingrediente>> catalogoConCodigo() async => [
    for (final p in await _repo.platillos())
      for (final i in p.ingredientes)
        if (i.codigoBarras != null) i,
    ...await _repo.ingredientesConCodigo(),
  ];

  /// Busca [codigo] en el catálogo local; `null` = pedir captura a mano.
  Future<Ingrediente?> buscarPorCodigoBarras(String codigo) async =>
      buscarPorCodigo(await catalogoConCodigo(), codigo);

  /// Captura a mano un ingrediente nuevo con su código y lo guarda en el
  /// catálogo local.
  Future<Ingrediente> guardarIngredienteConCodigo({
    required String codigo,
    required String nombre,
    required String unidad,
    SeccionCompra seccion = SeccionCompra.otros,
  }) async => (await guardarConCodigo(
    codigo: codigo,
    nombre: nombre,
    unidad: unidad,
    seccion: seccion,
  )).ingrediente;

  /// Como [guardarIngredienteConCodigo], y dice si el servidor ya lo guardó
  /// (`enServidor`) o solo quedó en la memoria de la sesión.
  Future<({Ingrediente ingrediente, bool enServidor})> guardarConCodigo({
    required String codigo,
    required String nombre,
    required String unidad,
    SeccionCompra seccion = SeccionCompra.otros,
  }) async {
    _exigirEdicion();
    final c = codigo.trim();
    if (c.isEmpty || nombre.trim().isEmpty || unidad.trim().isEmpty) {
      throw ArgumentError('Falta el código, el nombre o la unidad.');
    }
    final i = Ingrediente(nombre.trim(), 1, unidad.trim(), seccion, codigoBarras: c);
    final enServidor = await _repo.guardarIngredienteConCodigo(i);
    return (ingrediente: i, enServidor: enServidor);
  }

  /// Menú del día de Papá. Lo ve quien ve el menú de Papá y la cuenta Casa
  /// (D28), y solo con los nombres de los platillos del día.
  Future<List<ComidaDelDia>> menuDelDiaPapa(DateTime hoy) async {
    final puede =
        rol == Rol.casa || puedeVerMenu(rol, MenuId.papa, esMaestra: esMaestra);
    if (!puede) throw const PermisoDenegado();
    return _repo.menuDelDiaPapa(hoy);
  }

  Future<void> marcar(
    MenuId m,
    DateTime semana,
    String clave,
    bool comprado,
  ) async {
    _exigirEdicion();
    await _repo.marcar(m, lunesDe(semana), clave, comprado);
  }

  Future<List<Suplemento>> suplementos(MenuId m) async {
    _exigirVer(m);
    return _repo.suplementos(m);
  }

  Future<void> guardarSuplemento(MenuId m, Suplemento s) async {
    _exigirEdicion();
    await _repo.guardarSuplemento(m, s);
  }

  Future<void> quitarSuplemento(MenuId m, String id) async {
    _exigirEdicion();
    await _repo.quitarSuplemento(m, id);
  }
}

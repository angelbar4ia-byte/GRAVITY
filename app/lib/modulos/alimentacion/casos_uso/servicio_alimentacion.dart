/// Reglas de Alimentación (D23): quién ve y quién edita cada menú.
library;

import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../datos/perfiles.dart';
import '../datos/repositorio.dart';
import 'importar_recetas.dart';
import 'lista_compras.dart';

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

/// Una comida del día de Papá para la cuenta Casa (D28): solo el nombre del
/// platillo. Sin perfil clínico, sin suplementos, sin alimentos duros.
class ComidaDelDia {
  const ComidaDelDia(this.tiempo, this.platillo);
  final TiempoComida tiempo;
  final String platillo;
}

class ServicioAlimentacion {
  ServicioAlimentacion(this._repo, {required this.rol, this.esMaestra = false});
  final RepositorioAlimentacion _repo;
  final Rol rol;
  final bool esMaestra;

  bool get puedeVerPresupuesto =>
      puedeVerHayPresupuesto(rol, esMaestra: esMaestra);

  /// Sí o no (sin saldos, cuentas ni montos). `null` = sin respuesta aún.
  Future<bool?> hayPresupuesto() async {
    if (!puedeVerPresupuesto) throw const PermisoDenegado();
    return _repo.hayPresupuesto();
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
    return generarListaCompras(
      menu: await _repo.menu(m, lunes),
      platillos: await _repo.platillos(),
      comprados: await _repo.comprados(m, lunes),
      precios: await _repo.precios(),
    );
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
  Future<void> registrarCompra(
    MenuId m,
    DateTime semana,
    String clave, {
    required double cantidadComprada,
    required int totalCentavos,
  }) async {
    _exigirEdicion();
    if (!puedeVerCompras(rol, m, esMaestra: esMaestra)) {
      throw const PermisoDenegado();
    }
    await _repo.guardarPrecio(
      precioDeCompra(
        clave: clave,
        totalCentavos: totalCentavos,
        cantidadComprada: cantidadComprada,
      ),
    );
    await _repo.marcar(m, lunesDe(semana), clave, true);
  }

  /// Menú del día de Papá. Lo ve quien ve el menú de Papá y la cuenta Casa
  /// (D28), y solo con los nombres de los platillos del día.
  Future<List<ComidaDelDia>> menuDelDiaPapa(DateTime hoy) async {
    final puede =
        rol == Rol.casa || puedeVerMenu(rol, MenuId.papa, esMaestra: esMaestra);
    if (!puede) throw const PermisoDenegado();
    final dia = hoy.weekday - DateTime.monday;
    final entradas = (await _repo.menu(MenuId.papa, lunesDe(hoy)))
        .where((e) => e.dia == dia)
        .toList()
      ..sort((a, b) => a.tiempo.index.compareTo(b.tiempo.index));
    final nombres = {for (final p in await _repo.platillos()) p.id: p.nombre};
    return [
      for (final e in entradas)
        if (nombres[e.platilloId] != null)
          ComidaDelDia(e.tiempo, nombres[e.platilloId]!),
    ];
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

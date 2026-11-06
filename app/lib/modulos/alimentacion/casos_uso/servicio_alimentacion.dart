/// Reglas de Alimentación (D23): quién ve y quién edita cada menú.
library;

import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../datos/perfiles.dart';
import '../datos/repositorio.dart';
import 'lista_compras.dart';

class PermisoDenegado implements Exception {
  const PermisoDenegado();
  @override
  String toString() => 'Tu rol no tiene permiso para esto en Alimentación.';
}

bool _duenos(Rol r) => r == Rol.dueno || r == Rol.coadministrador;

/// Dueño y pareja editan los dos menús y marcan "comprado". La cuenta
/// maestra (D19) solo lee. Nadie más edita.
bool puedeEditarAlimentacion(Rol rol, {bool esMaestra = false}) => !esMaestra && _duenos(rol);

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
    puedeVerMenu(rol, menu, esMaestra: esMaestra) && !(rol == Rol.familiar && !esMaestra);

class ServicioAlimentacion {
  ServicioAlimentacion(this._repo, {required this.rol, this.esMaestra = false});
  final RepositorioAlimentacion _repo;
  final Rol rol;
  final bool esMaestra;

  bool get puedeEditar => puedeEditarAlimentacion(rol, esMaestra: esMaestra);
  List<MenuId> get menusVisibles =>
      [for (final m in MenuId.values) if (puedeVerMenu(rol, m, esMaestra: esMaestra)) m];
  List<MenuId> get menusConCompras =>
      [for (final m in MenuId.values) if (puedeVerCompras(rol, m, esMaestra: esMaestra)) m];

  void _exigirEdicion() {
    if (!puedeEditar) throw const PermisoDenegado();
  }

  void _exigirVer(MenuId m) {
    if (!puedeVerMenu(rol, m, esMaestra: esMaestra)) throw const PermisoDenegado();
  }

  PerfilMenu perfil(MenuId m) {
    _exigirVer(m);
    return perfilDe(m);
  }

  Future<List<Platillo>> platillos() => _repo.platillos();

  Future<List<EntradaMenu>> menu(MenuId m, DateTime semana) async {
    _exigirVer(m);
    return _repo.menu(m, lunesDe(semana));
  }

  /// Devuelve el platillo anterior de la celda (para deshacer).
  Future<String?> asignar(
      MenuId m, DateTime semana, int dia, TiempoComida t, String? platilloId) async {
    _exigirEdicion();
    _exigirVer(m);
    final lunes = lunesDe(semana);
    final antes = (await _repo.menu(m, lunes))
        .where((e) => e.dia == dia && e.tiempo == t)
        .map((e) => e.platilloId)
        .firstOrNull;
    await _repo.asignar(m, lunes, dia, t, platilloId);
    return antes;
  }

  Future<List<ItemCompra>> listaCompras(MenuId m, DateTime semana) async {
    if (!puedeVerCompras(rol, m, esMaestra: esMaestra)) throw const PermisoDenegado();
    final lunes = lunesDe(semana);
    return generarListaCompras(
      menu: await _repo.menu(m, lunes),
      platillos: await _repo.platillos(),
      comprados: await _repo.comprados(m, lunes),
    );
  }

  Future<void> marcar(MenuId m, DateTime semana, String clave, bool comprado) async {
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

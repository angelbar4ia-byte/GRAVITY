/// Reglas de Alimentación: permisos de escritura y vistas del menú.
library;

import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/permisos/permisos.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import 'lista_compras.dart';

class PermisoDenegado implements Exception {
  const PermisoDenegado();
  @override
  String toString() => 'Solo lectura: tu rol no puede editar Alimentación.';
}

/// `true` si [rol] edita el menú. La cuenta maestra (D19) solo lee.
bool puedeEditarAlimentacion(Rol rol, {bool esMaestra = false}) =>
    !esMaestra && puede(rol, Modulo.alimentacion, Accion.escribir);

class ServicioAlimentacion {
  ServicioAlimentacion(this._repo, {required this.puedeEditar});
  final RepositorioAlimentacion _repo;
  final bool puedeEditar;

  void _exigirEdicion() {
    if (!puedeEditar) throw const PermisoDenegado();
  }

  Future<List<Platillo>> platillos() => _repo.platillos();
  Future<List<EntradaMenu>> menu(DateTime lunes) => _repo.menu(lunesDe(lunes));

  /// Devuelve el platillo anterior de la celda (para deshacer).
  Future<String?> asignar(
    DateTime semana,
    int dia,
    TiempoComida t,
    String? platilloId,
  ) async {
    _exigirEdicion();
    final lunes = lunesDe(semana);
    final antes = (await _repo.menu(lunes))
        .where((e) => e.dia == dia && e.tiempo == t)
        .map((e) => e.platilloId)
        .firstOrNull;
    await _repo.asignar(lunes, dia, t, platilloId);
    return antes;
  }

  Future<List<ItemCompra>> listaCompras(DateTime semana) async {
    final lunes = lunesDe(semana);
    return generarListaCompras(
      menu: await _repo.menu(lunes),
      platillos: await _repo.platillos(),
      comprados: await _repo.comprados(lunes),
    );
  }

  Future<void> marcar(DateTime semana, String clave, bool comprado) async {
    _exigirEdicion();
    await _repo.marcar(lunesDe(semana), clave, comprado);
  }
}

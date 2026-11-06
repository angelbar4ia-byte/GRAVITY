/// Repositorio de Alimentación. Hoy solo en memoria: el contrato para el
/// servidor está en `docs/specs/fase-4-alimentacion.md`, sección 6.
library;

import 'ejemplo.dart';
import 'modelos.dart';

abstract interface class RepositorioAlimentacion {
  Future<List<Platillo>> platillos();

  /// Menú [menu] de la semana que empieza en [lunes].
  Future<List<EntradaMenu>> menu(MenuId menu, DateTime lunes);

  /// Asigna [platilloId] a la celda; `null` la vacía.
  Future<void> asignar(
    MenuId menu,
    DateTime lunes,
    int dia,
    TiempoComida tiempo,
    String? platilloId,
  );

  /// Claves (`claveCompra`) comprados en la semana.
  Future<Set<String>> comprados(MenuId menu, DateTime lunes);
  Future<void> marcar(MenuId menu, DateTime lunes, String clave, bool comprado);

  Future<List<Suplemento>> suplementos(MenuId menu);
  Future<void> guardarSuplemento(MenuId menu, Suplemento s);
  Future<void> quitarSuplemento(MenuId menu, String id);
}

String _k(MenuId m, DateTime lunes) =>
    '${m.name}|${lunes.year}-${lunes.month}-${lunes.day}';

class RepositorioAlimentacionEnMemoria implements RepositorioAlimentacion {
  /// [semanaEjemplo]: llena esa semana con el menú inventado de ambos menús.
  RepositorioAlimentacionEnMemoria({
    DateTime? semanaEjemplo,
    bool conEjemplo = true,
  }) {
    for (final m in MenuId.values) {
      _supl[m] = conEjemplo ? [...suplementosEjemplo(m)] : [];
      if (conEjemplo && semanaEjemplo != null) {
        for (final e in menuEjemplo(m)) {
          _menu.putIfAbsent(
            _k(m, lunesDe(semanaEjemplo)),
            () => {},
          )[(e.dia, e.tiempo)] = e.platilloId;
        }
      }
    }
  }

  final Map<String, Map<(int, TiempoComida), String>> _menu = {};
  final Map<String, Set<String>> _comprados = {};
  final Map<MenuId, List<Suplemento>> _supl = {};

  @override
  Future<List<Platillo>> platillos() async => platillosEjemplo;

  @override
  Future<List<EntradaMenu>> menu(MenuId menu, DateTime lunes) async => [
    for (final e in (_menu[_k(menu, lunes)] ?? const {}).entries)
      EntradaMenu(dia: e.key.$1, tiempo: e.key.$2, platilloId: e.value),
  ];

  @override
  Future<void> asignar(
    MenuId menu,
    DateTime lunes,
    int dia,
    TiempoComida tiempo,
    String? platilloId,
  ) async {
    final m = _menu.putIfAbsent(_k(menu, lunes), () => {});
    if (platilloId == null) {
      m.remove((dia, tiempo));
    } else {
      m[(dia, tiempo)] = platilloId;
    }
  }

  @override
  Future<Set<String>> comprados(MenuId menu, DateTime lunes) async => {
    ...?_comprados[_k(menu, lunes)],
  };

  @override
  Future<void> marcar(
    MenuId menu,
    DateTime lunes,
    String clave,
    bool comprado,
  ) async {
    final s = _comprados.putIfAbsent(_k(menu, lunes), () => {});
    comprado ? s.add(clave) : s.remove(clave);
  }

  @override
  Future<List<Suplemento>> suplementos(MenuId menu) async => [..._supl[menu]!];

  @override
  Future<void> guardarSuplemento(MenuId menu, Suplemento s) async {
    final l = _supl[menu]!;
    final i = l.indexWhere((x) => x.id == s.id);
    i < 0 ? l.add(s) : l[i] = s;
  }

  @override
  Future<void> quitarSuplemento(MenuId menu, String id) async =>
      _supl[menu]!.removeWhere((x) => x.id == id);
}

/// Repositorio de Alimentación. Hoy solo en memoria: el contrato para el
/// servidor está en `docs/specs/fase-4-alimentacion.md`, sección 6.
library;

import 'ejemplo.dart';
import 'modelos.dart';

abstract interface class RepositorioAlimentacion {
  Future<List<Platillo>> platillos();

  /// Menú de la semana que empieza en [lunes].
  Future<List<EntradaMenu>> menu(DateTime lunes);

  /// Asigna [platilloId] a la celda; `null` la vacía.
  Future<void> asignar(
    DateTime lunes,
    int dia,
    TiempoComida tiempo,
    String? platilloId,
  );

  /// Claves (`claveCompra`) comprados en la semana.
  Future<Set<String>> comprados(DateTime lunes);
  Future<void> marcar(DateTime lunes, String clave, bool comprado);
}

String _k(DateTime lunes) => '${lunes.year}-${lunes.month}-${lunes.day}';

class RepositorioAlimentacionEnMemoria implements RepositorioAlimentacion {
  /// [conEjemplo]: llena la semana de [semanaEjemplo] con el menú inventado.
  RepositorioAlimentacionEnMemoria({
    DateTime? semanaEjemplo,
    bool conEjemplo = true,
  }) {
    if (conEjemplo && semanaEjemplo != null) {
      for (final e in menuEjemplo()) {
        _menu.putIfAbsent(
          _k(lunesDe(semanaEjemplo)),
          () => {},
        )[(e.dia, e.tiempo)] = e.platilloId;
      }
    }
  }

  final Map<String, Map<(int, TiempoComida), String>> _menu = {};
  final Map<String, Set<String>> _comprados = {};

  @override
  Future<List<Platillo>> platillos() async => platillosEjemplo;

  @override
  Future<List<EntradaMenu>> menu(DateTime lunes) async => [
    for (final e in (_menu[_k(lunes)] ?? const {}).entries)
      EntradaMenu(dia: e.key.$1, tiempo: e.key.$2, platilloId: e.value),
  ];

  @override
  Future<void> asignar(
    DateTime lunes,
    int dia,
    TiempoComida tiempo,
    String? platilloId,
  ) async {
    final m = _menu.putIfAbsent(_k(lunes), () => {});
    if (platilloId == null) {
      m.remove((dia, tiempo));
    } else {
      m[(dia, tiempo)] = platilloId;
    }
  }

  @override
  Future<Set<String>> comprados(DateTime lunes) async => {
    ...?_comprados[_k(lunes)],
  };

  @override
  Future<void> marcar(DateTime lunes, String clave, bool comprado) async {
    final s = _comprados.putIfAbsent(_k(lunes), () => {});
    comprado ? s.add(clave) : s.remove(clave);
  }
}

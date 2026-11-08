/// Repositorio de Alimentación. Hoy solo en memoria: el contrato para el
/// servidor está en `docs/specs/fase-4-alimentacion.md`, sección 6.
library;

import 'dart:math' show Random;

import 'ejemplo.dart';
import 'modelos.dart';
import 'votacion.dart';

abstract interface class RepositorioAlimentacion {
  Future<List<Platillo>> platillos();

  /// Agrega o reemplaza (por id) platillos con receta: los importados.
  Future<void> guardarPlatillos(List<Platillo> platillos);

  /// Precio vigente por ingrediente, por `claveCompra`. Falta la clave = sin
  /// precio (no se calcula costo).
  Future<Map<String, PrecioIngrediente>> precios();

  /// Guarda el precio de un ingrediente (base o real). Una compra real
  /// reemplaza al base y las siguientes lo actualizan.
  Future<void> guardarPrecio(PrecioIngrediente precio);

  /// Votación del plan familiar de [dia] (sin hora), si existe.
  Future<VotacionPlan?> votacion(DateTime dia);
  Future<void> guardarVotacion(VotacionPlan votacion);

  /// Pide al servidor cerrar las votaciones vencidas (`ali_cerrar_votaciones`).
  /// Con empate, el servidor decide por volado; la app no decide.
  Future<void> cerrarVotacionesVencidas(DateTime ahora);

  /// "¿Hay presupuesto para comprar?" (`ali_hay_presupuesto`): solo sí o no,
  /// sin saldos, cuentas ni montos. `null` = el servidor no responde todavía.
  Future<bool?> hayPresupuesto();

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

/// Nombres de tabla que el servidor debe tener para esta fase (migración
/// 20261126 de backend). `ali_platillos` y `ali_compras_marcas` ya existen; a
/// `ali_platillos` se le agregan `pasos text[]` y `porciones smallint`.
abstract final class TablasAlimentacion {
  static const platillos = 'ali_platillos';
  static const precios = 'ali_precios';
  static const votaciones = 'ali_votaciones';
  static const propuestas = 'ali_propuestas';
  static const votos = 'ali_votos';
}

String _k(MenuId m, DateTime lunes) =>
    '${m.name}|${lunes.year}-${lunes.month}-${lunes.day}';

class RepositorioAlimentacionEnMemoria implements RepositorioAlimentacion {
  /// [semanaEjemplo]: llena esa semana con el menú inventado de ambos menús.
  RepositorioAlimentacionEnMemoria({
    DateTime? semanaEjemplo,
    bool conEjemplo = true,
    this.hayPresupuestoSupuesto = true,
    bool Function()? volado,
  }) : _volado = volado ?? (() => Random().nextBool()) {
    if (conEjemplo) {
      for (final p in preciosBaseEjemplo()) {
        _precios[p.clave] = p;
      }
    }
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
  final List<Platillo> _platillos = [...platillosEjemplo];
  final Map<String, PrecioIngrediente> _precios = {};
  final Map<String, VotacionPlan> _votaciones = {};

  /// Supuesto de la demostración: sí o no, sin cifras.
  bool hayPresupuestoSupuesto;

  /// Hace de servidor en memoria: el volado de `ali_cerrar_votaciones`.
  final bool Function() _volado;

  @override
  Future<bool?> hayPresupuesto() async => hayPresupuestoSupuesto;

  @override
  Future<void> cerrarVotacionesVencidas(DateTime ahora) async {
    for (final e in _votaciones.entries.toList()) {
      final v = e.value;
      if (v.propuestas.length == 2 &&
          !v.abierta(ahora) &&
          v.ganadoraVoladoId == null &&
          (v.votos.isEmpty || v.hayEmpate)) {
        _votaciones[e.key] =
            v.conVolado(v.propuestas[_volado() ? 0 : 1].id);
      }
    }
  }

  @override
  Future<List<Platillo>> platillos() async => [..._platillos];

  @override
  Future<void> guardarPlatillos(List<Platillo> platillos) async {
    for (final p in platillos) {
      final i = _platillos.indexWhere((x) => x.id == p.id);
      i < 0 ? _platillos.add(p) : _platillos[i] = p;
    }
  }

  @override
  Future<Map<String, PrecioIngrediente>> precios() async => {..._precios};

  @override
  Future<void> guardarPrecio(PrecioIngrediente precio) async =>
      _precios[precio.clave] = precio;

  String _kd(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Future<VotacionPlan?> votacion(DateTime dia) async => _votaciones[_kd(dia)];

  @override
  Future<void> guardarVotacion(VotacionPlan v) async =>
      _votaciones[_kd(v.dia)] = v;

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

/// Con sesión real y mientras el servidor no tenga las tablas de Alimentación
/// (spec, sección 6): nada de datos de ejemplo mostrados como si fueran del
/// hogar. Lectura vacía; escribir no está disponible todavía.
class RepositorioAlimentacionSinServidor implements RepositorioAlimentacion {
  const RepositorioAlimentacionSinServidor();

  static Never _no() =>
      throw UnsupportedError('Alimentación aún no tiene tablas en el servidor.');

  @override
  Future<List<Platillo>> platillos() async => const [];
  @override
  Future<void> guardarPlatillos(List<Platillo> platillos) async => _no();
  @override
  Future<Map<String, PrecioIngrediente>> precios() async => const {};
  @override
  Future<void> guardarPrecio(PrecioIngrediente precio) async => _no();
  @override
  Future<VotacionPlan?> votacion(DateTime dia) async => null;
  @override
  Future<void> cerrarVotacionesVencidas(DateTime ahora) async {}
  @override
  Future<bool?> hayPresupuesto() async => null;
  @override
  Future<void> guardarVotacion(VotacionPlan votacion) async => _no();
  @override
  Future<List<EntradaMenu>> menu(MenuId menu, DateTime lunes) async => const [];
  @override
  Future<void> asignar(MenuId menu, DateTime lunes, int dia, TiempoComida tiempo,
          String? platilloId) async =>
      _no();
  @override
  Future<Set<String>> comprados(MenuId menu, DateTime lunes) async => const {};
  @override
  Future<void> marcar(MenuId menu, DateTime lunes, String clave, bool comprado) async => _no();
  @override
  Future<List<Suplemento>> suplementos(MenuId menu) async => const [];
  @override
  Future<void> guardarSuplemento(MenuId menu, Suplemento s) async => _no();
  @override
  Future<void> quitarSuplemento(MenuId menu, String id) async => _no();
}

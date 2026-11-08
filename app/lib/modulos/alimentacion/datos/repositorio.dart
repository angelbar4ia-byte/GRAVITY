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

  /// Compras reales con precio (historial), de cualquier ingrediente.
  Future<List<CompraPrecio>> historialCompras();
  Future<void> guardarCompraPrecio(CompraPrecio compra);

  /// Ingredientes capturados a mano con su código de barras.
  Future<List<Ingrediente>> ingredientesConCodigo();

  /// Guarda un ingrediente con su código. Mientras el servidor no tenga la
  /// columna `codigo_barras`, queda solo en memoria de la sesión y devuelve
  /// `false`; con servidor devolverá `true`.
  Future<bool> guardarIngredienteConCodigo(Ingrediente ingrediente);

  /// Votación del plan familiar de [dia] (sin hora), si existe.
  Future<VotacionPlan?> votacion(DateTime dia);
  Future<void> guardarVotacion(VotacionPlan votacion);

  /// Pide al servidor cerrar las votaciones vencidas (`ali_cerrar_votaciones`).
  /// Con empate, el servidor decide por volado; la app no decide.
  Future<void> cerrarVotacionesVencidas(DateTime ahora);

  /// "¿Hay presupuesto para comprar?" (`ali_hay_presupuesto`): solo sí o no,
  /// sin saldos, cuentas ni montos. `null` = el servidor no responde todavía.
  Future<bool?> hayPresupuesto();

  /// Lo mismo para un monto (el total de la lista de la semana), en centavos.
  Future<bool?> hayPresupuestoPara(int montoCentavos);

  /// Menú del día de Papá para la cuenta Casa (`ali_menu_del_dia_papa`): solo
  /// nombres de platillo por tiempo.
  Future<List<ComidaDelDia>> menuDelDiaPapa(DateTime hoy);

  /// Compras de la semana que están en el servidor (`ali_compras`), además de
  /// lo que sale del menú. Vacío donde no hay servidor.
  Future<List<CompraLista>> comprasLista(MenuId menu, DateTime lunes);

  /// Registra una compra real con precio. En el servidor es
  /// `ali_marcar_comprada`: él escribe el precio real, la fila de la compra y
  /// el movimiento del libro correcto. La app no escribe dinero.
  Future<ResultadoCompra> registrarCompraReal({
    required MenuId menu,
    required DateTime lunes,
    required CompraPrecio compra,
    required PrecioIngrediente precio,
    required CuentaCompra cuenta,
    String? cuentaPagoId,
  });

  /// Cuentas de pago que se ofrecen para [cuenta] (la elegible de su libro
  /// personal o del libro de la casa), con la de omisión marcada. Papá: vacío
  /// (sin cuenta la compra va al albacea).
  Future<List<CuentaPago>> cuentasDePago(CuentaCompra cuenta);

  /// Agrega a la lista (`ali_agregar_a_lista`); nunca inserta en `ali_compras`.
  Future<void> agregarALista({
    required String nombre,
    required String unidad,
    required double cantidad,
  });

  /// El ingrediente del catálogo con ese nombre (sin importar mayúsculas), o
  /// `null`. La marca y la unidad no cuentan: no hay duplicados por nombre.
  Future<FichaIngrediente?> ingredientePorNombre(String nombre);

  /// Cambia unidad y presentación del MISMO ingrediente
  /// (`ali_editar_presentacion`); no crea otro.
  Future<FichaIngrediente> editarPresentacion({
    required String ingredienteId,
    required String unidad,
    required String presentacion,
  });

  /// `true` solo para el albacea vigente (no la suplente).
  Future<bool> esAlbacea();

  /// Compras de Papá pendientes de pago (solo las ve el albacea).
  Future<List<SolicitudPago>> solicitudesPendientes();

  /// Cuentas del libro de Papá para aprobar (solo nombres, sin saldos).
  Future<List<CuentaPago>> cuentasDelLibroDePapa();

  /// `ali_resolver_solicitud_pago`: aprueba con [cuentaPagoId] o rechaza con
  /// [motivo].
  Future<void> resolverSolicitud({
    required String solicitudId,
    required bool aprobar,
    String? cuentaPagoId,
    String? motivo,
  });

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

/// Nombres de tabla de Alimentación que existen en el servidor (migraciones
/// `20261126`, `20261127` y `20261128`). El precio vive en `ali_ingredientes`
/// y el historial en `ali_precios_historial`; no hay `ali_precios` ni
/// `ali_propuestas` (las propuestas son `ali_votacion_opciones`).
abstract final class TablasAlimentacion {
  static const platillos = 'ali_platillos';
  static const ingredientes = 'ali_ingredientes';
  static const preciosHistorial = 'ali_precios_historial';
  static const compras = 'ali_compras';
  static const votaciones = 'ali_votaciones';
  static const opciones = 'ali_votacion_opciones';
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
  final List<CompraPrecio> _historial = [];
  final Map<String, Ingrediente> _conCodigo = {};
  final Map<String, VotacionPlan> _votaciones = {};

  /// Supuesto de la demostración: sí o no, sin cifras.
  bool hayPresupuestoSupuesto;

  /// Hace de servidor en memoria: el volado de `ali_cerrar_votaciones`.
  final bool Function() _volado;


  final Map<String, FichaIngrediente> _fichas = {};
  final List<(String, double, String)> listaAgregada = [];

  @override
  Future<List<CuentaPago>> cuentasDePago(CuentaCompra cuenta) async =>
      cuenta == CuentaCompra.papa
      ? const []
      : [CuentaPago(id: 'cuenta-${cuenta.name}', nombre: 'Efectivo', porOmision: true)];

  @override
  Future<void> agregarALista({
    required String nombre,
    required String unidad,
    required double cantidad,
  }) async => listaAgregada.add((nombre, cantidad, unidad));

  @override
  Future<FichaIngrediente?> ingredientePorNombre(String nombre) async =>
      _fichas[nombre.trim().toLowerCase()];

  @override
  Future<FichaIngrediente> editarPresentacion({
    required String ingredienteId,
    required String unidad,
    required String presentacion,
  }) async {
    final e = _fichas.entries.where((x) => x.value.id == ingredienteId);
    if (e.isEmpty) throw StateError('El ingrediente no existe.');
    final f = FichaIngrediente(
      id: ingredienteId,
      nombre: e.first.value.nombre,
      unidad: unidad,
      presentacion: presentacion,
    );
    _fichas[e.first.key] = f;
    return f;
  }

  @override
  Future<bool> esAlbacea() async => false;
  @override
  Future<List<SolicitudPago>> solicitudesPendientes() async => const [];
  @override
  Future<List<CuentaPago>> cuentasDelLibroDePapa() async => const [];
  @override
  Future<void> resolverSolicitud({
    required String solicitudId,
    required bool aprobar,
    String? cuentaPagoId,
    String? motivo,
  }) async {}

  @override
  Future<bool?> hayPresupuesto() async => hayPresupuestoSupuesto;

  @override
  Future<bool?> hayPresupuestoPara(int montoCentavos) async =>
      hayPresupuestoSupuesto;

  @override
  Future<List<CompraLista>> comprasLista(MenuId menu, DateTime lunes) async =>
      const [];

  @override
  Future<List<ComidaDelDia>> menuDelDiaPapa(DateTime hoy) async {
    final dia = hoy.weekday - DateTime.monday;
    final entradas = (await menu(MenuId.papa, lunesDe(hoy)))
        .where((e) => e.dia == dia)
        .toList()
      ..sort((a, b) => a.tiempo.index.compareTo(b.tiempo.index));
    final nombres = {for (final p in _platillos) p.id: p.nombre};
    return [
      for (final e in entradas)
        if (nombres[e.platilloId] != null)
          ComidaDelDia(e.tiempo, nombres[e.platilloId]!),
    ];
  }

  /// Hace de servidor en memoria: precio real, historial y marca.
  @override
  Future<ResultadoCompra> registrarCompraReal({
    required MenuId menu,
    required DateTime lunes,
    required CompraPrecio compra,
    required PrecioIngrediente precio,
    required CuentaCompra cuenta,
    String? cuentaPagoId,
  }) async {
    _historial.add(compra);
    _precios[precio.clave] = precio;
    await marcar(menu, lunes, compra.clave, true);
    return const ResultadoCompra();
  }

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

  @override
  Future<List<CompraPrecio>> historialCompras() async => [..._historial];

  @override
  Future<void> guardarCompraPrecio(CompraPrecio compra) async =>
      _historial.add(compra);

  @override
  Future<List<Ingrediente>> ingredientesConCodigo() async =>
      [..._conCodigo.values];

  @override
  Future<bool> guardarIngredienteConCodigo(Ingrediente ingrediente) async {
    _conCodigo[ingrediente.clave] = ingrediente;
    _fichas[ingrediente.nombre.trim().toLowerCase()] = FichaIngrediente(
      id: 'ing-${ingrediente.nombre.trim().toLowerCase()}',
      nombre: ingrediente.nombre,
      unidad: ingrediente.unidad,
    );
    return true;
  }

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
  Future<List<CompraPrecio>> historialCompras() async => const [];
  @override
  Future<void> guardarCompraPrecio(CompraPrecio compra) async => _no();
  @override
  Future<List<Ingrediente>> ingredientesConCodigo() async => const [];
  @override
  Future<bool> guardarIngredienteConCodigo(Ingrediente ingrediente) async => _no();
  @override
  Future<VotacionPlan?> votacion(DateTime dia) async => null;
  @override
  Future<void> cerrarVotacionesVencidas(DateTime ahora) async {}
  @override
  Future<bool?> hayPresupuesto() async => null;
  @override
  Future<bool?> hayPresupuestoPara(int montoCentavos) async => null;
  @override
  Future<List<ComidaDelDia>> menuDelDiaPapa(DateTime hoy) async => const [];
  @override
  Future<List<CompraLista>> comprasLista(MenuId menu, DateTime lunes) async =>
      const [];
  @override
  Future<ResultadoCompra> registrarCompraReal({
    required MenuId menu,
    required DateTime lunes,
    required CompraPrecio compra,
    required PrecioIngrediente precio,
    required CuentaCompra cuenta,
    String? cuentaPagoId,
  }) async => _no();
  @override
  Future<List<CuentaPago>> cuentasDePago(CuentaCompra cuenta) async => const [];
  @override
  Future<void> agregarALista({
    required String nombre,
    required String unidad,
    required double cantidad,
  }) async => _no();
  @override
  Future<FichaIngrediente?> ingredientePorNombre(String nombre) async => null;
  @override
  Future<FichaIngrediente> editarPresentacion({
    required String ingredienteId,
    required String unidad,
    required String presentacion,
  }) async => _no();
  @override
  Future<bool> esAlbacea() async => false;
  @override
  Future<List<SolicitudPago>> solicitudesPendientes() async => const [];
  @override
  Future<List<CuentaPago>> cuentasDelLibroDePapa() async => const [];
  @override
  Future<void> resolverSolicitud({
    required String solicitudId,
    required bool aprobar,
    String? cuentaPagoId,
    String? motivo,
  }) async => _no();
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

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

  /// Tiendas del hogar (Fase 8), por nombre.
  Future<List<Tienda>> tiendas();

  /// Agrega una tienda a la lista del hogar (nombre 1 a 60). Si ya existe una
  /// con ese nombre (sin importar mayúsculas), devuelve la existente.
  Future<Tienda> agregarTienda(String nombre);

  /// Cambia el nombre de una tienda (`ali_editar_tienda`).
  Future<Tienda> editarTienda(String id, String nombre);

  /// Borra una tienda (`ali_borrar_tienda`). Si tiene compras, el servidor la
  /// desactiva en su lugar y responde `desactivada`.
  Future<ResultadoBorradoTienda> borrarTienda(String id);

  /// Regresa una compra marcada (`ali_regresar_compra`): vuelve a pendiente y
  /// la original queda en el historial como revertida. [motivo]: 3 o más
  /// caracteres. Devuelve `true` si se retiró una solicitud al albacea
  /// (compra de Papá aún sin pagar).
  Future<bool> regresarCompra({
    required MenuId menu,
    required DateTime lunes,
    required String clave,
    required String motivo,
  });

  /// Porciones recomendadas por persona del menú compartido de dueño y pareja
  /// (la semana de [lunes]). Vacío donde el servidor no responde.
  Future<List<PorcionPersona>> porcionesRecomendadas(DateTime lunes);

  /// Fija la porción recomendada de [cuenta] para [platilloId] en la semana de
  /// [lunes] (menú compartido de dueño y pareja). La otra persona conserva la
  /// suya. De 0.25 a 20.
  Future<void> fijarPorcion({
    required String platilloId,
    required DateTime lunes,
    required CuentaCompra cuenta,
    required double porciones,
  });

  /// Historial completo de compras reales de [cuenta] (Fase 8): con cantidad,
  /// total pagado y tienda. Nunca el precio base de supuesto.
  Future<List<CompraPrecio>> historialCompleto(CuentaCompra cuenta);

  /// Despensa de [cuenta] (solo la que tu rol puede leer; la RLS manda).
  Future<List<ItemDespensa>> despensa(CuentaCompra cuenta);

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

  /// Solicitudes de reembolso rechazadas de compras que hizo esta persona y que
  /// todavía puede reenviar una vez (v1.4).
  Future<List<SolicitudPago>> solicitudesRechazadasMias();

  /// Reenvía una vez la solicitud rechazada con [justificacion] (quien compró).
  Future<void> reenviarSolicitud({
    required String solicitudId,
    required String justificacion,
  });

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
  static const tiendas = 'ali_tiendas';
  static const despensa = 'ali_despensa';
  static const votaciones = 'ali_votaciones';
  static const opciones = 'ali_votacion_opciones';
  static const votos = 'ali_votos';
}

String _k(MenuId m, DateTime lunes) =>
    '${m.name}|${lunes.year}-${lunes.month}-${lunes.day}';

/// Un fallo de Alimentación en el servidor, con mensaje para mostrar.
class ErrorAlimentacionServidor implements Exception {
  const ErrorAlimentacionServidor(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

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
    if (conEjemplo) {
      // Despensa de demostración (inventada), para ver "qué puedo cocinar".
      for (final c in [CuentaCompra.dueno, CuentaCompra.pareja]) {
        despensaMemoria[c] = const [
          ItemDespensa(nombre: 'Huevo', unidad: 'pza', cantidad: 6),
          ItemDespensa(nombre: 'Frijoles de la olla', unidad: 'taza', cantidad: 2),
          ItemDespensa(nombre: 'Tortilla', unidad: 'pza', cantidad: 10),
          ItemDespensa(nombre: 'Avena', unidad: 'g', cantidad: 500),
          ItemDespensa(nombre: 'Leche', unidad: 'ml', cantidad: 1000),
        ];
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
  final List<(CuentaCompra?, CompraPrecio)> _historialCuentas = [];
  final List<Tienda> _tiendas = [];

  /// Porciones por persona (el servidor las calcula; las pruebas las llenan).
  final List<PorcionPersona> porcionesMemoria = [];

  /// Claves con solicitud al albacea sin resolver (pruebas).
  final Set<String> solicitudesPendientesMemoria = {};

  /// Compras regresadas en memoria: (clave, motivo).
  final List<(String, String)> regresadas = [];

  /// Despensa por cuenta (la demostración y las pruebas la llenan).
  final Map<CuentaCompra, List<ItemDespensa>> despensaMemoria = {};
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
      : [
          CuentaPago(
            id: 'cuenta-${cuenta.name}',
            nombre: 'Efectivo',
            porOmision: true,
          ),
        ];

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
  Future<List<SolicitudPago>> solicitudesRechazadasMias() async => const [];
  @override
  Future<void> reenviarSolicitud({
    required String solicitudId,
    required String justificacion,
  }) async {}
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
    final entradas =
        (await menu(
            MenuId.papa,
            lunesDe(hoy),
          )).where((e) => e.dia == dia).toList()
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
    _historialCuentas.add((cuenta, compra));
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
        _votaciones[e.key] = v.conVolado(v.propuestas[_volado() ? 0 : 1].id);
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
  Future<void> guardarCompraPrecio(CompraPrecio compra) async {
    _historial.add(compra);
    _historialCuentas.add((null, compra));
  }

  @override
  Future<List<Tienda>> tiendas() async => [..._tiendas]
    ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

  @override
  Future<Tienda> agregarTienda(String nombre) async {
    final n = nombre.trim();
    for (final t in _tiendas) {
      if (t.nombre.toLowerCase() == n.toLowerCase()) return t;
    }
    final t = Tienda(id: 'tienda-${_tiendas.length + 1}', nombre: n);
    _tiendas.add(t);
    return t;
  }

  @override
  Future<Tienda> editarTienda(String id, String nombre) async {
    final n = nombre.trim();
    final i = _tiendas.indexWhere((t) => t.id == id);
    if (i < 0) throw const ErrorAlimentacionServidor('La tienda no existe.');
    if (n.isEmpty || n.length > maxCaracteresTienda) {
      throw const ErrorAlimentacionServidor(
        'El nombre de la tienda lleva de 1 a $maxCaracteresTienda caracteres.',
      );
    }
    if (_tiendas.any(
      (t) => t.id != id && t.nombre.toLowerCase() == n.toLowerCase(),
    )) {
      throw const ErrorAlimentacionServidor('Ya hay una tienda con ese nombre.');
    }
    final nueva = Tienda(id: id, nombre: n, activa: _tiendas[i].activa);
    _tiendas[i] = nueva;
    // El historial conserva la tienda con su nombre nuevo.
    for (var k = 0; k < _historialCuentas.length; k++) {
      final (c, h) = _historialCuentas[k];
      if (h.tiendaId == id) {
        _historialCuentas[k] = (c, _conTienda(h, n));
      }
    }
    for (var k = 0; k < _historial.length; k++) {
      if (_historial[k].tiendaId == id) {
        _historial[k] = _conTienda(_historial[k], n);
      }
    }
    return nueva;
  }

  CompraPrecio _conTienda(CompraPrecio h, String nombre) => CompraPrecio(
    clave: h.clave,
    nombre: h.nombre,
    unidad: h.unidad,
    totalCentavos: h.totalCentavos,
    cantidad: h.cantidad,
    fecha: h.fecha,
    tiendaId: h.tiendaId,
    tienda: nombre,
    compraId: h.compraId,
    revertida: h.revertida,
    cuentaPago: h.cuentaPago,
  );

  @override
  Future<ResultadoBorradoTienda> borrarTienda(String id) async {
    final i = _tiendas.indexWhere((t) => t.id == id);
    if (i < 0) throw const ErrorAlimentacionServidor('La tienda no existe.');
    final tieneCompras = _historialCuentas.any((e) => e.$2.tiendaId == id);
    if (tieneCompras) {
      _tiendas[i] = Tienda(id: id, nombre: _tiendas[i].nombre, activa: false);
      return ResultadoBorradoTienda.desactivada;
    }
    _tiendas.removeAt(i);
    return ResultadoBorradoTienda.borrada;
  }

  @override
  Future<bool> regresarCompra({
    required MenuId menu,
    required DateTime lunes,
    required String clave,
    required String motivo,
  }) async {
    if (motivo.trim().length < minCaracteresMotivoRegreso) {
      throw const ErrorAlimentacionServidor(
        'El motivo lleva al menos $minCaracteresMotivoRegreso caracteres.',
      );
    }
    // La original se conserva en el historial como revertida.
    for (var k = _historialCuentas.length - 1; k >= 0; k--) {
      final (c, h) = _historialCuentas[k];
      if (h.clave == clave && !h.revertida) {
        final r = CompraPrecio(
          clave: h.clave,
          nombre: h.nombre,
          unidad: h.unidad,
          totalCentavos: h.totalCentavos,
          cantidad: h.cantidad,
          fecha: h.fecha,
          tiendaId: h.tiendaId,
          tienda: h.tienda,
          compraId: h.compraId,
          revertida: true,
          cuentaPago: h.cuentaPago,
        );
        _historialCuentas[k] = (c, r);
        final j = _historial.indexOf(h);
        if (j >= 0) _historial[j] = r;
        break;
      }
    }
    regresadas.add((clave, motivo.trim()));
    await marcar(menu, lunes, clave, false);
    return solicitudesPendientesMemoria.remove(clave);
  }

  @override
  Future<List<PorcionPersona>> porcionesRecomendadas(DateTime lunes) async => [
    ...porcionesMemoria,
  ];

  @override
  Future<void> fijarPorcion({
    required String platilloId,
    required DateTime lunes,
    required CuentaCompra cuenta,
    required double porciones,
  }) async {
    porcionesMemoria
      ..removeWhere((p) => p.platilloId == platilloId && p.cuenta == cuenta)
      ..add(
        PorcionPersona(
          platilloId: platilloId,
          cuenta: cuenta,
          porciones: porciones,
        ),
      );
  }

  @override
  Future<List<CompraPrecio>> historialCompleto(CuentaCompra cuenta) async => [
    for (final (c, compra) in _historialCuentas)
      if (c == null || c == cuenta) compra,
  ];

  @override
  Future<List<ItemDespensa>> despensa(CuentaCompra cuenta) async => [
    ...?despensaMemoria[cuenta],
  ];

  @override
  Future<List<Ingrediente>> ingredientesConCodigo() async => [
    ..._conCodigo.values,
  ];

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

  static Never _no() => throw UnsupportedError(
    'Alimentación aún no tiene tablas en el servidor.',
  );

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
  Future<List<Tienda>> tiendas() async => const [];
  @override
  Future<Tienda> agregarTienda(String nombre) async => _no();
  @override
  Future<Tienda> editarTienda(String id, String nombre) async => _no();
  @override
  Future<ResultadoBorradoTienda> borrarTienda(String id) async => _no();
  @override
  Future<bool> regresarCompra({
    required MenuId menu,
    required DateTime lunes,
    required String clave,
    required String motivo,
  }) async => _no();
  @override
  Future<List<PorcionPersona>> porcionesRecomendadas(DateTime lunes) async =>
      const [];
  @override
  Future<void> fijarPorcion({
    required String platilloId,
    required DateTime lunes,
    required CuentaCompra cuenta,
    required double porciones,
  }) async => _no();
  @override
  Future<List<CompraPrecio>> historialCompleto(CuentaCompra cuenta) async =>
      const [];
  @override
  Future<List<ItemDespensa>> despensa(CuentaCompra cuenta) async => const [];
  @override
  Future<List<Ingrediente>> ingredientesConCodigo() async => const [];
  @override
  Future<bool> guardarIngredienteConCodigo(Ingrediente ingrediente) async =>
      _no();
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
  Future<List<SolicitudPago>> solicitudesRechazadasMias() async => const [];
  @override
  Future<void> reenviarSolicitud({
    required String solicitudId,
    required String justificacion,
  }) async => _no();
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
  Future<void> asignar(
    MenuId menu,
    DateTime lunes,
    int dia,
    TiempoComida tiempo,
    String? platilloId,
  ) async => _no();
  @override
  Future<Set<String>> comprados(MenuId menu, DateTime lunes) async => const {};
  @override
  Future<void> marcar(
    MenuId menu,
    DateTime lunes,
    String clave,
    bool comprado,
  ) async => _no();
  @override
  Future<List<Suplemento>> suplementos(MenuId menu) async => const [];
  @override
  Future<void> guardarSuplemento(MenuId menu, Suplemento s) async => _no();
  @override
  Future<void> quitarSuplemento(MenuId menu, String id) async => _no();
}

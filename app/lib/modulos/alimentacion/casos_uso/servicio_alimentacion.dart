/// Reglas de Alimentación (D23): quién ve y quién edita cada menú.
library;

import '../../../nucleo/contratos/roles.dart';
import '../datos/lector_codigo.dart';
import '../datos/modelos.dart';
import '../datos/perfiles.dart';
import '../datos/repositorio.dart';
import 'importar_recetas.dart';
import 'lista_compras.dart';
import 'sugerir_platillos.dart';

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
    SugeridorRecetas? sugeridor,
  }) : _ahora = ahora ?? DateTime.now,
       _sugeridor = sugeridor ?? const SugeridorNoDisponible();
  final DateTime Function() _ahora;
  final SugeridorRecetas _sugeridor;
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

  /// Cuenta de compra que se propone según el rol de quien compra.
  CuentaCompra cuentaPorOmisionDe(MenuId m) => cuentaPorOmision(rol, m);

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
    String? cuentaPagoId,
    String? tiendaId,
  }) async {
    _exigirEdicion();
    if (!puedeVerCompras(rol, m, esMaestra: esMaestra)) {
      throw const PermisoDenegado();
    }
    // La tienda es obligatoria (Fase 8) y debe ser de la lista del hogar.
    if (tiendaId == null || tiendaId.isEmpty) {
      throw ArgumentError('Elige la tienda de la compra.');
    }
    final tienda = (await _repo.tiendas())
        .where((t) => t.id == tiendaId)
        .firstOrNull;
    if (tienda == null || !tienda.activa) {
      throw ArgumentError('La tienda no está en la lista del hogar.');
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
      tiendaId: tienda.id,
      tienda: tienda.nombre,
    );
    final previas = historialDe(await _repo.historialCompras(), clave);
    final alerta = calcularAlerta(previas.isEmpty ? null : previas.first, compra);
    final r = await _repo.registrarCompraReal(
      menu: m,
      lunes: lunesDe(semana),
      compra: compra,
      precio: precio,
      cuenta: cuenta ?? cuentaPorOmision(rol, m),
      cuentaPagoId: cuentaPagoId,
    );
    return RegistroCompra(
      alerta: alerta,
      pendienteAlbacea: r.pendienteAlbacea,
    );
  }

  // ------------------------------------------------------- Tiendas (Fase 8)

  /// Tiendas del hogar, para elegir al registrar una compra.
  Future<List<Tienda>> tiendas() async {
    if (menusConCompras.isEmpty) throw const PermisoDenegado();
    return _repo.tiendas();
  }

  /// Agrega una tienda a la lista del hogar (dueño y pareja). Nombre de 1 a
  /// 60 caracteres; con el mismo nombre devuelve la que ya había.
  Future<Tienda> agregarTienda(String nombre) async {
    _exigirEdicion();
    final n = nombre.trim();
    if (n.isEmpty || n.length > maxCaracteresTienda) {
      throw ArgumentError(
        'El nombre de la tienda lleva de 1 a $maxCaracteresTienda caracteres.',
      );
    }
    return _repo.agregarTienda(n);
  }

  /// Cambia el nombre de una tienda (dueño y pareja). 1 a 60 caracteres.
  Future<Tienda> editarTienda(String id, String nombre) async {
    _exigirEdicion();
    final n = nombre.trim();
    if (n.isEmpty || n.length > maxCaracteresTienda) {
      throw ArgumentError(
        'El nombre de la tienda lleva de 1 a $maxCaracteresTienda caracteres.',
      );
    }
    return _repo.editarTienda(id, n);
  }

  /// Borra una tienda (dueño y pareja). Con compras, el servidor la
  /// desactiva en su lugar: el resultado lo dice para avisarlo.
  Future<ResultadoBorradoTienda> borrarTienda(String id) async {
    _exigirEdicion();
    return _repo.borrarTienda(id);
  }

  /// Regresa una compra marcada (dueño y pareja): vuelve a pendiente y el
  /// historial conserva la original como revertida. [motivo]: 3 o más
  /// caracteres. Devuelve `true` si se retiró una solicitud al albacea.
  Future<bool> regresarCompra(
    MenuId m,
    DateTime semana,
    String clave, {
    required String motivo,
  }) async {
    _exigirEdicion();
    if (!puedeVerCompras(rol, m, esMaestra: esMaestra)) {
      throw const PermisoDenegado();
    }
    final t = motivo.trim();
    if (t.length < minCaracteresMotivoRegreso) {
      throw ArgumentError(
        'El motivo lleva al menos $minCaracteresMotivoRegreso caracteres.',
      );
    }
    return _repo.regresarCompra(
      menu: m,
      lunes: lunesDe(semana),
      clave: clave,
      motivo: t,
    );
  }

  /// Porciones recomendadas por persona del menú compartido de dueño y
  /// pareja, por platillo. Solo quien ve ese menú; nunca el de Papá ni el
  /// perfil de nadie. Vacío si el servidor no las da.
  Future<Map<String, List<PorcionPersona>>> porcionesPorPlatillo(
    DateTime semana,
  ) async {
    _exigirVer(MenuId.pareja);
    final r = <String, List<PorcionPersona>>{};
    for (final p in await _repo.porcionesRecomendadas(lunesDe(semana))) {
      (r[p.platilloId] ??= []).add(p);
    }
    return r;
  }

  /// Fija la porción recomendada de [cuenta] (dueño o pareja) para un platillo
  /// del menú compartido. Solo dueño y pareja; de 0.25 a 20.
  Future<void> fijarPorcion({
    required String platilloId,
    required DateTime semana,
    required CuentaCompra cuenta,
    required double porciones,
  }) async {
    _exigirEdicion();
    if (porciones.isNaN || porciones < 0.25 || porciones > 20) {
      throw ArgumentError('La porción va de 0.25 a 20.');
    }
    await _repo.fijarPorcion(
      platilloId: platilloId,
      lunes: lunesDe(semana),
      cuenta: cuenta,
      porciones: porciones,
    );
  }

  /// Historial completo de compras reales del libro o lista de [m] (la misma
  /// regla de la lista de compras). Las anteriores a la Fase 8 vienen sin
  /// tienda.
  Future<List<CompraPrecio>> historialCompleto(MenuId m) async {
    if (!puedeVerCompras(rol, m, esMaestra: esMaestra)) {
      throw const PermisoDenegado();
    }
    return _repo.historialCompleto(cuentaPorOmision(rol, m));
  }

  // ------------------------------------------- Platillos desde la despensa

  /// Cuenta de la despensa que le toca a [rol]: Papá para quien solo ve su
  /// menú (familiar, cuidadora); la cuenta Casa no ve platillos.
  static CuentaCompra cuentaDeDespensa(Rol rol) => switch (rol) {
    Rol.dueno => CuentaCompra.dueno,
    Rol.coadministrador => CuentaCompra.pareja,
    Rol.casa => CuentaCompra.casa,
    Rol.familiar || Rol.cuidador => CuentaCompra.papa,
  };

  /// Despensa de **la cuenta que pide** (nunca la de otra).
  Future<List<ItemDespensa>> despensa() async {
    if (menusVisibles.isEmpty) throw const PermisoDenegado();
    return _repo.despensa(cuentaDeDespensa(rol));
  }

  /// Platillos del catálogo contra la despensa de esta cuenta.
  Future<List<PlatilloConDespensa>> platillosConLaDespensa() async =>
      platillosConDespensa(await platillos(), await despensa());

  /// Lo único que sale hacia la IA: ver [ContextoSugerencia].
  Future<ContextoSugerencia> contextoDeSugerencia(String preferencias) async =>
      ContextoSugerencia.de(await despensa(), preferencias);

  /// "Sugerir con IA". Solo propone: **no guarda nada**. Para guardar, la
  /// persona confirma y se llama [guardarSugerida].
  Future<List<Platillo>> sugerirConIA(String preferencias) async =>
      _sugeridor.sugerir(await contextoDeSugerencia(preferencias));

  /// Guarda una receta sugerida tras la confirmación de la persona (dueño y
  /// pareja), igual que una importada.
  Future<void> guardarSugerida(Platillo receta) async {
    _exigirEdicion();
    await _repo.guardarPlatillos([receta]);
  }

  /// Cuentas de pago que se ofrecen en [m] (nombres, sin saldos). La de
  /// omisión viene marcada; la persona puede elegir otra. Papá: ninguna.
  Future<List<CuentaPago>> cuentasDePago(MenuId m) async {
    _exigirEdicion();
    return _repo.cuentasDePago(cuentaPorOmision(rol, m));
  }

  /// La cuenta de pago a usar: la elegida si es una de las ofrecidas; si no, la
  /// de omisión. Una elegida siempre gana a la omisión.
  static CuentaPago? cuentaEfectiva(List<CuentaPago> ofrecidas, String? elegida) {
    for (final c in ofrecidas) {
      if (c.id == elegida) return c;
    }
    return ofrecidas.where((c) => c.porOmision).firstOrNull;
  }

  /// Agrega un ingrediente a la lista (dueño y pareja) por la función del
  /// servidor.
  Future<void> agregarALista({
    required String nombre,
    required String unidad,
    required double cantidad,
  }) async {
    _exigirEdicion();
    if (nombre.trim().isEmpty || unidad.trim().isEmpty || cantidad <= 0) {
      throw ArgumentError('Falta el nombre, la unidad o una cantidad mayor que cero.');
    }
    await _repo.agregarALista(
      nombre: nombre.trim(),
      unidad: unidad.trim(),
      cantidad: cantidad,
    );
  }

  /// La ficha del ingrediente con ese nombre, si existe.
  Future<FichaIngrediente?> ficha(String nombre) {
    _exigirEdicion();
    return _repo.ingredientePorNombre(nombre);
  }

  /// Edita unidad y presentación del MISMO ingrediente.
  Future<FichaIngrediente> editarPresentacion({
    required String ingredienteId,
    required String unidad,
    required String presentacion,
  }) async {
    _exigirEdicion();
    if (unidad.trim().isEmpty) throw ArgumentError('Falta la unidad.');
    return _repo.editarPresentacion(
      ingredienteId: ingredienteId,
      unidad: unidad,
      presentacion: presentacion,
    );
  }

  // ------------------------------------------------------------------ Albacea

  /// Solo el albacea ve las compras de Papá pendientes de pago: dueño o
  /// pareja (no la maestra) que además lo sea en el libro de Papá. La
  /// suplente y el resto no.
  Future<bool> puedeResolverSolicitudes() async =>
      puedeEditar && await _repo.esAlbacea();

  Future<void> _exigirAlbacea() async {
    if (!await puedeResolverSolicitudes()) throw const PermisoDenegado();
  }

  Future<List<SolicitudPago>> solicitudesPendientes() async {
    await _exigirAlbacea();
    return _repo.solicitudesPendientes();
  }

  Future<List<CuentaPago>> cuentasDelLibroDePapa() async {
    await _exigirAlbacea();
    return _repo.cuentasDelLibroDePapa();
  }

  /// Aprueba con una cuenta del libro de Papá.
  Future<void> aprobarSolicitud(String id, {required String cuentaPagoId}) async {
    await _exigirAlbacea();
    if (cuentaPagoId.isEmpty) throw ArgumentError('Elige la cuenta de pago.');
    await _repo.resolverSolicitud(
      solicitudId: id,
      aprobar: true,
      cuentaPagoId: cuentaPagoId,
    );
  }

  /// Rechaza con motivo (mínimo 3 caracteres).
  /// Solicitudes rechazadas de compras de esta persona que aún puede reenviar.
  Future<List<SolicitudPago>> solicitudesRechazadasMias() =>
      _repo.solicitudesRechazadasMias();

  /// Reenvía una vez una solicitud rechazada con una justificación de 3 a 200
  /// caracteres. Lo registra el servidor (solo quien compró, una vez).
  Future<void> reenviarSolicitud(String id, {required String justificacion}) async {
    final j = justificacion.trim();
    if (j.length < 3 || j.length > 200) {
      throw ArgumentError('La justificación lleva de 3 a 200 caracteres.');
    }
    await _repo.reenviarSolicitud(solicitudId: id, justificacion: j);
  }

  Future<void> rechazarSolicitud(String id, {required String motivo}) async {
    await _exigirAlbacea();
    final m = motivo.trim();
    if (m.length < 3) throw ArgumentError('El motivo lleva al menos 3 caracteres.');
    await _repo.resolverSolicitud(solicitudId: id, aprobar: false, motivo: m);
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
  Future<({Ingrediente ingrediente, bool enServidor, FichaIngrediente? existente})>
  guardarConCodigo({
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
    // Mismo nombre = mismo ingrediente: se abre el existente, no se crea otro.
    final existente = await _repo.ingredientePorNombre(nombre);
    if (existente != null) {
      return (ingrediente: i, enServidor: true, existente: existente);
    }
    final enServidor = await _repo.guardarIngredienteConCodigo(i);
    return (ingrediente: i, enServidor: enServidor, existente: null);
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

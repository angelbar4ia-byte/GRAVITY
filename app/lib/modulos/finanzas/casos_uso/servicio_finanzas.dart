/// Casos de uso de Finanzas (especificación de la Fase 1, sección 8): cada
/// acción revisa el permiso en el libro (espejo de `fin_puede`), arma los
/// movimientos con `finanzas_dominio` (que valida las reglas del libro) y los
/// guarda con el repositorio. **La app no mueve dinero sola**: todo lo que
/// crea movimientos es una acción confirmada por la persona.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:uuid/uuid.dart';

import '../datos/ids.dart';
import '../datos/permisos_libro.dart';
import '../datos/repositorio.dart';

export '../datos/ids.dart' show ClavesId, idEstable;

/// Una línea de un gasto (un ticket con varios rubros se divide por líneas).
class LineaGasto {
  const LineaGasto({required this.monto, this.categoriaId, this.nota});

  final int monto;

  /// Subcategoría o detalle; nula = "Por clasificar".
  final String? categoriaId;
  final String? nota;
}

/// Lo que se registró (para deshacer y para el aviso).
class ResultadoRegistro {
  const ResultadoRegistro(this.movimientos, this.resultado);

  final List<Movimiento> movimientos;
  final ResultadoEscritura resultado;

  bool get enCola => resultado == ResultadoEscritura.enCola;
}

/// Motivo de la anulación al deshacer justo después de capturar (F1).
const motivoDeshacer = 'Deshecho al capturar';

class ServicioFinanzas {
  ServicioFinanzas({
    required this.repositorio,
    required this.personaId,
    this.hogarId = '',
    this.esMaestra = false,
    this.soloLectura = false,
    this.esDueno = false,
    DateTime Function()? reloj,
    String Function()? generarId,
  }) : _reloj = reloj ?? DateTime.now,
       _generarId = generarId ?? const Uuid().v4;

  final RepositorioFinanzas repositorio;
  final String personaId;

  /// Hogar de la sesión (para los ids estables de lo que es del hogar).
  final String hogarId;
  final bool esMaestra;

  /// La cuenta maestra que **no es la dueña** (D19, 23/oct/2026): no registra
  /// ni administra nada, tampoco lo suyo ni lo del hogar.
  final bool soloLectura;

  /// La persona es el dueño del hogar (puede cambiar la membresía de un
  /// compartido del que es miembro, aunque no lo haya creado).
  final bool esDueno;
  final DateTime Function() _reloj;
  final String Function() _generarId;

  /// Id de la anulación de [movimientoId]: hay a lo más una por movimiento
  /// (índice único en `anula_a`), así que reintentar "Deshacer" no duplica.
  static String idAnulacionDe(String movimientoId) =>
      idEstable(ClavesId.anulacion(movimientoId));

  DatosFinanzas get _d => repositorio.actual?.datos ?? DatosFinanzas.vacio;
  DateTime get _ahora => _reloj();
  Fecha get hoy => Fecha.deDateTime(_reloj());

  // ---------------------------------------------------------------- permisos

  Libro _libro(String libroId) =>
      _d.libro(libroId) ?? (throw const ErrorFinanzas('No existe ese libro.'));

  PermisoLibro permiso(String libroId) {
    final libro = _d.libro(libroId);
    if (libro == null) return PermisoLibro.ninguno;
    return permisoDeCarga(
      repositorio.actual ?? CargaFinanzas(datos: DatosFinanzas.vacio),
      libro,
      personaId,
      hoy: hoy,
      esMaestra: esMaestra,
      soloLectura: soloLectura,
    );
  }

  void _exigirEscribir(String libroId) {
    if (soloLectura) {
      throw const ErrorFinanzas('La cuenta maestra solo lee: no registra nada.');
    }
    final libro = _d.libro(libroId);
    if (libro != null && libro.archivado && permiso(libroId).leer) {
      throw ErrorFinanzas(
        '${libro.nombre} está archivado: es de solo lectura, ya no se '
        'registra en él.',
      );
    }
    if (!permiso(libroId).escribir) {
      throw const ErrorFinanzas(
        'Solo lectura: no puedes registrar en este libro.',
      );
    }
  }

  /// Lo del **hogar** (categorías, cuentas de gasto, días inhábiles,
  /// importaciones): la cuenta maestra que no es la dueña solo lo lee (M6).
  void _exigirHogar() {
    if (soloLectura) {
      throw const ErrorFinanzas(
        'La cuenta maestra solo lee: no cambia la configuración del hogar.',
      );
    }
  }

  void _exigirAdministrar(String libroId) {
    final libro = _d.libro(libroId);
    if (libro != null && libro.archivado && !soloLectura) {
      if (!permiso(libroId).administrar) {
        throw ErrorFinanzas(
          '${libro.nombre} está archivado: solo quien lo creó lo reactiva.',
        );
      }
    }
    if (!permiso(libroId).administrar) {
      throw const ErrorFinanzas(
        'Solo quien lleva este libro cambia su configuración.',
      );
    }
  }

  /// En el libro de papá todo va en su nombre y con motivo (regla 3 de 4.5).
  ({String realizadoPor, String? enNombreDe}) _quien(
    String libroId,
    String? motivo,
  ) {
    final libro = _libro(libroId);
    if (libro.tipo != TipoLibro.representado) {
      return (realizadoPor: personaId, enNombreDe: null);
    }
    if (!motivoValido(motivo)) {
      throw ErrorFinanzas(
        'En el libro de ${libro.nombre} cada movimiento lleva un motivo. '
        '$mensajeMotivoCorto',
      );
    }
    return (realizadoPor: libro.titularId!, enNombreDe: libro.titularId);
  }

  static String? _limpio(String? texto) {
    final t = texto?.trim();
    if (t == null || t.isEmpty) return null;
    return t.length > 200 ? t.substring(0, 200) : t;
  }

  // ------------------------------------------------------------------ gastos

  /// Registra un gasto (F1) con una o varias líneas; varias líneas comparten
  /// `grupo_id` (ticket dividido, 5.2). Sin categoría va a "Por clasificar".
  Future<ResultadoRegistro> registrarGasto({
    required String libroId,
    required String cuentaOrigenId,
    required List<LineaGasto> lineas,
    Fecha? fecha,
    String? nota,
    String? motivo,
    ViaCaptura via = ViaCaptura.manual,
  }) async {
    _exigirEscribir(libroId);
    if (lineas.isEmpty || lineas.any((l) => l.monto <= 0)) {
      throw const ErrorFinanzas('Escribe un monto mayor que cero.');
    }
    final origen = _d.cuenta(cuentaOrigenId);
    if (origen == null ||
        origen.libroId != libroId ||
        (origen.clase != ClaseCuenta.activo &&
            origen.clase != ClaseCuenta.pasivo)) {
      throw const ErrorFinanzas('Elige una cuenta de este libro para pagar.');
    }
    final quien = _quien(libroId, motivo);
    final porClasificar = _cuentaPorClasificar(libroId);
    final grupo = lineas.length > 1 ? _generarId() : null;
    final ahora = _ahora;
    final movimientos = <Movimiento>[];
    for (final l in lineas) {
      final cuentaGasto = l.categoriaId == null
          ? porClasificar
          : _d.arbol.cuentaGastoDe(l.categoriaId!);
      if (cuentaGasto == null) {
        throw const ErrorFinanzas('Esa categoría no tiene cuenta de gasto.');
      }
      movimientos.add(
        Movimiento(
          id: _generarId(),
          tipo: TipoMovimiento.gasto,
          fecha: fecha ?? hoy,
          registradoEn: ahora,
          cuentaOrigenId: cuentaOrigenId,
          cuentaDestinoId: cuentaGasto,
          monto: l.monto,
          realizadoPor: quien.realizadoPor,
          registradoPor: personaId,
          via: via,
          categoriaId: l.categoriaId,
          grupoId: grupo,
          nota: _limpio(l.nota ?? nota),
          motivo: _limpio(motivo),
          enNombreDe: quien.enNombreDe,
        ),
      );
    }
    final r = await repositorio.agregarMovimientos(movimientos);
    return ResultadoRegistro(movimientos, r);
  }

  String? _cuentaPorClasificar(String libroId) =>
      _d.parametrosDe(libroId).cuentaPorClasificarId ??
      _d
          .cuentasDe(libroId)
          .where((c) => c.tipo == TipoCuenta.porClasificar)
          .firstOrNull
          ?.id;

  /// Deshace lo recién capturado con anulaciones (nunca se borra).
  Future<void> deshacer(ResultadoRegistro registro) async {
    for (final m in registro.movimientos) {
      await anular(m.id, motivo: motivoDeshacer);
    }
  }

  /// Anula un movimiento con un contraasiento (motivo obligatorio). Lleva la
  /// misma fecha económica: la semana del original se recalcula (P14).
  Future<Movimiento> anular(String movimientoId, {required String motivo}) async {
    if (!motivoValido(motivo)) {
      throw const ErrorFinanzas(
        'Escribe el motivo de la anulación: $mensajeMotivoCorto',
      );
    }
    final original = _d.movimientos
        .where((m) => m.id == movimientoId)
        .firstOrNull;
    if (original == null) throw const ErrorFinanzas('No existe ese movimiento.');
    final libros = {
      for (final id in [original.cuentaOrigenId, original.cuentaDestinoId])
        ?_d.cuenta(id)?.libroId,
    };
    if (libros.isEmpty) {
      throw const ErrorFinanzas('No puedes anular ese movimiento.');
    }
    libros.forEach(_exigirEscribir);
    final libro = _d.nuevoLibroHogar();
    // Hay a lo más una anulación por movimiento (índice único en `anula_a`):
    // tocar "Deshacer" o "Anular" otra vez avisa en lugar de reintentar.
    if (libro.contraasientoDe(movimientoId) != null) {
      throw const ErrorFinanzas('Ese movimiento ya está anulado.');
    }
    // En el libro de papá la anulación también va en su nombre (el servidor
    // exige `en_nombre_de` y motivo en todo movimiento de ese libro).
    final representado = libros
        .map(_libro)
        .where((l) => l.tipo == TipoLibro.representado)
        .firstOrNull;
    try {
      final contra = libro.anular(
        movimientoId,
        nuevoId: idAnulacionDe(movimientoId),
        motivo: _limpio(motivo)!,
        registradoPor: personaId,
        registradoEn: _ahora,
        enNombreDe: representado?.titularId,
      );
      await repositorio.agregarMovimientos([contra]);
      return contra;
    } on ErrorLibro catch (e) {
      throw ErrorFinanzas(e.mensaje);
    }
  }

  // ---------------------------------------------------------------- ingresos

  /// Registra un ingreso extra con su fecha real (5.1 bis, punto 4) desde la
  /// cuenta "Extras" del libro (se crea si no existe).
  Future<ResultadoRegistro> registrarIngresoExtra({
    required String libroId,
    required int monto,
    required String cuentaDestinoId,
    Fecha? fecha,
    String? nota,
    String? motivo,
  }) async {
    _exigirEscribir(libroId);
    if (monto <= 0) throw const ErrorFinanzas('Escribe un monto mayor que cero.');
    final destino = _d.cuenta(cuentaDestinoId);
    if (destino == null ||
        destino.libroId != libroId ||
        destino.clase != ClaseCuenta.activo) {
      throw const ErrorFinanzas('Elige la cuenta donde entró el dinero.');
    }
    final quien = _quien(libroId, motivo);
    final extras = await _cuentaExtras(libroId);
    final m = Movimiento(
      id: _generarId(),
      tipo: TipoMovimiento.ingreso,
      fecha: fecha ?? hoy,
      registradoEn: _ahora,
      cuentaOrigenId: extras,
      cuentaDestinoId: cuentaDestinoId,
      monto: monto,
      realizadoPor: quien.realizadoPor,
      registradoPor: personaId,
      nota: _limpio(nota),
      motivo: _limpio(motivo),
      enNombreDe: quien.enNombreDe,
    );
    final r = await repositorio.agregarMovimientos([m]);
    return ResultadoRegistro([m], r);
  }

  Future<String> _cuentaExtras(String libroId) async {
    final configuradas = {
      for (final i in _d.ingresosDe(libroId)) i.cuentaOrigenId,
    };
    final existente = _d
        .cuentasDe(libroId)
        .where(
          (c) =>
              c.tipo == TipoCuenta.origenIngreso &&
              c.estado == EstadoCuenta.activa &&
              !configuradas.contains(c.id),
        )
        .firstOrNull;
    if (existente != null) return existente.id;
    // Id estable: si el primer intento creó la cuenta y falló después, el
    // reintento no choca con el único (libro, nombre).
    final nueva = Cuenta(
      id: idEstable(ClavesId.cuentaDeLibro(libroId, 'origen_ingreso', 'Extras')),
      nombre: 'Extras',
      tipo: TipoCuenta.origenIngreso,
      libroId: libroId,
    );
    await repositorio.guardarCuentas([nueva]);
    return nueva.id;
  }

  /// Registra cualquier movimiento del libro (laptop, Ctrl + N): ingreso,
  /// gasto, reembolso, transferencia (también a otro libro: aportación),
  /// pago de deuda o reclasificación.
  Future<ResultadoRegistro> registrarMovimiento({
    required TipoMovimiento tipo,
    required String cuentaOrigenId,
    required String cuentaDestinoId,
    required int monto,
    Fecha? fecha,
    String? categoriaId,
    String? nota,
    String? motivo,
  }) async {
    if (monto <= 0) throw const ErrorFinanzas('Escribe un monto mayor que cero.');
    if (tipo == TipoMovimiento.anulacion ||
        tipo == TipoMovimiento.ajuste ||
        tipo == TipoMovimiento.apertura) {
      throw const ErrorFinanzas(
        'Las anulaciones, ajustes y saldos iniciales tienen su propia acción.',
      );
    }
    final libros = [
      for (final id in [cuentaOrigenId, cuentaDestinoId]) ?_d.cuenta(id)?.libroId,
    ];
    if (libros.isEmpty) {
      throw const ErrorFinanzas('Una de las cuentas debe ser de un libro.');
    }
    libros.forEach(_exigirEscribir);
    if (libros.toSet().length > 1 &&
        tipo != TipoMovimiento.transferencia &&
        tipo != TipoMovimiento.pagoDeuda) {
      throw const ErrorFinanzas(
        'Solo una transferencia o un pago de deuda va de un libro a otro.',
      );
    }
    final representado = libros
        .map(_libro)
        .where((l) => l.tipo == TipoLibro.representado)
        .firstOrNull;
    final quien = representado == null
        ? (realizadoPor: personaId, enNombreDe: null)
        : _quien(representado.id, motivo);
    final m = Movimiento(
      id: _generarId(),
      tipo: tipo,
      fecha: fecha ?? hoy,
      registradoEn: _ahora,
      cuentaOrigenId: cuentaOrigenId,
      cuentaDestinoId: cuentaDestinoId,
      monto: monto,
      realizadoPor: quien.realizadoPor,
      registradoPor: personaId,
      categoriaId: categoriaId,
      nota: _limpio(nota),
      motivo: _limpio(motivo),
      enNombreDe: quien.enNombreDe,
    );
    final r = await repositorio.agregarMovimientos([m]);
    return ResultadoRegistro([m], r);
  }

  // ----------------------------------------------------------------- cuentas

  String? _cuentaTecnica(String libroId, TipoCuenta tipo) {
    final p = _d.parametrosDe(libroId);
    final id = switch (tipo) {
      TipoCuenta.apertura => p.cuentaAperturaId,
      TipoCuenta.ajustes => p.cuentaAjustesId,
      _ => null,
    };
    return id ??
        _d.cuentasDe(libroId).where((c) => c.tipo == tipo).firstOrNull?.id;
  }

  /// Saldo inicial de una cuenta (uno por cuenta, 5.0 bis 2 punto 5).
  Future<void> registrarApertura({
    required String cuentaId,
    required int saldo,
    required Fecha fecha,
    String? motivo,
  }) async {
    final cuenta = _d.cuenta(cuentaId);
    final libroId = cuenta?.libroId;
    if (cuenta == null || libroId == null) {
      throw const ErrorFinanzas('No existe esa cuenta.');
    }
    _exigirEscribir(libroId);
    if (saldo <= 0) return;
    final apertura = _cuentaTecnica(libroId, TipoCuenta.apertura);
    if (apertura == null) {
      throw const ErrorFinanzas('El libro no tiene su cuenta de apertura.');
    }
    final pasivo = cuenta.clase == ClaseCuenta.pasivo;
    final quien = _quien(libroId, motivo ?? (
        _libro(libroId).tipo == TipoLibro.representado ? 'Saldo inicial' : null));
    await repositorio.agregarMovimientos([
      Movimiento(
        id: _generarId(),
        tipo: TipoMovimiento.apertura,
        fecha: fecha,
        registradoEn: _ahora,
        cuentaOrigenId: pasivo ? cuentaId : apertura,
        cuentaDestinoId: pasivo ? apertura : cuentaId,
        monto: saldo,
        realizadoPor: quien.realizadoPor,
        registradoPor: personaId,
        motivo: quien.enNombreDe == null ? null : (motivo ?? 'Saldo inicial'),
        enNombreDe: quien.enNombreDe,
      ),
    ]);
  }

  /// Crea una cuenta del libro y, si se da, su saldo inicial.
  Future<Cuenta> crearCuenta({
    required String libroId,
    required String nombre,
    required TipoCuenta tipo,
    int saldoInicial = 0,
    Fecha? fechaSaldo,
    int? limiteCentavos,
  }) async {
    _exigirAdministrar(libroId);
    if (nombre.trim().isEmpty) throw const ErrorFinanzas('Escribe un nombre.');
    const permitidos = {
      TipoCuenta.efectivo,
      TipoCuenta.banco,
      TipoCuenta.ahorro,
      TipoCuenta.inversion,
      TipoCuenta.tarjeta,
      TipoCuenta.prestamo,
      TipoCuenta.origenIngreso,
      TipoCuenta.porCobrar,
    };
    if (!permitidos.contains(tipo)) {
      throw const ErrorFinanzas('Ese tipo de cuenta no se crea a mano.');
    }
    final repetido = _d.cuentas.any(
      (c) => normalizarNombre(c.nombre) == normalizarNombre(nombre) &&
          c.libroId == libroId,
    );
    if (repetido) throw const ErrorFinanzas('Ya hay una cuenta con ese nombre.');
    final cuenta = Cuenta(
      id: _generarId(),
      nombre: nombre.trim(),
      tipo: tipo,
      libroId: libroId,
      limiteCentavos: limiteCentavos,
    );
    await repositorio.guardarCuentas([cuenta]);
    if (saldoInicial > 0) {
      await registrarApertura(
        cuentaId: cuenta.id,
        saldo: saldoInicial,
        fecha: fechaSaldo ?? hoy,
      );
    }
    return cuenta;
  }

  /// Congela, cierra, archiva o reactiva. Una cuenta de **activos o pasivos**
  /// se cierra o archiva solo con saldo cero (5.0 bis 2, punto 5); las de
  /// **gasto e ingreso** se cierran o archivan sin pedir saldo cero (respuestas
  /// del dueño del 23/oct/2026): ya no admiten movimientos nuevos, pero lo
  /// anterior se puede anular.
  Future<void> cambiarEstadoCuenta(String cuentaId, EstadoCuenta estado) async {
    final cuenta = _d.cuenta(cuentaId);
    if (cuenta == null) throw const ErrorFinanzas('No existe esa cuenta.');
    final libroId = cuenta.libroId;
    if (libroId == null) {
      // Cuenta de gasto del hogar: es configuración del hogar.
      _exigirHogar();
    } else {
      _exigirAdministrar(libroId);
    }
    try {
      _d.nuevoLibroHogar().cambiarEstadoCuenta(cuentaId, estado);
    } on ErrorLibro {
      throw const ErrorFinanzas(
        'Una cuenta de activos o pasivos se cierra o archiva solo con saldo '
        'cero.',
      );
    }
    await repositorio.guardarCuentas([cuenta.conEstado(estado)]);
  }

  /// Borra una cuenta sin movimientos.
  Future<void> eliminarCuenta(String cuentaId) async {
    final cuenta = _d.cuenta(cuentaId);
    final libroId = cuenta?.libroId;
    if (cuenta == null || libroId == null) {
      throw const ErrorFinanzas('No existe esa cuenta.');
    }
    _exigirAdministrar(libroId);
    if (_d.movimientos.any(
      (m) => m.cuentaOrigenId == cuentaId || m.cuentaDestinoId == cuentaId,
    )) {
      throw const ErrorFinanzas(
        'La cuenta tiene movimientos: ciérrala o archívala.',
      );
    }
    await repositorio.eliminarCuenta(cuentaId);
  }

  /// Concilia una cuenta: declara el saldo real y, si hay diferencia, crea un
  /// **ajuste** con motivo en la cuenta Ajustes del libro (5.0 bis 2, punto 6).
  Future<ConciliacionGuardada> conciliar({
    required String cuentaId,
    required int saldoDeclarado,
    Fecha? fecha,
    String? motivo,
  }) async {
    final cuenta = _d.cuenta(cuentaId);
    final libroId = cuenta?.libroId;
    if (cuenta == null || libroId == null) {
      throw const ErrorFinanzas('No existe esa cuenta.');
    }
    _exigirEscribir(libroId);
    final dia = fecha ?? hoy;
    final ajustes = _cuentaTecnica(libroId, TipoCuenta.ajustes);
    if (ajustes == null) {
      throw const ErrorFinanzas('El libro no tiene su cuenta de ajustes.');
    }
    final libro = _d.nuevoLibroHogar();
    final calculado = libro.saldo(cuentaId, hasta: dia);
    if (saldoDeclarado != calculado && !motivoValido(motivo)) {
      throw const ErrorFinanzas(
        'Hay diferencia: escribe el motivo del ajuste. $mensajeMotivoCorto',
      );
    }
    final quien = _quien(
      libroId,
      _libro(libroId).tipo == TipoLibro.representado
          ? (motivo ?? 'Conciliación sin diferencia')
          : motivo,
    );
    final Conciliacion c;
    try {
      c = libro.conciliar(
        cuentaId: cuentaId,
        fecha: dia,
        saldoDeclarado: saldoDeclarado,
        cuentaAjustesId: ajustes,
        idAjuste: _generarId(),
        persona: quien.realizadoPor,
        registradoEn: _ahora,
        motivo: _limpio(motivo),
      );
    } on ErrorLibro catch (e) {
      throw ErrorFinanzas(e.mensaje);
    }
    final ajuste = c.ajuste;
    if (ajuste != null) {
      final conAutor = Movimiento(
        id: ajuste.id,
        tipo: ajuste.tipo,
        fecha: ajuste.fecha,
        registradoEn: ajuste.registradoEn,
        cuentaOrigenId: ajuste.cuentaOrigenId,
        cuentaDestinoId: ajuste.cuentaDestinoId,
        monto: ajuste.monto,
        realizadoPor: quien.realizadoPor,
        registradoPor: personaId,
        motivo: ajuste.motivo,
        enNombreDe: quien.enNombreDe,
      );
      await repositorio.agregarMovimientos([conAutor]);
    }
    final guardada = ConciliacionGuardada(
      id: _generarId(),
      libroId: libroId,
      cuentaId: cuentaId,
      fecha: dia,
      saldoDeclarado: saldoDeclarado,
      saldoCalculado: calculado,
      ajusteMovimientoId: ajuste?.id,
      motivo: _limpio(motivo),
      personaId: personaId,
      creadoEn: _ahora,
    );
    await repositorio.agregarConciliacion(guardada);
    return guardada;
  }

  // -------------------------------------------------------------- categorías

  /// Crea una categoría del hogar; las de nivel 1 llevan su cuenta de gasto.
  Future<Categoria> crearCategoria({
    required String nombre,
    String? padreId,
    Prioridad? prioridad,
    bool? protegida,
  }) async {
    _exigirHogar();
    final limpio = nombre.trim();
    if (limpio.isEmpty) throw const ErrorFinanzas('Escribe un nombre.');
    final padre = _d.arbol.porId(padreId);
    if (padreId != null && padre == null) {
      throw const ErrorFinanzas('No existe la categoría padre.');
    }
    if (padre != null && padre.nivel >= 3) {
      throw const ErrorFinanzas('El árbol tiene 3 niveles como máximo.');
    }
    if (_d.arbol.buscar(limpio, padreId: padreId) != null) {
      throw const ErrorFinanzas('Ya existe una categoría con ese nombre ahí.');
    }
    String? cuentaId;
    if (padre == null) {
      // Cada categoría principal es una cuenta de gasto del hogar (5.2). Si
      // ya hay una con ese nombre (p. ej. de un intento anterior), se usa.
      final existente = _d.cuentas
          .where(
            (c) =>
                c.tipo == TipoCuenta.deGasto &&
                normalizarNombre(c.nombre) == normalizarNombre(limpio),
          )
          .firstOrNull;
      if (existente != null) {
        cuentaId = existente.id;
      } else {
        final cuenta = Cuenta(
          id: idEstable(ClavesId.cuentaDeGasto(hogarId, limpio)),
          nombre: limpio,
          tipo: TipoCuenta.deGasto,
        );
        await repositorio.guardarCuentas([cuenta]);
        cuentaId = cuenta.id;
      }
    }
    final categoria = Categoria(
      id: _generarId(),
      padreId: padreId,
      nivel: (padre?.nivel ?? 0) + 1,
      nombre: limpio,
      prioridad: prioridad ?? padre?.prioridad ?? Prioridad.deseable,
      protegida: protegida ?? padre?.protegida ?? false,
      naturaleza: padre?.naturaleza ?? '',
      cuentaGastoId: cuentaId,
    );
    await repositorio.guardarCategorias([categoria]);
    return categoria;
  }

  Future<void> cambiarCategoria(Categoria categoria) async {
    _exigirHogar();
    await repositorio.guardarCategorias([categoria]);
  }

  /// Borra una categoría **sin datos**; con datos se archiva (5.2).
  Future<void> eliminarCategoria(String categoriaId) async {
    _exigirHogar();
    final conDatos =
        _d.categorias.any((c) => c.padreId == categoriaId) ||
        _d.movimientos.any((m) => m.categoriaId == categoriaId) ||
        _d.compromisos.any((c) => c.categoriaId == categoriaId);
    if (conDatos) {
      throw const ErrorFinanzas(
        'La categoría tiene datos: archívala en lugar de eliminarla.',
      );
    }
    await repositorio.eliminarCategoria(categoriaId);
  }

  /// Vista previa de la importación de la hoja Categorías (no guarda nada).
  PlanImportacion previsualizarImportacion(LecturaPlantilla lectura) =>
      planearImportacionCategorias(
        lectura,
        existentes: _d.categorias,
        cuentasExistentes: _d.cuentas,
        idPara: (clave) => idEstable(ClavesId.importacion(hogarId, clave)),
      );

  /// Importa la hoja Categorías: crea las cuentas de gasto, después el árbol
  /// y deja el registro de la importación. Reimportar no duplica.
  Future<PlanImportacion> importarCategorias(
    LecturaPlantilla lectura, {
    required String archivo,
    String hoja = 'Categorías',
  }) async {
    _exigirHogar();
    final plan = previsualizarImportacion(lectura);
    if (plan.cuentasNuevas.isNotEmpty) {
      await repositorio.guardarCuentas(plan.cuentasNuevas);
    }
    if (plan.nuevas.isNotEmpty) {
      await repositorio.guardarCategorias(plan.nuevas);
    }
    await repositorio.agregarImportacion(
      ImportacionGuardada(
        id: _generarId(),
        archivo: archivo,
        hoja: hoja,
        filasLeidas: plan.filasLeidas,
        filasCreadas: plan.filasCreadas,
        filasOmitidas: plan.omitidas.length,
        detalle: [
          for (final o in plan.omitidas.take(500))
            {'fila': o.numero, 'texto': o.texto, 'motivo': o.motivo},
        ],
        personaId: personaId,
        creadoEn: _ahora,
      ),
    );
    return plan;
  }

  // ----------------------------------------------------------- configuración

  /// Crea un ingreso con su primera vigencia y su cuenta de origen.
  Future<Ingreso> crearIngreso({
    required String libroId,
    required String nombre,
    required int montoNeto,
    required CalendarioConfig calendario,
    required String cuentaDestinoId,
    String? personaId,
    TipoIngreso tipo = TipoIngreso.salario,
    Certeza certeza = Certeza.segura,
    Fecha? desde,
  }) async {
    _exigirAdministrar(libroId);
    if (nombre.trim().isEmpty) throw const ErrorFinanzas('Escribe un nombre.');
    if (montoNeto <= 0) throw const ErrorFinanzas('El neto debe ser mayor que cero.');
    try {
      calendario.calendario;
    } on ArgumentError catch (e) {
      throw ErrorFinanzas('${e.message}');
    }
    // La cuenta de origen del ingreso (5.1) lleva su nombre; con id estable,
    // un reintento no choca con el único (libro, nombre).
    final usadas = {for (final i in _d.ingresosDe(libroId)) i.cuentaOrigenId};
    final previa = _d
        .cuentasDe(libroId)
        .where(
          (c) =>
              c.tipo == TipoCuenta.origenIngreso &&
              !usadas.contains(c.id) &&
              normalizarNombre(c.nombre) == normalizarNombre(nombre),
        )
        .firstOrNull;
    if (previa == null &&
        _d.cuentasDe(libroId).any(
          (c) => normalizarNombre(c.nombre) == normalizarNombre(nombre),
        )) {
      throw const ErrorFinanzas(
        'Ya hay una cuenta con ese nombre en el libro: usa otro nombre.',
      );
    }
    final origen =
        previa ??
        Cuenta(
          id: idEstable(
            ClavesId.cuentaDeLibro(libroId, 'origen_ingreso', nombre.trim()),
          ),
          nombre: nombre.trim(),
          tipo: TipoCuenta.origenIngreso,
          libroId: libroId,
        );
    if (previa == null) await repositorio.guardarCuentas([origen]);
    final libro = _libro(libroId);
    final id = _generarId();
    final ingreso = Ingreso(
      id: id,
      libroId: libroId,
      personaId: personaId ??
          (libro.tipo == TipoLibro.personal || libro.tipo == TipoLibro.representado
              ? libro.titularId
              : this.personaId),
      nombre: nombre.trim(),
      tipo: tipo,
      cuentaOrigenId: origen.id,
      cuentaDestinoId: cuentaDestinoId,
      certeza: certeza,
      vigencias: [
        VigenciaIngreso(
          id: _generarId(),
          ingresoId: id,
          montoNeto: montoNeto,
          calendario: calendario,
          desde: desde ?? Semana.de(hoy).inicio,
        ),
      ],
    );
    await repositorio.guardarIngreso(ingreso);
    return ingreso;
  }

  /// Cambia el neto o el calendario desde una fecha: vigencia nueva; la
  /// anterior solo cierra su `hasta` (5.1 bis, punto 2).
  Future<void> cambiarNeto(
    String ingresoId, {
    required int montoNeto,
    required CalendarioConfig calendario,
    required Fecha desde,
  }) async {
    final ingreso = _d.ingresos.where((i) => i.id == ingresoId).firstOrNull;
    if (ingreso == null) throw const ErrorFinanzas('No existe ese ingreso.');
    _exigirAdministrar(ingreso.libroId);
    try {
      await repositorio.guardarIngreso(
        ingreso.conNuevaVigencia(
          id: _generarId(),
          montoNeto: montoNeto,
          calendario: calendario,
          desde: desde,
        ),
      );
    } on ArgumentError catch (e) {
      throw ErrorFinanzas('${e.message}');
    }
  }

  Future<void> guardarIngreso(Ingreso ingreso) async {
    _exigirAdministrar(ingreso.libroId);
    await repositorio.guardarIngreso(ingreso);
  }

  Future<void> guardarCompromiso(Compromiso compromiso) async {
    _exigirAdministrar(compromiso.libroId);
    try {
      compromiso.validar();
    } on ArgumentError catch (e) {
      throw ErrorFinanzas('${e.message}');
    }
    await repositorio.guardarCompromiso(compromiso);
  }

  Future<void> guardarSobre(Sobre sobre) async {
    _exigirAdministrar(sobre.libroId);
    if (sobre.montoSemanal < 0) {
      throw const ErrorFinanzas('El monto no puede ser negativo.');
    }
    await repositorio.guardarSobre(sobre);
  }

  Future<void> guardarDeuda(Deuda deuda) async {
    _exigirAdministrar(deuda.libroId);
    try {
      deuda.validar();
    } on ArgumentError catch (e) {
      throw ErrorFinanzas('${e.message}');
    }
    await repositorio.guardarDeuda(deuda);
  }

  Future<void> guardarParametros(ParametrosFinanzas parametros) async {
    _exigirAdministrar(parametros.libroId);
    try {
      parametros.validar();
    } on ArgumentError catch (e) {
      throw ErrorFinanzas('${e.message}');
    }
    await repositorio.guardarParametros(parametros);
  }

  /// Precarga los festivos oficiales del año (LFT art. 74) **inactivos**,
  /// para que el dueño los revise y active (decisión 55).
  Future<int> precargarFestivos(int anio) async {
    _exigirHogar();
    final existentes = {for (final d in _d.diasInhabiles) d.fecha};
    final nuevos = [
      for (final d in festivosOficialesMexico(anio))
        if (!existentes.contains(d.fecha)) d.copiar(activo: false),
    ];
    if (nuevos.isNotEmpty) await repositorio.guardarDiasInhabiles(nuevos);
    return nuevos.length;
  }

  Future<void> activarDiaInhabil(DiaInhabil dia, {required bool activo}) async {
    _exigirHogar();
    await repositorio.guardarDiasInhabiles([
      dia.copiar(activo: activo, revisadoPor: personaId, revisadoEn: _ahora),
    ]);
  }

  Future<void> agregarDiaPropio(Fecha fecha, String nombre) async {
    _exigirHogar();
    if (nombre.trim().isEmpty) {
      throw const ErrorFinanzas('Escribe el nombre del día.');
    }
    await repositorio.guardarDiasInhabiles([
      DiaInhabil(
        fecha: fecha,
        nombre: nombre.trim(),
        tipo: TipoDiaInhabil.personal,
        fuente: 'Propio',
        revisadoPor: personaId,
        revisadoEn: _ahora,
      ),
    ]);
  }

  // ------------------------------------------------------------------- libros

  /// Crea un libro compartido (p. ej. "Gastos de la casa"): quien lo crea
  /// queda como miembro y como su **administrador**, y agrega a [otros] (2 o
  /// más adultos). Es **privado** por omisión; con [visibilidad] pública los
  /// adultos con Finanzas del hogar lo leen (sin escribir). El id sale del
  /// nombre: tocar dos veces o reintentar no crea otro.
  Future<String> crearLibroCompartido(
    String nombre,
    List<String> otros, {
    VisibilidadLibro visibilidad = VisibilidadLibro.privada,
  }) async {
    if (soloLectura) {
      throw const ErrorFinanzas('La cuenta maestra solo lee: no crea libros.');
    }
    if (nombre.trim().isEmpty) throw const ErrorFinanzas('Escribe un nombre.');
    final demas = [
      for (final p in {...otros})
        if (p != personaId) p,
    ];
    if (demas.isEmpty) {
      throw const ErrorFinanzas('Un libro compartido se crea con 2 o más miembros.');
    }
    final id = idEstable(ClavesId.libroCompartido(hogarId, nombre.trim()));
    await repositorio.crearLibroCompartido(
      id: id,
      nombre: nombre.trim(),
      otrosMiembros: demas,
      visibilidad: visibilidad,
    );
    return id;
  }

  /// El compartido [libroId] si la persona lo administra (lo creó); si no,
  /// error.
  Libro _delAdministrador(String libroId, {String quehacer = 'lo cambia'}) {
    final libro = _libro(libroId);
    if (soloLectura ||
        libro.tipo != TipoLibro.compartido ||
        !libro.esAdministrador(personaId)) {
      throw ErrorFinanzas('Solo quien creó ${libro.nombre} $quehacer.');
    }
    return libro;
  }

  /// Cambia quién más ve un compartido (solo su administrador).
  Future<void> cambiarVisibilidadLibro(
    String libroId,
    VisibilidadLibro visibilidad,
  ) async {
    final libro = _delAdministrador(libroId, quehacer: 'cambia su visibilidad');
    if (libro.visibilidad == visibilidad) return;
    await repositorio.cambiarVisibilidadLibro(libroId, visibilidad);
  }

  /// Archiva un compartido: solo lectura para todos. Es solo una decisión
  /// explícita de su administrador (salirse alguien ya no lo archiva).
  Future<void> archivarLibro(String libroId) async {
    final libro = _delAdministrador(libroId, quehacer: 'lo archiva');
    if (libro.archivado) return;
    await repositorio.archivarLibro(libroId, archivado: true);
  }

  /// Reactiva un compartido archivado (solo su administrador).
  Future<void> reactivarLibro(String libroId) async {
    final libro = _delAdministrador(libroId, quehacer: 'lo reactiva');
    if (!libro.archivado) return;
    await repositorio.archivarLibro(libroId, archivado: false);
  }

  /// `true` si la persona cambia la membresía de otros en [libro]: quien lo
  /// creó o el dueño del hogar si es miembro.
  bool _administraMiembros(Libro libro) =>
      !soloLectura &&
      libro.tipo == TipoLibro.compartido &&
      (libro.esAdministrador(personaId) ||
          (esDueno && libro.papelDe(personaId, hoy) != null && !libro.archivado));

  /// Agrega a [persona] a un compartido (su administrador).
  Future<void> agregarMiembroLibro(String libroId, String persona) async {
    final libro = _libro(libroId);
    if (!_administraMiembros(libro)) {
      throw ErrorFinanzas('Solo quien creó ${libro.nombre} agrega miembros.');
    }
    if (libro.papelDe(persona, hoy) != null) {
      throw const ErrorFinanzas('Esa persona ya es miembro.');
    }
    await repositorio.agregarMiembro(libroId, persona);
  }

  /// Saca a [persona] de un compartido (su administrador). Si quedan menos de
  /// 2 miembros, el presupuesto pasa a **privado** y sigue activo (2.ª ronda
  /// del 23/oct/2026); archivarlo es una acción aparte.
  Future<void> quitarMiembroLibro(String libroId, String persona) async {
    final libro = _libro(libroId);
    if (persona == personaId) return salirDelLibro(libroId);
    if (!_administraMiembros(libro)) {
      throw ErrorFinanzas('Solo quien creó ${libro.nombre} saca miembros.');
    }
    if (libro.papelDe(persona, hoy) == null) return;
    await repositorio.quitarMiembro(libroId, persona);
  }

  /// La persona se sale del libro (cualquier miembro puede, menos el último).
  /// Si quedan menos de 2 miembros, el presupuesto pasa a privado y sigue
  /// activo para quien se queda, que queda como administrador.
  Future<void> salirDelLibro(String libroId) async {
    final libro = _libro(libroId);
    if (soloLectura || libro.papelDe(personaId, hoy) == null) {
      throw const ErrorFinanzas('No eres miembro de ese libro.');
    }
    if (!libro.puedeSalir(personaId, hoy)) {
      throw ErrorFinanzas(
        'Eres el último miembro de ${libro.nombre}: no puedes salirte. Para '
        'dejar de usarlo, archívalo.',
      );
    }
    await repositorio.salirDelLibro(libroId);
  }

  /// `true` si el cargo [papel] del libro de papá [libroId] está vacío (se
  /// puede nombrar con [nombrarAlbacea]).
  bool cargoVacio(String libroId, PapelLibro papel) {
    final libro = _d.libro(libroId);
    if (libro == null) return false;
    return cargoVacioEnLibro(
      libro,
      papel,
      repositorio.actual?.adultosConFinanzas ?? const {},
      hoy,
    );
  }

  /// El **dueño** del hogar nombra albacea o suplente del libro de papá cuando
  /// ese cargo quedó vacío (o lo ocupa alguien que ya no es adulto con
  /// Finanzas): `fin_nombrar_albacea`, la única puerta (un INSERT directo ya no
  /// pasa).
  Future<void> nombrarAlbacea(
    String libroId,
    String persona, {
    PapelLibro papel = PapelLibro.albacea,
  }) async {
    if (soloLectura || !esDueno) {
      throw const ErrorFinanzas(
        'Solo el dueño del hogar nombra al albacea del libro de papá.',
      );
    }
    final libro = _libro(libroId);
    if (libro.tipo != TipoLibro.representado) {
      throw const ErrorFinanzas(
        'Solo el libro de una persona representada tiene albacea.',
      );
    }
    if (papel != PapelLibro.albacea && papel != PapelLibro.albaceaSuplente) {
      throw const ErrorFinanzas('El cargo es albacea o suplente.');
    }
    final adultos = repositorio.actual?.adultosConFinanzas ?? const <String>{};
    if (adultos.isNotEmpty && !adultos.contains(persona)) {
      throw const ErrorFinanzas(
        'Solo un adulto con Finanzas del hogar lleva un libro.',
      );
    }
    if (persona == libro.titularId) {
      throw const ErrorFinanzas(
        'La persona representada no es miembro de su libro.',
      );
    }
    if (!cargoVacio(libroId, papel)) {
      throw const ErrorFinanzas(
        'Ese cargo ya lo ocupa alguien: quien lo tiene debe dejarlo primero.',
      );
    }
    if (libro.papelDe(persona, hoy) != null) {
      throw const ErrorFinanzas(
        'Esa persona ya lleva el libro con otro cargo: que lo deje primero.',
      );
    }
    await repositorio.nombrarAlbacea(
      libroId: libroId,
      personaId: persona,
      papel: papel,
    );
  }

  /// Crea el libro de una persona representada (papá, sin cuenta; D19):
  /// quien lo crea queda como albacea y [suplenteId], si se da, como
  /// suplente. Lo hace el dueño (RPC `fin_crear_libro_representado`). El id
  /// sale del nombre: reintentar no crea otra persona.
  Future<String> crearLibroRepresentado(
    String nombreTitular, {
    String? nombreLibro,
    String? suplenteId,
  }) async {
    _exigirHogar();
    if (nombreTitular.trim().isEmpty) {
      throw const ErrorFinanzas('Escribe el nombre de la persona.');
    }
    if (suplenteId == personaId) {
      throw const ErrorFinanzas('El suplente es otra persona.');
    }
    final id = idEstable(
      ClavesId.libroRepresentado(hogarId, nombreTitular.trim()),
    );
    await repositorio.crearLibroRepresentado(
      id: id,
      nombreTitular: nombreTitular.trim(),
      nombreLibro: nombreLibro?.trim(),
      suplenteId: suplenteId,
    );
    return id;
  }

  // --------------------------------------------------------------------- plan

  VistaSemana vista(String libroId, Semana semana) =>
      vistaSemana(_d, libroId, semana, hoy: hoy);

  /// Activa la semana con la foto del plan (estado `activa`).
  Future<SemanaGuardada> activarSemana(String libroId, Semana semana) async {
    _exigirEscribir(libroId);
    if (_d.semanaGuardada(libroId, semana) != null) {
      throw const ErrorFinanzas('Esa semana ya está activada.');
    }
    final plan = armarPlanDelLibro(_d, libroId, semana);
    // Ids estables: la semana es única por (libro, lunes) y sus partidas por
    // (semana, origen); reintentar una activación a medias no choca.
    final foto = fotoDelPlan(
      plan,
      id: idEstable(ClavesId.semana(libroId, '${semana.inicio}')),
      libroId: libroId,
      arrastrePorOrigen: arrastresPorOrigen(_d, libroId, semana),
      activadaPor: personaId,
      activadaEn: _ahora,
      idPara: idEstable,
    );
    await repositorio.guardarSemana(foto);
    return foto;
  }

  /// Cierra la semana (revisión de 3 minutos): guarda la foto del cierre y del
  /// balance. No mueve dinero: aplicar el remanente es otra acción.
  Future<CierreGuardado> cerrarSemana(
    String libroId,
    Semana semana, {
    AccionCierre accion = AccionCierre.sinAplicar,
    bool conPendientes = false,
  }) async {
    _exigirEscribir(libroId);
    final v = vista(libroId, semana);
    if (v.guardada == null) {
      throw const ErrorFinanzas('Activa la semana antes de cerrarla.');
    }
    if (v.estado == EstadoSemana.cerrada) {
      throw const ErrorFinanzas('La semana ya está cerrada.');
    }
    final g = v.guardada!;
    final version = g.versionDelSiguienteCierre;
    final id = idEstable(ClavesId.cierre(g.id, version));
    // Si un intento anterior ya guardó el cierre de esta versión (y falló al
    // cerrar la semana), se reusa tal cual: mismo id y mismo contenido.
    final previo = _d.cierres.where((x) => x.id == id).firstOrNull;
    final cierre =
        previo ??
        cierreDeLaVista(
          v,
          _d,
          id: id,
          accion: accion,
          cerradoPor: personaId,
          cerradoEn: _ahora,
          conPendientes: conPendientes,
        );
    await repositorio.agregarCierre(cierre, libroId: libroId);
    return cierre;
  }

  /// Cierra con pendientes las semanas que pasaron 3 días sin cerrar
  /// (5.9 bis, punto 4). Devuelve cuántas cerró.
  Future<int> cerrarSemanasVencidas(String libroId) async {
    if (!permiso(libroId).escribir) return 0;
    var cerradas = 0;
    final abiertas = _d.semanas
        .where((s) => s.libroId == libroId && s.estado != EstadoSemana.cerrada)
        .toList()
      ..sort((a, b) => a.semana.compareTo(b.semana));
    for (final s in abiertas) {
      if (!vista(libroId, s.semana).debeCerrarseSola) continue;
      await cerrarSemana(
        libroId,
        s.semana,
        accion: AccionCierre.cierreAutomatico,
        conPendientes: true,
      );
      cerradas++;
    }
    return cerradas;
  }

  /// Reabre una semana cerrada (con confirmación); queda en la bitácora y el
  /// siguiente cierre es la versión siguiente.
  Future<void> reabrirSemana(String libroId, Semana semana) async {
    _exigirEscribir(libroId);
    final g = _d.semanaGuardada(libroId, semana);
    if (g == null || g.estado != EstadoSemana.cerrada) {
      throw const ErrorFinanzas('Solo se reabre una semana cerrada.');
    }
    await repositorio.cambiarEstadoSemana(g.id, EstadoSemana.activa);
  }

  /// Aplica el remanente que propuso el cierre: abono extra a cada deuda (pago
  /// de deuda) y ahorro (transferencia). Solo con la confirmación de la
  /// persona (5.6 bis, punto 6, regla 6).
  ///
  /// Con [cierreId], los movimientos llevan ids estables (uno por deuda y uno
  /// de ahorro por cierre): aplicar dos veces el mismo cierre no duplica.
  Future<List<Movimiento>> aplicarRemanente({
    required String libroId,
    required DestinoRemanente destino,
    required String cuentaOrigenId,
    String? cuentaAhorroId,
    String? motivo,
    String? cierreId,
  }) async {
    _exigirEscribir(libroId);
    final quien = _quien(libroId, motivo);
    String idPara(String destino) => cierreId == null
        ? _generarId()
        : idEstable(ClavesId.remanente(cierreId, destino));
    final movimientos = <Movimiento>[];
    for (final a in destino.abonosExtra) {
      final deuda = _d.deudas.where((x) => x.id == a.deuda.id).firstOrNull;
      final pasivo = deuda?.cuentaPasivoId;
      if (pasivo == null || a.monto <= 0) continue;
      movimientos.add(
        Movimiento(
          id: idPara(a.deuda.id),
          tipo: TipoMovimiento.pagoDeuda,
          fecha: hoy,
          registradoEn: _ahora,
          cuentaOrigenId: cuentaOrigenId,
          cuentaDestinoId: pasivo,
          monto: a.monto,
          realizadoPor: quien.realizadoPor,
          registradoPor: personaId,
          nota: 'Abono extra con el remanente',
          motivo: _limpio(motivo),
          enNombreDe: quien.enNombreDe,
        ),
      );
    }
    if (destino.ahorro > 0 && cuentaAhorroId != null) {
      movimientos.add(
        Movimiento(
          id: idPara('ahorro'),
          tipo: TipoMovimiento.transferencia,
          fecha: hoy,
          registradoEn: _ahora,
          cuentaOrigenId: cuentaOrigenId,
          cuentaDestinoId: cuentaAhorroId,
          monto: destino.ahorro,
          realizadoPor: quien.realizadoPor,
          registradoPor: personaId,
          nota: 'Ahorro con el remanente',
          motivo: _limpio(motivo),
          enNombreDe: quien.enNombreDe,
        ),
      );
    }
    if (movimientos.isEmpty) return movimientos;
    // Los que ya están (mismo id) no se repiten.
    final ya = {for (final m in _d.movimientos) m.id};
    final nuevos = [
      for (final m in movimientos)
        if (!ya.contains(m.id)) m,
    ];
    if (nuevos.isNotEmpty) await repositorio.agregarMovimientos(nuevos);
    return movimientos;
  }

  /// Marca un ingreso esperado como llegado, retrasado o que no llegará: uno
  /// que no llegó resta completo en su semana (regla 33).
  Future<void> marcarIngreso(
    String libroId,
    Vencimiento v,
    EstadoOcurrencia estado,
  ) async {
    _exigirEscribir(libroId);
    // Si dos pagos del mismo ingreso caen el mismo día (30 y último en
    // febrero; M4), la ocurrencia (única por fecha programada) vale los dos.
    final delDia = vencimientosEntre(
      _d,
      libroId,
      v.fecha.ajustada,
      v.fecha.ajustada,
    ).where(
      (x) =>
          x.origen == v.origen &&
          x.origenId == v.origenId &&
          x.fecha.programada == v.fecha.programada,
    );
    final montoEsperado = delDia.isEmpty
        ? v.monto
        : delDia.fold<int>(0, (t, x) => t + x.monto);
    final existente = _d.ocurrencias
        .where(
          (o) =>
              o.libroId == libroId &&
              o.origenId == v.origenId &&
              o.fechaProgramada == v.fecha.programada,
        )
        .firstOrNull;
    await repositorio.guardarOcurrencia(
      existente?.conEstado(estado) ??
          Ocurrencia(
            id: idEstable(
              ClavesId.ocurrencia(
                libroId,
                v.origen.name,
                v.origenId,
                '${v.fecha.programada}',
              ),
            ),
            libroId: libroId,
            origen: v.origen,
            origenId: v.origenId,
            fechaProgramada: v.fecha.programada,
            fechaAjustada: v.fecha.ajustada,
            montoEsperado: montoEsperado,
            estado: estado,
          ),
    );
  }
}

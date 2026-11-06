import 'motivo.dart';
import 'fecha.dart';
import 'semana.dart';

/// Clases contables de 5.0 bis 2, punto 1 ("¿qué tengo?, ¿qué debo?, ¿qué
/// entra y qué sale?"), más dos clases técnicas para que la partida doble
/// cuadre: [ajuste] (la cuenta "Ajustes" de la conciliación), [apertura]
/// (contrapartida de los saldos iniciales) y [entreLibros] (lo que entra o
/// sale hacia otro libro del hogar, D19: aportaciones a un compartido).
enum ClaseCuenta {
  activo,
  pasivo,
  ingreso,
  gasto,
  ajuste,
  apertura,
  entreLibros,
}

/// Tipos de cuenta del MVP 1 (5.0 bis y 5.0 bis 2, punto 5).
///
/// "Individual" y "compartida" no son tipos sino dueños de la cuenta; en el
/// MVP 1 (modo Individual) todas las cuentas son del dueño.
enum TipoCuenta {
  efectivo(ClaseCuenta.activo, liquida: true),
  banco(ClaseCuenta.activo, liquida: true),
  ahorro(ClaseCuenta.activo),
  inversion(ClaseCuenta.activo),

  /// Préstamos hechos a otros (cuenta por cobrar). Se usa desde la Fase 2.
  porCobrar(ClaseCuenta.activo),
  tarjeta(ClaseCuenta.pasivo),

  /// Préstamos y créditos. Se usa desde la Fase 2.
  prestamo(ClaseCuenta.pasivo),

  /// Origen de las entradas: salario, extras, rendimientos (5.1).
  origenIngreso(ClaseCuenta.ingreso),

  /// Cuenta de gasto por rubro (5.0 bis): recibe el presupuesto semanal.
  deGasto(ClaseCuenta.gasto),

  /// Intereses y cargos (5.0 bis 2): gasto, pero aparte en los reportes.
  gastoFinanciero(ClaseCuenta.gasto),

  /// Captura rápida sin categoría: es gasto, pero no entra a los reportes por
  /// rubro hasta clasificarla (5.0 bis 2, punto 5).
  porClasificar(ClaseCuenta.gasto),

  /// Recibe las diferencias de conciliación; siempre visible en la auditoría.
  ajustes(ClaseCuenta.ajuste),

  /// Contrapartida técnica de los saldos iniciales (no se muestra).
  apertura(ClaseCuenta.apertura),

  /// Cuenta **virtual** que representa a otro libro del hogar en la vista de
  /// un libro (D19, regla 1 de 4.5): una aportación de "Mi libro" a "Gastos
  /// de la casa" sale de mi banco hacia esta cuenta. Nunca se guarda.
  otroLibro(ClaseCuenta.entreLibros);

  final ClaseCuenta clase;

  /// Cuenta líquida: entra al "disponible" (5.0 bis 2, punto 7).
  final bool liquida;

  const TipoCuenta(this.clase, {this.liquida = false});
}

/// Ciclo de vida de una cuenta (5.0 bis 2, punto 5).
enum EstadoCuenta { activa, congelada, cerrada, archivada }

class Cuenta {
  final String id;
  final String nombre;
  final TipoCuenta tipo;
  final EstadoCuenta estado;

  /// Categoría ligada (solo en cuentas de gasto por rubro).
  final String? categoriaId;

  /// Persona titular; nulo = del hogar (en el MVP 1 todas son del Dueño).
  final String? titularId;

  /// Límite de crédito de una tarjeta (opcional, centavos).
  final int? limiteCentavos;

  /// Libro al que pertenece (D19). Nulo = del **hogar**: las cuentas de gasto
  /// por rubro son comunes a todos los libros (regla 2 de 4.5).
  final String? libroId;

  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.estado = EstadoCuenta.activa,
    this.categoriaId,
    this.titularId,
    this.limiteCentavos,
    this.libroId,
  });

  /// `true` si es común a todo el hogar (sin libro).
  bool get delHogar => libroId == null;

  ClaseCuenta get clase => tipo.clase;

  Cuenta conEstado(EstadoCuenta nuevo) => copiar(estado: nuevo);

  /// Copia con cambios (el id y el tipo no cambian: el libro depende de ellos).
  Cuenta copiar({
    String? nombre,
    EstadoCuenta? estado,
    String? categoriaId,
    String? titularId,
    int? limiteCentavos,
  }) => Cuenta(
    id: id,
    nombre: nombre ?? this.nombre,
    tipo: tipo,
    estado: estado ?? this.estado,
    categoriaId: categoriaId ?? this.categoriaId,
    titularId: titularId ?? this.titularId,
    limiteCentavos: limiteCentavos ?? this.limiteCentavos,
    libroId: libroId,
  );

  @override
  String toString() => '$nombre ($id)';
}

/// Tipos de movimiento del MVP 1 (tabla de 5.0 bis 2, punto 2).
///
/// Quedan para la Fase 2 o después: préstamo recibido (`ingreso_financiado`),
/// préstamo a un familiar, devolución y rendimientos de inversión.
enum TipoMovimiento {
  /// Saldo inicial de una cuenta, con fecha. No se edita (5.0 bis 2, punto 5).
  apertura,

  /// Sueldo o extra: origen de ingreso → banco o efectivo.
  ingreso,

  /// Gasto con efectivo, débito o tarjeta: activo o tarjeta → cuenta de gasto.
  gasto,

  /// Reembolso de un gasto: baja el gasto, no es ingreso (5.1 bis, punto 1).
  reembolso,

  /// Entre cuentas propias: depósito o retiro de efectivo, aportación a ahorro.
  transferencia,

  /// Pago de capital a una tarjeta o préstamo (los intereses son un gasto
  /// aparte, a la cuenta de gasto financiero).
  pagoDeuda,

  /// Clasifica un gasto capturado en "Por clasificar".
  reclasificacion,

  /// Diferencia de conciliación (motivo obligatorio).
  ajuste,

  /// Contraasiento: el mismo movimiento con origen y destino invertidos.
  anulacion,
}

/// Vía de captura del movimiento (5.0 bis). Voz, imagen y QR llegan después
/// del MVP 1; se dejan en el modelo para no cambiarlo.
enum ViaCaptura { manual, voz, imagen, qr, importacion }

/// Estados de confirmación (5.0 bis y 5.0 ter). "Anulado" no es un estado del
/// movimiento: se deduce de que exista un contraasiento confirmado.
enum EstadoMovimiento { pendiente, confirmado, enRevision, rechazado }

/// Un asiento del libro (entidad `Movimiento`, sección 7). Es **inmutable**:
/// nunca se edita ni se borra; se corrige con [TipoMovimiento.anulacion].
class Movimiento {
  /// UUID generado en el dispositivo (la cola sin conexión es idempotente).
  final String id;
  final TipoMovimiento tipo;

  /// Fecha económica: define la semana a la que pertenece (5.6 bis, punto 2).
  final Fecha fecha;

  /// Cuándo se capturó.
  final DateTime registradoEn;
  final String cuentaOrigenId;
  final String cuentaDestinoId;

  /// Centavos, siempre positivo; la dirección la dan origen y destino.
  final int monto;

  /// Quién lo hizo y quién lo capturó (pueden ser distintos: albacea).
  final String realizadoPor;
  final String registradoPor;
  final ViaCaptura via;

  /// Subcategoría o detalle (niveles 2 y 3) dentro de la cuenta de gasto.
  final String? categoriaId;

  /// Agrupa los movimientos de una misma operación: las líneas de un ticket
  /// dividido o el capital y los intereses de un pago de tarjeta.
  final String? grupoId;
  final String? nota;

  /// Obligatorio en ajustes y anulaciones.
  final String? motivo;

  /// En un contraasiento, el movimiento que anula.
  final String? anulaA;

  /// Persona en cuyo nombre se registra: el albacea en el libro de papá
  /// (D19, regla 3 de 4.5). Exige [motivo].
  final String? enNombreDe;

  /// Estado con el que nace: confirmado, o pendiente si otra persona debe
  /// confirmarlo (5.0 ter).
  final EstadoMovimiento estadoInicial;

  Movimiento({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.registradoEn,
    required this.cuentaOrigenId,
    required this.cuentaDestinoId,
    required this.monto,
    required this.realizadoPor,
    String? registradoPor,
    this.via = ViaCaptura.manual,
    this.categoriaId,
    this.grupoId,
    this.nota,
    this.motivo,
    this.anulaA,
    this.enNombreDe,
    this.estadoInicial = EstadoMovimiento.confirmado,
  }) : registradoPor = registradoPor ?? realizadoPor {
    if (estadoInicial != EstadoMovimiento.confirmado &&
        estadoInicial != EstadoMovimiento.pendiente) {
      throw ArgumentError('Un movimiento nace confirmado o pendiente');
    }
  }

  /// El mismo movimiento con otras cuentas (para la vista de un libro, donde
  /// la cuenta de otro libro se cambia por una virtual).
  Movimiento conCuentas(String origen, String destino) => Movimiento(
    id: id,
    tipo: tipo,
    fecha: fecha,
    registradoEn: registradoEn,
    cuentaOrigenId: origen,
    cuentaDestinoId: destino,
    monto: monto,
    realizadoPor: realizadoPor,
    registradoPor: registradoPor,
    via: via,
    categoriaId: categoriaId,
    grupoId: grupoId,
    nota: nota,
    motivo: motivo,
    anulaA: anulaA,
    enNombreDe: enNombreDe,
    estadoInicial: estadoInicial,
  );

  bool mismoContenido(Movimiento o) =>
      o.id == id &&
      o.tipo == tipo &&
      o.fecha == fecha &&
      o.registradoEn == registradoEn &&
      o.cuentaOrigenId == cuentaOrigenId &&
      o.cuentaDestinoId == cuentaDestinoId &&
      o.monto == monto &&
      o.realizadoPor == realizadoPor &&
      o.registradoPor == registradoPor &&
      o.via == via &&
      o.categoriaId == categoriaId &&
      o.grupoId == grupoId &&
      o.nota == nota &&
      o.motivo == motivo &&
      o.anulaA == anulaA &&
      o.enNombreDe == enNombreDe &&
      o.estadoInicial == estadoInicial;

  @override
  String toString() =>
      '$tipo $id $fecha $cuentaOrigenId→$cuentaDestinoId $monto';
}

/// Confirmación, rechazo o revisión de un movimiento pendiente (5.0 ter).
/// Se agrega al libro; nunca se edita.
class Confirmacion {
  final String movimientoId;
  final EstadoMovimiento resultado;
  final String por;

  /// Si el albacea actúa en nombre de otro miembro.
  final String? enNombreDe;
  final String? motivo;
  final DateTime fechaHora;

  const Confirmacion({
    required this.movimientoId,
    required this.resultado,
    required this.por,
    required this.fechaHora,
    this.enNombreDe,
    this.motivo,
  });
}

/// Error de una regla del libro (movimiento inválido o acción prohibida).
class ErrorLibro implements Exception {
  final String mensaje;
  const ErrorLibro(this.mensaje);

  @override
  String toString() => 'ErrorLibro: $mensaje';
}

/// Activos, pasivos y patrimonio a una fecha (5.0 bis 2, puntos 3 y 4).
///
/// **Cuadre por libro (D19):** una aportación entre libros (transferencia o
/// pago de deuda que cruza de un libro a otro) cambia el patrimonio de cada
/// libro **sin pasar por su resultado**: no es ingreso del que la recibe ni
/// gasto del que la entrega. Por eso el cuadre de cada libro es
///
/// `patrimonio final = inicial + resultado + ajustes + recibidas − entregadas`.
class Balance {
  final int activos;
  final int pasivos;

  /// Saldos iniciales netos (cuenta técnica de apertura).
  final int patrimonioInicial;

  /// Ingresos − gastos acumulados.
  final int resultadoAcumulado;
  final int ajustes;

  /// Aportaciones que **entraron** al libro desde otros libros (netas de sus
  /// anulaciones): suben un activo o bajan un pasivo de este libro.
  final int aportacionesRecibidas;

  /// Aportaciones que **salieron** del libro hacia otros libros (netas de sus
  /// anulaciones): bajan un activo de este libro.
  final int aportacionesEntregadas;

  const Balance({
    required this.activos,
    required this.pasivos,
    required this.patrimonioInicial,
    required this.resultadoAcumulado,
    required this.ajustes,
    this.aportacionesRecibidas = 0,
    this.aportacionesEntregadas = 0,
  });

  int get patrimonio => activos - pasivos;

  /// Aportaciones netas: recibidas − entregadas.
  int get entreLibros => aportacionesRecibidas - aportacionesEntregadas;

  /// Patrimonio que dan las cuentas de resultado y las aportaciones:
  /// inicial + resultado + ajustes + recibidas − entregadas.
  int get patrimonioEsperado =>
      patrimonioInicial +
      resultadoAcumulado +
      ajustes +
      aportacionesRecibidas -
      aportacionesEntregadas;

  /// Diferencia del cuadre: patrimonio − [patrimonioEsperado]. Cero si todo
  /// cuadra; distinto de cero es un "descuadre".
  int get descuadre => patrimonio - patrimonioEsperado;

  bool get cuadra => descuadre == 0;
}

/// Estado de resultados de un periodo (5.0 bis 2, punto 4).
class EstadoResultados {
  final Periodo periodo;
  final int ingresos;

  /// Gasto sin el financiero.
  final int gastos;
  final int gastoFinanciero;

  const EstadoResultados({
    required this.periodo,
    required this.ingresos,
    required this.gastos,
    required this.gastoFinanciero,
  });

  int get resultado => ingresos - gastos - gastoFinanciero;
}

/// Resultado de una conciliación (5.0 bis 2, punto 6).
class Conciliacion {
  final String cuentaId;
  final Fecha fecha;
  final int saldoDeclarado;
  final int saldoCalculado;

  /// Movimiento de ajuste creado (nulo si no hubo diferencia).
  final Movimiento? ajuste;

  const Conciliacion({
    required this.cuentaId,
    required this.fecha,
    required this.saldoDeclarado,
    required this.saldoCalculado,
    this.ajuste,
  });

  int get diferencia => saldoDeclarado - saldoCalculado;
}

/// Libro de movimientos **solo-agregar** con partida doble simplificada
/// (5.0 bis y 5.0 bis 2).
///
/// - Cada movimiento tiene origen y destino con el mismo monto.
/// - No hay forma de editar ni borrar un movimiento: se anula con
///   [anular], que agrega un contraasiento.
/// - Los saldos no se guardan: se calculan desde los movimientos.
/// - Agregar dos veces el mismo movimiento (mismo id y contenido) no hace nada
///   (idempotencia de la cola sin conexión).
class LibroMovimientos {
  final Map<String, Cuenta> _cuentas = {};
  final List<Movimiento> _movimientos = [];
  final Map<String, Movimiento> _porId = {};
  final List<Confirmacion> _confirmaciones = [];
  final Map<String, EstadoMovimiento> _estado = {};
  final Map<String, List<String>> _contraasientos = {};

  LibroMovimientos({Iterable<Cuenta> cuentas = const []}) {
    cuentas.forEach(abrirCuenta);
  }

  /// Vuelve a armar el libro con lo que ya está guardado (en el servidor o en
  /// la copia local).
  ///
  /// Los movimientos se agregan en el orden en que se registraron
  /// ([Movimiento.registradoEn], luego el id) con todas las cuentas abiertas,
  /// y al final cada cuenta toma su estado guardado: un movimiento viejo de
  /// una cuenta que hoy está cerrada sigue contando. Lo que no pasa las reglas
  /// del libro no se agrega y queda en [rechazadosAlRestaurar] (el servidor
  /// repite las mismas reglas, así que no debería pasar).
  ///
  /// Con [validar] en `false` se confía en lo guardado (el servidor ya aplicó
  /// las mismas reglas con todas las cuentas del hogar): sirve para armar la
  /// vista de un libro, donde las cuentas de otros libros son virtuales
  /// ([TipoCuenta.otroLibro]). Lo que se agregue después sí se valida.
  factory LibroMovimientos.restaurar({
    required Iterable<Cuenta> cuentas,
    Iterable<Movimiento> movimientos = const [],
    Iterable<Confirmacion> confirmaciones = const [],
    bool validar = true,
  }) {
    final libro = LibroMovimientos().._confiar = !validar;
    final guardadas = cuentas.toList();
    for (final c in guardadas) {
      libro.abrirCuenta(c.conEstado(EstadoCuenta.activa));
    }
    final ordenados = movimientos.toList()
      ..sort((a, b) {
        final r = a.registradoEn.compareTo(b.registradoEn);
        if (r != 0) return r;
        // Un contraasiento siempre va después de su original.
        if (a.anulaA == b.id) return 1;
        if (b.anulaA == a.id) return -1;
        return a.id.compareTo(b.id);
      });
    for (final m in ordenados) {
      try {
        libro.agregar(m);
      } on ErrorLibro catch (e) {
        libro._rechazados.add((m, e.mensaje));
      }
    }
    for (final c in confirmaciones) {
      try {
        libro._resolver(
          c.movimientoId,
          c.resultado,
          por: c.por,
          fechaHora: c.fechaHora,
          enNombreDe: c.enNombreDe,
          motivo: c.motivo,
        );
      } on ErrorLibro catch (e) {
        libro._rechazados.add((libro._porId[c.movimientoId]!, e.mensaje));
      }
    }
    for (final c in guardadas) {
      libro._cuentas[c.id] = c;
    }
    libro._confiar = false;
    return libro;
  }

  /// Mientras se restaura sin validar.
  bool _confiar = false;

  final List<(Movimiento, String)> _rechazados = [];

  /// Movimientos guardados que no pasaron las reglas al restaurar, con el
  /// motivo.
  List<(Movimiento, String)> get rechazadosAlRestaurar =>
      List.unmodifiable(_rechazados);

  // ---------------------------------------------------------------- cuentas

  List<Cuenta> get cuentas => List.unmodifiable(_cuentas.values);

  Cuenta cuenta(String id) =>
      _cuentas[id] ?? (throw ErrorLibro('No existe la cuenta $id'));

  void abrirCuenta(Cuenta cuenta) {
    if (_cuentas.containsKey(cuenta.id)) {
      throw ErrorLibro('Ya existe la cuenta ${cuenta.id}');
    }
    _cuentas[cuenta.id] = cuenta;
  }

  bool tieneMovimientos(String cuentaId) => _movimientos.any(
    (m) => m.cuentaOrigenId == cuentaId || m.cuentaDestinoId == cuentaId,
  );

  /// Cambia el estado de una cuenta. Una cuenta de **activos o pasivos** solo
  /// se cierra o se archiva con saldo cero y sin movimientos pendientes (5.0 bis
  /// 2, punto 5; prueba 6). Las de **gasto e ingreso** se cierran o archivan
  /// sin pedir saldo cero (respuestas del dueño del 23/oct/2026): lo gastado o
  /// ingresado queda en su historia y ya no admiten movimientos nuevos.
  void cambiarEstadoCuenta(String cuentaId, EstadoCuenta nuevo) {
    final actual = cuenta(cuentaId);
    if ((nuevo == EstadoCuenta.cerrada || nuevo == EstadoCuenta.archivada) &&
        (actual.clase == ClaseCuenta.activo ||
            actual.clase == ClaseCuenta.pasivo)) {
      if (saldo(cuentaId, incluirPendientes: true) != 0 ||
          saldo(cuentaId) != 0) {
        throw ErrorLibro(
          'Solo se cierra o archiva una cuenta con saldo cero: $actual',
        );
      }
    }
    _cuentas[cuentaId] = actual.conEstado(nuevo);
  }

  /// Elimina una cuenta **sin movimientos**. Con movimientos no se borra: se
  /// cierra o se archiva (5.0 bis 2, punto 5).
  void eliminarCuenta(String cuentaId) {
    cuenta(cuentaId);
    if (tieneMovimientos(cuentaId)) {
      throw ErrorLibro(
        'La cuenta $cuentaId tiene movimientos: ciérrala o archívala',
      );
    }
    _cuentas.remove(cuentaId);
  }

  // ----------------------------------------------------------- movimientos

  List<Movimiento> get movimientos => List.unmodifiable(_movimientos);

  List<Confirmacion> get confirmaciones => List.unmodifiable(_confirmaciones);

  Movimiento movimiento(String id) =>
      _porId[id] ?? (throw ErrorLibro('No existe el movimiento $id'));

  /// Agrega un movimiento después de validar las reglas del libro.
  ///
  /// Devuelve el movimiento guardado. Si ya existía uno con el mismo id y el
  /// mismo contenido, no hace nada; con otro contenido, falla (no se edita).
  Movimiento agregar(Movimiento m) {
    final existente = _porId[m.id];
    if (existente != null) {
      if (existente.mismoContenido(m)) return existente;
      throw ErrorLibro(
        'Ya existe el movimiento ${m.id} con otro contenido: los movimientos '
        'no se editan, se anulan',
      );
    }
    if (!_confiar) _validar(m);
    _movimientos.add(m);
    _porId[m.id] = m;
    _estado[m.id] = m.estadoInicial;
    final anulado = m.anulaA;
    if (anulado != null) {
      _contraasientos.putIfAbsent(anulado, () => []).add(m.id);
    }
    return m;
  }

  /// Anula [movimientoId] con un contraasiento: el mismo monto con origen y
  /// destino invertidos y motivo obligatorio (5.0 bis, "Auditoría y control").
  ///
  /// Interpretación: el contraasiento lleva **la misma fecha económica** que
  /// el original (si no se indica [fecha]), para que la semana del original se
  /// recalcule (5.6 bis, prueba 9); [registradoEn] marca cuándo se anuló. Las
  /// fotos de cierre ya guardadas no cambian.
  ///
  /// Solo hay anulación total. Para devolver una parte se usa un
  /// [TipoMovimiento.reembolso].
  ///
  /// Si la anulación involucra a otra persona, se crea con
  /// [estado] = pendiente y debe confirmarse (5.0 ter). En el libro de papá
  /// el contraasiento va también [enNombreDe] él (por omisión, el del
  /// original).
  Movimiento anular(
    String movimientoId, {
    required String nuevoId,
    required String motivo,
    required String registradoPor,
    required DateTime registradoEn,
    Fecha? fecha,
    EstadoMovimiento estado = EstadoMovimiento.confirmado,
    String? enNombreDe,
  }) {
    final original = movimiento(movimientoId);
    return agregar(
      Movimiento(
        id: nuevoId,
        tipo: TipoMovimiento.anulacion,
        fecha: fecha ?? original.fecha,
        registradoEn: registradoEn,
        cuentaOrigenId: original.cuentaDestinoId,
        cuentaDestinoId: original.cuentaOrigenId,
        monto: original.monto,
        realizadoPor: original.realizadoPor,
        registradoPor: registradoPor,
        categoriaId: original.categoriaId,
        grupoId: original.grupoId,
        motivo: motivo,
        anulaA: original.id,
        enNombreDe: enNombreDe ?? original.enNombreDe,
        estadoInicial: estado,
      ),
    );
  }

  /// Estado vigente de un movimiento según sus confirmaciones.
  EstadoMovimiento estadoDe(String movimientoId) {
    movimiento(movimientoId);
    return _estado[movimientoId]!;
  }

  /// Contraasiento vigente (pendiente, en revisión o confirmado) del
  /// movimiento, si lo hay.
  Movimiento? contraasientoDe(String movimientoId) {
    for (final id in _contraasientos[movimientoId] ?? const <String>[]) {
      if (_estado[id] != EstadoMovimiento.rechazado) return _porId[id];
    }
    return null;
  }

  /// `true` si el movimiento tiene un contraasiento **confirmado**.
  bool estaAnulado(String movimientoId) {
    final c = contraasientoDe(movimientoId);
    return c != null && _estado[c.id] == EstadoMovimiento.confirmado;
  }

  /// Confirma un movimiento pendiente (o en revisión).
  ///
  /// Quien lo registró o lo realizó no puede confirmarlo. Si el albacea actúa
  /// en nombre de otro miembro ([enNombreDe]), el motivo es obligatorio
  /// (salvaguarda 1 de 5.0 ter).
  void confirmar(
    String movimientoId, {
    required String por,
    required DateTime fechaHora,
    String? enNombreDe,
    String? motivo,
  }) => _resolver(
    movimientoId,
    EstadoMovimiento.confirmado,
    por: por,
    fechaHora: fechaHora,
    enNombreDe: enNombreDe,
    motivo: motivo,
  );

  /// Rechaza un movimiento pendiente: deja de contar en todos los saldos.
  void rechazar(
    String movimientoId, {
    required String por,
    required DateTime fechaHora,
    required String motivo,
    String? enNombreDe,
  }) => _resolver(
    movimientoId,
    EstadoMovimiento.rechazado,
    por: por,
    fechaHora: fechaHora,
    enNombreDe: enNombreDe,
    motivo: motivo,
  );

  /// Pasa un movimiento pendiente a "en revisión" (hay una diferencia).
  void marcarEnRevision(
    String movimientoId, {
    required String por,
    required DateTime fechaHora,
    required String motivo,
  }) => _resolver(
    movimientoId,
    EstadoMovimiento.enRevision,
    por: por,
    fechaHora: fechaHora,
    motivo: motivo,
  );

  void _resolver(
    String movimientoId,
    EstadoMovimiento resultado, {
    required String por,
    required DateTime fechaHora,
    String? enNombreDe,
    String? motivo,
  }) {
    final m = movimiento(movimientoId);
    final actual = _estado[movimientoId]!;
    final permitido =
        actual == EstadoMovimiento.pendiente ||
        (actual == EstadoMovimiento.enRevision &&
            resultado != EstadoMovimiento.enRevision);
    if (!permitido) {
      throw ErrorLibro('El movimiento $movimientoId ya está $actual');
    }
    if (por == m.registradoPor || por == m.realizadoPor) {
      throw ErrorLibro('Quien registra o realiza un movimiento no lo confirma');
    }
    if (enNombreDe != null && _vacio(motivo)) {
      throw const ErrorLibro(
        'Confirmar en nombre de otro miembro exige un motivo',
      );
    }
    if (resultado != EstadoMovimiento.confirmado && _vacio(motivo)) {
      throw const ErrorLibro('Rechazar o pedir revisión exige un motivo');
    }
    _confirmaciones.add(
      Confirmacion(
        movimientoId: movimientoId,
        resultado: resultado,
        por: por,
        fechaHora: fechaHora,
        enNombreDe: enNombreDe,
        motivo: motivo,
      ),
    );
    _estado[movimientoId] = resultado;
  }

  // ---------------------------------------------------------------- saldos

  bool _cuenta(String movimientoId, {required bool incluirPendientes}) {
    final estado = _estado[movimientoId]!;
    if (estado == EstadoMovimiento.confirmado) return true;
    return incluirPendientes &&
        (estado == EstadoMovimiento.pendiente ||
            estado == EstadoMovimiento.enRevision);
  }

  /// Signo "natural" del saldo de cada clase: lo que tengo (activo), lo que
  /// debo (pasivo), lo que entró (ingreso), lo que gasté (gasto), el ajuste
  /// neto y el patrimonio inicial.
  static int _signoComoDestino(ClaseCuenta clase) {
    switch (clase) {
      case ClaseCuenta.activo:
      case ClaseCuenta.gasto:
        return 1;
      case ClaseCuenta.pasivo:
      case ClaseCuenta.ingreso:
      case ClaseCuenta.ajuste:
      case ClaseCuenta.apertura:
      case ClaseCuenta.entreLibros:
        return -1;
    }
  }

  /// Saldo de una cuenta (`saldo = saldo inicial + entradas − salidas`, 5.0
  /// bis) con el signo natural de su clase: en una tarjeta es lo que se debe.
  ///
  /// Por omisión cuenta solo lo **confirmado** ("saldo confirmado"); con
  /// [incluirPendientes] da el "saldo con pendientes" (5.0 bis 2, punto 7).
  /// [desde] y [hasta] limitan por fecha económica, inclusive.
  int saldo(
    String cuentaId, {
    Fecha? desde,
    Fecha? hasta,
    bool incluirPendientes = false,
  }) {
    final signo = _signoComoDestino(cuenta(cuentaId).clase);
    var total = 0;
    for (final m in _movimientos) {
      if (!_cuenta(m.id, incluirPendientes: incluirPendientes)) continue;
      if (desde != null && m.fecha.antesDe(desde)) continue;
      if (hasta != null && m.fecha.despuesDe(hasta)) continue;
      if (m.cuentaDestinoId == cuentaId) total += signo * m.monto;
      if (m.cuentaOrigenId == cuentaId) total -= signo * m.monto;
    }
    return total;
  }

  int _sumaClase(ClaseCuenta clase, {Fecha? desde, Fecha? hasta}) => _cuentas
      .values
      .where((c) => c.clase == clase)
      .fold<int>(0, (t, c) => t + saldo(c.id, desde: desde, hasta: hasta));

  /// Balance a la fecha [al] (o con todo el libro si es nulo).
  Balance balance({Fecha? al}) {
    final (recibidas, entregadas) = aportaciones(hasta: al);
    return Balance(
      activos: _sumaClase(ClaseCuenta.activo, hasta: al),
      pasivos: _sumaClase(ClaseCuenta.pasivo, hasta: al),
      patrimonioInicial: _sumaClase(ClaseCuenta.apertura, hasta: al),
      resultadoAcumulado:
          _sumaClase(ClaseCuenta.ingreso, hasta: al) -
          _sumaClase(ClaseCuenta.gasto, hasta: al),
      ajustes: _sumaClase(ClaseCuenta.ajuste, hasta: al),
      aportacionesRecibidas: recibidas,
      aportacionesEntregadas: entregadas,
    );
  }

  /// Aportaciones con otros libros (D19) como `(recibidas, entregadas)`, con
  /// la fecha económica entre [desde] y [hasta] (inclusive).
  ///
  /// En la vista de un libro, otro libro es una cuenta de clase
  /// [ClaseCuenta.entreLibros]: lo que va **hacia** ella es una aportación
  /// entregada y lo que viene **de** ella, una recibida. La anulación de una
  /// aportación la descuenta de su mismo lado (anular una entregada baja las
  /// entregadas; no cuenta como recibida).
  (int, int) aportaciones({Fecha? desde, Fecha? hasta}) {
    var recibidas = 0;
    var entregadas = 0;
    bool otroLibro(String id) => _cuentas[id]?.clase == ClaseCuenta.entreLibros;
    for (final m in _movimientos) {
      if (!_cuenta(m.id, incluirPendientes: false)) continue;
      if (desde != null && m.fecha.antesDe(desde)) continue;
      if (hasta != null && m.fecha.despuesDe(hasta)) continue;
      final haciaOtro = otroLibro(m.cuentaDestinoId);
      final deOtro = otroLibro(m.cuentaOrigenId);
      if (haciaOtro == deOtro) continue;
      if (m.tipo == TipoMovimiento.anulacion) {
        // El contraasiento invierte el original: si ahora viene de otro
        // libro, el original salió hacia él (era entregada).
        if (deOtro) {
          entregadas -= m.monto;
        } else {
          recibidas -= m.monto;
        }
      } else if (haciaOtro) {
        entregadas += m.monto;
      } else {
        recibidas += m.monto;
      }
    }
    return (recibidas, entregadas);
  }

  /// Estado de resultados de [periodo], con el gasto financiero aparte.
  EstadoResultados estadoResultados(Periodo periodo) {
    var gastos = 0;
    var financiero = 0;
    for (final c in _cuentas.values.where(
      (c) => c.clase == ClaseCuenta.gasto,
    )) {
      final s = saldo(c.id, desde: periodo.inicio, hasta: periodo.fin);
      if (c.tipo == TipoCuenta.gastoFinanciero) {
        financiero += s;
      } else {
        gastos += s;
      }
    }
    return EstadoResultados(
      periodo: periodo,
      ingresos: _sumaClase(
        ClaseCuenta.ingreso,
        desde: periodo.inicio,
        hasta: periodo.fin,
      ),
      gastos: gastos,
      gastoFinanciero: financiero,
    );
  }

  /// "Disponible": efectivo y bancos, sin ahorro ni inversión (5.0 bis 2,
  /// punto 7).
  int disponible({Fecha? al}) => _cuentas.values
      .where((c) => c.tipo.liquida)
      .fold<int>(0, (t, c) => t + saldo(c.id, hasta: al));

  /// Gasto neto de cada cuenta de gasto en [periodo] (lo "gastado" de cada
  /// partida del presupuesto). Incluye anulaciones y reembolsos.
  Map<String, int> gastoPorCuenta(Periodo periodo) => {
    for (final c in _cuentas.values.where((c) => c.clase == ClaseCuenta.gasto))
      c.id: saldo(c.id, desde: periodo.inicio, hasta: periodo.fin),
  };

  /// Cuánto aportó cada persona a una cuenta de gasto en [periodo]
  /// (5.0 bis, "cada miembro decide a cuál aportar").
  Map<String, int> aportacionesPorPersona(
    String cuentaGastoId,
    Periodo periodo,
  ) {
    final c = cuenta(cuentaGastoId);
    if (c.clase != ClaseCuenta.gasto) {
      throw ErrorLibro('$c no es una cuenta de gasto');
    }
    final resultado = <String, int>{};
    for (final m in _movimientos) {
      if (!_cuenta(m.id, incluirPendientes: false)) continue;
      if (!periodo.contiene(m.fecha)) continue;
      var delta = 0;
      if (m.cuentaDestinoId == cuentaGastoId) delta += m.monto;
      if (m.cuentaOrigenId == cuentaGastoId) delta -= m.monto;
      if (delta != 0) {
        resultado[m.realizadoPor] = (resultado[m.realizadoPor] ?? 0) + delta;
      }
    }
    resultado.removeWhere((_, v) => v == 0);
    return resultado;
  }

  /// Concilia una cuenta: compara el [saldoDeclarado] con el calculado a la
  /// [fecha] y, si hay diferencia, registra un **ajuste** contra la cuenta
  /// [cuentaAjustesId] con motivo obligatorio (5.0 bis 2, punto 6).
  Conciliacion conciliar({
    required String cuentaId,
    required Fecha fecha,
    required int saldoDeclarado,
    required String cuentaAjustesId,
    required String idAjuste,
    required String persona,
    required DateTime registradoEn,
    String? motivo,
  }) {
    final c = cuenta(cuentaId);
    if (c.clase != ClaseCuenta.activo && c.clase != ClaseCuenta.pasivo) {
      throw ErrorLibro('Solo se concilian activos y pasivos: $c');
    }
    final calculado = saldo(cuentaId, hasta: fecha);
    final diferencia = saldoDeclarado - calculado;
    if (diferencia == 0) {
      return Conciliacion(
        cuentaId: cuentaId,
        fecha: fecha,
        saldoDeclarado: saldoDeclarado,
        saldoCalculado: calculado,
      );
    }
    // Sube un activo: Ajustes → cuenta. Sube un pasivo: cuenta → Ajustes.
    final sube = diferencia > 0;
    final haciaLaCuenta = c.clase == ClaseCuenta.activo ? sube : !sube;
    final ajuste = agregar(
      Movimiento(
        id: idAjuste,
        tipo: TipoMovimiento.ajuste,
        fecha: fecha,
        registradoEn: registradoEn,
        cuentaOrigenId: haciaLaCuenta ? cuentaAjustesId : cuentaId,
        cuentaDestinoId: haciaLaCuenta ? cuentaId : cuentaAjustesId,
        monto: diferencia.abs(),
        realizadoPor: persona,
        motivo: motivo,
      ),
    );
    return Conciliacion(
      cuentaId: cuentaId,
      fecha: fecha,
      saldoDeclarado: saldoDeclarado,
      saldoCalculado: calculado,
      ajuste: ajuste,
    );
  }

  // ----------------------------------------------------------- validación

  static bool _vacio(String? texto) => texto == null || texto.trim().isEmpty;

  static const _activoOPasivo = {ClaseCuenta.activo, ClaseCuenta.pasivo};

  /// Combinaciones de clase (origen → destino) válidas por tipo
  /// (tabla de 5.0 bis 2, punto 2).
  static const Map<TipoMovimiento, List<(Set<ClaseCuenta>, Set<ClaseCuenta>)>>
  _combinaciones = {
    TipoMovimiento.apertura: [
      ({ClaseCuenta.apertura}, {ClaseCuenta.activo}),
      ({ClaseCuenta.pasivo}, {ClaseCuenta.apertura}),
    ],
    TipoMovimiento.ingreso: [
      ({ClaseCuenta.ingreso}, {ClaseCuenta.activo}),
    ],
    TipoMovimiento.gasto: [
      (_activoOPasivo, {ClaseCuenta.gasto}),
    ],
    TipoMovimiento.reembolso: [
      ({ClaseCuenta.gasto}, _activoOPasivo),
    ],
    TipoMovimiento.transferencia: [
      ({ClaseCuenta.activo}, {ClaseCuenta.activo}),
    ],
    TipoMovimiento.pagoDeuda: [
      ({ClaseCuenta.activo}, {ClaseCuenta.pasivo}),
    ],
    TipoMovimiento.reclasificacion: [
      ({ClaseCuenta.gasto}, {ClaseCuenta.gasto}),
    ],
    TipoMovimiento.ajuste: [
      ({ClaseCuenta.ajuste}, _activoOPasivo),
      (_activoOPasivo, {ClaseCuenta.ajuste}),
    ],
  };

  void _validar(Movimiento m) {
    if (m.monto <= 0) {
      throw ErrorLibro('El monto debe ser mayor que cero (${m.id})');
    }
    if (m.enNombreDe != null && !motivoValido(m.motivo)) {
      throw ErrorLibro(
        'Registrar en nombre de otra persona exige un motivo de al menos 3 '
        'caracteres visibles (${m.id})',
      );
    }
    if (m.cuentaOrigenId == m.cuentaDestinoId) {
      throw ErrorLibro('Origen y destino deben ser distintos (${m.id})');
    }
    final origen = cuenta(m.cuentaOrigenId);
    final destino = cuenta(m.cuentaDestinoId);

    if (m.tipo == TipoMovimiento.anulacion) {
      _validarAnulacion(m, origen, destino);
      return;
    }
    if (m.anulaA != null) {
      throw ErrorLibro('Solo un contraasiento puede anular otro movimiento');
    }
    for (final c in [origen, destino]) {
      if (c.estado != EstadoCuenta.activa) {
        throw ErrorLibro(
          'La cuenta $c está ${c.estado}: no admite movimientos',
        );
      }
    }
    final valida = _combinaciones[m.tipo]!.any(
      (par) => par.$1.contains(origen.clase) && par.$2.contains(destino.clase),
    );
    if (!valida) {
      throw ErrorLibro(
        'Un movimiento de tipo ${m.tipo.name} no puede ir de '
        '${origen.clase.name} a ${destino.clase.name} (${m.id})',
      );
    }
    // D19 (regla 5 del trigger): solo una transferencia o un pago de deuda
    // cruzan de un libro a otro (aportación); su anulación, por ser el
    // espejo del original, también. Las cuentas de gasto del hogar no tienen
    // libro y no cuentan como cruce.
    final libroOrigen = origen.libroId;
    final libroDestino = destino.libroId;
    if (libroOrigen != null &&
        libroDestino != null &&
        libroOrigen != libroDestino &&
        m.tipo != TipoMovimiento.transferencia &&
        m.tipo != TipoMovimiento.pagoDeuda) {
      throw ErrorLibro(
        'Solo una transferencia o un pago de deuda va de un libro a otro '
        '(${m.id})',
      );
    }
    switch (m.tipo) {
      case TipoMovimiento.ajuste:
        if (!motivoValido(m.motivo)) {
          throw const ErrorLibro(
            'Un ajuste exige un motivo de al menos 3 caracteres visibles',
          );
        }
      case TipoMovimiento.reclasificacion:
        if (origen.tipo != TipoCuenta.porClasificar) {
          throw const ErrorLibro(
            'Solo se reclasifica desde "Por clasificar"; lo demás se corrige '
            'con anulación',
          );
        }
      case TipoMovimiento.apertura:
        final cuentaReal = origen.clase == ClaseCuenta.apertura
            ? destino
            : origen;
        final yaAbierta = _movimientos.any(
          (o) =>
              o.tipo == TipoMovimiento.apertura &&
              (o.cuentaOrigenId == cuentaReal.id ||
                  o.cuentaDestinoId == cuentaReal.id) &&
              _estado[o.id] != EstadoMovimiento.rechazado &&
              !estaAnulado(o.id),
        );
        if (yaAbierta) {
          throw ErrorLibro(
            'La cuenta $cuentaReal ya tiene saldo inicial; se corrige con '
            'anulación o con un ajuste',
          );
        }
      default:
        break;
    }
  }

  void _validarAnulacion(Movimiento c, Cuenta origen, Cuenta destino) {
    final anulado = c.anulaA;
    if (anulado == null) {
      throw ErrorLibro('El contraasiento ${c.id} no dice qué movimiento anula');
    }
    final original = movimiento(anulado);
    if (original.tipo == TipoMovimiento.anulacion) {
      throw const ErrorLibro(
        'No se anula un contraasiento: registra de nuevo el movimiento correcto',
      );
    }
    if (_estado[original.id] != EstadoMovimiento.confirmado) {
      throw ErrorLibro(
        'Solo se anula un movimiento confirmado; uno pendiente se rechaza '
        '(${original.id})',
      );
    }
    if (contraasientoDe(original.id) != null) {
      throw ErrorLibro('El movimiento ${original.id} ya tiene una anulación');
    }
    if (c.monto != original.monto ||
        c.cuentaOrigenId != original.cuentaDestinoId ||
        c.cuentaDestinoId != original.cuentaOrigenId) {
      throw const ErrorLibro(
        'El contraasiento debe tener el mismo monto con origen y destino '
        'invertidos',
      );
    }
    if (!motivoValido(c.motivo)) {
      throw const ErrorLibro(
        'Una anulación exige un motivo de al menos 3 caracteres visibles',
      );
    }
    // Una cuenta cerrada o archivada no admite movimientos nuevos; la
    // anulación de uno anterior sí si la cuenta es de **gasto o ingreso**
    // (que se cierran con saldo; respuestas del dueño del 23/oct/2026).
    for (final cuenta in [origen, destino]) {
      final cerrada =
          cuenta.estado == EstadoCuenta.cerrada ||
          cuenta.estado == EstadoCuenta.archivada;
      final deResultado =
          cuenta.clase == ClaseCuenta.gasto ||
          cuenta.clase == ClaseCuenta.ingreso;
      if (cerrada && !deResultado) {
        throw ErrorLibro('La cuenta $cuenta está ${cuenta.estado}');
      }
    }
  }
}

/// Transferencias entre personas y aportación de referencia a la casa
/// (Fase 8, bloque 1; D19).
///
/// - Una persona **propone** una transferencia por una de las tres rutas
///   permitidas; el **receptor** la confirma o la rechaza con un botón. Sin
///   confirmación no se mueve nada (el servidor, `fin_responder_transferencia`,
///   es quien registra el movimiento en los libros).
/// - La **aportación de referencia** reparte el total del periodo en 50%
///   Papá y 50% entre el dueño y la pareja. Es una guía: la aportación es
///   libre y nadie queda como deudor.
///
/// Dinero en centavos. Nada de esto sale a la IA ni a las bocinas (D3).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import 'fuente_tablas.dart';
import 'repositorio.dart';

// ------------------------------------------------------------------ rutas

/// Las tres rutas permitidas (respuesta del dueño, 8/nov/2026).
enum RutaTransferencia {
  parejaADueno('pareja_a_dueno', 'Pareja → dueño'),
  duenoACasa('dueno_a_casa', 'Dueño → casa'),
  parejaACasa('pareja_a_casa', 'Pareja → casa');

  const RutaTransferencia(this.codigo, this.titulo);

  /// Texto que se guarda en el servidor.
  final String codigo;
  final String titulo;

  /// `true` si el destino es la cuenta general de la casa.
  bool get esACasa => this != parejaADueno;

  static RutaTransferencia? desdeCodigo(String? c) {
    for (final r in values) {
      if (r.codigo == c) return r;
    }
    return null;
  }
}

/// Quién es la persona frente a las rutas (según su rol en el hogar).
enum ParteTransferencia { dueno, pareja, otra }

/// Las rutas que [parte] puede **proponer**: dueño → casa; pareja → dueño y
/// pareja → casa. Cualquier otra persona no propone ninguna.
List<RutaTransferencia> rutasQueOfrece(ParteTransferencia parte) =>
    switch (parte) {
      ParteTransferencia.dueno => const [RutaTransferencia.duenoACasa],
      ParteTransferencia.pareja => const [
        RutaTransferencia.parejaADueno,
        RutaTransferencia.parejaACasa,
      ],
      ParteTransferencia.otra => const [],
    };

enum EstadoTransferencia {
  pendiente('Pendiente'),
  confirmada('Confirmada'),
  rechazada('Rechazada'),
  cancelada('Cancelada');

  const EstadoTransferencia(this.titulo);
  final String titulo;

  static EstadoTransferencia desdeTexto(String? t) {
    for (final e in values) {
      if (e.name == t) return e;
    }
    return EstadoTransferencia.pendiente;
  }
}

/// Lo que se puede hacer con una transferencia (`p_accion`).
enum AccionTransferencia {
  confirmar,
  rechazar,
  cancelar;

  String get paraServidor => name;
}

/// Largo máximo de la nota corta.
const largoMaximoNotaTransferencia = 80;

class Transferencia {
  const Transferencia({
    required this.id,
    required this.ruta,
    required this.origenId,
    required this.receptorId,
    required this.montoCentavos,
    required this.estado,
    required this.creadaEn,
    this.nota = '',
  });

  final String id;
  final RutaTransferencia ruta;
  final String origenId;

  /// Quien debe confirmar.
  final String receptorId;
  final int montoCentavos;
  final EstadoTransferencia estado;
  final DateTime creadaEn;
  final String nota;

  Transferencia conEstado(EstadoTransferencia nuevo) => Transferencia(
    id: id,
    ruta: ruta,
    origenId: origenId,
    receptorId: receptorId,
    montoCentavos: montoCentavos,
    estado: nuevo,
    creadaEn: creadaEn,
    nota: nota,
  );

  /// Desde una fila de `fin_transferencias`.
  static Transferencia? deFila(Map<String, dynamic> f) {
    final ruta = RutaTransferencia.desdeCodigo('${f['ruta']}');
    if (ruta == null) return null;
    return Transferencia(
      id: '${f['id']}',
      ruta: ruta,
      origenId: '${f['origen_id']}',
      receptorId: '${f['receptor_id']}',
      montoCentavos: (f['monto_centavos'] as num).toInt(),
      estado: EstadoTransferencia.desdeTexto(f['estado'] as String?),
      creadaEn: DateTime.parse('${f['creado_en'] ?? f['created_at']}'),
      nota: '${f['nota'] ?? ''}',
    );
  }
}

/// Error de validación al proponer; `null` si es válida.
String? errorAlProponer(int? montoCentavos, String nota) {
  if (montoCentavos == null || montoCentavos <= 0) {
    return 'Escribe un monto mayor que cero.';
  }
  if (nota.trim().length > largoMaximoNotaTransferencia) {
    return 'La nota admite hasta $largoMaximoNotaTransferencia caracteres.';
  }
  return null;
}

// ---------------------------------------------------------------- periodo

/// Periodo de la aportación de referencia (configurable por el dueño).
enum PeriodoAportacion {
  semana('semana', 'Semana'),
  mes('mes', 'Mes'),
  bimestre('bimestre', 'Bimestre'),
  semestre('semestre', 'Semestre'),
  anio('anio', 'Año');

  const PeriodoAportacion(this.codigo, this.titulo);
  final String codigo;
  final String titulo;

  static PeriodoAportacion desdeCodigo(Object? c) {
    for (final p in values) {
      if (p.codigo == c) return p;
    }
    return PeriodoAportacion.mes;
  }

  /// Primer y último día (incluidos) del periodo que contiene a [hoy]. La
  /// semana empieza en lunes; bimestre y semestre, en meses calendario.
  (Fecha, Fecha) rango(Fecha hoy) {
    switch (this) {
      case PeriodoAportacion.semana:
        final inicio = hoy.sumarDias(-(hoy.diaSemana - 1));
        return (inicio, inicio.sumarDias(6));
      case PeriodoAportacion.mes:
        return (hoy.primerDiaDelMes, hoy.ultimoDiaDelMes);
      case PeriodoAportacion.bimestre:
        return _porMeses(hoy, 2);
      case PeriodoAportacion.semestre:
        return _porMeses(hoy, 6);
      case PeriodoAportacion.anio:
        return _porMeses(hoy, 12);
    }
  }

  static (Fecha, Fecha) _porMeses(Fecha hoy, int largo) {
    final primero = ((hoy.mes - 1) ~/ largo) * largo + 1;
    final ultimo = primero + largo - 1;
    return (
      Fecha.enMes(hoy.anio, primero, 1),
      Fecha.enMes(hoy.anio, ultimo, 1).ultimoDiaDelMes,
    );
  }
}

// ------------------------------------------------------------ referencia

/// Reparto de referencia de [totalCentavos]: 50% Papá y 50% entre el dueño y
/// la pareja. Redondeo explícito: Papá recibe la mitad hacia abajo; la otra
/// mitad se parte entre el dueño (el centavo sobrante, si lo hay) y la pareja.
/// Las tres partes suman siempre el total.
class ReferenciaAportacion {
  const ReferenciaAportacion({
    required this.totalCentavos,
    required this.papaCentavos,
    required this.duenoCentavos,
    required this.parejaCentavos,
  });

  factory ReferenciaAportacion.de(int totalCentavos) {
    final total = totalCentavos < 0 ? 0 : totalCentavos;
    final papa = total ~/ 2;
    final resto = total - papa;
    final pareja = resto ~/ 2;
    return ReferenciaAportacion(
      totalCentavos: total,
      papaCentavos: papa,
      duenoCentavos: resto - pareja,
      parejaCentavos: pareja,
    );
  }

  final int totalCentavos;
  final int papaCentavos;
  final int duenoCentavos;
  final int parejaCentavos;

  int get sumaCentavos => papaCentavos + duenoCentavos + parejaCentavos;
}

/// Total de gastos de la casa en el periodo: gastos confirmados contra
/// cuentas del libro [libroCasaId], con fecha en [desde]..[hasta], sin los
/// anulados (ni los contraasientos).
int totalGastoCasa(
  DatosFinanzas datos,
  String libroCasaId,
  Fecha desde,
  Fecha hasta,
) {
  final cuentasCasa = {
    for (final c in datos.cuentas)
      if (c.libroId == libroCasaId) c.id,
  };
  final anulados = {
    for (final m in datos.movimientos)
      if (m.tipo == TipoMovimiento.anulacion && m.anulaA != null) m.anulaA!,
  };
  var total = 0;
  for (final m in datos.movimientos) {
    if (m.tipo != TipoMovimiento.gasto) continue;
    if (m.estadoInicial != EstadoMovimiento.confirmado) continue;
    if (anulados.contains(m.id)) continue;
    if (!cuentasCasa.contains(m.cuentaOrigenId)) continue;
    if (m.fecha.compareTo(desde) < 0 || m.fecha.compareTo(hasta) > 0) continue;
    total += m.monto;
  }
  return total;
}

/// Lo aportado a la casa en el periodo por [personaId]: transferencias
/// **confirmadas** a la casa, con la fecha de creación dentro del periodo.
int aportadoPorPersona(
  List<Transferencia> transferencias,
  String personaId,
  Fecha desde,
  Fecha hasta,
) {
  var suma = 0;
  for (final t in transferencias) {
    if (t.estado != EstadoTransferencia.confirmada || !t.ruta.esACasa) continue;
    if (t.origenId != personaId) continue;
    final f = Fecha.deDateTime(t.creadaEn);
    if (f.compareTo(desde) < 0 || f.compareTo(hasta) > 0) continue;
    suma += t.montoCentavos;
  }
  return suma;
}

// ------------------------------------------------------------ repositorio

abstract interface class RepositorioTransferencias {
  /// Propone una transferencia (`fin_proponer_transferencia`); devuelve el id.
  Future<String> proponer({
    required RutaTransferencia ruta,
    required int montoCentavos,
    String nota = '',
  });

  /// Confirma, rechaza o cancela (`fin_responder_transferencia`).
  Future<void> responder(String transferenciaId, AccionTransferencia accion);

  /// Las transferencias que la persona puede ver (las suyas), recientes primero.
  Future<List<Transferencia>> listar();

  /// Periodo configurado de la aportación.
  Future<PeriodoAportacion> periodo();

  /// Solo el dueño (`fin_fijar_periodo_aportacion`).
  Future<void> fijarPeriodo(PeriodoAportacion periodo);
}

class RepositorioTransferenciasSupabase implements RepositorioTransferencias {
  RepositorioTransferenciasSupabase(this.fuente);
  final FuenteTablas fuente;

  @override
  Future<String> proponer({
    required RutaTransferencia ruta,
    required int montoCentavos,
    String nota = '',
  }) async {
    final error = errorAlProponer(montoCentavos, nota);
    if (error != null) throw ErrorFinanzas(error);
    final r = await fuente.rpc('fin_proponer_transferencia', {
      'p_ruta': ruta.codigo,
      'p_monto_centavos': montoCentavos,
      'p_nota': nota.trim(),
    });
    return '$r';
  }

  @override
  Future<void> responder(
    String transferenciaId,
    AccionTransferencia accion,
  ) async {
    await fuente.rpc('fin_responder_transferencia', {
      'p_transferencia': transferenciaId,
      'p_accion': accion.paraServidor,
    });
  }

  @override
  Future<List<Transferencia>> listar() async {
    final filas = await fuente.leer('fin_transferencias');
    return [for (final f in filas) ?Transferencia.deFila(f)]
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  @override
  Future<PeriodoAportacion> periodo() async => PeriodoAportacion.desdeCodigo(
    await fuente.rpc('fin_periodo_aportacion', {}),
  );

  @override
  Future<void> fijarPeriodo(PeriodoAportacion periodo) async {
    await fuente.rpc('fin_fijar_periodo_aportacion', {
      'p_periodo': periodo.codigo,
    });
  }
}

/// Para pruebas y demostración (varias personas comparten el almacén con
/// [comoPersona]).
class RepositorioTransferenciasEnMemoria implements RepositorioTransferencias {
  RepositorioTransferenciasEnMemoria({
    required String personaId,
    required String duenoId,
    required String parejaId,
    DateTime Function()? reloj,
  }) : _personaId = personaId, // ignore: prefer_initializing_formals
       _a = _Almacen(duenoId, parejaId, reloj ?? DateTime.now);

  RepositorioTransferenciasEnMemoria._(this._personaId, this._a);

  final String _personaId;
  final _Almacen _a;

  RepositorioTransferenciasEnMemoria comoPersona(String personaId) =>
      RepositorioTransferenciasEnMemoria._(personaId, _a);

  /// Cuántas confirmaciones se aplicaron (para pruebas: lo que "se movió").
  int get movimientosAplicados => _a.aplicados;

  ParteTransferencia get _parte => _personaId == _a.duenoId
      ? ParteTransferencia.dueno
      : _personaId == _a.parejaId
      ? ParteTransferencia.pareja
      : ParteTransferencia.otra;

  @override
  Future<String> proponer({
    required RutaTransferencia ruta,
    required int montoCentavos,
    String nota = '',
  }) async {
    if (!rutasQueOfrece(_parte).contains(ruta)) {
      throw const ErrorFinanzas('Esa ruta no está permitida.');
    }
    final error = errorAlProponer(montoCentavos, nota);
    if (error != null) throw ErrorFinanzas(error);
    // Receptor: el dueño en pareja → dueño; en las rutas a la casa confirma
    // el otro adulto (el servidor es quien lo decide de verdad).
    final receptor = ruta == RutaTransferencia.parejaADueno
        ? _a.duenoId
        : (_personaId == _a.duenoId ? _a.parejaId : _a.duenoId);
    final id = 'transf-${++_a.contador}';
    _a.filas.add(
      Transferencia(
        id: id,
        ruta: ruta,
        origenId: _personaId,
        receptorId: receptor,
        montoCentavos: montoCentavos,
        estado: EstadoTransferencia.pendiente,
        creadaEn: _a.reloj(),
        nota: nota.trim(),
      ),
    );
    return id;
  }

  @override
  Future<void> responder(
    String transferenciaId,
    AccionTransferencia accion,
  ) async {
    final i = _a.filas.indexWhere((t) => t.id == transferenciaId);
    if (i < 0) throw const ErrorFinanzas('No existe esa transferencia.');
    final t = _a.filas[i];
    if (t.estado != EstadoTransferencia.pendiente) {
      throw const ErrorFinanzas('La transferencia ya no está pendiente.');
    }
    switch (accion) {
      case AccionTransferencia.confirmar:
        if (t.receptorId != _personaId) {
          throw const ErrorFinanzas('Solo quien recibe puede confirmar.');
        }
        _a.filas[i] = t.conEstado(EstadoTransferencia.confirmada);
        _a.aplicados++;
      case AccionTransferencia.rechazar:
        if (t.receptorId != _personaId) {
          throw const ErrorFinanzas('Solo quien recibe puede rechazar.');
        }
        _a.filas[i] = t.conEstado(EstadoTransferencia.rechazada);
      case AccionTransferencia.cancelar:
        if (t.origenId != _personaId) {
          throw const ErrorFinanzas('Solo quien propuso puede cancelar.');
        }
        _a.filas[i] = t.conEstado(EstadoTransferencia.cancelada);
    }
  }

  @override
  Future<List<Transferencia>> listar() async => [
    for (final t in _a.filas.reversed)
      if (t.origenId == _personaId || t.receptorId == _personaId) t,
  ];

  @override
  Future<PeriodoAportacion> periodo() async => _a.periodo;

  @override
  Future<void> fijarPeriodo(PeriodoAportacion periodo) async {
    if (_personaId != _a.duenoId) {
      throw const ErrorFinanzas('Solo el dueño cambia el periodo.');
    }
    _a.periodo = periodo;
  }
}

class _Almacen {
  _Almacen(this.duenoId, this.parejaId, this.reloj);
  final String duenoId;
  final String parejaId;
  final DateTime Function() reloj;
  final List<Transferencia> filas = [];
  PeriodoAportacion periodo = PeriodoAportacion.mes;
  int contador = 0;
  int aplicados = 0;
}

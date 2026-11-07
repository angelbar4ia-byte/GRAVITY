/// Vista temporal de Finanzas de Papá para el familiar (D24).
///
/// El familiar no tiene acceso permanente: **pide** la vista con un motivo, el
/// dueño la **autoriza por 30 minutos** (o la rechaza) y puede **cancelarla**
/// antes de tiempo. El servidor es quien manda (RLS con `fin_vista_papa_vigente`);
/// aquí viven el modelo, la interfaz del repositorio y dos implementaciones:
/// Supabase (RPC `fin_pedir_vista_papa`, `fin_responder_vista`) y memoria (para
/// pruebas y demostración, con el reloj inyectado).
///
/// Nada de esto lleva montos: las solicitudes solo tienen quién, cuándo y el
/// motivo escrito por la persona (la bitácora tampoco lleva cifras).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import 'demostracion.dart' show datosDeLibros;
import 'fuente_tablas.dart';
import 'repositorio.dart';

/// Cuánto dura una autorización (D24).
const duracionVistaPapa = Duration(minutes: 30);

/// Estado de una solicitud. [vencida] no se guarda: es una autorizada cuyo
/// tiempo ya pasó.
enum EstadoVista {
  pendiente,
  autorizada,
  rechazada,
  cancelada,
  vencida;

  static EstadoVista desdeTexto(String? texto) {
    for (final e in values) {
      if (e.name == texto) return e;
    }
    return EstadoVista.pendiente;
  }
}

/// Lo que se puede hacer con una solicitud (`fin_responder_vista`).
enum AccionVista {
  autorizar,
  rechazar,
  cancelar;

  /// Texto que espera el servidor en `p_accion`.
  String get paraServidor => name;
}

class SolicitudVista {
  const SolicitudVista({
    required this.id,
    required this.solicitanteId,
    required this.motivo,
    required this.estado,
    required this.pedidaEn,
    this.vigenteHasta,
  });

  final String id;
  final String solicitanteId;
  final String motivo;

  /// Estado guardado (nunca [EstadoVista.vencida]; ver [estadoEn]).
  final EstadoVista estado;
  final DateTime pedidaEn;

  /// Hasta cuándo vale la autorización (solo si fue autorizada).
  final DateTime? vigenteHasta;

  /// Estado a la hora [ahora]: una autorizada pasada de tiempo es vencida.
  EstadoVista estadoEn(DateTime ahora) =>
      estado == EstadoVista.autorizada && !_antes(ahora, vigenteHasta)
      ? EstadoVista.vencida
      : estado;

  /// La autorización sigue vigente a la hora [ahora].
  bool vigenteEn(DateTime ahora) => estadoEn(ahora) == EstadoVista.autorizada;

  /// Lo que falta de la autorización (cero si ya no vale).
  Duration restanteEn(DateTime ahora) {
    if (!vigenteEn(ahora)) return Duration.zero;
    return vigenteHasta!.difference(ahora);
  }

  static bool _antes(DateTime ahora, DateTime? limite) =>
      limite != null && ahora.isBefore(limite);

  SolicitudVista conEstado(EstadoVista nuevo, {DateTime? vigenteHasta}) =>
      SolicitudVista(
        id: id,
        solicitanteId: solicitanteId,
        motivo: motivo,
        estado: nuevo,
        pedidaEn: pedidaEn,
        vigenteHasta: vigenteHasta ?? this.vigenteHasta,
      );

  /// Desde una fila de `fin_vistas_solicitadas`.
  static SolicitudVista deFila(Map<String, dynamic> f) => SolicitudVista(
    id: '${f['id']}',
    solicitanteId: '${f['solicitante']}',
    motivo: '${f['motivo'] ?? ''}',
    estado: EstadoVista.desdeTexto(f['estado'] as String?),
    pedidaEn: DateTime.parse(
      '${f['creado_en'] ?? f['created_at'] ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String()}',
    ),
    vigenteHasta: f['vigente_hasta'] == null
        ? null
        : DateTime.parse('${f['vigente_hasta']}'),
  );
}

/// Todo lo que la app lee y escribe de la vista temporal.
abstract interface class RepositorioVistaPapa {
  /// Pide la vista (`fin_pedir_vista_papa`); devuelve el id de la solicitud.
  /// Lanza [ErrorFinanzas] si el motivo no alcanza o no hay señal.
  Future<String> pedir(String motivo);

  /// Autoriza, rechaza o cancela (`fin_responder_vista`).
  Future<void> responder(String solicitudId, AccionVista accion);

  /// Las solicitudes que la persona puede ver (las suyas; el dueño, todas).
  Future<List<SolicitudVista>> listar();

  /// El servidor dice que hay una autorización vigente para la persona
  /// (`fin_vista_papa_vigente`).
  Future<bool> vigente();

  /// Lo del libro de Papá, **solo si hay autorización vigente**; si no,
  /// `null`. Es lo único de Papá que ve el familiar, y solo en memoria: no se
  /// guarda en la copia del equipo.
  Future<DatosFinanzas?> leerVista();
}

// ------------------------------------------------------------------ Supabase

class RepositorioVistaPapaSupabase implements RepositorioVistaPapa {
  RepositorioVistaPapaSupabase({
    required this.fuente,
    required this.cargarLibros,
  });

  final FuenteTablas fuente;

  /// Lo que el servidor deja leer hoy (la RLS filtra); de ahí se toma el libro
  /// de Papá.
  final Future<DatosFinanzas> Function() cargarLibros;

  @override
  Future<String> pedir(String motivo) async {
    if (!motivoValido(motivo)) throw const ErrorFinanzas(mensajeMotivoCorto);
    final r = await fuente.rpc('fin_pedir_vista_papa', {'p_motivo': motivo});
    return '$r';
  }

  @override
  Future<void> responder(String solicitudId, AccionVista accion) async {
    await fuente.rpc('fin_responder_vista', {
      'p_solicitud': solicitudId,
      'p_accion': accion.paraServidor,
    });
  }

  @override
  Future<List<SolicitudVista>> listar() async {
    final filas = await fuente.leer('fin_vistas_solicitadas');
    return [for (final f in filas) SolicitudVista.deFila(f)]
      ..sort((a, b) => b.pedidaEn.compareTo(a.pedidaEn));
  }

  @override
  Future<bool> vigente() async =>
      (await fuente.rpc('fin_vista_papa_vigente', {})) == true;

  @override
  Future<DatosFinanzas?> leerVista() async {
    if (!await vigente()) return null;
    final datos = await cargarLibros();
    return _soloLibroDePapa(datos);
  }
}

DatosFinanzas _soloLibroDePapa(DatosFinanzas d) => datosDeLibros(d, {
  for (final l in d.libros)
    if (l.tipo == TipoLibro.representado) l.id,
}, conservarLibros: false);

// ------------------------------------------------------------------- memoria

class _Almacen {
  _Almacen({
    required this.duenoId,
    required this.datosPapa,
    required this.reloj,
    required this.generarId,
  });

  final String duenoId;
  final DatosFinanzas datosPapa;
  final DateTime Function() reloj;
  final String Function() generarId;
  final List<SolicitudVista> filas = [];
}

/// Para pruebas y demostración. Varias personas comparten el mismo almacén con
/// [comoPersona] (cada una ve lo que vería con la RLS).
class RepositorioVistaPapaEnMemoria implements RepositorioVistaPapa {
  RepositorioVistaPapaEnMemoria({
    required String personaId,
    required String duenoId,
    DatosFinanzas? datosPapa,
    DateTime Function()? reloj,
    String Function()? generarId,
  }) : _personaId = personaId, // ignore: prefer_initializing_formals
       _a = _Almacen(
         duenoId: duenoId,
         datosPapa: datosPapa ?? DatosFinanzas.vacio,
         reloj: reloj ?? DateTime.now,
         generarId: generarId ?? _contadorDeIds(),
       );

  RepositorioVistaPapaEnMemoria._(this._personaId, this._a);

  final String _personaId;
  final _Almacen _a;

  /// Otra persona sobre las mismas solicitudes.
  RepositorioVistaPapaEnMemoria comoPersona(String personaId) =>
      RepositorioVistaPapaEnMemoria._(personaId, _a);

  bool get _esDueno => _personaId == _a.duenoId;

  static String Function() _contadorDeIds() {
    var n = 0;
    return () => 'vista-${++n}';
  }

  @override
  Future<String> pedir(String motivo) async {
    if (!motivoValido(motivo)) throw const ErrorFinanzas(mensajeMotivoCorto);
    if (_esDueno) {
      throw const ErrorFinanzas('El dueño no necesita pedir la vista.');
    }
    final id = _a.generarId();
    _a.filas.add(
      SolicitudVista(
        id: id,
        solicitanteId: _personaId,
        motivo: motivo.trim(),
        estado: EstadoVista.pendiente,
        pedidaEn: _a.reloj(),
      ),
    );
    return id;
  }

  @override
  Future<void> responder(String solicitudId, AccionVista accion) async {
    final i = _a.filas.indexWhere((s) => s.id == solicitudId);
    if (i < 0) throw const ErrorFinanzas('No existe esa solicitud.');
    final s = _a.filas[i];
    final ahora = _a.reloj();
    switch (accion) {
      case AccionVista.autorizar:
        if (!_esDueno) throw const ErrorFinanzas('Solo el dueño autoriza.');
        if (s.estado != EstadoVista.pendiente) {
          throw const ErrorFinanzas('La solicitud ya no está pendiente.');
        }
        _a.filas[i] = s.conEstado(
          EstadoVista.autorizada,
          vigenteHasta: ahora.add(duracionVistaPapa),
        );
      case AccionVista.rechazar:
        if (!_esDueno) throw const ErrorFinanzas('Solo el dueño rechaza.');
        if (s.estado != EstadoVista.pendiente) {
          throw const ErrorFinanzas('La solicitud ya no está pendiente.');
        }
        _a.filas[i] = s.conEstado(EstadoVista.rechazada);
      case AccionVista.cancelar:
        final propia = s.solicitanteId == _personaId;
        if (!_esDueno && !propia) {
          throw const ErrorFinanzas('No puedes cancelar esta solicitud.');
        }
        if (!(s.estado == EstadoVista.pendiente || s.vigenteEn(ahora))) {
          throw const ErrorFinanzas('La solicitud ya no está vigente.');
        }
        _a.filas[i] = s.conEstado(EstadoVista.cancelada);
    }
  }

  @override
  Future<List<SolicitudVista>> listar() async => [
    for (final s in _a.filas.reversed)
      if (_esDueno || s.solicitanteId == _personaId) s,
  ];

  @override
  Future<bool> vigente() async {
    final ahora = _a.reloj();
    return _a.filas.any(
      (s) => s.solicitanteId == _personaId && s.vigenteEn(ahora),
    );
  }

  @override
  Future<DatosFinanzas?> leerVista() async =>
      await vigente() ? _a.datosPapa : null;
}

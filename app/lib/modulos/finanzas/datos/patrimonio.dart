/// Objetivos, inversiones, bienes y previsión (Fase 8, bloque 3; D19, D25).
///
/// Reglas (`docs/specs/fase-8-patrimonio.md`):
///
/// - Cada registro pertenece a un libro de una persona (D19). Solo la titular y
///   el dueño como albacea de Papá lo ven; el suplente de Papá lee como en la
///   Fase 1; la pareja ve lo de la casa; Casa, familiar y cuidadora, nada
///   ([permisoPatrimonio]).
/// - Lo capturado a mano es [OrigenDato.capturado]; solo lo leído del estado
///   en PDF es [OrigenDato.verificado] ([inversionLeidaDeEstado]).
/// - El **rendimiento** de una inversión es obligatorio al capturarla (cero
///   es válido) y se muestra tal como se capturó: en este bloque no hay
///   ningún cálculo automático.
/// - La **fecha meta** de un objetivo es opcional (v1.1): sin ella el avance
///   da las semanas estimadas y no dice si llega "a tiempo".
/// - Un bien o una previsión **sin fecha de captura** no es vigente.
/// - El objetivo **lee** el apartado de ahorro, no lo copia ([avanceObjetivo]).
/// - Nada de esto va a la IA ni a las bocinas (D3).
///
/// Dinero en centavos; rendimientos en puntos base. Las tablas del servidor
/// son `fin_objetivos`, `fin_inversiones`, `fin_bienes` y `fin_previsiones`
/// (RLS por persona); se escriben con `fin_objetivo_guardar`,
/// `fin_inversion_guardar`, `fin_bien_guardar` y `fin_prevision_guardar`, y el
/// avance se lee con `fin_objetivo_avance` ([RepositorioPatrimonioSupabase],
/// migración 20261136).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    show Fecha, OrigenDato, PermisoLibro;

import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/permisos/permisos.dart' as permisos;
import 'fuente_tablas.dart';

// ------------------------------------------------------------------ permisos

/// Lo que una persona puede hacer con el patrimonio de un libro.
class PermisoPatrimonio {
  const PermisoPatrimonio({this.ver = false, this.editar = false});

  final bool ver;
  final bool editar;

  static const ninguno = PermisoPatrimonio();
}

/// Permiso de patrimonio dado el permiso en el libro ([permiso], de
/// `permisoDeCarga`) y el [rol]:
///
/// - Sin Finanzas en el rol (Casa, familiar, cuidadora): nada.
/// - La cuenta maestra que lee un libro ajeno y el lector de un compartido
///   público (no miembros): nada. El patrimonio es de la persona.
/// - Miembro del libro: ve; edita solo si el libro lo deja escribir (el
///   suplente de Papá en espera solo lee).
PermisoPatrimonio permisoPatrimonio(
  PermisoLibro permiso,
  Rol rol, {
  bool soloLectura = false,
}) {
  if (!permisos.puede(rol, Modulo.finanzas, Accion.leer)) {
    return PermisoPatrimonio.ninguno;
  }
  if (!permiso.leer || permiso.comoMaestra || permiso.comoLector) {
    return PermisoPatrimonio.ninguno;
  }
  return PermisoPatrimonio(
    ver: true,
    editar:
        !soloLectura &&
        permiso.escribir &&
        permisos.puede(rol, Modulo.finanzas, Accion.escribir),
  );
}

// ----------------------------------------------------------------- objetivos

class Objetivo {
  const Objetivo({
    required this.id,
    required this.libroId,
    required this.nombre,
    required this.metaCentavos,
    this.fechaMeta,
    this.bolsaId,
    this.titularId,
  });

  final String id;
  final String libroId;
  final String nombre;
  final int metaCentavos;

  /// Fecha límite elegida; `null` si la persona no puso ninguna.
  final Fecha? fechaMeta;

  /// Bolsa del apartado de ahorro de la que lee el avance (no se copia).
  final String? bolsaId;

  /// Titular del libro (la persona dueña del dato); el servidor la exige.
  final String? titularId;
}

/// Cuánto falta y en cuántas semanas se alcanza con el apartado.
class AvanceObjetivo {
  const AvanceObjetivo({
    required this.ahorrado,
    required this.falta,
    required this.apartadoSemanal,
    this.semanasHastaFecha,
    this.semanasParaAlcanzar,
  });

  /// Lo que tiene la bolsa (leído).
  final int ahorrado;
  final int falta;

  /// Lo que la persona aparta por semana (leído); 0 si no aparta nada.
  final int apartadoSemanal;

  /// `0` si ya se alcanzó; `null` si no hay apartado (no se puede estimar).
  final int? semanasParaAlcanzar;

  /// Semanas completas que quedan hasta la fecha meta (`0` si ya pasó);
  /// `null` si el objetivo no tiene fecha meta.
  final int? semanasHastaFecha;

  bool get alcanzado => falta == 0;

  /// `true` si con el apartado actual llega a la fecha; `null` sin
  /// estimación o sin fecha meta (no hay contra qué comparar).
  bool? get llegaATiempo => alcanzado
      ? true
      : semanasParaAlcanzar == null || semanasHastaFecha == null
      ? null
      : semanasParaAlcanzar! <= semanasHastaFecha!;
}

/// Avance de un objetivo de meta [metaCentavos] con lo [ahorrado] en su bolsa
/// y su [apartadoSemanal] (ambos **leídos** del apartado de ahorro). Las
/// semanas se redondean hacia arriba, con enteros.
AvanceObjetivo avanceObjetivo({
  required int metaCentavos,
  required int ahorrado,
  required int apartadoSemanal,
  required Fecha? fechaMeta,
  required Fecha hoy,
}) {
  final falta = metaCentavos > ahorrado ? metaCentavos - ahorrado : 0;
  final apartado = apartadoSemanal > 0 ? apartadoSemanal : 0;
  final int? semanas = falta == 0
      ? 0
      : apartado == 0
      ? null
      : (falta + apartado - 1) ~/ apartado;
  final dias = fechaMeta == null ? null : hoy.diasHasta(fechaMeta);
  return AvanceObjetivo(
    ahorrado: ahorrado,
    falta: falta,
    apartadoSemanal: apartado,
    semanasParaAlcanzar: semanas,
    semanasHastaFecha: dias == null ? null : (dias > 0 ? dias ~/ 7 : 0),
  );
}

// ------------------------------------------------------------- inversiones

class Inversion {
  const Inversion({
    required this.id,
    required this.libroId,
    required this.nombre,
    required this.saldoCentavos,
    required this.fechaCaptura,
    this.institucion,
    this.rendimientoPuntosBase,
    this.origen = OrigenDato.capturado,
    this.titularId,
  });

  final String id;
  final String libroId;
  final String nombre;
  final String? institucion;
  final int saldoCentavos;

  /// Rendimiento **como se capturó**, en puntos base (550 = 5.50 %). No se
  /// calcula a partir del saldo ni de nada más en este bloque.
  final int? rendimientoPuntosBase;
  final Fecha fechaCaptura;
  final OrigenDato origen;
  final String? titularId;

  bool get esVerificada => origen == OrigenDato.verificado;

  /// Etiqueta del origen: "Capturado" o "Verificado".
  String get etiquetaOrigen => esVerificada ? 'Verificado' : 'Capturado';

  /// El rendimiento tal cual se capturó ("5.50 %"), o `null` si no se capturó.
  String? get rendimientoTexto => rendimientoPuntosBase == null
      ? null
      : '${textoPuntosBase(rendimientoPuntosBase!)} %';
}

/// Puntos base a texto con dos decimales (550 → "5.50").
String textoPuntosBase(int pb) {
  final signo = pb < 0 ? '-' : '';
  final a = pb.abs();
  return '$signo${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}

/// Puntos base de un texto capturado ("5.5", "5,50", "5.50 %"); `null` si no es
/// un número de hasta dos decimales.
int? puntosBaseDeTexto(String texto) {
  final t = texto.trim().replaceAll('%', '').trim().replaceAll(',', '.');
  final m = RegExp(r'^(\d{1,3})(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final decimales = (m.group(2) ?? '').padRight(2, '0');
  return int.parse(m.group(1)!) * 100 + int.parse(decimales);
}

/// Alta de una inversión **capturada a mano**: siempre `capturado`. El
/// rendimiento es obligatorio (cero es válido); un vacío no se guarda.
Inversion inversionCapturada({
  required String id,
  required String libroId,
  required String nombre,
  required int saldoCentavos,
  required Fecha fechaCaptura,
  required int? rendimientoPuntosBase,
  String? institucion,
  String? titularId,
}) {
  final n = nombre.trim();
  if (n.isEmpty || n.length > 60) {
    throw ArgumentError('El nombre va de 1 a 60 caracteres');
  }
  if (saldoCentavos < 0) throw ArgumentError('El saldo no puede ser negativo');
  if (rendimientoPuntosBase == null) {
    throw ArgumentError('El rendimiento es obligatorio (puede ser 0)');
  }
  return Inversion(
    id: id,
    libroId: libroId,
    nombre: n,
    saldoCentavos: saldoCentavos,
    fechaCaptura: fechaCaptura,
    institucion: (institucion ?? '').trim().isEmpty
        ? null
        : institucion!.trim(),
    rendimientoPuntosBase: rendimientoPuntosBase,
    origen: OrigenDato.capturado,
    titularId: titularId,
  );
}

/// Lo que lee el lector de estados de inversión en PDF (solo la laptop; el
/// archivo no sale de ella).
class EstadoInversionLeido {
  const EstadoInversionLeido({
    required this.nombre,
    required this.saldoCentavos,
    required this.fecha,
    this.institucion,
    this.rendimientoPuntosBase,
  });

  final String nombre;
  final String? institucion;
  final int saldoCentavos;
  final int? rendimientoPuntosBase;
  final Fecha fecha;
}

/// Interfaz del lector de PDF (la implementa plataforma en la laptop). La app
/// no sube el archivo a ningún lado.
abstract interface class LectorEstadoInversion {
  /// `true` si esta máquina puede leer el PDF (la laptop con el lector).
  bool get disponible;

  /// Lee un estado de inversión; `null` si la persona cancela.
  Future<EstadoInversionLeido?> leer();
}

class LectorEstadoInversionNoDisponible implements LectorEstadoInversion {
  const LectorEstadoInversionNoDisponible();

  @override
  bool get disponible => false;

  @override
  Future<EstadoInversionLeido?> leer() async => null;
}

/// Alta de una inversión **leída del estado en PDF**: `verificado`.
Inversion inversionLeidaDeEstado({
  required String id,
  required String libroId,
  required EstadoInversionLeido estado,
  String? titularId,
}) => Inversion(
  id: id,
  libroId: libroId,
  nombre: estado.nombre,
  institucion: estado.institucion,
  saldoCentavos: estado.saldoCentavos,
  rendimientoPuntosBase: estado.rendimientoPuntosBase,
  fechaCaptura: estado.fecha,
  origen: OrigenDato.verificado,
  titularId: titularId,
);

// ------------------------------------------------------- bienes y previsión

enum TipoBien {
  auto('auto', 'Auto'),
  casa('casa', 'Casa'),
  otro('otro', 'Otro');

  const TipoBien(this.clave, this.etiqueta);
  final String clave;
  final String etiqueta;

  static TipoBien deClave(String? c) =>
      values.firstWhere((t) => t.clave == c, orElse: () => otro);
}

enum TipoPrevision {
  seguro('seguro', 'Seguro'),
  pension('pension', 'Pensión'),
  otro('otro', 'Otro');

  const TipoPrevision(this.clave, this.etiqueta);
  final String clave;
  final String etiqueta;

  static TipoPrevision deClave(String? c) =>
      values.firstWhere((t) => t.clave == c, orElse: () => otro);
}

class Bien {
  const Bien({
    required this.id,
    required this.libroId,
    required this.tipo,
    required this.nombre,
    required this.valorCentavos,
    this.fechaCaptura,
    this.titularId,
  });

  final String? titularId;
  final String id;
  final String libroId;
  final TipoBien tipo;
  final String nombre;
  final int valorCentavos;

  /// Fecha en que la persona capturó el valor. Sin ella, no es vigente.
  final Fecha? fechaCaptura;

  bool get vigente => fechaCaptura != null;
}

class Prevision {
  const Prevision({
    required this.id,
    required this.libroId,
    required this.tipo,
    required this.nombre,
    required this.valorCentavos,
    this.fechaCaptura,
    this.titularId,
  });

  final String? titularId;
  final String id;
  final String libroId;
  final TipoPrevision tipo;
  final String nombre;
  final int valorCentavos;
  final Fecha? fechaCaptura;

  bool get vigente => fechaCaptura != null;
}

// --------------------------------------------------------------- repositorio

abstract interface class RepositorioPatrimonio {
  Future<List<Objetivo>> objetivos(String libroId);
  Future<List<Inversion>> inversiones(String libroId);
  Future<List<Bien>> bienes(String libroId);
  Future<List<Prevision>> previsiones(String libroId);
  Future<void> guardarObjetivo(Objetivo o);
  Future<void> guardarInversion(Inversion i);
  Future<void> guardarBien(Bien b);
  Future<void> guardarPrevision(Prevision p);
}

class RepositorioPatrimonioEnMemoria implements RepositorioPatrimonio {
  RepositorioPatrimonioEnMemoria({
    List<Objetivo> objetivos = const [],
    List<Inversion> inversiones = const [],
    List<Bien> bienes = const [],
    List<Prevision> previsiones = const [],
  }) : _objetivos = {for (final o in objetivos) o.id: o},
       _inversiones = {for (final i in inversiones) i.id: i},
       _bienes = {for (final b in bienes) b.id: b},
       _previsiones = {for (final p in previsiones) p.id: p};

  final Map<String, Objetivo> _objetivos;
  final Map<String, Inversion> _inversiones;
  final Map<String, Bien> _bienes;
  final Map<String, Prevision> _previsiones;

  @override
  Future<List<Objetivo>> objetivos(String libroId) async => [
    for (final o in _objetivos.values)
      if (o.libroId == libroId) o,
  ];

  @override
  Future<List<Inversion>> inversiones(String libroId) async => [
    for (final i in _inversiones.values)
      if (i.libroId == libroId) i,
  ];

  @override
  Future<List<Bien>> bienes(String libroId) async => [
    for (final b in _bienes.values)
      if (b.libroId == libroId) b,
  ];

  @override
  Future<List<Prevision>> previsiones(String libroId) async => [
    for (final p in _previsiones.values)
      if (p.libroId == libroId) p,
  ];

  @override
  Future<void> guardarObjetivo(Objetivo o) async => _objetivos[o.id] = o;

  @override
  Future<void> guardarInversion(Inversion i) async => _inversiones[i.id] = i;

  @override
  Future<void> guardarBien(Bien b) async => _bienes[b.id] = b;

  @override
  Future<void> guardarPrevision(Prevision p) async => _previsiones[p.id] = p;
}

/// Adaptador del servidor (migración 20261136): lee las tablas (la RLS filtra
/// por persona; solo lo activo) y escribe **solo con las RPC** de guardar.
/// Las inversiones se leen de la vista de vigentes (con fecha de captura).
/// La fecha meta opcional y el rendimiento obligatorio (v1.1) piden la
/// migración 20261137 del servidor; hasta entonces `fecha_meta` es `not null`.
class RepositorioPatrimonioSupabase implements RepositorioPatrimonio {
  RepositorioPatrimonioSupabase(this.fuente);

  final FuenteTablas fuente;

  static const tablaObjetivos = 'fin_objetivos';
  static const vistaInversiones = 'fin_v_inversiones_vigentes';
  static const tablaBienes = 'fin_bienes';
  static const tablaPrevisiones = 'fin_previsiones';
  static const rpcObjetivo = 'fin_objetivo_guardar';
  static const rpcInversion = 'fin_inversion_guardar';
  static const rpcBien = 'fin_bien_guardar';
  static const rpcPrevision = 'fin_prevision_guardar';
  static const rpcAvance = 'fin_objetivo_avance';

  Fecha? _f(Object? v) => v == null ? null : Fecha.parse('$v'.substring(0, 10));
  String? _s(Fecha? f) => f?.toString();

  /// Filas del [libroId] que siguen activas ([activo] es la columna de baja).
  Future<List<Map<String, dynamic>>> _filas(
    String tabla,
    String libroId, {
    String? activo,
  }) async => [
    for (final f in await fuente.leer(tabla))
      if (f['libro_id'] == libroId && (activo == null || f[activo] != false)) f,
  ];

  @override
  Future<List<Objetivo>> objetivos(String libroId) async => [
    for (final f in await _filas(tablaObjetivos, libroId, activo: 'activo'))
      Objetivo(
        id: f['id'] as String,
        libroId: libroId,
        nombre: f['nombre'] as String,
        metaCentavos: (f['monto_meta_centavos'] as num).toInt(),
        fechaMeta: _f(f['fecha_meta']),
        bolsaId: f['bolsa_id'] as String?,
        titularId: f['titular_id'] as String?,
      ),
  ];

  @override
  Future<List<Inversion>> inversiones(String libroId) async => [
    for (final f in await _filas(vistaInversiones, libroId))
      Inversion(
        id: f['id'] as String,
        libroId: libroId,
        nombre: f['nombre'] as String,
        saldoCentavos: (f['saldo_centavos'] as num).toInt(),
        rendimientoPuntosBase: (f['rendimiento_pb'] as num?)?.toInt(),
        fechaCaptura: _f(f['fecha_captura'])!,
        origen: OrigenDato.deClave(f['origen'] as String?),
        titularId: f['titular_id'] as String?,
      ),
  ];

  @override
  Future<List<Bien>> bienes(String libroId) async => [
    for (final f in await _filas(tablaBienes, libroId, activo: 'activo'))
      Bien(
        id: f['id'] as String,
        libroId: libroId,
        tipo: TipoBien.deClave(f['tipo'] as String?),
        nombre: f['nombre'] as String,
        valorCentavos: (f['valor_centavos'] as num).toInt(),
        fechaCaptura: _f(f['fecha_captura']),
        titularId: f['titular_id'] as String?,
      ),
  ];

  @override
  Future<List<Prevision>> previsiones(String libroId) async => [
    for (final f in await _filas(tablaPrevisiones, libroId, activo: 'activa'))
      Prevision(
        id: f['id'] as String,
        libroId: libroId,
        tipo: TipoPrevision.deClave(f['tipo'] as String?),
        nombre: f['nombre'] as String,
        valorCentavos: (f['valor_centavos'] as num).toInt(),
        fechaCaptura: _f(f['fecha_captura']),
        titularId: f['titular_id'] as String?,
      ),
  ];

  String _titular(String? titularId) {
    if (titularId == null || titularId.isEmpty) {
      throw StateError('Falta la titular del libro para guardar.');
    }
    return titularId;
  }

  @override
  Future<void> guardarObjetivo(Objetivo o) async {
    await fuente.rpc(rpcObjetivo, {
      'p_id': o.id,
      'p_libro': o.libroId,
      'p_titular': _titular(o.titularId),
      'p_nombre': o.nombre,
      'p_monto_meta_centavos': o.metaCentavos,
      'p_fecha_meta': _s(o.fechaMeta),
      'p_bolsa': o.bolsaId,
    });
  }

  @override
  Future<void> guardarInversion(Inversion i) async {
    await fuente.rpc(rpcInversion, {
      'p_id': i.id,
      'p_libro': i.libroId,
      'p_titular': _titular(i.titularId),
      'p_nombre': i.nombre,
      'p_saldo_centavos': i.saldoCentavos,
      'p_rendimiento_pb': i.rendimientoPuntosBase,
      'p_origen': i.origen.clave,
      'p_fecha_captura': _s(i.fechaCaptura),
    });
  }

  @override
  Future<void> guardarBien(Bien b) async {
    await fuente.rpc(rpcBien, {
      'p_id': b.id,
      'p_libro': b.libroId,
      'p_titular': _titular(b.titularId),
      'p_nombre': b.nombre,
      'p_tipo': b.tipo.clave,
      'p_valor_centavos': b.valorCentavos,
      'p_fecha_captura': _s(b.fechaCaptura),
    });
  }

  @override
  Future<void> guardarPrevision(Prevision p) async {
    await fuente.rpc(rpcPrevision, {
      'p_id': p.id,
      'p_libro': p.libroId,
      'p_titular': _titular(p.titularId),
      'p_nombre': p.nombre,
      'p_tipo': p.tipo.clave,
      'p_valor_centavos': p.valorCentavos,
      'p_fecha_captura': _s(p.fechaCaptura),
    });
  }

  /// Avance calculado por el servidor (`fin_objetivo_avance`): la fila cruda
  /// (`estado`, `falta_centavos`, `semanas_estimadas`, `a_tiempo`, ...). Con
  /// objetivo sin fecha meta, `a_tiempo` no aplica.
  Future<Map<String, dynamic>?> avance(String objetivoId, Fecha hoy) async {
    final r = await fuente.rpc(rpcAvance, {
      'p_objetivo': objetivoId,
      'p_hoy': hoy.toString(),
    });
    if (r is List && r.isNotEmpty) {
      return Map<String, dynamic>.from(r.first as Map);
    }
    if (r is Map) return Map<String, dynamic>.from(r);
    return null;
  }
}

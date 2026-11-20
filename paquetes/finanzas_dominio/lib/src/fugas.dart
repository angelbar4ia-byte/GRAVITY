/// Fugas silenciosas (Fase 8, bloque 6; secciones 3 y 4 de
/// `docs/specs/fase-8-fugas-y-deudas.md` v0.3). Dart puro.
///
/// Cuatro fugas con definición operativa ([TipoFuga]): **hormiga** (pequeño y
/// frecuente), **fantasma** (cobros que ni se recuerdan), **vampiro**
/// (constante y creciente) y **zombie** (se paga por inercia). Cada cobro cae
/// en **una sola fuga principal** con el árbol de la sección 4.1; prioridad
/// fantasma, zombie, vampiro, hormiga; **la persona gana a la regla**.
///
/// Todo es **local y con reglas**: ningún comercio, monto ni cuenta sale de
/// aquí (D3). Dinero en centavos; semana de lunes a domingo; los umbrales
/// viven en [ParametrosFugas]. Solo cuentan los gastos vigentes (sin
/// contraasiento, [gastosVigentesParaFugas]). Nada se edita: las decisiones y
/// respuestas son filas nuevas con `reemplazaA`, y vale la más reciente.
library;

import 'dinero.dart';
import 'deuda_calidad.dart';
import 'fecha.dart';
import 'frecuencia.dart';
import 'libro.dart';
import 'parametros_fugas.dart';
import 'presupuesto.dart';
import 'categorias.dart';
import 'semana.dart';

// ============================================================ vocabulario

/// Las cuatro fugas y "ninguna".
enum TipoFuga { hormiga, fantasma, vampiro, zombie, ninguna }

/// Estado de lo detectado.
enum EstadoFuga {
  /// Cuenta en los totales.
  confirmada,

  /// Fantasma candidato: se le pregunta a la persona; sin respuesta no se
  /// acusa (no cuenta en los totales).
  porReconocer,

  /// La persona pidió vigilarlo (o "es por la temporada").
  enVigilancia,

  /// La persona dijo "No es una fuga": el patrón queda protegido.
  protegida,

  /// Cancelado (con o sin folio).
  cancelada,

  /// Falta un dato para evaluar la regla.
  sinDato,

  /// Sin fuga (recurrente sano, categoría necesaria, etc.).
  sinFuga,
}

/// Quién decidió la clasificación.
enum OrigenFuga { regla, persona }

/// Marcas que acompañan a una fuga.
enum MarcaFuga {
  cobradoTrasCancelar,
  porPagarSoloElMinimo,
  servicioDelHogar,
  agrupadoSinComercio,
  canceladoSinFolio,
  porTemporada,
}

/// Preguntas y confirmaciones que la persona contesta (`fin_fuga_respuestas`).
///
/// Las de `yaNoLaQuiero` (Z4), `duplicado` (Z2) y `planViejo` (Z3) no están
/// en el catálogo de la tabla de la sección 6.2: se proponen al backend.
enum PreguntaFuga {
  reconoce,
  uso,
  yaNoSirve,
  yaNoExiste,
  yaNoLaQuiero,
  duplicado,
  planViejo,
  cancelado,
  temporada,
}

/// Respuesta de la persona. En `uso`: `si` = "Lo usé", `no` = "No lo usé".
/// En `reconoce`: `si` = "Sí, lo conozco", `no` = "No lo conocía".
enum RespuestaPersona { si, no, despues }

/// Clave del patrón de una subcategoría hormiga.
String claveHormiga(String categoriaId) => 'hormiga|$categoriaId';

/// Clave de un cargo financiero de una deuda o tarjeta con estados de cuenta.
String claveCargo(String deudaId) => 'cargo|$deudaId';

// ======================================================== normalización

const _acentos = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

const _marcadoresDeReferencia = {
  'ref',
  'referencia',
  'folio',
  'aut',
  'autorizacion',
  'num',
  'numero',
  'no',
  'id',
};

/// Comercio normalizado (sección 3.0): minúsculas, sin acentos, sin números
/// de referencia y pasado por el diccionario del hogar.
///
/// Se quitan los tokens con 3 o más dígitos (referencias, folios, terminales)
/// y los marcadores "ref", "folio", "no"… cuando les sigue un número. El
/// resultado vacío es "sin comercio" (`''`).
///
/// El [diccionario] del hogar asocia un alias normalizado con el nombre
/// normalizado; se aplica si el texto es igual al alias o empieza con él
/// seguido de un espacio.
String normalizarComercio(
  String? texto, {
  Map<String, String> diccionario = const {},
}) {
  if (texto == null) return '';
  final sb = StringBuffer();
  for (final c in texto.toLowerCase().split('')) {
    sb.write(_acentos[c] ?? c);
  }
  final tokens = sb
      .toString()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  bool conNumero(String t) => RegExp(r'\d').hasMatch(t);
  bool referencia(String t) => RegExp(r'\d').allMatches(t).length >= 3;
  final limpios = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    final sigueNumero = i + 1 < tokens.length && conNumero(tokens[i + 1]);
    if (_marcadoresDeReferencia.contains(t) && sigueNumero) continue;
    if (referencia(t)) continue;
    // "ref 12": el marcador ya se quitó; un número corto suelto que sigue a
    // un marcador también es referencia.
    if (i > 0 &&
        _marcadoresDeReferencia.contains(tokens[i - 1]) &&
        conNumero(t)) {
      continue;
    }
    limpios.add(t);
  }
  final normal = limpios.join(' ');
  for (final e in diccionario.entries) {
    final alias = normalizarComercio(e.key);
    if (alias.isEmpty) continue;
    if (normal == alias || normal.startsWith('$alias ')) {
      return normalizarComercio(e.value);
    }
  }
  return normal;
}

// ================================================================ datos

/// Un gasto vigente para las reglas de fugas.
class GastoFuga {
  final String id;
  final Fecha fecha;
  final int monto;
  final String? categoriaId;

  /// Comercio tal como se capturó (opcional); se normaliza al analizar.
  final String? comercio;

  /// Cargo automático: viene de una importación o conciliación, o la persona
  /// marcó "es un cargo automático".
  final bool cobroAutomatico;

  const GastoFuga({
    required this.id,
    required this.fecha,
    required this.monto,
    this.categoriaId,
    this.comercio,
    this.cobroAutomatico = false,
  });
}

/// Los gastos vigentes de un libro: tipo `gasto`, sin contraasiento y sin ser
/// ellos mismos un contraasiento (sección 2, punto 4). Anular un gasto cambia
/// las fugas de inmediato.
///
/// El comercio y la marca de cargo automático salen del propio movimiento
/// ([Movimiento.comercio], [Movimiento.cobroAutomatico]); [comercios] y
/// [automaticos] los completan por id. Los movimientos de
/// [ViaCaptura.importacion] cuentan como cobro automático.
List<GastoFuga> gastosVigentesParaFugas(
  Iterable<Movimiento> movimientos, {
  Map<String, String> comercios = const {},
  Set<String> automaticos = const {},
}) {
  final lista = movimientos.toList();
  final anulados = {
    for (final m in lista)
      if (m.tipo == TipoMovimiento.anulacion && m.anulaA != null) m.anulaA!,
  };
  return [
    for (final m in lista)
      if (m.tipo == TipoMovimiento.gasto && !anulados.contains(m.id))
        GastoFuga(
          id: m.id,
          fecha: m.fecha,
          monto: m.monto,
          categoriaId: m.categoriaId,
          comercio: comercios[m.id] ?? m.comercio,
          cobroAutomatico:
              automaticos.contains(m.id) ||
              m.cobroAutomatico ||
              m.via == ViaCaptura.importacion,
        ),
  ];
}

/// Qué es una categoría para las reglas de fugas.
class CategoriaFuga {
  final String id;

  /// Prioridad `deseable` o `discrecional` y no protegida (3.0).
  final bool recortable;

  /// Luz, agua, gas (editable por hogar). Solo puede ser vampiro (V-C).
  final bool servicioHogar;

  /// "Comisiones bancarias", "Intereses y cargos financieros".
  final bool cargoFinanciero;

  /// Subcategoría de seguros (para el posible duplicado, Z2).
  final bool seguro;

  const CategoriaFuga(
    this.id, {
    this.recortable = true,
    this.servicioHogar = false,
    this.cargoFinanciero = false,
    this.seguro = false,
  });

  /// Arma la categoría desde la del libro: es recortable si no es `necesario`
  /// ni está protegida.
  factory CategoriaFuga.deCategoria(
    Categoria c, {
    bool servicioHogar = false,
    bool cargoFinanciero = false,
    bool seguro = false,
  }) => CategoriaFuga(
    c.id,
    recortable: c.prioridad != Prioridad.necesario && !c.protegida,
    servicioHogar: servicioHogar,
    cargoFinanciero: cargoFinanciero,
    seguro: seguro,
  );
}

/// Lo que la persona declaró de un patrón (`fin_patrones_cobro`).
class PatronDeclarado {
  final String clave;

  /// Compromiso que la persona declaró: el patrón ya es reconocido.
  final String? compromisoId;
  final Fecha? canceladoEn;

  /// Folio de cancelación ([validarFolio]); vacío = "cancelado sin folio".
  final String? folio;

  /// El bien al que sirve ya no existe: la app propone zombie (Z5), la
  /// persona confirma.
  final bool bienYaNoExiste;

  const PatronDeclarado(
    this.clave, {
    this.compromisoId,
    this.canceladoEn,
    this.folio,
    this.bienYaNoExiste = false,
  });
}

/// Respuesta de la persona (`fin_fuga_respuestas`; solo agregar).
class RespuestaFuga {
  final String id;
  final String clave;
  final PreguntaFuga pregunta;
  final RespuestaPersona respuesta;

  /// Lunes de la semana en que se contestó.
  final Fecha periodoLunes;
  final DateTime registradoEn;

  /// La respuesta que corrige (no se edita: se agrega otra).
  final String? reemplazaA;

  RespuestaFuga({
    required this.id,
    required this.clave,
    required this.pregunta,
    required this.respuesta,
    required this.periodoLunes,
    required this.registradoEn,
    this.reemplazaA,
  }) {
    if (periodoLunes.diaSemana != DateTime.monday) {
      throw ArgumentError('periodoLunes debe ser lunes: $periodoLunes');
    }
  }
}

/// Decisión de la persona sobre una clasificación (`fin_fuga_clasificaciones`
/// con `origen = persona`; solo agregar).
class DecisionFuga {
  final String id;
  final String clave;

  /// Lo que decidió; `ninguna` = "No es una fuga" (patrón protegido).
  final TipoFuga fuga;

  /// "Lo necesito pero lo quiero revisar": sin fuga, se pregunta a los 3
  /// meses.
  final bool vigilar;
  final String? motivo;
  final DateTime decididaEn;

  /// Monto del último cobro cuando decidió (para el cambio material).
  final int? montoAlDecidir;
  final String? reemplazaA;

  const DecisionFuga({
    required this.id,
    required this.clave,
    required this.fuga,
    required this.decididaEn,
    this.vigilar = false,
    this.motivo,
    this.montoAlDecidir,
    this.reemplazaA,
  });
}

/// Si la decisión contradice lo que dijo la regla.
bool decisionContradice(DecisionFuga d, TipoFuga fugaDeLaRegla) =>
    d.vigilar ? false : d.fuga != fugaDeLaRegla;

/// El motivo es obligatorio (3 a 200 caracteres, como un ajuste del libro)
/// cuando la decisión contradice la regla; si no, es opcional pero acotado.
/// Lanza [ArgumentError].
void validarMotivoDecision(
  String? motivo, {
  required bool contradiceLaRegla,
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  final texto = motivo?.trim() ?? '';
  if (contradiceLaRegla &&
      (texto.length < parametros.motivoMin ||
          texto.length > parametros.motivoMax)) {
    throw ArgumentError(
      'El motivo es obligatorio: de ${parametros.motivoMin} a '
      '${parametros.motivoMax} caracteres',
    );
  }
  if (texto.length > parametros.motivoMax) {
    throw ArgumentError('El motivo admite hasta ${parametros.motivoMax}');
  }
}

/// Folio de cancelación: de 1 a 40 caracteres, solo letras, números y
/// guiones (DF-26). Lanza [ArgumentError] si no cumple.
void validarFolio(
  String folio, {
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  if (!RegExp('^[A-Za-z0-9-]{1,${parametros.folioMax}}\$').hasMatch(folio)) {
    throw ArgumentError(
      'El folio lleva de 1 a ${parametros.folioMax} caracteres: letras, '
      'números y guiones',
    );
  }
}

/// Estado de la cancelación de un patrón.
enum EstadoCancelacion { noCancelado, cancelado, canceladoSinFolio }

/// "Cancelado" con folio; "cancelado sin folio" (pendiente de completar)
/// sin él. Un folio inválido lanza [ArgumentError].
EstadoCancelacion estadoCancelacion({
  Fecha? canceladoEn,
  String? folio,
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  if (canceladoEn == null) return EstadoCancelacion.noCancelado;
  if (folio == null || folio.isEmpty) {
    return EstadoCancelacion.canceladoSinFolio;
  }
  validarFolio(folio, parametros: parametros);
  return EstadoCancelacion.cancelado;
}

// ============================================================== patrones

/// Un cobro que se repite (3.0).
class PatronCobro {
  final String clave;

  /// Comercio normalizado; `null` si el gasto no lo trae.
  final String? comercioNorm;
  final String? categoriaId;

  /// Los cobros, de más antiguo a más reciente.
  final List<GastoFuga> cobros;
  final CadenciaCobro cadencia;
  final bool montoEstable;

  /// Se agrupó por subcategoría y monto porque no hay comercio (DF-20).
  final bool agrupadoSinComercio;

  const PatronCobro({
    required this.clave,
    required this.comercioNorm,
    required this.categoriaId,
    required this.cobros,
    required this.cadencia,
    required this.montoEstable,
    required this.agrupadoSinComercio,
  });

  /// Al menos 3 cobros en intervalos regulares y de monto estable.
  bool get esRecurrente => cadencia != CadenciaCobro.irregular && montoEstable;

  /// Cobro automático si cualquiera de sus cobros lo es.
  bool get automatico => cobros.any((c) => c.cobroAutomatico);

  int get ultimoMonto => cobros.last.monto;
  Fecha get ultimaFecha => cobros.last.fecha;
  Fecha get primeraFecha => cobros.first.fecha;

  /// Sigue cobrándose: el último cobro es de hace menos de dos periodos de
  /// su cadencia.
  bool estaActivo(Fecha hoy, ParametrosFugas p) {
    final t = _tolerancia(p, cadencia);
    if (t == null) return true;
    return ultimaFecha.diasHasta(hoy) <= 2 * (t.dias + t.tolerancia);
  }
}

ToleranciaCadencia? _tolerancia(ParametrosFugas p, CadenciaCobro c) {
  for (final t in p.tolerancias) {
    if (t.cadencia == c) return t;
  }
  return null;
}

Frecuencia? _frecuenciaDe(CadenciaCobro c) => switch (c) {
  CadenciaCobro.semanal => Frecuencia.semanal,
  CadenciaCobro.quincenal => Frecuencia.quincenal,
  CadenciaCobro.mensual => Frecuencia.mensual,
  CadenciaCobro.bimestral => Frecuencia.bimestral,
  CadenciaCobro.anual => Frecuencia.anual,
  CadenciaCobro.irregular => null,
};

/// Mediana en centavos (con cantidad par, el promedio de los dos centrales,
/// R1).
int mediana(List<int> valores) {
  if (valores.isEmpty) throw ArgumentError('No hay valores');
  final s = [...valores]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : dividirRedondeando(s[m - 1] + s[m], 2);
}

CadenciaCobro _cadenciaDe(List<Fecha> fechas, ParametrosFugas p) {
  if (fechas.length < p.recurrenteMinCobros) return CadenciaCobro.irregular;
  final dias = [
    for (var i = 1; i < fechas.length; i++) fechas[i - 1].diasHasta(fechas[i]),
  ];
  for (final t in p.tolerancias) {
    if (dias.every((d) => (d - t.dias).abs() <= t.tolerancia)) {
      return t.cadencia;
    }
  }
  return CadenciaCobro.irregular;
}

/// Monto estable: cada cobro dentro de ± 10 % de la mediana. Con 4 o más
/// cobros no se mide el último, que es el que se juzga por crecimiento (VB2):
/// así un aumento reciente no deshace el patrón (necesario para DF-11).
bool _montoEstable(List<int> montos, ParametrosFugas p) {
  if (montos.length < p.recurrenteMinCobros) return false;
  final base = montos.length >= 4
      ? montos.sublist(0, montos.length - 1)
      : montos;
  final med = mediana(base);
  return base.every(
    (m) => (m - med).abs() * puntosBaseEnCien <= med * p.recurrenteTolerancia,
  );
}

/// Agrupa los gastos en patrones de cobro: mismo comercio normalizado y misma
/// categoría; sin comercio, misma subcategoría y monto parecido (DF-20). Los
/// servicios del hogar y los cargos financieros sin comercio se agrupan solo
/// por categoría, porque su monto cambia de un recibo a otro.
List<PatronCobro> detectarPatrones(
  Iterable<GastoFuga> gastos, {
  Map<String, CategoriaFuga> categorias = const {},
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
  Map<String, String> diccionario = const {},
}) {
  final conComercio = <String, List<GastoFuga>>{};
  final sinComercio = <String, List<GastoFuga>>{};
  final nombres = <String, String>{};
  for (final g in gastos) {
    final norm = normalizarComercio(g.comercio, diccionario: diccionario);
    final cat = g.categoriaId ?? '';
    if (norm.isNotEmpty) {
      final k = '$norm|$cat';
      conComercio.putIfAbsent(k, () => []).add(g);
      nombres[k] = norm;
    } else {
      sinComercio.putIfAbsent(cat, () => []).add(g);
    }
  }

  PatronCobro armar(
    String clave,
    String? norm,
    String? cat,
    List<GastoFuga> lista,
    bool sinCom,
  ) {
    final cobros = [...lista]
      ..sort((a, b) {
        final r = a.fecha.compareTo(b.fecha);
        return r != 0 ? r : a.id.compareTo(b.id);
      });
    return PatronCobro(
      clave: clave,
      comercioNorm: norm,
      categoriaId: cat,
      cobros: cobros,
      cadencia: _cadenciaDe([for (final c in cobros) c.fecha], parametros),
      montoEstable: _montoEstable([
        for (final c in cobros) c.monto,
      ], parametros),
      agrupadoSinComercio: sinCom,
    );
  }

  final patrones = <PatronCobro>[
    for (final e in conComercio.entries)
      armar(e.key, nombres[e.key], e.value.first.categoriaId, e.value, false),
  ];

  for (final e in sinComercio.entries) {
    final cat = e.key.isEmpty ? null : e.key;
    final c = categorias[e.key];
    final porCategoria = c != null && (c.servicioHogar || c.cargoFinanciero);
    if (porCategoria) {
      patrones.add(armar('sin_comercio|${e.key}', null, cat, e.value, true));
      continue;
    }
    final ordenados = [...e.value]
      ..sort((a, b) {
        final r = a.monto.compareTo(b.monto);
        return r != 0 ? r : a.id.compareTo(b.id);
      });
    var grupo = <GastoFuga>[];
    void cierra() {
      if (grupo.isEmpty) return;
      patrones.add(
        armar(
          'sin_comercio|${e.key}|${grupo.first.monto}',
          null,
          cat,
          grupo,
          true,
        ),
      );
      grupo = [];
    }

    for (final g in ordenados) {
      if (grupo.isNotEmpty &&
          (g.monto - grupo.first.monto) * puntosBaseEnCien >
              grupo.first.monto * parametros.sinComercioTolerancia) {
        cierra();
      }
      grupo.add(g);
    }
    cierra();
  }
  patrones.sort((a, b) => a.clave.compareTo(b.clave));
  return patrones;
}

// ============================================================== ventanas

/// Las últimas [semanas] semanas completas (lunes a domingo) **terminadas**
/// antes de la semana de [hoy] (DF-22).
Periodo ventanaDeSemanas(Fecha hoy, int semanas) {
  final actual = Semana.de(hoy);
  return Periodo(actual.mas(-semanas).inicio, actual.anterior.fin);
}

// ================================================================ entrada

/// Todo lo que hace falta para clasificar las fugas de un libro.
class EntradaFugas {
  final Fecha hoy;

  /// Ingreso semanal esperado del libro (para el mes de referencia).
  final int ingresoSemanalCentavos;
  final List<GastoFuga> gastos;
  final Map<String, CategoriaFuga> categorias;
  final ParametrosFugas parametros;

  /// Alias de comercio del hogar (diccionario 5.2).
  final Map<String, String> diccionario;
  final List<PatronDeclarado> declarados;
  final List<RespuestaFuga> respuestas;
  final List<DecisionFuga> decisiones;

  /// Estados de cuenta con los pagos hechos (V-A, V-D).
  final List<CorteDeTarjeta> cortes;

  const EntradaFugas({
    required this.hoy,
    required this.ingresoSemanalCentavos,
    required this.gastos,
    this.categorias = const {},
    this.parametros = ParametrosFugas.porDefecto,
    this.diccionario = const {},
    this.declarados = const [],
    this.respuestas = const [],
    this.decisiones = const [],
    this.cortes = const [],
  });
}

// ============================================================== resultado

/// Una fuga (o un patrón evaluado) con la regla que la puso ahí.
class FugaDetectada {
  final String clave;
  final TipoFuga fuga;

  /// Código de la regla (`H`, `F3`, `F4`, `Z1`..`Z5`, `VA`, `VB`, `VC`, `VD`,
  /// `PERSONA`, ...).
  final String regla;
  final OrigenFuga origen;
  final EstadoFuga estado;
  final Set<MarcaFuga> marcas;
  final String? comercioNorm;
  final String? categoriaId;
  final String? deudaId;
  final CadenciaCobro cadencia;
  final Fecha? ultimaFecha;

  /// Ids de los gastos que sostienen la fuga (un gasto, una sola fuga).
  final List<String> gastoIds;
  final int ultimoMontoCentavos;

  /// Hormiga: suma de las 4 semanas. Demás: lo cobrado en los últimos 12
  /// meses.
  final int totalCentavos;

  /// Equivalente semanal (R1) y estimado anual (exacto).
  final int semanalCentavos;
  final int anualCentavos;

  /// Hay que volver a preguntar (cambio material, 12 meses, vigilar).
  final bool requiereRevision;

  /// El patrón es recurrente, automático y reconocido: se le puede preguntar
  /// el uso.
  final bool preguntarUso;

  const FugaDetectada({
    required this.clave,
    required this.fuga,
    required this.regla,
    this.origen = OrigenFuga.regla,
    this.estado = EstadoFuga.confirmada,
    this.marcas = const {},
    this.comercioNorm,
    this.categoriaId,
    this.deudaId,
    this.cadencia = CadenciaCobro.irregular,
    this.ultimaFecha,
    this.gastoIds = const [],
    this.ultimoMontoCentavos = 0,
    this.totalCentavos = 0,
    this.semanalCentavos = 0,
    this.anualCentavos = 0,
    this.requiereRevision = false,
    this.preguntarUso = false,
  });

  bool get cuenta =>
      estado == EstadoFuga.confirmada && fuga != TipoFuga.ninguna;

  FugaDetectada _con({
    TipoFuga? fuga,
    String? regla,
    OrigenFuga? origen,
    EstadoFuga? estado,
    bool? requiereRevision,
    bool? preguntarUso,
  }) => FugaDetectada(
    clave: clave,
    fuga: fuga ?? this.fuga,
    regla: regla ?? this.regla,
    origen: origen ?? this.origen,
    estado: estado ?? this.estado,
    marcas: marcas,
    comercioNorm: comercioNorm,
    categoriaId: categoriaId,
    deudaId: deudaId,
    cadencia: cadencia,
    ultimaFecha: ultimaFecha,
    gastoIds: gastoIds,
    ultimoMontoCentavos: ultimoMontoCentavos,
    totalCentavos: totalCentavos,
    semanalCentavos: semanalCentavos,
    anualCentavos: anualCentavos,
    requiereRevision: requiereRevision ?? this.requiereRevision,
    preguntarUso: preguntarUso ?? this.preguntarUso,
  );

  @override
  String toString() => '$clave -> ${fuga.name} ($regla, ${estado.name})';
}

/// Qué propone la app sin clasificar (la persona confirma).
enum TipoPropuesta { duplicado, planViejo, yaNoExiste }

class PropuestaFuga {
  final String clave;
  final TipoPropuesta tipo;

  /// Otros patrones implicados (por ejemplo, el otro seguro).
  final List<String> relacionadas;

  const PropuestaFuga(this.clave, this.tipo, [this.relacionadas = const []]);
}

/// Totales de una fuga (solo lo confirmado).
class TotalFuga {
  final TipoFuga fuga;
  final int elementos;
  final int totalCentavos;
  final int semanalCentavos;
  final int anualCentavos;

  const TotalFuga(
    this.fuga,
    this.elementos,
    this.totalCentavos,
    this.semanalCentavos,
    this.anualCentavos,
  );
}

/// Resultado de [analizarFugas].
class ResultadoFugas {
  /// Todo lo evaluado, incluidos los patrones sin fuga.
  final List<FugaDetectada> todas;
  final List<PropuestaFuga> propuestas;

  /// Todas las hormigas juntas pasan del umbral de conjunto (informativa).
  final bool alertaConjuntoHormiga;
  final int ingresoMensualReferencia;

  const ResultadoFugas({
    required this.todas,
    required this.propuestas,
    required this.alertaConjuntoHormiga,
    required this.ingresoMensualReferencia,
  });

  /// Las que cuentan en los totales: una sola fuga principal por cobro.
  List<FugaDetectada> get confirmadas => [
    for (final f in todas)
      if (f.cuenta) f,
  ];

  /// Fantasmas candidatos que esperan respuesta.
  List<FugaDetectada> get porReconocer => [
    for (final f in todas)
      if (f.estado == EstadoFuga.porReconocer) f,
  ];

  List<FugaDetectada> deTipo(TipoFuga t) => [
    for (final f in confirmadas)
      if (f.fuga == t) f,
  ];

  FugaDetectada? de(String clave) {
    for (final f in todas) {
      if (f.clave == clave) return f;
    }
    return null;
  }

  /// Totales por fuga (monto, semanal y anual). El semanal sale del anual
  /// exacto con R1.
  TotalFuga total(TipoFuga t) {
    final l = deTipo(t);
    final anual = l.fold<int>(0, (a, f) => a + f.anualCentavos);
    return TotalFuga(
      t,
      l.length,
      l.fold<int>(0, (a, f) => a + f.totalCentavos),
      Equivalente(anual).semanal,
      anual,
    );
  }

  /// Ids de gasto que sostienen alguna fuga confirmada.
  List<String> get gastoIdsEnFugas => [
    for (final f in confirmadas) ...f.gastoIds,
  ];
}

// ================================================================ motor

class _Ctx {
  final EntradaFugas e;
  late final List<RespuestaFuga> vigentes = _respuestasVigentes(e.respuestas);
  late final Map<String, PatronDeclarado> declarados = {
    for (final d in e.declarados) d.clave: d,
  };
  late final Map<String, DecisionFuga> decisiones = _decisionesVigentes(
    e.decisiones,
  );

  _Ctx(this.e);

  ParametrosFugas get p => e.parametros;

  RespuestaFuga? ultima(String clave, PreguntaFuga q) {
    RespuestaFuga? r;
    for (final x in vigentes) {
      if (x.clave == clave && x.pregunta == q) r = x;
    }
    return r;
  }

  bool confirma(String clave, PreguntaFuga q) =>
      ultima(clave, q)?.respuesta == RespuestaPersona.si;
}

int _porFecha(RespuestaFuga a, RespuestaFuga b) {
  var r = a.periodoLunes.compareTo(b.periodoLunes);
  if (r == 0) r = a.registradoEn.compareTo(b.registradoEn);
  return r != 0 ? r : a.id.compareTo(b.id);
}

/// Respuestas vigentes: las que ninguna otra reemplaza, de la más antigua a la
/// más reciente.
List<RespuestaFuga> _respuestasVigentes(Iterable<RespuestaFuga> todas) {
  final reemplazadas = {
    for (final r in todas)
      if (r.reemplazaA != null) r.reemplazaA!,
  };
  return [
    for (final r in todas)
      if (!reemplazadas.contains(r.id)) r,
  ]..sort(_porFecha);
}

/// Respuestas vigentes (las que ninguna otra reemplaza), ordenadas.
List<RespuestaFuga> respuestasVigentes(Iterable<RespuestaFuga> todas) =>
    _respuestasVigentes(todas);

Map<String, DecisionFuga> _decisionesVigentes(Iterable<DecisionFuga> todas) {
  final reemplazadas = {
    for (final d in todas)
      if (d.reemplazaA != null) d.reemplazaA!,
  };
  final porClave = <String, DecisionFuga>{};
  final vivas =
      [
        for (final d in todas)
          if (!reemplazadas.contains(d.id)) d,
      ]..sort((a, b) {
        final r = a.decididaEn.compareTo(b.decididaEn);
        return r != 0 ? r : a.id.compareTo(b.id);
      });
  for (final d in vivas) {
    porClave[d.clave] = d;
  }
  return porClave;
}

int _mesesEntre(Fecha a, Fecha b) {
  final m = (b.anio - a.anio) * 12 + (b.mes - a.mes);
  return b.dia < a.dia ? m - 1 : m;
}

/// Clasifica las fugas de un libro (sección 4.1). Una sola fuga principal por
/// cobro; la persona gana a la regla; sin respuesta no se acusa.
ResultadoFugas analizarFugas(EntradaFugas entrada) {
  final x = _Ctx(entrada);
  final p = x.p;
  final ref = ingresoMensualDeReferencia(entrada.ingresoSemanalCentavos);

  final patrones = detectarPatrones(
    entrada.gastos,
    categorias: entrada.categorias,
    parametros: p,
    diccionario: entrada.diccionario,
  );

  final todas = <FugaDetectada>[];
  final propuestas = <PropuestaFuga>[];

  // Con estados de cuenta, los cargos financieros salen de ellos y no de los
  // gastos de la categoría (el gasto no dice de qué deuda es: se evita contar
  // dos veces).
  final hayCortes = entrada.cortes.isNotEmpty;

  for (final pat in patrones) {
    final cat = entrada.categorias[pat.categoriaId];
    if (cat != null && cat.cargoFinanciero && hayCortes) continue;
    final porRegla = _clasificarPatron(x, pat, cat);
    todas.add(_aplicarDecision(x, porRegla, pat.ultimoMonto));
  }

  todas.addAll(_cargosDeCortes(x));
  // Un gasto, una sola fuga principal: la que ya salió de un patrón de cobro
  // (zombie, fantasma, vampiro...) gana; la hormiga no lo cuenta otra vez.
  final yaEnFuga = {
    for (final f in todas)
      if (f.cuenta) ...f.gastoIds,
  };
  final hormigas = _hormigas(x, ref, yaEnFuga);
  todas.addAll(hormigas);

  propuestas.addAll(_propuestas(x, patrones, todas));

  final sumaHormigas = [
    for (final f in hormigas)
      if (f.cuenta) f.totalCentavos,
  ].fold<int>(0, (a, b) => a + b);
  final alerta =
      ref > 0 &&
      sumaHormigas > 0 &&
      compararProporcion(sumaHormigas, ref, p.hormigaConjuntoPb) > 0;

  todas.sort((a, b) => a.clave.compareTo(b.clave));
  return ResultadoFugas(
    todas: todas,
    propuestas: propuestas,
    alertaConjuntoHormiga: alerta,
    ingresoMensualReferencia: ref,
  );
}

FugaDetectada _aplicarDecision(_Ctx x, FugaDetectada regla, int montoActual) {
  final d = x.decisiones[regla.clave];
  if (d == null) return regla;
  final p = x.p;
  final hoy = x.e.hoy;
  final desde = Fecha.deDateTime(d.decididaEn);
  var revisar = false;
  final meses = d.vigilar ? p.vigilarMeses : p.cambioMaterialMeses;
  if (_mesesEntre(desde, hoy) >= meses) revisar = true;
  if (!d.vigilar && d.montoAlDecidir != null && d.montoAlDecidir! > 0) {
    final cambio = (montoActual - d.montoAlDecidir!).abs();
    if (cambio * puntosBaseEnCien >= d.montoAlDecidir! * p.cambioMaterialPb) {
      revisar = true;
    }
  }
  if (d.vigilar) {
    return regla._con(
      fuga: TipoFuga.ninguna,
      regla: 'PERSONA',
      origen: OrigenFuga.persona,
      estado: EstadoFuga.enVigilancia,
      requiereRevision: revisar,
      preguntarUso: false,
    );
  }
  return regla._con(
    fuga: d.fuga,
    regla: 'PERSONA',
    origen: OrigenFuga.persona,
    estado: d.fuga == TipoFuga.ninguna
        ? EstadoFuga.protegida
        : EstadoFuga.confirmada,
    requiereRevision: revisar,
    preguntarUso: false,
  );
}

FugaDetectada _deLaRegla(
  PatronCobro pat,
  _Ctx x,
  TipoFuga fuga,
  String regla, {
  EstadoFuga estado = EstadoFuga.confirmada,
  Set<MarcaFuga> marcas = const {},
  bool preguntarUso = false,
}) {
  final p = x.p;
  final desde = x.e.hoy.sumarDias(-365);
  final total12 = pat.cobros
      .where((c) => c.fecha.despuesDe(desde))
      .fold<int>(0, (a, c) => a + c.monto);
  final frec = _frecuenciaDe(pat.cadencia);
  final anual = frec == null
      ? total12
      : Equivalente.de(pat.ultimoMonto, frec).anualCentavos;
  return FugaDetectada(
    clave: pat.clave,
    fuga: fuga,
    regla: regla,
    estado: estado,
    marcas: {
      ...marcas,
      if (pat.agrupadoSinComercio) MarcaFuga.agrupadoSinComercio,
    },
    comercioNorm: pat.comercioNorm,
    categoriaId: pat.categoriaId,
    cadencia: pat.cadencia,
    ultimaFecha: pat.ultimaFecha,
    gastoIds: [for (final c in pat.cobros) c.id],
    ultimoMontoCentavos: pat.ultimoMonto,
    totalCentavos: total12,
    semanalCentavos: Equivalente(anual).semanal,
    anualCentavos: anual,
    preguntarUso: preguntarUso && p.zombieRespuestas > 0,
  );
}

FugaDetectada _clasificarPatron(_Ctx x, PatronCobro pat, CategoriaFuga? cat) {
  final p = x.p;
  final hoy = x.e.hoy;
  final decl = x.declarados[pat.clave];

  FugaDetectada ninguna(
    String regla, {
    EstadoFuga estado = EstadoFuga.sinFuga,
    Set<MarcaFuga> marcas = const {},
  }) => _deLaRegla(
    pat,
    x,
    TipoFuga.ninguna,
    regla,
    estado: estado,
    marcas: marcas,
  );

  // Paso 0: ¿es un gasto de categoría que se evalúa?
  if (cat == null) return ninguna('0');

  // Cancelado: lo cobrado después de cancelar es fantasma (F4); si no, queda
  // cancelado (con o sin folio).
  if (decl?.canceladoEn != null) {
    final despues = pat.cobros.any(
      (c) => c.fecha.despuesDe(decl!.canceladoEn!),
    );
    if (despues) {
      return _deLaRegla(
        pat,
        x,
        TipoFuga.fantasma,
        'F4',
        marcas: {MarcaFuga.cobradoTrasCancelar},
      );
    }
    return ninguna(
      'CANCELADO',
      estado: EstadoFuga.cancelada,
      marcas: {
        if (estadoCancelacion(
              canceladoEn: decl!.canceladoEn,
              folio: decl.folio,
              parametros: p,
            ) ==
            EstadoCancelacion.canceladoSinFolio)
          MarcaFuga.canceladoSinFolio,
      },
    );
  }

  // Paso 1: cargo financiero con gastos (sin estados de cuenta).
  if (cat.cargoFinanciero) {
    if (x.confirma(pat.clave, PreguntaFuga.yaNoLaQuiero)) {
      return _deLaRegla(pat, x, TipoFuga.zombie, 'Z4');
    }
    final anual = pat.cadencia == CadenciaCobro.anual;
    int periodo(Fecha f) => anual ? f.anio : f.anio * 12 + f.mes;
    final ahora = periodo(hoy);
    final con = {
      for (final c in pat.cobros)
        if (periodo(c.fecha) > ahora - p.cargoPeriodosVentana &&
            periodo(c.fecha) <= ahora)
          periodo(c.fecha),
    };
    if (con.length >= p.cargoPeriodosMin) {
      return _deLaRegla(pat, x, TipoFuga.vampiro, 'VA');
    }
    return ninguna('VA');
  }

  // Paso 1b: servicio del hogar contra su mediana (V-C).
  if (cat.servicioHogar) return _servicio(x, pat);

  // Categorías necesarias o protegidas no se recortan.
  if (!cat.recortable) return ninguna('0');

  // Paso 2: cobro automático recurrente.
  if (!(pat.esRecurrente && pat.automatico)) return ninguna('5');

  final reconoce = x.ultima(pat.clave, PreguntaFuga.reconoce)?.respuesta;
  if (reconoce == RespuestaPersona.no) {
    return _deLaRegla(pat, x, TipoFuga.fantasma, 'F3');
  }
  final reconocido =
      reconoce == RespuestaPersona.si || decl?.compromisoId != null;
  if (!reconocido) {
    return _deLaRegla(
      pat,
      x,
      TipoFuga.fantasma,
      'F3',
      estado: EstadoFuga.porReconocer,
    );
  }

  // Zombie: lo que la persona confirmó.
  final usos = [
    for (final r in x.vigentes)
      if (r.clave == pat.clave &&
          r.pregunta == PreguntaFuga.uso &&
          r.respuesta != RespuestaPersona.despues)
        r,
  ];
  final ultimosNoUse =
      usos.length >= p.zombieRespuestas &&
      usos
          .sublist(usos.length - p.zombieRespuestas)
          .every((r) => r.respuesta == RespuestaPersona.no);
  if (ultimosNoUse) return _deLaRegla(pat, x, TipoFuga.zombie, 'Z1');
  if (x.confirma(pat.clave, PreguntaFuga.yaNoSirve)) {
    return _deLaRegla(pat, x, TipoFuga.zombie, 'Z1');
  }
  if (x.confirma(pat.clave, PreguntaFuga.duplicado)) {
    return _deLaRegla(pat, x, TipoFuga.zombie, 'Z2');
  }
  if (x.confirma(pat.clave, PreguntaFuga.planViejo)) {
    return _deLaRegla(pat, x, TipoFuga.zombie, 'Z3');
  }
  if (x.confirma(pat.clave, PreguntaFuga.yaNoLaQuiero)) {
    return _deLaRegla(pat, x, TipoFuga.zombie, 'Z4');
  }
  if (x.confirma(pat.clave, PreguntaFuga.yaNoExiste)) {
    return _deLaRegla(pat, x, TipoFuga.zombie, 'Z5');
  }

  // Vampiro: crece (VB2).
  if (_crece(x, pat)) return _deLaRegla(pat, x, TipoFuga.vampiro, 'VB');

  return _deLaRegla(
    pat,
    x,
    TipoFuga.ninguna,
    'RECURRENTE',
    estado: EstadoFuga.sinFuga,
    preguntarUso: true,
  );
}

bool _crece(_Ctx x, PatronCobro pat) {
  final p = x.p;
  final desde = x.e.hoy.sumarDias(-p.vampiroDiasHistoria);
  final montos = [
    for (final c in pat.cobros)
      if (c.fecha.despuesDe(desde)) c.monto,
  ];
  if (montos.length < 2) return false;
  final primero = montos.first;
  final ultimo = montos.last;
  if (primero > 0 &&
      ultimo * puntosBaseEnCien >=
          primero * (puntosBaseEnCien + p.vampiroCrecimientoPb)) {
    return true;
  }
  final n = p.vampiroAumentosSeguidos;
  if (montos.length >= n + 1) {
    final cola = montos.sublist(montos.length - n - 1);
    var sube = true;
    for (var i = 1; i < cola.length; i++) {
      if (cola[i] <= cola[i - 1]) sube = false;
    }
    if (sube) return true;
  }
  return false;
}

/// V-C: un servicio del hogar que se infla contra su propia mediana.
FugaDetectada _servicio(_Ctx x, PatronCobro pat) {
  final p = x.p;
  final montos = [for (final c in pat.cobros) c.monto];
  if (montos.length < p.servicioPeriodosMin) {
    return _deLaRegla(
      pat,
      x,
      TipoFuga.ninguna,
      'VC1',
      estado: EstadoFuga.sinDato,
      marcas: {MarcaFuga.servicioDelHogar},
    );
  }
  final base = montos.length > p.servicioPeriodosMediana
      ? montos.sublist(montos.length - p.servicioPeriodosMediana)
      : montos;
  final med = mediana(base);
  final recientes = montos.length > p.servicioVentana
      ? montos.sublist(montos.length - p.servicioVentana)
      : montos;
  final superan = recientes
      .where(
        (m) =>
            m * puntosBaseEnCien >=
            med * (puntosBaseEnCien + p.servicioMedianaPb),
      )
      .length;
  if (superan < p.servicioMinSuperan) {
    return _deLaRegla(
      pat,
      x,
      TipoFuga.ninguna,
      'VC3',
      marcas: {MarcaFuga.servicioDelHogar},
      estado: EstadoFuga.sinFuga,
    );
  }
  final temporada = x.ultima(pat.clave, PreguntaFuga.temporada);
  if (temporada != null &&
      temporada.respuesta == RespuestaPersona.si &&
      temporada.periodoLunes.anio == x.e.hoy.anio) {
    return _deLaRegla(
      pat,
      x,
      TipoFuga.ninguna,
      'VC3',
      estado: EstadoFuga.enVigilancia,
      marcas: {MarcaFuga.servicioDelHogar, MarcaFuga.porTemporada},
    );
  }
  return _deLaRegla(
    pat,
    x,
    TipoFuga.vampiro,
    'VC',
    marcas: {MarcaFuga.servicioDelHogar},
  );
}

/// V-A y V-D con estados de cuenta, y Z4 de una cuenta que no se quiere.
List<FugaDetectada> _cargosDeCortes(_Ctx x) {
  final p = x.p;
  final hoy = x.e.hoy;
  final ids = {for (final c in x.e.cortes) c.deudaId}.toList()..sort();
  final salida = <FugaDetectada>[];
  for (final deudaId in ids) {
    final clave = claveCargo(deudaId);
    final vig = cortesVigentes(x.e.cortes, deudaId);
    final desde = hoy.sumarDias(-365);
    final total12 = vig
        .where((c) => c.estado.fechaCorte.despuesDe(desde))
        .fold<int>(0, (a, c) => a + c.estado.intereses + c.estado.cargos);
    final ultimo = vig.first;

    FugaDetectada arma(
      TipoFuga fuga,
      String regla, {
      Set<MarcaFuga> marcas = const {},
      EstadoFuga estado = EstadoFuga.confirmada,
    }) => FugaDetectada(
      clave: clave,
      fuga: fuga,
      regla: regla,
      estado: estado,
      marcas: marcas,
      deudaId: deudaId,
      cadencia: CadenciaCobro.mensual,
      ultimaFecha: ultimo.estado.fechaCorte,
      ultimoMontoCentavos: ultimo.estado.intereses + ultimo.estado.cargos,
      totalCentavos: total12,
      semanalCentavos: Equivalente(total12).semanal,
      anualCentavos: total12,
    );

    FugaDetectada r;
    if (x.confirma(clave, PreguntaFuga.yaNoLaQuiero)) {
      r = arma(TipoFuga.zombie, 'Z4');
    } else {
      // V-D: intereses por pagar solo el mínimo (basta un corte).
      var porMinimo = false;
      if (ultimo.estado.intereses > 0) {
        final prev = vig.length > 1 ? vig[1] : null;
        // Nulo = sin dato: no se acusa (no se lee como «pagó cero»).
        final pagos =
            prev?.pagosAlCorteCentavos ?? ultimo.pagosCicloAnteriorCentavos;
        final sinIntereses = prev != null
            ? prev.estado.pagoSinIntereses
            : ultimo.estado.pagoSinIntereses;
        porMinimo = pagos != null && pagos < sinIntereses;
      }
      if (porMinimo) {
        r = arma(
          TipoFuga.vampiro,
          'VD',
          marcas: {MarcaFuga.porPagarSoloElMinimo},
        );
      } else {
        final con = vig
            .take(p.cargoPeriodosVentana)
            .where((c) => c.estado.intereses + c.estado.cargos > 0)
            .length;
        r = con >= p.cargoPeriodosMin
            ? arma(TipoFuga.vampiro, 'VA')
            : arma(TipoFuga.ninguna, 'VA', estado: EstadoFuga.sinFuga);
      }
    }
    salida.add(_aplicarDecision(x, r, r.ultimoMontoCentavos));
  }
  return salida;
}

/// Hormiga por subcategoría (H1 a H5), con la ventana de 4 semanas.
List<FugaDetectada> _hormigas(_Ctx x, int ref, Set<String> yaEnFuga) {
  final p = x.p;
  final ventana = ventanaDeSemanas(x.e.hoy, p.hormigaSemanasVentana);
  final porCat = <String, List<GastoFuga>>{};
  for (final g in x.e.gastos) {
    final cat = x.e.categorias[g.categoriaId];
    if (cat == null || !cat.recortable) continue; // H1
    if (cat.servicioHogar || cat.cargoFinanciero) continue;
    if (g.cobroAutomatico) continue; // H1
    if (g.monto > p.topeHormigaCentavos) continue; // H2
    if (!ventana.contiene(g.fecha)) continue;
    porCat.putIfAbsent(g.categoriaId!, () => []).add(g);
  }
  final salida = <FugaDetectada>[];
  final claves = porCat.keys.toList()..sort();
  for (final cat in claves) {
    final candidatos = porCat[cat]!;
    // H3 a H5 miden el hábito de la categoría con todas sus compras chicas...
    if (candidatos.length < p.hormigaMinGastos) continue; // H3
    final semanas = {for (final g in candidatos) Semana.de(g.fecha)};
    if (semanas.length < p.hormigaMinSemanas) continue; // H4
    final sumaHabito = candidatos.fold<int>(0, (a, g) => a + g.monto);
    if (ref <= 0 ||
        compararProporcion(sumaHabito, ref, p.hormigaMinIngresoPb) < 0) {
      continue; // H5
    }
    // ...pero un gasto que ya sostiene otra fuga (fantasma, zombie, vampiro:
    // prioridad de la sección 4.1) no se cuenta dos veces: la hormiga solo
    // lleva el resto.
    final lista = [
      for (final g in candidatos)
        if (!yaEnFuga.contains(g.id)) g,
    ];
    if (lista.isEmpty) continue;
    final suma = lista.fold<int>(0, (a, g) => a + g.monto);
    final anual = suma * 52 ~/ p.hormigaSemanasVentana;
    final r = FugaDetectada(
      clave: claveHormiga(cat),
      fuga: TipoFuga.hormiga,
      regla: 'H',
      categoriaId: cat,
      cadencia: CadenciaCobro.irregular,
      gastoIds: [for (final g in lista) g.id],
      totalCentavos: suma,
      semanalCentavos: dividirRedondeando(suma, p.hormigaSemanasVentana),
      anualCentavos: anual,
    );
    salida.add(_aplicarDecision(x, r, 0));
  }
  return salida;
}

List<PropuestaFuga> _propuestas(
  _Ctx x,
  List<PatronCobro> patrones,
  List<FugaDetectada> todas,
) {
  final p = x.p;
  final salida = <PropuestaFuga>[];
  final sinZombie = {
    for (final f in todas)
      if (f.fuga != TipoFuga.zombie && f.fuga != TipoFuga.fantasma) f.clave,
  };
  bool candidato(PatronCobro pat) =>
      pat.esRecurrente &&
      pat.estaActivo(x.e.hoy, p) &&
      sinZombie.contains(pat.clave) &&
      x.decisiones[pat.clave] == null &&
      x.declarados[pat.clave]?.canceladoEn == null;

  final activos = patrones.where(candidato).toList();

  // Z2: dos seguros activos en la misma subcategoría.
  final porCat = <String, List<PatronCobro>>{};
  for (final pat in activos) {
    final cat = x.e.categorias[pat.categoriaId];
    if (cat != null && cat.seguro) {
      porCat.putIfAbsent(pat.categoriaId!, () => []).add(pat);
    }
  }
  for (final g in porCat.values.where((g) => g.length >= 2)) {
    for (final pat in g) {
      salida.add(
        PropuestaFuga(pat.clave, TipoPropuesta.duplicado, [
          for (final o in g)
            if (o.clave != pat.clave) o.clave,
        ]),
      );
    }
  }

  // Z3: mismo comercio normalizado en dos patrones activos; el candidato es
  // el más antiguo.
  final porComercio = <String, List<PatronCobro>>{};
  for (final pat in activos) {
    if (pat.comercioNorm != null) {
      porComercio.putIfAbsent(pat.comercioNorm!, () => []).add(pat);
    }
  }
  for (final g in porComercio.values.where((g) => g.length >= 2)) {
    final orden = [...g]
      ..sort((a, b) => a.primeraFecha.compareTo(b.primeraFecha));
    salida.add(
      PropuestaFuga(orden.first.clave, TipoPropuesta.planViejo, [
        for (final o in orden.skip(1)) o.clave,
      ]),
    );
  }

  // Z5: el bien al que sirve ya no existe.
  for (final pat in patrones) {
    final d = x.declarados[pat.clave];
    if (d != null &&
        d.bienYaNoExiste &&
        sinZombie.contains(pat.clave) &&
        x.decisiones[pat.clave] == null) {
      salida.add(PropuestaFuga(pat.clave, TipoPropuesta.yaNoExiste));
    }
  }
  return salida;
}

// ============================================================ preguntas

/// Qué se le pregunta a la persona.
enum TipoPregunta { reconoce, uso }

class PreguntaRevision {
  final String clave;
  final TipoPregunta tipo;

  const PreguntaRevision(this.clave, this.tipo);
}

/// Preguntas de la revisión mensual (D25), como máximo
/// [ParametrosFugas.revisionMaxPreguntas]: primero "¿Lo reconoces?" de los
/// fantasmas candidatos y después "¿Lo usaste?" de los recurrentes
/// reconocidos. Una por patrón, como máximo una al mes y una por periodo de su
/// cadencia; una anual, 30 días antes del cobro esperado. Sin respuesta, la
/// pregunta no cuenta ni a favor ni en contra.
List<PreguntaRevision> preguntasDeRevision(
  ResultadoFugas resultado,
  EntradaFugas entrada,
) {
  final p = entrada.parametros;
  final hoy = entrada.hoy;
  final vigentes = _respuestasVigentes(entrada.respuestas);

  RespuestaFuga? ultima(String clave, PreguntaFuga q) {
    RespuestaFuga? r;
    for (final v in vigentes) {
      if (v.clave == clave && v.pregunta == q) r = v;
    }
    return r;
  }

  bool preguntadoEnElMes(RespuestaFuga? r) =>
      r != null &&
      r.periodoLunes.anio == hoy.anio &&
      r.periodoLunes.mes == hoy.mes;

  final salida = <PreguntaRevision>[];
  for (final f in resultado.todas) {
    if (f.estado == EstadoFuga.porReconocer && f.origen == OrigenFuga.regla) {
      if (!preguntadoEnElMes(ultima(f.clave, PreguntaFuga.reconoce))) {
        salida.add(PreguntaRevision(f.clave, TipoPregunta.reconoce));
      }
    }
  }
  for (final f in resultado.todas) {
    if (!f.preguntarUso) continue;
    final previa = ultima(f.clave, PreguntaFuga.uso);
    if (f.cadencia == CadenciaCobro.anual) {
      final t = _tolerancia(p, CadenciaCobro.anual)!;
      final esperado = f.ultimaFecha!.sumarDias(t.dias);
      final falta = hoy.diasHasta(esperado);
      if (falta < 0 || falta > p.preguntaAnualDiasAntes) continue;
      if (previa != null && !previa.periodoLunes.antesDe(f.ultimaFecha!)) {
        continue;
      }
    } else {
      final t = _tolerancia(p, f.cadencia);
      final minimo = t != null && t.dias > 30 ? t.dias : 30;
      if (previa != null && previa.periodoLunes.diasHasta(hoy) < minimo) {
        continue;
      }
    }
    salida.add(PreguntaRevision(f.clave, TipoPregunta.uso));
  }
  return salida.take(p.revisionMaxPreguntas).toList();
}

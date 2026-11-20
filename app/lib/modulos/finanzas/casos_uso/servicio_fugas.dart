/// Casos de uso de las fugas silenciosas y de la deuda buena o mala (Fase 8,
/// bloque 6; `docs/specs/fase-8-fugas-y-deudas.md`).
///
/// - **Todo se calcula en el dispositivo, con reglas locales** (`analizarFugas`
///   y `evaluarDeudas` de `finanzas_dominio`): ni el comercio ni el monto salen
///   a la IA en la nube ni a las bocinas (D3, D6). No hay red para clasificar.
/// - **La app propone y la persona decide.** Sin respuesta no se acusa. Una
///   deuda mala **solo avisa y sugiere**: nada aquí bloquea un registro.
/// - **Permisos por rol** (D5, D19): ve y responde solo quien puede ver las
///   deudas del libro **y** es dueño o coadministrador; la cuenta maestra solo
///   lee; el familiar, el cuidador, Casa, la tablet pública y la vista temporal
///   de Papá no ven nada. El servidor lo vuelve a verificar (RLS y RPC).
/// - Las escrituras (responder, clasificar, cancelar, declarar el propósito)
///   necesitan señal: el repositorio de Supabase lanza `ErrorFinanzas` con
///   `sinConexion` y la pantalla lo dice.
/// - Los avisos van **sin cifras ni comercios** (D20), con claves estables
///   para avisar una sola vez.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../../../nucleo/contratos/roles.dart' show Rol;
import '../datos/repositorio.dart' show ErrorFinanzas;
import '../datos/repositorio_fugas.dart';
import 'servicio_finanzas.dart';

/// Tipos de aviso del bloque (D20: catálogo cerrado, título genérico).
abstract final class TiposAvisoFugas {
  static const fugaPorReconocer = 'fuga_por_reconocer';
  static const fugaRevisionMensual = 'fuga_revision_mensual';
  static const deudaEnVigilancia = 'deuda_en_vigilancia';
  static const deudaSeVolvioMala = 'deuda_se_volvio_mala';
}

/// Claves estables de los avisos (solo minúsculas, dígitos y `_:.-`; sin
/// comercios ni cifras de dinero).
abstract final class ClavesAvisoFugas {
  /// Un cobro por reconocer: una sola vez por patrón.
  static String porReconocer(String patronId) => 'fuga:$patronId:por_reconocer';

  /// La revisión de cobros: una por libro y mes.
  static String revisionMensual(String libroId, Fecha hoy) =>
      'fuga:revision:$libroId:${hoy.anio}-${hoy.mes.toString().padLeft(2, '0')}';

  /// Una deuda que subió de nivel: una por deuda, nivel y semana (el lunes en
  /// que cambió). Un mismo cambio avisa una sola vez, aunque lo calculen dos
  /// dispositivos; un deterioro nuevo, semanas después, vuelve a avisar.
  static String deuda(String deudaId, String nivel, Fecha lunes) =>
      'deuda:$deudaId:$nivel:$lunes';
}

/// Lo que dice el libro sobre sus fugas, calculado ahora.
class AnalisisFugas {
  const AnalisisFugas({
    required this.libroId,
    required this.hoy,
    required this.resultado,
    required this.preguntas,
    required this.patronesDetectados,
    required this.ingresoMensualCentavos,
    this.fallo = false,
  });

  /// Libro sin nada que mostrar (o un cálculo que no se pudo hacer).
  AnalisisFugas.vacio(this.libroId, this.hoy, {this.fallo = false})
    : resultado = const ResultadoFugas(
        todas: [],
        propuestas: [],
        alertaConjuntoHormiga: false,
        ingresoMensualReferencia: 0,
      ),
      preguntas = const [],
      patronesDetectados = const {},
      ingresoMensualCentavos = 0;

  final String libroId;
  final Fecha hoy;
  final ResultadoFugas resultado;

  /// La revisión mensual: como máximo 7 preguntas, ya filtradas.
  final List<PreguntaRevision> preguntas;
  final Map<String, PatronCobro> patronesDetectados;
  final int ingresoMensualCentavos;

  /// El cálculo lanzó un error inesperado (se muestra el estado vacío).
  final bool fallo;

  /// Las fugas confirmadas de un tipo (una sola fuga principal por cobro).
  List<FugaDetectada> deTipo(TipoFuga t) => resultado.deTipo(t);

  TotalFuga total(TipoFuga t) => resultado.total(t);

  /// Cobros que esperan respuesta de la persona (fantasmas candidatos).
  List<FugaDetectada> get porReconocer => resultado.porReconocer;

  /// Hay algo que mostrar: alguna fuga, un candidato o una pregunta.
  bool get hayAlgo =>
      resultado.confirmadas.isNotEmpty ||
      resultado.porReconocer.isNotEmpty ||
      preguntas.isNotEmpty;

  /// Cuántos gastos sostienen la fuga [f] (el MISMO conjunto que su total,
  /// hallazgo H-04).
  int comprasDe(FugaDetectada f) => f.gastoIds.length;
}

/// Una deuda con su calidad (la señal, el estado mostrado y lo declarado).
class DeudaConCalidad {
  const DeudaConCalidad({
    required this.deuda,
    required this.calidad,
    required this.mostrado,
    this.declaracion,
    this.precioContadoCentavos,
    this.esMsi = false,
  });

  final Deuda deuda;

  /// Lo que dicen las reglas hoy.
  final CalidadDeuda calidad;

  /// Lo que se muestra: el de las reglas, salvo que una mejora espere sus dos
  /// evaluaciones semanales seguidas (histéresis, 5.5).
  final EstadoCalidad mostrado;
  final DeclaracionDeuda? declaracion;
  final int? precioContadoCentavos;
  final bool esMsi;

  /// Una mejora todavía no se muestra (espera la evaluación de la semana
  /// siguiente).
  bool get mejoraEnEspera => mostrado != calidad.estado;
}

/// El efecto de las compras a meses sobre el ingreso (gadget «Tus MSI y tu
/// ingreso»).
class ResumenMsi {
  const ResumenMsi({
    required this.activos,
    required this.mensualidadesCentavos,
    required this.puntosBase,
    required this.sobreIngreso,
    required this.activosNivel,
  });

  final int activos;
  final int mensualidadesCentavos;

  /// Mensualidades ÷ ingreso mensual, en puntos base redondeados (solo para
  /// mostrar).
  final int puntosBase;
  final NivelSenal sobreIngreso;
  final NivelSenal activosNivel;

  /// El peor de los dos niveles.
  NivelSenal get nivel =>
      sobreIngreso == NivelSenal.rojo || activosNivel == NivelSenal.rojo
      ? NivelSenal.rojo
      : sobreIngreso == NivelSenal.ambar || activosNivel == NivelSenal.ambar
      ? NivelSenal.ambar
      : (sobreIngreso == NivelSenal.sinDato
            ? NivelSenal.sinDato
            : NivelSenal.verde);
}

class ServicioFugas {
  ServicioFugas({
    required this.finanzas,
    required this.repositorio,
    this.rol,
    this.esTabletPublica = false,
    DateTime Function()? reloj,
    Set<String>? avisadas,
  }) : _reloj = reloj ?? DateTime.now,
       _avisadas = avisadas ?? <String>{};

  final ServicioFinanzas finanzas;
  final RepositorioFugas repositorio;

  /// Rol de la sesión (solo el dueño y el coadministrador ven fugas y deudas
  /// buenas o malas, D5).
  final Rol? rol;

  /// La tablet pública del modo Casa: no muestra nada de esto (D14).
  final bool esTabletPublica;
  final DateTime Function() _reloj;

  DatosFinanzas get _d => finanzas.datos;
  Fecha get hoy => finanzas.hoy;
  DatosFugas get _g => repositorio.actuales;

  /// Claves ya avisadas (compartida entre instancias del servicio de la misma
  /// sesión: el servidor también deduplica por `(persona, clave)`).
  final Set<String> _avisadas;
  DateTime? _topeHasta;

  /// Claves ya avisadas en esta sesión (para las pruebas).
  Set<String> get avisadas => Set.unmodifiable(_avisadas);

  // ---------------------------------------------------------------- permisos

  /// Ve las fugas y la calidad de las deudas del libro: puede leerlo, es dueño
  /// o coadministrador y no es la tablet pública. La cuenta maestra lo ve **en
  /// solo lectura**.
  bool puedeVer(String libroId) =>
      !esTabletPublica &&
      (rol == Rol.dueno || rol == Rol.coadministrador) &&
      finanzas.permiso(libroId).leer;

  /// Responde, clasifica y cancela: puede ver y escribir (la cuenta maestra y
  /// los libros archivados, no).
  bool puedeResponder(String libroId) {
    if (!puedeVer(libroId) || finanzas.soloLectura) return false;
    final libro = _d.libro(libroId);
    if (libro == null || libro.archivado) return false;
    return finanzas.permiso(libroId).escribir;
  }

  /// Declara el propósito de una deuda: además, administra el libro.
  bool puedeDeclarar(String libroId) =>
      puedeResponder(libroId) && finanzas.permiso(libroId).administrar;

  void _exigirResponder(String libroId) {
    if (!puedeVer(libroId)) {
      throw const ErrorFinanzas('No puedes ver las fugas de este libro.');
    }
    finanzas.exigirEscribir(libroId);
  }

  /// El libro de Papá: la decisión va «en nombre de» él y lleva motivo.
  bool _esRepresentado(String libroId) =>
      _d.libro(libroId)?.tipo == TipoLibro.representado;

  String? _motivoParaDecision(String libroId, String? motivo) {
    final t = motivo?.trim();
    if (_esRepresentado(libroId) && !motivoValido(t)) {
      throw ErrorFinanzas(
        'En el libro de Papá cada decisión lleva un motivo. '
        '$mensajeMotivoCorto',
      );
    }
    return t == null || t.isEmpty ? null : t;
  }

  // ------------------------------------------------------------------ fugas

  Set<String> _idsDeGastosDelLibro(String libroId) {
    final cuentas = {
      for (final c in _d.cuentas)
        if (c.libroId == libroId) c.id,
    };
    return {
      for (final m in _d.movimientos)
        if (m.tipo == TipoMovimiento.gasto &&
            m.estadoInicial == EstadoMovimiento.confirmado &&
            cuentas.contains(m.cuentaOrigenId))
          m.id,
    };
  }

  /// Cómo trata cada categoría el análisis: recortable, servicio del hogar,
  /// cargo financiero o seguro. Por el **nombre** de la categoría (la
  /// plantilla del hogar); sin acentos ni mayúsculas.
  Map<String, CategoriaFuga> categoriasParaFugas() {
    final arbol = _d.arbol;
    final salida = <String, CategoriaFuga>{};
    for (final c in _d.categorias) {
      final nombre = normalizarNombre(c.nombre);
      final padre = c.padreId == null ? null : arbol.porId(c.padreId!);
      final padreNombre = padre == null ? '' : normalizarNombre(padre.nombre);
      final servicio =
          c.nivel > 1 &&
          padreNombre.contains('vivienda') &&
          RegExp(r'\b(luz|agua|gas|electricidad)\b').hasMatch(nombre);
      final cargo =
          nombre.contains('comision') ||
          nombre.contains('intereses') ||
          nombre.contains('cargos financieros');
      final seguro = nombre.contains('seguro') && c.nivel > 1;
      salida[c.id] = CategoriaFuga.deCategoria(
        c,
        servicioHogar: servicio,
        cargoFinanciero: cargo,
        seguro: seguro,
      );
    }
    return salida;
  }

  int _ingresoSemanal(String libroId) {
    try {
      return armarPlanDelLibro(
        _d,
        libroId,
        Semana.de(hoy),
      ).plan.ingresoEquivalente.semanal;
    } on Object {
      return 0;
    }
  }

  EntradaFugas _entrada(String libroId, {bool conDecisiones = true}) {
    final registrados = _g.patrones.where((p) => p.libroId == libroId).toList();
    final clavePorId = {for (final p in registrados) p.id: p.clave};
    final delLibro = _idsDeGastosDelLibro(libroId);
    final gastos = [
      for (final g in gastosVigentesParaFugas(_d.movimientos))
        if (delLibro.contains(g.id)) g,
    ];
    return EntradaFugas(
      hoy: hoy,
      ingresoSemanalCentavos: _ingresoSemanal(libroId),
      gastos: gastos,
      categorias: categoriasParaFugas(),
      parametros: _g.parametrosDe(libroId),
      declarados: [
        for (final p in registrados)
          PatronDeclarado(
            p.clave,
            compromisoId: p.compromisoId,
            canceladoEn: p.canceladoEn,
            folio: p.folio,
          ),
      ],
      respuestas: [
        for (final r in _g.respuestas)
          if (r.libroId == libroId &&
              r.pregunta != PreguntaFuga.cancelado &&
              clavePorId[r.patronId] != null)
            RespuestaFuga(
              id: r.id,
              clave: clavePorId[r.patronId]!,
              pregunta: r.pregunta,
              respuesta: r.respuesta,
              periodoLunes: r.periodoLunes,
              registradoEn: r.registradoEn,
              reemplazaA: r.reemplazaA,
            ),
      ],
      decisiones: conDecisiones
          ? [
              for (final c in _g.clasificaciones)
                if (c.libroId == libroId &&
                    c.origen == OrigenFuga.persona &&
                    clavePorId[c.patronId] != null)
                  DecisionFuga(
                    id: c.id,
                    clave: clavePorId[c.patronId]!,
                    fuga: c.fuga,
                    vigilar: c.vigilar,
                    motivo: c.motivo,
                    decididaEn: c.decididaEn,
                    montoAlDecidir: c.montoAlDecidirCentavos,
                    reemplazaA: c.reemplazaA,
                  ),
            ]
          : const [],
      cortes: _cortes(libroId),
    );
  }

  List<CorteDeTarjeta> _cortes(String libroId) => [
    for (final e in _d.estadosDeCuenta)
      if (e.libroId == libroId)
        CorteDeTarjeta(estado: e, pagosAlCorteCentavos: _g.pagosAlCorte[e.id]),
  ];

  /// Las fugas del libro con lo cargado, lo respondido y las reglas locales.
  /// Si la persona no puede verlas, vacío. **No lanza.**
  AnalisisFugas analizar(String libroId) {
    if (!puedeVer(libroId)) return AnalisisFugas.vacio(libroId, hoy);
    try {
      final e = _entrada(libroId);
      final r = analizarFugas(e);
      return AnalisisFugas(
        libroId: libroId,
        hoy: hoy,
        resultado: r,
        preguntas: preguntasDeRevision(r, e),
        patronesDetectados: {
          for (final p in detectarPatrones(
            e.gastos,
            categorias: e.categorias,
            parametros: e.parametros,
          ))
            p.clave: p,
        },
        ingresoMensualCentavos: ingresoMensualDeReferencia(
          e.ingresoSemanalCentavos,
        ),
      );
    } on Object {
      return AnalisisFugas.vacio(libroId, hoy, fallo: true);
    }
  }

  /// Lo que dijo la regla de [clave], sin la decisión de la persona (para
  /// saber si la decisión la contradice).
  TipoFuga _fugaDeLaRegla(String libroId, String clave) {
    try {
      return analizarFugas(_entrada(libroId, conDecisiones: false))
              .de(clave)
              ?.fuga ??
          TipoFuga.ninguna;
    } on Object {
      return TipoFuga.ninguna;
    }
  }

  /// Id estable del patrón [clave] del libro: repetir (o dos dispositivos)
  /// no duplica.
  static String idPatron(String libroId, String clave) =>
      idEstable('fuga-patron:$libroId:$clave');

  /// Asegura que el patrón exista en el servidor (lo detecta la app; solo
  /// entonces hay a qué colgarle una respuesta). Devuelve su id.
  Future<String> _asegurarPatron(String libroId, String clave) async {
    final existente = _g.patronDeClave(libroId, clave);
    if (existente != null) return existente.id;
    final a = analizar(libroId);
    final f = a.resultado.de(clave);
    final p = a.patronesDetectados[clave];
    if (f == null && p == null) {
      throw const ErrorFinanzas('Ese cobro ya no aparece en tu libro.');
    }
    return repositorio.crearPatron(
      id: idPatron(libroId, clave),
      libroId: libroId,
      clave: clave,
      comercioNorm: f?.comercioNorm ?? p?.comercioNorm,
      categoriaId: f?.categoriaId ?? p?.categoriaId,
      cadencia: f?.cadencia ?? p?.cadencia ?? CadenciaCobro.irregular,
      automatico: p?.automatico ?? (f?.fuga == TipoFuga.fantasma),
    );
  }

  /// «Sí, lo conozco» / «No lo conocía» / «Después», «Lo usé» / «No lo usé»,
  /// «Ya no me sirve»… Una pregunta por patrón y periodo; la última vale.
  Future<void> responder({
    required String libroId,
    required String clave,
    required PreguntaFuga pregunta,
    required RespuestaPersona respuesta,
    String? motivo,
  }) async {
    _exigirResponder(libroId);
    final exige =
        pregunta != PreguntaFuga.reconoce &&
        pregunta != PreguntaFuga.uso &&
        pregunta != PreguntaFuga.temporada;
    final m = exige ? _motivoParaDecision(libroId, motivo) : null;
    final patronId = await _asegurarPatron(libroId, clave);
    await repositorio.responder(
      id: finanzas.nuevoId(),
      patronId: patronId,
      pregunta: pregunta,
      respuesta: respuesta,
      periodoLunes: Semana.de(hoy).inicio,
      motivo: m,
    );
  }

  /// «No es así»: la persona gana a la regla. [fuga] `ninguna` = «No es una
  /// fuga» (el patrón queda protegido); otro tipo = «Es de otro tipo»;
  /// [vigilar] = «Lo necesito pero lo quiero revisar». Si contradice a la
  /// regla, el [motivo] es obligatorio (3 a 200 caracteres).
  Future<void> clasificar({
    required String libroId,
    required String clave,
    required TipoFuga fuga,
    String? motivo,
    bool vigilar = false,
  }) async {
    _exigirResponder(libroId);
    final deLaRegla = _fugaDeLaRegla(libroId, clave);
    final contradice = !vigilar && fuga != deLaRegla;
    try {
      validarMotivoDecision(motivo, contradiceLaRegla: contradice);
    } on ArgumentError catch (e) {
      throw ErrorFinanzas('${e.message}');
    }
    final m = _motivoParaDecision(libroId, motivo);
    final patronId = await _asegurarPatron(libroId, clave);
    final detectada = analizar(libroId).resultado.de(clave);
    await repositorio.clasificar(
      id: finanzas.nuevoId(),
      patronId: patronId,
      fuga: vigilar ? TipoFuga.ninguna : fuga,
      fugaRegla: deLaRegla,
      motivo: m,
      regla: detectada?.regla,
      vigilar: vigilar,
      montoCentavos: detectada?.ultimoMontoCentavos,
    );
  }

  /// «Ya lo cancelé»: fecha y folio de cancelación (hasta 40 caracteres:
  /// letras, números y guiones). Sin folio se guarda como «cancelado sin
  /// folio» (pendiente de completar).
  Future<void> cancelar({
    required String libroId,
    required String clave,
    required Fecha fecha,
    String? folio,
    String? motivo,
  }) async {
    _exigirResponder(libroId);
    final f = folio?.trim();
    if (f != null && f.isNotEmpty) {
      try {
        validarFolio(f);
      } on ArgumentError catch (e) {
        throw ErrorFinanzas('${e.message}');
      }
    }
    if (fecha.despuesDe(hoy)) {
      throw const ErrorFinanzas(
        'La fecha de cancelación es de hoy o anterior.',
      );
    }
    final m = _motivoParaDecision(libroId, motivo);
    final patronId = await _asegurarPatron(libroId, clave);
    await repositorio.cancelar(
      id: finanzas.nuevoId(),
      patronId: patronId,
      fecha: fecha,
      folio: f == null || f.isEmpty ? null : f,
      motivo: m,
    );
  }

  /// El estado de cancelación de [clave] (nada si el patrón no existe aún).
  EstadoCancelacion estadoDeCancelacion(String libroId, String clave) {
    final p = _g.patronDeClave(libroId, clave);
    if (p == null) return EstadoCancelacion.noCancelado;
    return estadoCancelacion(canceladoEn: p.canceladoEn, folio: p.folio);
  }

  // ----------------------------------------------------------------- deudas

  ClaseDeuda _claseDe(Deuda d) =>
      d.clase ??
      switch (d.tipo) {
        TipoDeuda.msi => ClaseDeuda.msi,
        TipoDeuda.familiar => ClaseDeuda.familiar,
        _ => ClaseDeuda.prestamo,
      };

  /// Cuántas mensualidades de [msi] están pagadas: las que cubre lo que ya se
  /// pagó (total menos lo pendiente en su cuenta).
  int _pagadas(Msi msi) {
    final saldo = _d.vista(msi.libroId).saldo(msi.cuentaPasivoId);
    final pagado = (msi.montoTotal - saldo).clamp(0, msi.montoTotal);
    var acumulado = 0;
    var n = 0;
    for (final c in mensualidadesMsi(msi.montoTotal, msi.mensualidades)) {
      if (acumulado + c > pagado) break;
      acumulado += c;
      n++;
    }
    return n;
  }

  EntradaCalidadDeuda _entradaCalidad(String libroId) {
    final p = _g.parametrosDe(libroId);
    final ingresoMensual = ingresoMensualDeReferencia(_ingresoSemanal(libroId));
    final msis = {for (final m in _d.msiDe(libroId)) m.deudaId: m};
    final deudas = <DeudaParaCalidad>[];
    final tarjetas = <TarjetaParaCalidad>[];
    for (final d in _d.deudasDe(libroId)) {
      if (!d.activa) continue;
      final clase = _claseDe(d);
      final decl = _g.propositoDe(d.id);
      final saldo = saldoDeDeuda(_d, d);
      MsiParaCalidad? msi;
      final m = msis[d.id];
      if (clase == ClaseDeuda.msi && m != null) {
        msi = MsiParaCalidad.deMsi(
          m,
          tarjetaId: m.tarjetaDeudaId ?? '',
          pagadas: _pagadas(m),
          precioContadoCentavos: decl?.precioContadoCentavos,
        );
      }
      final mensual = d.abono <= 0
          ? 0
          : Equivalente.de(d.abono, d.frecuencia).enPeriodo(TipoPeriodo.mes);
      deudas.add(
        DeudaParaCalidad(
          id: d.id,
          nombre: d.titulo,
          clase: clase,
          msi: msi,
          mensualidadesPendientes: (saldo ?? 1) > 0 ? 1 : 0,
          pagoMensualCentavos: mensual,
          declaracion: decl?.declaracion,
          estadosDePagos: estadosDePagos(
            _d.ocurrencias,
            deudaId: d.id,
            hoy: hoy,
          ),
        ),
      );
      if (clase == ClaseDeuda.tarjeta) {
        final cuenta = d.cuentaPasivoId == null
            ? null
            : _d.cuenta(d.cuentaPasivoId!);
        tarjetas.add(
          TarjetaParaCalidad(
            deudaId: d.id,
            saldoCentavos: saldo ?? 0,
            limiteCentavos: cuenta?.limiteCentavos,
          ),
        );
      }
    }
    return EntradaCalidadDeuda(
      hoy: hoy,
      ingresoMensualCentavos: ingresoMensual,
      deudas: deudas,
      tarjetas: tarjetas,
      cortes: _cortes(libroId),
      parametros: p,
    );
  }

  /// Aplica la histéresis (5.5): subir de nivel es inmediato; bajar exige
  /// [ParametrosFugas.bajaNivelEvaluaciones] evaluaciones semanales seguidas.
  /// [SemaforoRegistrado.bajasSeguidas] cuenta **una por semana**: si esta
  /// semana ya se contó, no se vuelve a contar.
  HistorialNivel resolverNivel(
    SemaforoRegistrado? ultimo,
    EstadoCalidad calculado,
    Fecha lunesActual,
    ParametrosFugas p,
  ) {
    final previoEstado = ultimo == null ? null : estadoDeNivel(ultimo.nivel);
    if (ultimo == null || previoEstado == null) {
      return HistorialNivel(calculado);
    }
    // «Por declarar» no es un nivel juzgado: al declarar el propósito se ve el
    // resultado enseguida (la histéresis evita el vaivén entre niveles ya
    // juzgados, no la primera vez).
    if (previoEstado == EstadoCalidad.porDeclarar) {
      return HistorialNivel(calculado);
    }
    final previo = HistorialNivel(previoEstado, ultimo.bajasSeguidas);
    if (ultimo.lunes == lunesActual) {
      // Esta semana ya se evaluó: solo sube (o se queda igual); una mejora
      // espera a la semana siguiente.
      return _rango(calculado) >= _rango(previoEstado)
          ? HistorialNivel(calculado)
          : previo;
    }
    return aplicarHisteresis(
      previo: previo,
      calculado: calculado,
      parametros: p,
    );
  }

  static int _rango(EstadoCalidad e) => switch (e) {
    EstadoCalidad.seVolvioMala => 2,
    EstadoCalidad.enVigilancia || EstadoCalidad.porDeclarar => 1,
    _ => 0,
  };

  /// Las deudas activas del libro con su calidad. Vacío si no puede verlas.
  /// **No lanza.**
  List<DeudaConCalidad> calidadDeDeudas(String libroId) {
    if (!puedeVer(libroId)) return const [];
    try {
      final e = _entradaCalidad(libroId);
      final lunes = Semana.de(hoy).inicio;
      final lista = <DeudaConCalidad>[];
      for (final d in _d.deudasDe(libroId)) {
        if (!d.activa) continue;
        final dp = e.deudas.where((x) => x.id == d.id).firstOrNull;
        if (dp == null) continue;
        final c = evaluarDeuda(e, dp);
        var mostrado = c.estado;
        if (nivelDeEstado(c.estado) != null) {
          mostrado = resolverNivel(
            _g.semaforoDe(d.id),
            c.estado,
            lunes,
            e.parametros,
          ).nivel;
        }
        final decl = _g.propositoDe(d.id);
        lista.add(
          DeudaConCalidad(
            deuda: d,
            calidad: c,
            mostrado: mostrado,
            declaracion: decl?.declaracion,
            precioContadoCentavos: decl?.precioContadoCentavos,
            esMsi: dp.clase == ClaseDeuda.msi,
          ),
        );
      }
      return lista;
    } on Object {
      return const [];
    }
  }

  /// «Tus MSI y tu ingreso»: lo que suman las mensualidades de los MSI activos
  /// frente al ingreso mensual de referencia.
  ResumenMsi resumenMsi(String libroId) {
    final e = _entradaCalidad(libroId);
    final activos = e.msisActivos;
    final suma = activos.fold<int>(0, (a, m) => a + m.mensualidad);
    return ResumenMsi(
      activos: activos.length,
      mensualidadesCentavos: suma,
      puntosBase: proporcionEnPuntosBase(suma, e.ingresoMensualCentavos),
      sobreIngreso: senalMsiSobreIngreso(
        suma,
        e.ingresoMensualCentavos,
        parametros: e.parametros,
      ),
      activosNivel: senalMsiActivos(activos.length, parametros: e.parametros),
    );
  }

  /// Vista previa de un MSI nuevo con mensualidad [mensualidadCentavos]: el
  /// efecto sobre el semáforo, **sin bloquear nada** (DD-19).
  VistaPreviaMsi vistaPreviaMsi(String libroId, int mensualidadCentavos) {
    final e = _entradaCalidad(libroId);
    return vistaPreviaMsiNuevo(
      activosActuales: e.msisActivos,
      mensualidadNuevaCentavos: mensualidadCentavos,
      ingresoMensualCentavos: e.ingresoMensualCentavos,
      parametros: e.parametros,
    );
  }

  /// Declara para qué fue una deuda (vale la más reciente). Solo quien
  /// administra el libro.
  Future<void> declararProposito({
    required String libroId,
    required String deudaId,
    required DeclaracionDeuda declaracion,
    int? precioContadoCentavos,
    String? motivo,
  }) async {
    _exigirResponder(libroId);
    finanzas.exigirAdministrar(libroId);
    final d = _d.deudas.where((x) => x.id == deudaId).firstOrNull;
    if (d == null || d.libroId != libroId) {
      throw const ErrorFinanzas('Esa deuda no es de este libro.');
    }
    final texto = declaracion.objetivoTexto?.trim();
    if (texto != null && texto.isNotEmpty) {
      try {
        validarObjetivoTexto(texto);
      } on ArgumentError catch (e) {
        throw ErrorFinanzas('${e.message}');
      }
    }
    if (precioContadoCentavos != null && precioContadoCentavos <= 0) {
      throw const ErrorFinanzas(
        'El precio de contado debe ser mayor que cero.',
      );
    }
    final vida = declaracion.vidaUtilMeses;
    if (vida != null && (vida < 1 || vida > 600)) {
      throw const ErrorFinanzas('La vida útil va de 1 a 600 meses.');
    }
    final m = _motivoParaDecision(libroId, motivo);
    await repositorio.declararProposito(
      id: finanzas.nuevoId(),
      libroId: libroId,
      deudaId: deudaId,
      declaracion: DeclaracionDeuda(
        proposito: declaracion.proposito,
        objetivoTexto: texto == null || texto.isEmpty ? null : texto,
        bienId: declaracion.bienId,
        objetivoId: declaracion.objetivoId,
        vidaUtilMeses: vida,
        estado: declaracion.estado,
        usoPoco: declaracion.usoPoco,
      ),
      precioContadoCentavos: precioContadoCentavos,
      motivo: m,
    );
  }

  // ------------------------------------------------------------------ avisos

  /// Registra el semáforo de cada deuda cuando cambia su nivel y devuelve los
  /// cambios que **empeoraron** (a «en vigilancia» o «se volvió mala»). Sin
  /// señal no hace nada. **No lanza.**
  Future<List<({Deuda deuda, EstadoCalidad nivel, Fecha lunes})>>
  sincronizarSemaforos(String libroId) async {
    final empeoraron = <({Deuda deuda, EstadoCalidad nivel, Fecha lunes})>[];
    if (!puedeResponder(libroId)) return empeoraron;
    try {
      final e = _entradaCalidad(libroId);
      final lunes = Semana.de(hoy).inicio;
      for (final d in _d.deudasDe(libroId)) {
        if (!d.activa) continue;
        final dp = e.deudas.where((x) => x.id == d.id).firstOrNull;
        if (dp == null) continue;
        final c = evaluarDeuda(e, dp);
        final nivelCalculado = nivelDeEstado(c.estado);
        if (nivelCalculado == null) continue;
        final ultimo = _g.semaforoDe(d.id);
        final r = resolverNivel(ultimo, c.estado, lunes, e.parametros);
        final nivel = nivelDeEstado(r.nivel)!;
        final senales = [
          for (final s in c.senales)
            if ((s.nivel == NivelSenal.ambar ||
                    s.nivel == NivelSenal.rojo ||
                    s.nivel == NivelSenal.porDeclarar) &&
                RegExp(r'^[A-Z][0-9][a-z]?$').hasMatch(s.codigo))
              s.codigo,
        ];
        final agrego = await repositorio.registrarSemaforo(
          id: finanzas.nuevoId(),
          libroId: libroId,
          deudaId: d.id,
          lunes: lunes,
          nivel: nivel,
          senales: senales,
          bajasSeguidas: r.bajasSeguidas,
          calculadoEn: _reloj(),
        );
        final antes = ultimo == null ? 0 : _nivelRango(ultimo.nivel);
        if (agrego && _nivelRango(nivel) > antes && _nivelRango(nivel) > 0) {
          empeoraron.add((deuda: d, nivel: r.nivel, lunes: lunes));
        }
      }
    } on Object {
      // Sin señal o con el servidor caído: se vuelve a intentar al reabrir.
    }
    return empeoraron;
  }

  static int _nivelRango(String nivel) => switch (nivel) {
    'rojo' => 2,
    'ambar' => 1,
    _ => 0,
  };

  Future<bool> _emitir({
    required String libroId,
    required String tipo,
    required String objetoTipo,
    required String objetoId,
    required String clave,
  }) async {
    if (_avisadas.contains(clave)) return false;
    final pausa = _topeHasta;
    if (pausa != null) {
      if (_reloj().isBefore(pausa)) return false;
      _topeHasta = null;
    }
    try {
      await finanzas.repositorio.emitirAviso(
        libroId: libroId,
        tipo: tipo,
        objetoTipo: objetoTipo,
        objetoId: objetoId,
        clave: clave,
      );
      _avisadas.add(clave);
      return true;
    } on ErrorFinanzas catch (e) {
      if (e.topeAlcanzado) {
        _topeHasta = _reloj().add(const Duration(hours: 24));
      }
      // Sin señal: no se encola; se vuelve a intentar al reabrir.
      return false;
    }
  }

  /// Emite los avisos del bloque para [libroId] (al abrir el libro y con el
  /// cierre semanal), **sin cifras ni comercios** (D20) y con claves estables
  /// para avisar una sola vez:
  /// - `fuga_por_reconocer`: un cobro que se repite y la persona no ha
  ///   reconocido (uno por patrón);
  /// - `fuga_revision_mensual`: hay preguntas de la revisión (una por mes);
  /// - `deuda_en_vigilancia` y `deuda_se_volvio_mala`: una deuda empeoró.
  ///
  /// Solo si la persona puede escribir en el libro; nunca lanza. Devuelve
  /// cuántos avisos nuevos salieron.
  Future<int> emitirAvisos(String libroId) async {
    try {
      if (!puedeResponder(libroId)) return 0;
      var n = 0;
      final a = analizar(libroId);
      for (final f in a.porReconocer) {
        final String patronId;
        try {
          patronId = await _asegurarPatron(libroId, f.clave);
        } on ErrorFinanzas {
          continue;
        }
        if (await _emitir(
          libroId: libroId,
          tipo: TiposAvisoFugas.fugaPorReconocer,
          objetoTipo: 'patron',
          objetoId: patronId,
          clave: ClavesAvisoFugas.porReconocer(patronId),
        )) {
          n++;
        }
      }
      if (a.preguntas.isNotEmpty &&
          await _emitir(
            libroId: libroId,
            tipo: TiposAvisoFugas.fugaRevisionMensual,
            objetoTipo: 'libro',
            objetoId: libroId,
            clave: ClavesAvisoFugas.revisionMensual(libroId, hoy),
          )) {
        n++;
      }
      for (final c in await sincronizarSemaforos(libroId)) {
        final malo = c.nivel == EstadoCalidad.seVolvioMala;
        if (await _emitir(
          libroId: libroId,
          tipo: malo
              ? TiposAvisoFugas.deudaSeVolvioMala
              : TiposAvisoFugas.deudaEnVigilancia,
          objetoTipo: 'deuda',
          objetoId: c.deuda.id,
          clave: ClavesAvisoFugas.deuda(
            c.deuda.id,
            malo ? 'rojo' : 'ambar',
            c.lunes,
          ),
        )) {
          n++;
        }
      }
      return n;
    } on Object {
      return 0;
    }
  }
}

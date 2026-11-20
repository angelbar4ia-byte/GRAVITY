/// Repositorio de las fugas silenciosas y de la deuda buena o mala con Supabase
/// (Fase 8, bloque 6; migración `20261146000000_finanzas_fugas_deudas.sql`).
///
/// - **Leer:** las vistas `fin_v_*` de lo vigente (`fin_patrones_cobro` con su
///   estado derivado, clasificaciones, respuestas, propósitos de deuda,
///   semáforo actual y umbrales) y los pagos al corte de
///   `fin_v_estados_cuenta_vigentes`. La RLS deja leer solo a quien puede ver
///   las deudas del libro y es dueño o coadministrador (`fin_fugas_puede_ver`):
///   para el familiar, el cuidador, Casa, la tablet pública y la vista
///   temporal de Papá las lecturas vienen vacías.
/// - **Escribir:** solo por las RPC del servidor, **idempotentes por id**.
///   Ninguna tabla admite `insert` directo, así que nada pasa por la cola sin
///   conexión: sin señal las escrituras lanzan `ErrorFinanzas` con
///   `sinConexion` (igual que la dispersión) y la pantalla lo dice.
/// - Nada de esto sale a IA, bocinas ni tablet pública (D3, D6).
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';

import 'filas.dart';
import 'fuente_tablas.dart';
import 'repositorio.dart' show ErrorFinanzas;
import 'repositorio_fugas.dart';

/// Tablas, vistas y funciones de las fugas y la calidad de la deuda.
abstract final class TablasFugas {
  static const patrones = 'fin_patrones_cobro';
  static const patronesEstado = 'fin_v_patrones_estado';
  static const clasificaciones = 'fin_v_fuga_clasificaciones_vigentes';
  static const respuestas = 'fin_v_fuga_respuestas_vigentes';
  static const propositos = 'fin_v_deuda_propositos_vigentes';
  static const semaforo = 'fin_v_deuda_semaforo_actual';
  static const parametros = 'fin_v_fuga_parametros_vigentes';
  static const estadosCuenta = 'fin_v_estados_cuenta_vigentes';

  static const crearPatron = 'fin_patron_crear';
  static const responder = 'fin_fuga_responder';
  static const clasificar = 'fin_fuga_clasificar';
  static const cancelar = 'fin_patron_cancelar';
  static const declarar = 'fin_deuda_declarar';
  static const cambiarParametros = 'fin_fuga_parametros_cambiar';
  static const registrarSemaforo = 'fin_deuda_semaforo_registrar';
}

class RepositorioFugasSupabase implements RepositorioFugas {
  RepositorioFugasSupabase({required this.fuente});

  final FuenteTablas fuente;

  DatosFugas _datos = DatosFugas.vacio;
  final _cambios = StreamController<DatosFugas>.broadcast();

  @override
  DatosFugas get actuales => _datos;

  @override
  Stream<DatosFugas> get cambios => _cambios.stream;

  void _publicar(DatosFugas d) {
    _datos = d;
    if (!_cambios.isClosed) _cambios.add(d);
  }

  // ----------------------------------------------------------------- leer

  @override
  Future<void> cargar() async {
    final patrones = await fuente.leer(TablasFugas.patrones);
    final estados = await fuente.leer(TablasFugas.patronesEstado);
    final clasificaciones = await fuente.leer(TablasFugas.clasificaciones);
    final respuestas = await fuente.leer(TablasFugas.respuestas);
    final propositos = await fuente.leer(TablasFugas.propositos);
    final semaforos = await fuente.leer(TablasFugas.semaforo);
    final parametros = await fuente.leer(TablasFugas.parametros);
    final pagos = await _leerPagosAlCorte();

    final estadoPorPatron = {for (final e in estados) '${e['patron_id']}': e};
    _publicar(
      DatosFugas(
        patrones: [
          for (final f in patrones)
            patronDeFila(f, estadoPorPatron['${f['id']}']),
        ],
        clasificaciones: [
          for (final f in clasificaciones) ?clasificacionDeFila(f),
        ],
        respuestas: [for (final f in respuestas) ?respuestaDeFila(f)],
        propositos: [for (final f in propositos) ?propositoDeFila(f)],
        semaforos: [for (final f in semaforos) semaforoDeFila(f)],
        parametros: {
          for (final f in parametros) '${f['libro_id']}': parametrosDeFila(f),
        },
        pagosAlCorte: pagos,
      ),
    );
  }

  /// Los pagos al corte por estado de cuenta; si la vista aún no los tiene,
  /// todo queda «sin dato» (nunca «pagó cero»).
  Future<Map<String, int?>> _leerPagosAlCorte() async {
    try {
      final filas = await fuente.leer(
        TablasFugas.estadosCuenta,
        columnas: 'id,pagos_al_corte_centavos',
      );
      return {
        for (final f in filas)
          '${f['id']}': enteroONulo(f['pagos_al_corte_centavos']),
      };
    } on ErrorFinanzas catch (e) {
      if (e.sinConexion) rethrow;
      return const {};
    }
  }

  // -------------------------------------------------------------- escribir

  @override
  Future<String> crearPatron({
    required String id,
    required String libroId,
    required String clave,
    required CadenciaCobro cadencia,
    required bool automatico,
    String? comercioNorm,
    String? categoriaId,
    String? compromisoId,
    String origen = 'detectado',
  }) async {
    final r = await fuente.rpc(TablasFugas.crearPatron, {
      'p_id': id,
      'p_libro': libroId,
      'p_comercio_norm': comercioNorm,
      'p_categoria': categoriaId,
      'p_cadencia': nombreEnum(cadencia),
      'p_automatico': automatico,
      'p_clave': clave,
      'p_origen': origen,
      'p_compromiso': compromisoId,
    });
    final idFinal = r is String && r.isNotEmpty ? r : id;
    final previo = _datos.patron(idFinal);
    if (previo == null) {
      _publicar(
        _datos.copiar(
          patrones: [
            ..._datos.patrones,
            PatronRegistrado(
              id: idFinal,
              libroId: libroId,
              clave: clave,
              cadencia: cadencia,
              automatico: automatico,
              comercioNorm: comercioNorm,
              categoriaId: categoriaId,
              compromisoId: compromisoId,
              origen: origen,
            ),
          ],
        ),
      );
    }
    return idFinal;
  }

  /// Después de escribir se vuelve a pedir lo vigente (una sola fuente de
  /// verdad: el servidor). Si no hay señal justo después, se queda lo que
  /// había y la próxima carga lo trae.
  Future<void> _recargarTrasEscribir() async {
    try {
      await cargar();
    } on Object {
      // La escritura ya quedó en el servidor.
    }
  }

  @override
  Future<void> responder({
    required String id,
    required String patronId,
    required PreguntaFuga pregunta,
    required RespuestaPersona respuesta,
    required Fecha periodoLunes,
    String? motivo,
  }) async {
    await fuente.rpc(TablasFugas.responder, {
      'p_id': id,
      'p_patron': patronId,
      'p_pregunta': preguntaFugaClave(pregunta),
      'p_respuesta': nombreEnum(respuesta),
      'p_periodo_lunes': fechaIso(periodoLunes),
      'p_motivo': motivo,
    });
    await _recargarTrasEscribir();
  }

  @override
  Future<void> clasificar({
    required String id,
    required String patronId,
    required TipoFuga fuga,
    required TipoFuga fugaRegla,
    String? motivo,
    String? regla,
    bool vigilar = false,
    int? montoCentavos,
  }) async {
    await fuente.rpc(TablasFugas.clasificar, {
      'p_id': id,
      'p_patron': patronId,
      'p_fuga': nombreEnum(fuga),
      'p_fuga_regla': nombreEnum(fugaRegla),
      'p_motivo': motivo,
      // El servidor acepta códigos de 1 a 3 letras o dígitos (H, F3, VC...).
      'p_regla':
          regla != null && RegExp(r'^[A-Z][A-Z0-9]{0,2}$').hasMatch(regla)
          ? regla
          : null,
      'p_vigilar': vigilar,
      'p_monto_centavos': montoCentavos,
    });
    await _recargarTrasEscribir();
  }

  @override
  Future<void> cancelar({
    required String id,
    required String patronId,
    required Fecha fecha,
    String? folio,
    String? motivo,
  }) async {
    await fuente.rpc(TablasFugas.cancelar, {
      'p_id': id,
      'p_patron': patronId,
      'p_fecha': fechaIso(fecha),
      'p_folio': folio,
      'p_motivo': motivo,
    });
    await _recargarTrasEscribir();
  }

  @override
  Future<void> declararProposito({
    required String id,
    required String libroId,
    required String deudaId,
    required DeclaracionDeuda declaracion,
    int? precioContadoCentavos,
    String? motivo,
  }) async {
    await fuente.rpc(TablasFugas.declarar, {
      'p_id': id,
      'p_deuda': deudaId,
      'p_proposito': propositoClave(declaracion.proposito),
      'p_objetivo_texto': declaracion.objetivoTexto,
      'p_bien': declaracion.bienId,
      'p_objetivo': declaracion.objetivoId,
      'p_vida_util': declaracion.vidaUtilMeses,
      'p_estado': estadoObjetivoClave(declaracion.estado),
      'p_uso_poco': declaracion.usoPoco,
      'p_precio_contado_centavos': precioContadoCentavos,
      'p_motivo': motivo,
    });
    await _recargarTrasEscribir();
  }

  @override
  Future<bool> registrarSemaforo({
    required String id,
    required String libroId,
    required String deudaId,
    required Fecha lunes,
    required String nivel,
    List<String> senales = const [],
    int bajasSeguidas = 0,
    DateTime? calculadoEn,
  }) async {
    final r = await fuente.rpc(TablasFugas.registrarSemaforo, {
      'p_id': id,
      'p_deuda': deudaId,
      'p_lunes': fechaIso(lunes),
      'p_nivel': nivel,
      'p_senales': senales,
      'p_bajas_seguidas': bajasSeguidas,
      'p_calculado_en': calculadoEn == null ? null : horaIso(calculadoEn),
    });
    final agrego = r == true;
    if (agrego) {
      _publicar(
        _datos.copiar(
          semaforos: [
            for (final s in _datos.semaforos)
              if (s.deudaId != deudaId) s,
            SemaforoRegistrado(
              libroId: libroId,
              deudaId: deudaId,
              lunes: lunes,
              nivel: nivel,
              senales: senales,
              bajasSeguidas: bajasSeguidas,
              calculadoEn: calculadoEn ?? DateTime.now(),
            ),
          ],
        ),
      );
    }
    return agrego;
  }

  @override
  Future<void> cambiarParametros(
    String libroId,
    ParametrosFugas p, {
    String? motivo,
  }) async {
    await fuente.rpc(TablasFugas.cambiarParametros, {
      'p_libro': libroId,
      'p_tope_hormiga_centavos': p.topeHormigaCentavos,
      'p_hormiga_min_gastos': p.hormigaMinGastos,
      'p_hormiga_min_semanas': p.hormigaMinSemanas,
      'p_hormiga_min_ingreso_pb': p.hormigaMinIngresoPb,
      'p_hormiga_conjunto_pb': p.hormigaConjuntoPb,
      'p_recurrente_tolerancia_pb': p.recurrenteTolerancia,
      'p_vampiro_crecimiento_pb': p.vampiroCrecimientoPb,
      'p_zombie_respuestas': p.zombieRespuestas,
      'p_servicio_periodos_min': p.servicioPeriodosMin,
      'p_servicio_periodos_mediana': p.servicioPeriodosMediana,
      'p_servicio_mediana_pb': p.servicioMedianaPb,
      'p_msi_ambar_pb': p.msiAmbarPb,
      'p_msi_rojo_pb': p.msiRojoPb,
      'p_msi_activos_ambar': p.msiActivosAmbar,
      'p_msi_activos_rojo': p.msiActivosRojo,
      'p_plazo_ambar_meses': p.plazoAmbarMeses,
      'p_baja_nivel_evaluaciones': p.bajaNivelEvaluaciones,
      'p_motivo': motivo,
    });
    await _recargarTrasEscribir();
  }

  Future<void> cerrar() => _cambios.close();
}

// ============================================================== filas

CadenciaCobro _cadencia(Object? v) =>
    enumONulo(CadenciaCobro.values, v) ?? CadenciaCobro.irregular;

PatronRegistrado patronDeFila(
  Map<String, dynamic> f,
  Map<String, dynamic>? estado,
) {
  final cancelado = estado?['cancelado_en'];
  return PatronRegistrado(
    id: '${f['id']}',
    libroId: '${f['libro_id']}',
    clave: '${f['clave']}',
    comercioNorm: texto(f['comercio_norm']),
    categoriaId: texto(f['categoria_id']),
    compromisoId: texto(f['compromiso_id']),
    cadencia: _cadencia(f['cadencia']),
    automatico: booleano(f['automatico']),
    origen: texto(f['origen']) ?? 'detectado',
    protegido: booleano(estado?['protegido']),
    vigilar: booleano(estado?['vigilar']),
    canceladoEn: cancelado == null ? null : fechaReq(cancelado),
    folio: texto(estado?['folio_cancelacion']),
    canceladoSinFolio: booleano(estado?['cancelado_sin_folio']),
  );
}

TipoFuga? _tipoFuga(Object? v) => enumONulo(TipoFuga.values, v);

ClasificacionRegistrada? clasificacionDeFila(Map<String, dynamic> f) {
  final fuga = _tipoFuga(f['fuga']);
  if (fuga == null) return null;
  return ClasificacionRegistrada(
    id: '${f['id']}',
    libroId: '${f['libro_id']}',
    patronId: '${f['patron_id']}',
    fuga: fuga,
    origen: f['origen'] == 'persona' ? OrigenFuga.persona : OrigenFuga.regla,
    regla: texto(f['regla']),
    fugaRegla: _tipoFuga(f['fuga_regla']),
    vigilar: booleano(f['vigilar']),
    montoAlDecidirCentavos: enteroONulo(f['monto_al_decidir_centavos']),
    reemplazaA: texto(f['reemplaza_a']),
    motivo: texto(f['motivo']),
    decididaEn:
        horaDe(f['decidido_en']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

RespuestaRegistrada? respuestaDeFila(Map<String, dynamic> f) {
  final pregunta = preguntaFugaDeClave(f['pregunta']);
  final respuesta = enumONulo(RespuestaPersona.values, f['respuesta']);
  if (pregunta == null || respuesta == null) return null;
  final cancelacion = f['fecha_cancelacion'];
  return RespuestaRegistrada(
    id: '${f['id']}',
    libroId: '${f['libro_id']}',
    patronId: '${f['patron_id']}',
    pregunta: pregunta,
    respuesta: respuesta,
    fechaCancelacion: cancelacion == null ? null : fechaReq(cancelacion),
    folio: texto(f['folio']),
    periodoLunes: fechaReq(f['periodo_lunes']),
    reemplazaA: texto(f['reemplaza_a']),
    registradoEn:
        horaDe(f['registrado_en']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

PropositoRegistrado? propositoDeFila(Map<String, dynamic> f) {
  final proposito = propositoDeClave(f['proposito']);
  if (proposito == null) return null;
  return PropositoRegistrado(
    id: '${f['id']}',
    libroId: '${f['libro_id']}',
    deudaId: '${f['deuda_id']}',
    declaracion: DeclaracionDeuda(
      proposito: proposito,
      objetivoTexto: texto(f['objetivo_texto']),
      bienId: texto(f['bien_id']),
      objetivoId: texto(f['objetivo_id']),
      vidaUtilMeses: enteroONulo(f['vida_util_meses']),
      estado:
          estadoObjetivoDeClave(f['estado_objetivo']) ?? EstadoObjetivo.vigente,
      usoPoco: booleano(f['uso_poco']),
    ),
    precioContadoCentavos: enteroONulo(f['precio_contado_centavos']),
    declaradoEn:
        horaDe(f['declarado_en']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

SemaforoRegistrado semaforoDeFila(Map<String, dynamic> f) {
  final senales = f['senales'];
  return SemaforoRegistrado(
    libroId: '${f['libro_id']}',
    deudaId: '${f['deuda_id']}',
    lunes: fechaReq(f['lunes']),
    nivel: '${f['nivel']}',
    senales: senales is List ? [for (final s in senales) '$s'] : const [],
    bajasSeguidas: entero(f['bajas_seguidas']),
    calculadoEn:
        horaDe(f['calculado_en']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

ParametrosFugas parametrosDeFila(Map<String, dynamic> f) {
  const base = ParametrosFugas.porDefecto;
  int n(String k, int porOmision) => enteroONulo(f[k]) ?? porOmision;
  return ParametrosFugas(
    topeHormigaCentavos: n('tope_hormiga_centavos', base.topeHormigaCentavos),
    hormigaMinGastos: n('hormiga_min_gastos', base.hormigaMinGastos),
    hormigaMinSemanas: n('hormiga_min_semanas', base.hormigaMinSemanas),
    hormigaMinIngresoPb: n('hormiga_min_ingreso_pb', base.hormigaMinIngresoPb),
    hormigaConjuntoPb: n('hormiga_conjunto_pb', base.hormigaConjuntoPb),
    recurrenteTolerancia: n(
      'recurrente_tolerancia_pb',
      base.recurrenteTolerancia,
    ),
    vampiroCrecimientoPb: n(
      'vampiro_crecimiento_pb',
      base.vampiroCrecimientoPb,
    ),
    zombieRespuestas: n('zombie_respuestas', base.zombieRespuestas),
    servicioPeriodosMin: n('servicio_periodos_min', base.servicioPeriodosMin),
    servicioPeriodosMediana: n(
      'servicio_periodos_mediana',
      base.servicioPeriodosMediana,
    ),
    servicioMedianaPb: n('servicio_mediana_pb', base.servicioMedianaPb),
    msiAmbarPb: n('msi_ambar_pb', base.msiAmbarPb),
    msiRojoPb: n('msi_rojo_pb', base.msiRojoPb),
    msiActivosAmbar: n('msi_activos_ambar', base.msiActivosAmbar),
    msiActivosRojo: n('msi_activos_rojo', base.msiActivosRojo),
    plazoAmbarMeses: n('plazo_ambar_meses', base.plazoAmbarMeses),
    bajaNivelEvaluaciones: n(
      'baja_nivel_evaluaciones',
      base.bajaNivelEvaluaciones,
    ),
  );
}

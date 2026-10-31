/// Casos de uso de la Fase 2: deudas a detalle, ahorro y fondo de emergencia.
/// Los cálculos son de `finanzas_dominio`; aquí se validan permisos, se arman
/// los movimientos del libro (solo agregar) y se guardan las filas nuevas. La
/// app **nunca mueve dinero sola**: toda aportación es una propuesta que la
/// persona confirma.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../datos/repositorio.dart';
import '../importacion/lector_ficha.dart';
import 'servicio_finanzas.dart';

/// Se llama al registrar un pago de una ocurrencia: la plataforma retira el
/// aviso local de esa ocurrencia (regla 38).
typedef AlRegistrarPago = void Function(String objetoId, Fecha fecha);

/// Claves de los avisos de una ocurrencia de pago, para retirarlos al pagar
/// (regla 38): `tipo:objeto_id:fecha:n` con `n` de 1 a 3.
List<String> clavesDeAvisosDePago(String objetoId, Fecha fecha) => [
  for (final tipo in const ['pago_proximo', 'limite_tarjeta', 'pago_vencido'])
    for (var n = 1; n <= 3; n++) '$tipo:$objetoId:$fecha:$n',
];

/// Resumen de una deuda para las pantallas.
class ResumenDeuda {
  const ResumenDeuda({
    required this.deuda,
    required this.saldo,
    this.estado,
    this.uso,
  });

  final Deuda deuda;
  final int? saldo;
  final EstadoDeCuenta? estado;
  final UsoDelLimite? uso;
}

/// Una bolsa con su saldo y su avance.
class ResumenBolsa {
  const ResumenBolsa({
    required this.bolsa,
    required this.saldo,
    this.meta,
    this.pendiente = 0,
    this.semaforo,
  });

  final BolsaAhorro bolsa;
  final int saldo;
  final int? meta;
  final int pendiente;
  final Semaforo? semaforo;
}

/// El fondo de emergencia hoy.
class ResumenFondo {
  const ResumenFondo({
    required this.nivel,
    required this.meta,
    required this.saldo,
    required this.esencial,
    this.semanasDecimas,
    this.semaforo,
    required this.sugerido,
  });

  final NivelFondo nivel;
  final int? meta;
  final int saldo;
  final GastoEsencial esencial;

  /// Semanas cubiertas en décimas (30 = "3.0"); nulo sin gasto esencial.
  final int? semanasDecimas;
  final Semaforo? semaforo;
  final NivelFondo sugerido;
}

class ServicioDeudasAhorro {
  ServicioDeudasAhorro(this.base, {this.alRegistrarPago});

  final ServicioFinanzas base;
  final AlRegistrarPago? alRegistrarPago;

  DatosFinanzas get _d => base.datos;

  // ------------------------------------------------------------------ deudas

  /// Las deudas activas del libro con su saldo, último estado de cuenta y
  /// uso del límite (solo tarjetas con límite capturado).
  List<ResumenDeuda> deudas(String libroId) {
    final lista = <ResumenDeuda>[];
    for (final d in _d.deudasDe(libroId)) {
      if (!d.activa) continue;
      final saldo = saldoDeDeuda(_d, d);
      UsoDelLimite? uso;
      final cuenta = d.cuentaPasivoId == null ? null : _d.cuenta(d.cuentaPasivoId!);
      if (d.clase == ClaseDeuda.tarjeta && cuenta?.limiteCentavos != null) {
        var msiPendiente = 0;
        for (final m in _d.msiDe(libroId)) {
          if (m.tarjetaDeudaId != d.id) continue;
          final s = _d.cuenta(m.cuentaPasivoId);
          if (s != null) msiPendiente += _d.vista(libroId).saldo(s.id);
        }
        uso = usoDelLimite(
          saldo: saldo ?? 0,
          limite: cuenta!.limiteCentavos,
          msiPendiente: msiPendiente,
        );
      }
      lista.add(
        ResumenDeuda(
          deuda: d,
          saldo: saldo,
          estado: _d.ultimoEstadoDeCuenta(d.id),
          uso: uso,
        ),
      );
    }
    return lista;
  }

  List<DeudaPlan> _planes(String libroId) => [
    for (final d in _d.deudasDe(libroId))
      if (d.activa)
        if ((saldoDeDeuda(_d, d) ?? 1) > 0)
          d.plan(saldo: saldoDeDeuda(_d, d)),
  ];

  /// Orden de pago por costo, con el motivo de cada lugar (reglas 1 a 4).
  List<LugarDePago> ordenDePago(String libroId) {
    final planes = _planes(libroId);
    try {
      return ordenConMotivo(planes);
    } on ArgumentError {
      return const [];
    }
  }

  /// Costo de deber: interés semanal estimado de las deudas con costo.
  CostoDeDeber costoDeDeberDe(String libroId) {
    try {
      return costoDeDeber(_planes(libroId));
    } on ArgumentError {
      return const CostoDeDeber({}, 0, {});
    }
  }

  /// Captura la tasa de una deuda (la app no la inventa; regla 5).
  Future<void> capturarTasa(String deudaId, int puntosBase, {int? catPb}) async {
    final d = _deuda(deudaId);
    if (puntosBase < 0) throw const ErrorFinanzas('La tasa no puede ser negativa.');
    await base.guardarDeuda(
      d.copiar(tasaAnualPuntosBase: puntosBase, catPuntosBase: catPb),
    );
  }

  Deuda _deuda(String id) =>
      _d.deudas.where((d) => d.id == id).firstOrNull ??
      (throw const ErrorFinanzas('No existe esa deuda.'));

  /// Agrega el estado de cuenta de un corte (solo agregar; otro registro del
  /// mismo corte lo corrige).
  Future<EstadoDeCuenta> registrarEstadoDeCuenta({
    required String deudaId,
    required Fecha corte,
    required Fecha limitePago,
    required int saldoAlCorte,
    required int pagoMinimo,
    required int pagoSinIntereses,
    int intereses = 0,
    int cargos = 0,
    int? tasaDeclaradaPb,
    int? catPb,
  }) async {
    final d = _deuda(deudaId);
    base.exigirEscribir(d.libroId);
    if (limitePago.antesDe(corte)) {
      throw const ErrorFinanzas(
        'La fecha límite de pago no puede ser antes del corte.',
      );
    }
    if ([saldoAlCorte, pagoMinimo, pagoSinIntereses, intereses, cargos]
        .any((x) => x < 0)) {
      throw const ErrorFinanzas('Los montos no pueden ser negativos.');
    }
    final e = EstadoDeCuenta(
      id: base.nuevoId(),
      libroId: d.libroId,
      deudaId: deudaId,
      fechaCorte: corte,
      fechaLimitePago: limitePago,
      saldoAlCorte: saldoAlCorte,
      pagoMinimo: pagoMinimo,
      pagoSinIntereses: pagoSinIntereses,
      intereses: intereses,
      cargos: cargos,
      tasaDeclaradaPb: tasaDeclaradaPb,
      catPb: catPb,
      registradoEn: base.ahora,
    );
    await base.repositorio.agregarEstadoDeCuenta(e);
    return e;
  }

  /// Crea una compra a meses: su cuenta pasivo propia, su deuda de clase MSI
  /// (sin intereses, sin abono extra) y la ficha de la compra. [pagadas] son
  /// las mensualidades que ya pagaste.
  Future<Msi> crearMsi({
    required String libroId,
    required String comercio,
    String? descripcion,
    required int total,
    required int meses,
    required Fecha fechaCompra,
    required int diaPago,
    String? tarjetaDeudaId,
    int pagadas = 0,
    String? id,
  }) async {
    base.exigirAdministrar(libroId);
    if (comercio.trim().isEmpty) throw const ErrorFinanzas('Escribe el comercio.');
    if (total <= 0) throw const ErrorFinanzas('Escribe el total de la compra.');
    if (meses < 2 || meses > 48) {
      throw const ErrorFinanzas('Los meses van de 2 a 48.');
    }
    if (diaPago < 1 || diaPago > 31) {
      throw const ErrorFinanzas('El día de pago va de 1 a 31.');
    }
    final cuotas = mensualidadesMsi(total, meses);
    final pendiente = pendienteDeMsi(cuotas, pagadas);
    var nombreCuenta = 'MSI ${comercio.trim()}';
    for (var n = 2;
        _d.cuentasDe(libroId).any(
          (c) => normalizarNombre(c.nombre) == normalizarNombre(nombreCuenta),
        );
        n++) {
      nombreCuenta = 'MSI ${comercio.trim()} ($n)';
    }
    final pasivo = await base.crearCuenta(
      libroId: libroId,
      nombre: nombreCuenta,
      tipo: TipoCuenta.prestamo,
      saldoInicial: pendiente,
      fechaSaldo: fechaCompra.despuesDe(base.hoy) ? base.hoy : fechaCompra,
    );
    final deuda = Deuda(
      id: id == null ? base.nuevoId() : idEstable('$id:deuda'),
      libroId: libroId,
      nombre: 'MSI ${comercio.trim()}',
      tipo: TipoDeuda.msi,
      clase: ClaseDeuda.msi,
      acreedor: comercio.trim(),
      montoOriginal: total,
      cuentaPasivoId: pasivo.id,
      abono: cuotas.first,
      frecuencia: Frecuencia.mensual,
      calendario: CalendarioConfig.mensual(
        [diaPago],
        regla: ReglaDiaInhabil.sinCambio,
      ),
      permitePagoAnticipado: false,
    );
    await base.guardarDeuda(deuda);
    final msi = Msi(
      id: id ?? base.nuevoId(),
      libroId: libroId,
      deudaId: deuda.id,
      tarjetaDeudaId: tarjetaDeudaId,
      cuentaPasivoId: pasivo.id,
      comercio: comercio.trim(),
      descripcion: descripcion?.trim().isEmpty ?? true ? null : descripcion!.trim(),
      fechaCompra: fechaCompra,
      montoTotal: total,
      mensualidades: meses,
    );
    await base.repositorio.guardarMsi(msi);
    return msi;
  }

  /// Pago de una deuda desde una cuenta (la hoja corta del teléfono). Si viene
  /// de un vencimiento, la ocurrencia queda cumplida y se retiran sus avisos.
  Future<ResultadoRegistro> pagarDeuda({
    required String deudaId,
    required String cuentaOrigenId,
    required int monto,
    Fecha? fecha,
    Vencimiento? vencimiento,
    String? objetoAvisoId,
    String? motivo,
  }) async {
    final d = _deuda(deudaId);
    final pasivo = d.cuentaPasivoId;
    if (pasivo == null) {
      throw const ErrorFinanzas('Esta deuda no tiene cuenta para el pago.');
    }
    final r = await base.registrarMovimiento(
      tipo: TipoMovimiento.pagoDeuda,
      cuentaOrigenId: cuentaOrigenId,
      cuentaDestinoId: pasivo,
      monto: monto,
      fecha: fecha,
      motivo: motivo,
    );
    if (vencimiento != null) {
      await base.marcarIngreso(d.libroId, vencimiento, EstadoOcurrencia.cumplida);
      final objeto =
          objetoAvisoId ??
          idEstable(
            ClavesId.ocurrencia(
              d.libroId,
              OrigenOcurrencia.deuda.name,
              vencimiento.origenId,
              '${vencimiento.fecha.programada}',
            ),
          );
      alRegistrarPago?.call(objeto, vencimiento.fecha.ajustada);
    }
    return r;
  }

  // ------------------------------------------------------------------ ahorro

  int saldoDeBolsa(BolsaAhorro b) => _d.vista(b.libroId).saldo(b.cuentaId);

  /// Gasto esencial semanal: lo de las partidas protegidas del plan (el
  /// historial por cierre llega cuando el cierre guarde la marca de
  /// "esencial"; hasta entonces se rotula *"según tu plan"*, regla 18).
  GastoEsencial gastoEsencial(String libroId, Semana semana) {
    final plan = armarPlanDelLibro(_d, libroId, semana);
    var esencial = 0;
    for (final r in plan.plan.partidas) {
      if (r.origen.protegida) esencial += r.semanal;
    }
    final p = _d.parametrosDe(libroId);
    var minimos = 0;
    if (p.esencialesIncluyenMinimos) {
      for (final d in _d.deudasDe(libroId)) {
        if (d.activa && d.tipo != TipoDeuda.msi) minimos += d.minimo;
      }
    }
    return gastoEsencialSemanal(
      esencialesPorSemanaCerrada: const [],
      presupuestoEsencial: esencial > 0 ? esencial : null,
      minimosDeDeudaSemanales: minimos,
      incluirMinimos: p.esencialesIncluyenMinimos,
    );
  }

  /// El fondo de emergencia del libro (nulo si aún no se crea).
  ResumenFondo? fondo(String libroId, Semana semana) {
    final b = _d.bolsasDe(libroId)
        .where((x) => x.tipo == TipoBolsaAhorro.fondoEmergencia)
        .firstOrNull;
    if (b == null) return null;
    final saldo = saldoDeBolsa(b);
    final esencial = gastoEsencial(libroId, semana);
    final nivel = NivelFondo.values.firstWhere(
      (n) => n.numero == (b.nivelMeta ?? NivelFondo.porDefecto.numero),
    );
    final sem = esencial.semanal;
    final meta = sem == null ? null : metaDelFondo(nivel, sem);
    return ResumenFondo(
      nivel: nivel,
      meta: meta,
      saldo: saldo,
      esencial: esencial,
      semanasDecimas: sem == null ? null : semanasCubiertasDecimas(saldo, sem),
      semaforo: meta == null ? null : semaforoDelFondo(saldo, meta),
      sugerido: nivelSugeridoDelFondo(
        ingresosActivos: _d.ingresosDe(libroId).length,
        soloIngresosInseguros: false,
        dependientesCuidados: _d.parametrosDe(libroId).dependientesCuidados,
      ),
    );
  }

  /// Las bolsas con su avance.
  List<ResumenBolsa> bolsas(String libroId, Semana semana) {
    final f = fondo(libroId, semana);
    return [
      for (final b in _d.bolsasDe(libroId))
        () {
          final saldo = saldoDeBolsa(b);
          final meta = b.tipo == TipoBolsaAhorro.fondoEmergencia
              ? f?.meta
              : b.meta;
          return ResumenBolsa(
            bolsa: b,
            saldo: saldo,
            meta: meta,
            semaforo: b.tipo == TipoBolsaAhorro.fondoEmergencia
                ? f?.semaforo
                : null,
            pendiente: _d.aportaciones
                .where((a) => a.bolsaId == b.id)
                .fold(0, (t, a) => t + a.pendiente),
          );
        }(),
    ];
  }

  /// Crea una bolsa: su cuenta de ahorro y su configuración.
  Future<BolsaAhorro> crearBolsa({
    required String libroId,
    required String nombre,
    required TipoBolsaAhorro tipo,
    int? meta,
    int? montoAnual,
    Fecha? fechaMeta,
    int? nivel,
    int? aporteFijo,
    List<MetodoAhorro> metodos = const [],
    int saldoInicial = 0,
  }) async {
    base.exigirAdministrar(libroId);
    if (nombre.trim().isEmpty) throw const ErrorFinanzas('Escribe un nombre.');
    if (tipo == TipoBolsaAhorro.fondoEmergencia &&
        _d.bolsasDe(libroId).any((b) => b.tipo == tipo)) {
      throw const ErrorFinanzas('Ya tienes un fondo de emergencia.');
    }
    if (tipo == TipoBolsaAhorro.reserva && (montoAnual ?? 0) <= 0) {
      throw const ErrorFinanzas('Escribe el monto de la reserva al año.');
    }
    if (tipo == TipoBolsaAhorro.metaFecha &&
        ((meta ?? 0) <= 0 || fechaMeta == null)) {
      throw const ErrorFinanzas('Una meta con fecha lleva monto y fecha.');
    }
    final cuenta = await base.crearCuenta(
      libroId: libroId,
      nombre: nombre.trim(),
      tipo: TipoCuenta.ahorro,
      saldoInicial: saldoInicial,
    );
    final b = BolsaAhorro(
      id: base.nuevoId(),
      libroId: libroId,
      nombre: nombre.trim(),
      tipo: tipo,
      cuentaId: cuenta.id,
      meta: tipo == TipoBolsaAhorro.fondoEmergencia ? null : meta,
      montoAnual: tipo == TipoBolsaAhorro.reserva ? montoAnual : null,
      fechaMeta: tipo == TipoBolsaAhorro.metaFecha ? fechaMeta : null,
      nivelMeta: tipo == TipoBolsaAhorro.fondoEmergencia
          ? (nivel ?? NivelFondo.porDefecto.numero)
          : null,
      aporteFijo: aporteFijo,
      metodos: metodos,
    );
    await base.repositorio.guardarBolsa(b);
    return b;
  }

  /// Cambia el nivel del fondo (de ahí en adelante; el historial son los
  /// movimientos).
  Future<void> cambiarNivelFondo(String bolsaId, NivelFondo nivel) async {
    final b = _bolsa(bolsaId);
    base.exigirAdministrar(b.libroId);
    await base.repositorio.guardarBolsa(b.copiar(nivelMeta: nivel.numero));
  }

  BolsaAhorro _bolsa(String id) =>
      _d.bolsas.where((b) => b.id == id).firstOrNull ??
      (throw const ErrorFinanzas('No existe esa bolsa.'));

  /// Lo que se sugiere aportar a [b] esta semana, por etapa.
  List<PasoDeAhorro> _pasos(String libroId, Semana semana) {
    final esencial = gastoEsencial(libroId, semana).semanal;
    final pasos = <PasoDeAhorro>[];
    for (final b in _d.bolsasDe(libroId)) {
      final saldo = saldoDeBolsa(b);
      switch (b.tipo) {
        case TipoBolsaAhorro.fondoEmergencia:
          if (esencial == null) break;
          final nivel = b.nivelMeta ?? NivelFondo.porDefecto.numero;
          final n1 = metaDelFondo(NivelFondo.colchon, esencial);
          final m = metaDelFondo(
            NivelFondo.values.firstWhere((n) => n.numero == nivel),
            esencial,
          );
          final colchon = saldo >= n1 ? 0 : n1 - saldo;
          pasos.add(PasoDeAhorro(b.id, EtapaAhorro.colchon, colchon));
          final resto = m - (saldo > n1 ? saldo : n1);
          pasos.add(
            PasoDeAhorro(b.id, EtapaAhorro.fondoHastaLaMeta, resto > 0 ? resto : 0),
          );
        case TipoBolsaAhorro.reserva:
          pasos.add(
            PasoDeAhorro(
              b.id,
              EtapaAhorro.reservas,
              aportacionDeReserva(b.montoAnual ?? 0),
            ),
          );
        case TipoBolsaAhorro.metaFecha:
          final semanas =
              (semana.inicio.diasHasta(b.fechaMeta!) / 7).ceil();
          pasos.add(
            PasoDeAhorro(
              b.id,
              EtapaAhorro.metasConFecha,
              aportacionDeMetaConFecha(
                meta: b.meta ?? 0,
                saldo: saldo,
                semanasRestantes: semanas,
              ),
            ),
          );
        case TipoBolsaAhorro.metaLibre:
          var s = b.aporteFijo ?? 0;
          if (b.metodos.contains(MetodoAhorro.reto52Semanas) && b.retoBase != null) {
            final n = _d.aportaciones.where((a) => a.bolsaId == b.id).length + 1;
            if (n <= 52) s += retoDeSemana(n, b.retoBase!);
          }
          final falta = (b.meta ?? (1 << 40)) - saldo;
          pasos.add(
            PasoDeAhorro(b.id, EtapaAhorro.metasSinFecha, s > falta ? falta : s),
          );
      }
    }
    return pasos;
  }

  /// Reparto del remanente de la semana (regla 22): propuestas guardadas,
  /// una por bolsa; nada se mueve hasta confirmar. [remanente] es el que
  /// calculó el motor de la semana.
  Future<RepartoDeAhorro> proponerReparto({
    required String libroId,
    required Semana semana,
    required int remanente,
  }) async {
    base.exigirEscribir(libroId);
    final guardada = _d.semanaGuardada(libroId, semana);
    if (guardada == null) {
      throw const ErrorFinanzas('Activa la semana para repartir el ahorro.');
    }
    final planes = _planes(libroId);
    final conExtra = hayDeudaQueRecibeExtraSeguro(planes);
    final reparto = repartirAhorro(
      remanente: remanente,
      pasos: _pasos(libroId, semana),
      hayDeudaConExtra: conExtra,
      ahorroMinimoConDeuda: _d.parametrosDe(libroId).ahorroMinimoConDeudaPuntosBase,
    );
    for (final b in _d.bolsasDe(libroId)) {
      final id = idEstable(ClavesId.aportacionFila(b.id, guardada.id));
      final previa = _d.aportaciones.where((a) => a.id == id).firstOrNull;
      if (previa != null && previa.estado != EstadoAportacion.propuesta) continue;
      final sugerido = reparto.aportadoA(b.id);
      await base.repositorio.guardarAportacion(
        AportacionAhorro(
          id: id,
          libroId: libroId,
          semanaId: guardada.id,
          bolsaId: b.id,
          sugerido: sugerido + reparto.pendienteDe(b.id),
        ),
      );
    }
    return reparto;
  }

  /// Confirma una aportación: una transferencia de [cuentaOrigenId] a la
  /// cuenta de la bolsa. Necesita señal (el servidor liga el movimiento).
  Future<void> confirmarAportacion({
    required String aportacionId,
    required String cuentaOrigenId,
    int? monto,
  }) async {
    final a = _d.aportaciones.firstWhere(
      (x) => x.id == aportacionId,
      orElse: () => throw const ErrorFinanzas('No existe esa aportación.'),
    );
    final b = _bolsa(a.bolsaId);
    base.exigirEscribir(a.libroId);
    final cuanto = monto ?? a.sugerido;
    if (cuanto <= 0) throw const ErrorFinanzas('Escribe un monto mayor que cero.');
    final quien = base.quienDe(a.libroId, null);
    final m = Movimiento(
      id: idEstable(ClavesId.aportacion(b.id, a.semanaId)),
      tipo: TipoMovimiento.transferencia,
      fecha: base.hoy,
      registradoEn: base.ahora,
      cuentaOrigenId: cuentaOrigenId,
      cuentaDestinoId: b.cuentaId,
      monto: cuanto,
      realizadoPor: quien.realizadoPor,
      registradoPor: base.personaId,
      enNombreDe: quien.enNombreDe,
      nota: 'Aportación a ${b.nombre}',
    );
    final r = await base.repositorio.agregarMovimientos([m]);
    if (r == ResultadoEscritura.enCola) throw ErrorFinanzas.conexion;
    await base.repositorio.guardarAportacion(
      AportacionAhorro(
        id: a.id,
        libroId: a.libroId,
        semanaId: a.semanaId,
        bolsaId: a.bolsaId,
        sugerido: a.sugerido,
        aportado: cuanto,
        estado: EstadoAportacion.confirmada,
        movimientoId: m.id,
      ),
    );
  }

  /// Pospone u omite una aportación: lo no aportado queda pendiente sin
  /// castigo (regla 24).
  Future<void> posponerAportacion(String aportacionId, {bool omitir = false}) async {
    final a = _d.aportaciones.firstWhere(
      (x) => x.id == aportacionId,
      orElse: () => throw const ErrorFinanzas('No existe esa aportación.'),
    );
    base.exigirEscribir(a.libroId);
    await base.repositorio.guardarAportacion(
      AportacionAhorro(
        id: a.id,
        libroId: a.libroId,
        semanaId: a.semanaId,
        bolsaId: a.bolsaId,
        sugerido: a.sugerido,
        estado: omitir ? EstadoAportacion.omitida : EstadoAportacion.pospuesta,
      ),
    );
  }

  /// Retira de una bolsa a [cuentaDestinoId] (o a [bolsaDestinoId] si cambia
  /// de destino). No cambia el patrimonio (criterio 26). El motivo lleva al
  /// menos 3 caracteres visibles.
  Future<void> retirar({
    required String bolsaId,
    required int monto,
    required TipoRetiro tipo,
    required String motivo,
    String? cuentaDestinoId,
    String? bolsaDestinoId,
  }) async {
    final b = _bolsa(bolsaId);
    base.exigirEscribir(b.libroId);
    if (monto <= 0) throw const ErrorFinanzas('Escribe un monto mayor que cero.');
    if (!motivoValido(motivo)) {
      throw const ErrorFinanzas(mensajeMotivoCorto);
    }
    if (monto > saldoDeBolsa(b)) {
      throw const ErrorFinanzas('La bolsa no tiene tanto saldo.');
    }
    String destinoCuenta;
    if (tipo == TipoRetiro.cambioDeDestino) {
      final otra = bolsaDestinoId == null ? null : _bolsa(bolsaDestinoId);
      if (otra == null || otra.id == b.id) {
        throw const ErrorFinanzas('Elige la bolsa de destino.');
      }
      destinoCuenta = otra.cuentaId;
    } else {
      destinoCuenta = cuentaDestinoId ??
          (throw const ErrorFinanzas('Elige a qué cuenta va el dinero.'));
    }
    final quien = base.quienDe(b.libroId, motivo);
    final m = Movimiento(
      id: base.nuevoId(),
      tipo: TipoMovimiento.transferencia,
      fecha: base.hoy,
      registradoEn: base.ahora,
      cuentaOrigenId: b.cuentaId,
      cuentaDestinoId: destinoCuenta,
      monto: monto,
      realizadoPor: quien.realizadoPor,
      registradoPor: base.personaId,
      enNombreDe: quien.enNombreDe,
      motivo: motivo.trim(),
    );
    final r = await base.repositorio.agregarMovimientos([m]);
    if (r == ResultadoEscritura.enCola) throw ErrorFinanzas.conexion;
    await base.repositorio.agregarRetiro(
      RetiroAhorro(
        id: base.nuevoId(),
        libroId: b.libroId,
        bolsaId: b.id,
        movimientoId: m.id,
        tipo: tipo,
        motivo: motivo.trim(),
        bolsaDestinoId: tipo == TipoRetiro.cambioDeDestino ? bolsaDestinoId : null,
        registradoEn: base.ahora,
      ),
    );
  }
}

/// Resultado de aplicar la ficha.
class ResultadoFicha {
  const ResultadoFicha({this.creadas = 0, this.yaExistian = 0});

  final int creadas;
  final int yaExistian;
}

extension ImportarFicha on ServicioDeudasAhorro {
  /// Crea lo de la [lectura] que aún no existe (los ids salen del ID de la
  /// ficha: reimportar no duplica). Cada tarjeta lleva su cuenta pasivo con el
  /// saldo como apertura; nada se inventa.
  Future<ResultadoFicha> aplicarFicha(String libroId, LecturaFicha lectura) async {
    base.exigirAdministrar(libroId);
    final datos = base.datos;
    var creadas = 0;
    var existian = 0;
    String idDe(String hoja, String idFicha) =>
        idEstable(ClavesId.ficha(libroId, hoja, idFicha));

    String nombreLibre(String nombre) {
      var candidato = nombre;
      var n = 2;
      while (base.datos.cuentasDe(libroId).any(
        (c) => normalizarNombre(c.nombre) == normalizarNombre(candidato),
      )) {
        candidato = '$nombre ($n)';
        n++;
      }
      return candidato;
    }

    for (final t in lectura.tarjetas) {
      final id = idDe('tarjetas', t.idFicha);
      if (datos.deudas.any((d) => d.id == id)) {
        existian++;
        continue;
      }
      final nombre = t.nombre.isEmpty || t.nombre == t.institucion
          ? t.institucion
          : '${t.institucion} ${t.nombre}';
      final cuenta = await base.crearCuenta(
        libroId: libroId,
        nombre: nombreLibre(nombre),
        tipo: TipoCuenta.tarjeta,
        saldoInicial: t.saldo,
        limiteCentavos: t.limite,
      );
      await base.guardarDeuda(
        Deuda(
          id: id,
          libroId: libroId,
          nombre: nombre,
          tipo: TipoDeuda.conCosto,
          clase: ClaseDeuda.tarjeta,
          acreedor: t.institucion,
          cuentaPasivoId: cuenta.id,
          abono: t.minimo ?? 0,
          minimo: t.minimo ?? 0,
          frecuencia: Frecuencia.mensual,
          calendario: t.limitePagoDia == null || t.limitePagoDia == 0
              ? null
              : CalendarioConfig.mensual(
                  [t.limitePagoDia!],
                  regla: ReglaDiaInhabil.sinCambio,
                ),
          tasaAnualPuntosBase: t.tasaPb ?? 0,
          catPuntosBase: t.catPb,
          corteDia: t.corteDia,
        ),
      );
      creadas++;
    }

    final c = lectura.credito;
    if (c != null) {
      final id = idDe('credito', 'auto');
      if (datos.deudas.any((d) => d.id == id)) {
        existian++;
      } else {
        final cuenta = await base.crearCuenta(
          libroId: libroId,
          nombre: nombreLibre(c.institucion),
          tipo: TipoCuenta.prestamo,
          saldoInicial: c.saldo,
        );
        await base.guardarDeuda(
          Deuda(
            id: id,
            libroId: libroId,
            nombre: c.institucion,
            tipo: TipoDeuda.conCosto,
            clase: ClaseDeuda.credito,
            acreedor: c.institucion,
            cuentaPasivoId: cuenta.id,
            abono: c.mensualidad ?? 0,
            minimo: c.mensualidad ?? 0,
            frecuencia: Frecuencia.mensual,
            calendario: c.diaPago == null || c.diaPago == 0
                ? null
                : CalendarioConfig.mensual(
                    [c.diaPago!],
                    regla: ReglaDiaInhabil.siguienteDiaHabil,
                  ),
            tasaAnualPuntosBase: c.tasaPb ?? 0,
            montoOriginal: c.montoOriginal,
            // Nulo = verificar con la caja (regla 12).
            permitePagoAnticipado: c.permitePagoAnticipado,
          ),
        );
        creadas++;
      }
    }

    for (final m in lectura.msi) {
      final id = idDe('msi', m.idFicha);
      if (base.datos.msi.any((x) => x.id == id)) {
        existian++;
        continue;
      }
      await crearMsi(
        libroId: libroId,
        comercio: m.comercio,
        descripcion: m.descripcion,
        total: m.total,
        meses: m.meses,
        fechaCompra: m.fechaCompra,
        diaPago: m.fechaCompra.dia > 28 ? 28 : m.fechaCompra.dia,
        pagadas: m.pagadas,
        id: id,
        tarjetaDeudaId: m.idTarjeta == null
            ? null
            : (base.datos.deudas.any((d) => d.id == idDe('tarjetas', m.idTarjeta!))
                  ? idDe('tarjetas', m.idTarjeta!)
                  : null),
      );
      creadas++;
    }
    return ResultadoFicha(creadas: creadas, yaExistian: existian);
  }
}

/// [hayDeudaQueRecibeExtra] que no falla si falta la tasa de una deuda.
bool hayDeudaQueRecibeExtraSeguro(Iterable<DeudaPlan> planes) {
  try {
    return hayDeudaQueRecibeExtra(planes);
  } on ArgumentError {
    return false;
  }
}

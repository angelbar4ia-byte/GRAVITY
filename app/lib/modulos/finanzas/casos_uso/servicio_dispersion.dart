/// Casos de uso de la dispersión de ingresos (especificación
/// `docs/specs/fase-8-finanzas-dispersion.md`): proponer el reparto de un
/// ingreso con el dominio, aceptarlo, dejarlo para después, deshacerlo y
/// corregir el tipo de un ingreso.
///
/// **La app propone y la persona confirma; nunca mueve dinero sola.** Aceptar
/// solo crea movimientos para el abono extra (pago de deuda) y el ahorro
/// (transferencia), con ids estables: repetir no duplica. Los renglones de
/// presupuesto y de pago de deuda **asignan** (no mueven dinero).
///
/// Los permisos se revisan con los del libro (`ServicioFinanzas`, espejo de
/// `fin_puede`); el servidor los vuelve a verificar. Nada de esto va a IA ni a
/// bocinas (D3, D6): corre en el dispositivo con lo cargado.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../datos/ids.dart' show claveDeLineaDispersion;
import '../datos/repositorio.dart' show ErrorFinanzas;
import '../datos/repositorio_dispersiones.dart';
import 'servicio_finanzas.dart';

/// Motivo de los asientos de deshacer un reparto.
const motivoDeshacerReparto = 'Reparto deshecho';

class ServicioDispersion {
  ServicioDispersion({required this.finanzas, required this.repositorio});

  final ServicioFinanzas finanzas;
  final RepositorioDispersiones repositorio;

  DatosFinanzas get _d => finanzas.datos;

  /// Parámetros del libro. Sin fila, los de omisión: con confirmación y
  /// **desde el lunes de la semana anterior** (pregunta abierta P2).
  ParametrosDispersion parametros(String libroId) =>
      repositorio.parametrosDe(libroId) ??
      ParametrosDispersion(desde: Semana.de(finanzas.hoy).anterior.inicio);

  /// Los ingresos del libro con su estado de reparto.
  List<IngresoPorRepartir> ingresos(String libroId) => ingresosDelLibro(
    _d,
    libroId,
    repositorio.actuales,
    parametros: parametros(libroId),
  );

  /// El reparto propuesto de [ingreso] con el plan de la semana de hoy.
  ///
  /// Si hay una propuesta guardada (editada antes), arranca de ella.
  PropuestaDispersion proponer(IngresoPorRepartir ingreso) {
    final plan = armarPlanDelLibro(
      _d,
      ingreso.libroId,
      Semana.de(finanzas.hoy),
    );
    final base = proponerDispersion(
      ingreso: ingreso,
      plan: plan.plan,
      parametros: parametros(ingreso.libroId),
    );
    final guardada = _vigentePendiente(ingreso.movimientoId);
    if (guardada == null || guardada.estado != EstadoDispersion.propuesta) {
      return base;
    }
    return PropuestaDispersion(
      movimientoId: ingreso.movimientoId,
      monto: ingreso.monto,
      lineas: [
        for (final l in guardada.lineas)
          if (l.destino != DestinoLinea.porRepartir) l,
      ],
      faltante: base.faltante,
      destinoRemanente: base.destinoRemanente,
    );
  }

  Dispersion? _vigentePendiente(String movimientoId) => repositorio.actuales
      .where(
        (x) =>
            x.movimientoId == movimientoId &&
            x.estado != EstadoDispersion.anulada,
      )
      .firstOrNull;

  /// «Dejar para después»: si la persona editó la propuesta, la guarda
  /// (estado «propuesta»); si no, no guarda nada y el ingreso sigue «por
  /// repartir». No crea movimientos.
  Future<void> dejarParaDespues({
    required IngresoPorRepartir ingreso,
    PropuestaDispersion? propuestaEditada,
    String? motivo,
  }) async {
    finanzas.exigirEscribir(ingreso.libroId);
    if (!ingreso.estado.pendiente) {
      throw const ErrorFinanzas('Ese ingreso ya está repartido.');
    }
    if (propuestaEditada == null) return;
    await _guardarReparto(
      ingreso: ingreso,
      estado: EstadoDispersion.propuesta,
      modo: ModoDispersion.confirmacion,
      lineas: propuestaEditada.lineasParaGuardar(),
      motivo: motivo,
    );
  }

  /// Acepta el reparto: guarda la dispersión y crea los movimientos del abono
  /// extra y del ahorro.
  ///
  /// [cuentaAhorroId] es obligatoria si la propuesta lleva ahorro. En el libro
  /// de Papá el [motivo] es obligatorio y el albacea confirma en su nombre.
  Future<Dispersion> aceptar({
    required IngresoPorRepartir ingreso,
    required PropuestaDispersion propuesta,
    String? cuentaAhorroId,
    String? motivo,
  }) async {
    finanzas.exigirEscribir(ingreso.libroId);
    final quien = finanzas.quienDe(ingreso.libroId, motivo);
    final aplicada = repositorio.actuales
        .where(
          (x) => x.movimientoId == ingreso.movimientoId && x.estado.aplicada,
        )
        .firstOrNull;
    if (aplicada != null) {
      throw const ErrorFinanzas('Ese ingreso ya está repartido.');
    }
    if (propuesta.quedaPorRepartir < 0 ||
        propuesta.totalRepartido > ingreso.monto) {
      throw const ErrorFinanzas(
        'El reparto pasa del monto del ingreso: revísalo.',
      );
    }
    if (propuesta.ahorro > 0 && cuentaAhorroId == null) {
      throw const ErrorFinanzas(
        'Elige la cuenta de ahorro o deja ese dinero por repartir.',
      );
    }
    final id = _idDeReparto(ingreso.movimientoId);
    final lineas = propuesta.lineasParaGuardar();
    final movimientos = _movimientosDe(
      id: id,
      ingreso: ingreso,
      lineas: lineas,
      cuentaAhorroId: cuentaAhorroId,
      quien: quien,
      motivo: motivo,
    );
    // Valida con las reglas del libro antes de guardar nada.
    final libro = _d.nuevoLibroHogar();
    try {
      for (final m in movimientos) {
        libro.agregar(m);
      }
    } on ErrorLibro catch (e) {
      throw ErrorFinanzas(e.mensaje);
    }
    // Con servidor, `fin_confirmar_dispersion` crea los movimientos en la misma
    // transacción que el reparto (y repetir no duplica); en memoria los agrega
    // el servicio.
    if (!repositorio.ligaMovimientos) {
      final ya = {for (final m in _d.movimientos) m.id};
      final nuevos = [
        for (final m in movimientos)
          if (!ya.contains(m.id)) m,
      ];
      if (nuevos.isNotEmpty) {
        await finanzas.repositorio.agregarMovimientos(nuevos);
      }
    }
    final d = await _guardarReparto(
      ingreso: ingreso,
      estado: EstadoDispersion.confirmada,
      modo: ModoDispersion.confirmacion,
      lineas: lineas,
      motivo: motivo,
      id: id,
      enNombreDe: quien.enNombreDe,
      movimientos: movimientos,
      cuentaAhorroId: cuentaAhorroId,
    );
    _avisarCambio(ingreso.libroId);
    return d;
  }

  /// Deshace un reparto aplicado: anula los movimientos que creó y el ingreso
  /// vuelve a «por repartir» (el reparto queda «anulado»).
  Future<void> deshacer(String dispersionId) async {
    final d = repositorio.actuales
        .where((x) => x.id == dispersionId)
        .firstOrNull;
    if (d == null || !d.estado.aplicada) {
      throw const ErrorFinanzas('Ese reparto no se puede deshacer.');
    }
    finanzas.exigirEscribir(d.libroId);
    // Con servidor, `fin_deshacer_dispersion` anula los movimientos y el reparto
    // en una transacción (idempotente); en memoria los anula el servicio.
    if (!repositorio.ligaMovimientos) {
      final libro = _d.nuevoLibroHogar();
      for (final l in d.lineas) {
        if (!l.destino.mueveDinero) continue;
        final id = idEstable(
          ClavesId.dispersionMovimiento(d.id, claveDeLineaDispersion(l)),
        );
        final existe = _d.movimientos.any((m) => m.id == id);
        if (existe && libro.contraasientoDe(id) == null) {
          await finanzas.anular(id, motivo: motivoDeshacerReparto);
        }
      }
    }
    await repositorio.deshacer(d, motivo: motivoDeshacerReparto);
    _avisarCambio(d.libroId);
  }

  /// Modo automático (decisión 1; pregunta abierta P1): asigna lo comprometido
  /// de los ingresos que cubren todo. No crea movimientos. Devuelve cuántos
  /// repartió. Sin permiso de escribir o en modo con confirmación, no hace
  /// nada.
  Future<int> aplicarAutomaticas(String libroId) async {
    final p = parametros(libroId);
    if (p.modo != ModoDispersion.automatico) return 0;
    if (!finanzas.permiso(libroId).escribir || finanzas.soloLectura) return 0;
    var hechos = 0;
    for (final i in ingresos(libroId)) {
      if (i.estado != EstadoDispersion.porRepartir) continue;
      final propuesta = proponer(i);
      if (estadoAlRecibir(propuesta, p.modo) != EstadoDispersion.automatica) {
        continue;
      }
      await _guardarReparto(
        ingreso: i,
        estado: EstadoDispersion.automatica,
        modo: ModoDispersion.automatico,
        lineas: propuesta.lineasAutomaticas(),
      );
      hechos++;
    }
    return hechos;
  }

  /// Corrige el tipo de un ingreso con anulación y contraasiento (decisión 4).
  Future<CorreccionIngreso> cambiarTipo({
    required String movimientoId,
    required String cuentaOrigenId,
    required String motivo,
  }) async {
    final original = _d.movimientos
        .where((m) => m.id == movimientoId)
        .firstOrNull;
    if (original == null) {
      throw const ErrorFinanzas('No existe ese movimiento.');
    }
    final libroId = _d.cuenta(original.cuentaDestinoId)?.libroId;
    if (libroId == null) {
      throw const ErrorFinanzas('No puedes cambiar el tipo de ese ingreso.');
    }
    finanzas.exigirEscribir(libroId);
    if (!motivoValido(motivo)) {
      throw const ErrorFinanzas(
        'Escribe el motivo del cambio: $mensajeMotivoCorto',
      );
    }
    final repartido = repositorio.actuales.any(
      (x) => x.movimientoId == movimientoId && x.estado.aplicada,
    );
    if (repartido) {
      throw const ErrorFinanzas(
        'Ese ingreso ya está repartido. Deshaz el reparto y vuelve a '
        'intentarlo.',
      );
    }
    final libro = _d.libro(libroId)!;
    final ajeno =
        libro.tipo == TipoLibro.compartido &&
        original.realizadoPor != finanzas.personaId;
    final CorreccionIngreso c;
    try {
      c = corregirTipoDeIngreso(
        _d.nuevoLibroHogar(),
        movimientoId: movimientoId,
        nuevaCuentaOrigenId: cuentaOrigenId,
        idAnulacion: idEstable(ClavesId.correccionIngreso(movimientoId, 'a')),
        idNuevo: idEstable(ClavesId.correccionIngreso(movimientoId, 'n')),
        grupoId: idEstable(ClavesId.correccionIngreso(movimientoId, 'g')),
        motivo: motivo.trim(),
        registradoPor: finanzas.personaId,
        registradoEn: finanzas.ahora,
        estado: ajeno
            ? EstadoMovimiento.pendiente
            : EstadoMovimiento.confirmado,
      );
    } on ErrorDispersion catch (e) {
      throw ErrorFinanzas(e.mensaje);
    }
    // Con servidor, `fin_corregir_tipo_ingreso` agrega los dos asientos en una
    // transacción (y rechaza lo ya repartido); en memoria los agrega el
    // servicio. En los dos casos la propuesta del ingreso viejo ya no vale.
    if (!repositorio.ligaMovimientos) {
      await finanzas.repositorio.agregarMovimientos([c.anulacion, c.nuevo]);
    }
    await repositorio.corregirTipo(
      movimientoId: movimientoId,
      cuentaOrigenId: cuentaOrigenId,
      motivo: motivo.trim(),
      idAnulacion: c.anulacion.id,
      idNuevo: c.nuevo.id,
      grupoId: c.anulacion.grupoId!,
    );
    _avisarCambio(libroId);
    return c;
  }

  // -------------------------------------------------------------- internos

  String _idDeReparto(String movimientoId) {
    final pendiente = _vigentePendiente(movimientoId);
    if (pendiente != null && pendiente.estado.pendiente) return pendiente.id;
    final intentos = repositorio.actuales
        .where((x) => x.movimientoId == movimientoId)
        .length;
    return idEstable(ClavesId.dispersion(movimientoId, intentos + 1));
  }

  List<Movimiento> _movimientosDe({
    required String id,
    required IngresoPorRepartir ingreso,
    required List<LineaDispersion> lineas,
    required String? cuentaAhorroId,
    required ({String realizadoPor, String? enNombreDe}) quien,
    String? motivo,
  }) {
    final limpio = motivo?.trim();
    final nota = limpio == null || limpio.isEmpty ? null : limpio;
    final movimientos = <Movimiento>[];
    for (final l in lineas) {
      if (!l.destino.mueveDinero || l.monto <= 0) continue;
      final String destino;
      final TipoMovimiento tipo;
      final String texto;
      if (l.destino == DestinoLinea.abonoExtra) {
        final deuda = _d.deudas
            .where((x) => x.id == l.referenciaId)
            .firstOrNull;
        final pasivo = deuda?.cuentaPasivoId;
        if (pasivo == null) {
          throw ErrorFinanzas(
            'La deuda ${l.etiqueta} no tiene cuenta para recibir el abono.',
          );
        }
        destino = pasivo;
        tipo = TipoMovimiento.pagoDeuda;
        texto = 'Abono extra con un ingreso';
      } else {
        destino = cuentaAhorroId!;
        tipo = TipoMovimiento.transferencia;
        texto = 'Ahorro con un ingreso';
      }
      movimientos.add(
        Movimiento(
          id: idEstable(
            ClavesId.dispersionMovimiento(id, claveDeLineaDispersion(l)),
          ),
          tipo: tipo,
          fecha: finanzas.hoy,
          registradoEn: finanzas.ahora,
          cuentaOrigenId: ingreso.cuentaDestinoId,
          cuentaDestinoId: destino,
          monto: l.monto,
          realizadoPor: quien.realizadoPor,
          registradoPor: finanzas.personaId,
          nota: texto,
          motivo: nota,
          enNombreDe: quien.enNombreDe,
        ),
      );
    }
    return movimientos;
  }

  Future<Dispersion> _guardarReparto({
    required IngresoPorRepartir ingreso,
    required EstadoDispersion estado,
    required ModoDispersion modo,
    required List<LineaDispersion> lineas,
    String? motivo,
    String? id,
    String? enNombreDe,
    List<Movimiento> movimientos = const [],
    String? cuentaAhorroId,
  }) async {
    final d = Dispersion(
      id: id ?? _idDeReparto(ingreso.movimientoId),
      libroId: ingreso.libroId,
      movimientoId: ingreso.movimientoId,
      estado: estado,
      modo: modo,
      lineas: lineas,
      creadaEn: finanzas.ahora,
      resueltaPor: estado == EstadoDispersion.confirmada
          ? finanzas.personaId
          : null,
      resueltaEn: estado == EstadoDispersion.confirmada ? finanzas.ahora : null,
      enNombreDe: enNombreDe,
      motivo: motivo?.trim().isEmpty ?? true ? null : motivo!.trim(),
    );
    if (estado == EstadoDispersion.confirmada) {
      await repositorio.confirmar(
        d,
        movimientos: movimientos,
        cuentaAhorroId: cuentaAhorroId,
      );
    } else {
      await repositorio.guardar(d);
    }
    return d;
  }

  void _avisarCambio(String libroId) {
    try {
      finanzas.alCambiarLibro?.call(libroId);
    } catch (_) {
      // Un aviso nunca debe impedir un guardado.
    }
  }
}

/// Dónde se guardan los repartos de ingresos (`fin_dispersiones` y
/// `fin_dispersion_lineas`; `docs/specs/fase-8-finanzas-dispersion.md`,
/// sección 8).
///
/// Dos versiones detrás de la misma interfaz:
/// - [RepositorioDispersionesEnMemoria]: pruebas y modo demostración. El
///   servicio agrega los movimientos al libro por su cuenta.
/// - `RepositorioDispersionesSupabase` (`repositorio_dispersiones_supabase.dart`):
///   el servidor guarda el reparto, **liga los movimientos de abono extra y
///   ahorro en la misma transacción** (`fin_confirmar_dispersion`), deshace el
///   reparto (`fin_deshacer_dispersion`) y corrige el tipo de un ingreso
///   (`fin_corregir_tipo_ingreso`) y cambia un reparto ya confirmado
///   (`fin_cambiar_dispersion`, con control de versión). Confirmar, deshacer,
///   cambiar y corregir necesitan señal, como los estados de cuenta.
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';

import 'repositorio.dart' show ErrorFinanzas;

abstract interface class RepositorioDispersiones {
  /// Los repartos vigentes y anulados, en el orden en que se guardaron.
  List<Dispersion> get actuales;

  /// Avisa cada vez que cambian [actuales].
  Stream<List<Dispersion>> get cambios;

  /// Verdadero si el servidor crea y anula **él mismo** los movimientos del
  /// reparto (y los dos asientos de corregir el tipo): el servicio entonces no
  /// los agrega al libro. Falso en la versión en memoria.
  bool get ligaMovimientos;

  /// Guarda un reparto que **no mueve dinero**: una propuesta o uno
  /// automático.
  Future<void> guardar(Dispersion dispersion);

  /// Confirma un reparto. [movimientos] son los asientos de abono extra y de
  /// ahorro que el servicio armó y validó (ids estables); con
  /// [ligaMovimientos] el servidor los crea al confirmar; si no, el servicio ya
  /// los agregó. [cuentaAhorroId] es la cuenta que recibe el ahorro.
  Future<void> confirmar(
    Dispersion dispersion, {
    required List<Movimiento> movimientos,
    String? cuentaAhorroId,
  });

  /// Deshace un reparto aplicado: queda anulado (con [ligaMovimientos], el
  /// servidor también anula los movimientos que creó).
  Future<void> deshacer(Dispersion dispersion, {required String motivo});

  /// Cambia un reparto ya confirmado (P5, 20/nov/2026): [anterior] queda
  /// «reemplazado» (conserva su historial) y [nueva] es la versión siguiente.
  /// Con [ligaMovimientos] el servidor, en una transacción, anula con
  /// contraasiento lo que creó [anterior] y crea los [movimientos] de la nueva
  /// (solo abono extra y ahorro); si no, el servicio ya los agregó.
  ///
  /// Control de versión: viaja la versión de [anterior] que la persona vio; si
  /// el servidor ya tiene otra, lanza un `ErrorFinanzas` con `repartoCambio`
  /// (y el repositorio vuelve a cargar los repartos).
  Future<void> cambiar(
    Dispersion nueva, {
    required Dispersion anterior,
    required List<Movimiento> movimientos,
    String? cuentaAhorroId,
  });

  /// Corrige el tipo de un ingreso. Con [ligaMovimientos] el servidor agrega la
  /// anulación y el ingreso nuevo (con estos ids y grupo); en cualquier caso, el
  /// reparto en borrador del ingreso viejo queda anulado.
  Future<void> corregirTipo({
    required String movimientoId,
    required String cuentaOrigenId,
    required String motivo,
    required String idAnulacion,
    required String idNuevo,
    required String grupoId,
  });

  /// Parámetros del libro (nulos si no hay fila; la app usa los de omisión).
  ParametrosDispersion? parametrosDe(String libroId);

  Future<void> guardarParametros(
    String libroId,
    ParametrosDispersion p, {
    String? motivo,
  });
}

/// Versión en memoria (pruebas y demostración).
class RepositorioDispersionesEnMemoria implements RepositorioDispersiones {
  RepositorioDispersionesEnMemoria({
    Iterable<Dispersion> inicial = const [],
    Map<String, ParametrosDispersion> parametros = const {},
  }) : _lista = [...inicial],
       _parametros = {...parametros};

  final List<Dispersion> _lista;
  final Map<String, ParametrosDispersion> _parametros;
  final _cambios = StreamController<List<Dispersion>>.broadcast();

  @override
  List<Dispersion> get actuales => List.unmodifiable(_lista);

  @override
  Stream<List<Dispersion>> get cambios => _cambios.stream;

  @override
  bool get ligaMovimientos => false;

  @override
  Future<void> guardar(Dispersion dispersion) async {
    final i = _lista.indexWhere((x) => x.id == dispersion.id);
    if (i < 0) {
      _lista.add(dispersion);
    } else {
      _lista[i] = dispersion;
    }
    _cambios.add(actuales);
  }

  @override
  Future<void> confirmar(
    Dispersion dispersion, {
    required List<Movimiento> movimientos,
    String? cuentaAhorroId,
  }) => guardar(dispersion);

  @override
  Future<void> deshacer(Dispersion dispersion, {required String motivo}) =>
      guardar(dispersion.conEstado(EstadoDispersion.anulada));

  @override
  Future<void> cambiar(
    Dispersion nueva, {
    required Dispersion anterior,
    required List<Movimiento> movimientos,
    String? cuentaAhorroId,
  }) async {
    final vigente = _lista.where((x) => x.id == anterior.id).firstOrNull;
    if (vigente == null ||
        !vigente.estado.aplicada ||
        vigente.version != anterior.version) {
      throw const ErrorFinanzas(
        ErrorFinanzas.mensajeRepartoCambio,
        repartoCambio: true,
      );
    }
    await guardar(vigente.conEstado(EstadoDispersion.reemplazada));
    await guardar(nueva);
  }

  @override
  Future<void> corregirTipo({
    required String movimientoId,
    required String cuentaOrigenId,
    required String motivo,
    required String idAnulacion,
    required String idNuevo,
    required String grupoId,
  }) async {
    for (final d in actuales) {
      if (d.movimientoId == movimientoId && d.estado.vigente) {
        await guardar(d.conEstado(EstadoDispersion.anulada));
      }
    }
  }

  @override
  ParametrosDispersion? parametrosDe(String libroId) => _parametros[libroId];

  @override
  Future<void> guardarParametros(
    String libroId,
    ParametrosDispersion p, {
    String? motivo,
  }) async {
    _parametros[libroId] = p;
    _cambios.add(actuales);
  }

  Future<void> cerrar() => _cambios.close();
}

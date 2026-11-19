/// Repositorio de los repartos de ingresos con Supabase
/// (`docs/specs/fase-8-finanzas-dispersion.md`; migración
/// `20261147000000_finanzas_dispersion.sql`).
///
/// - **Leer:** `fin_dispersiones` y `fin_dispersion_lineas` (la RLS deja ver
///   solo los libros que la persona lleva y solo a dueño y coadministrador) y
///   las columnas `dispersion_*` de `fin_parametros`.
/// - **Escribir:** solo por las RPC del servidor (`fin_guardar_propuesta`,
///   `fin_confirmar_dispersion`, `fin_deshacer_dispersion`,
///   `fin_corregir_tipo_ingreso`, `fin_dispersion_parametros_cambiar`). Las
///   tablas no tienen `INSERT` directo, así que **nada pasa por la cola sin
///   conexión**: confirmar, deshacer y corregir el tipo necesitan señal (el
///   servidor liga los movimientos al guardar, como en los estados de cuenta).
///   Solo guardar una propuesta (un borrador sin dinero) tolera la falta de
///   señal: queda en este dispositivo hasta la próxima carga.
/// - Nada de esto sale a IA, bocinas ni tablet pública (D3, D6): los montos
///   solo viajan entre la app de la persona y su servidor.
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';

import 'filas.dart';
import 'fuente_tablas.dart';
import 'ids.dart';
import 'repositorio.dart' show ErrorFinanzas;
import 'repositorio_dispersiones.dart';

/// Tablas y funciones del reparto de ingresos.
abstract final class TablasDispersion {
  static const dispersiones = 'fin_dispersiones';
  static const lineas = 'fin_dispersion_lineas';
  static const guardarPropuesta = 'fin_guardar_propuesta';
  static const confirmar = 'fin_confirmar_dispersion';
  static const deshacer = 'fin_deshacer_dispersion';
  static const corregirTipo = 'fin_corregir_tipo_ingreso';
  static const parametros = 'fin_dispersion_parametros_cambiar';

  /// Columnas de `fin_parametros` que son del reparto.
  static const columnasParametros =
      'libro_id,dispersion_modo,dispersion_desde,'
      'dispersion_parte_libre_pb,dispersion_tope_ahorro';
}

class RepositorioDispersionesSupabase implements RepositorioDispersiones {
  RepositorioDispersionesSupabase({
    required this.fuente,
    this.alCambiarMovimientos,
  });

  final FuenteTablas fuente;

  /// Se llama después de una operación que **creó o anuló movimientos en el
  /// servidor**, para que Finanzas vuelva a cargar el libro (saldos, semana,
  /// «Quedan»).
  final Future<void> Function()? alCambiarMovimientos;

  List<Dispersion> _lista = const [];
  Map<String, ParametrosDispersion> _parametros = const {};
  final _cambios = StreamController<List<Dispersion>>.broadcast();

  /// Borradores que no se pudieron subir por falta de señal (solo este
  /// dispositivo; la próxima carga con señal los reemplaza por lo del
  /// servidor).
  final Map<String, Dispersion> _borradores = {};

  @override
  List<Dispersion> get actuales => List.unmodifiable([
    ..._lista.where((d) => !_borradores.containsKey(d.id)),
    ..._borradores.values,
  ]);

  @override
  Stream<List<Dispersion>> get cambios => _cambios.stream;

  @override
  bool get ligaMovimientos => true;

  // ----------------------------------------------------------------- leer

  /// Vuelve a pedir al servidor los repartos y los parámetros. Sin señal lanza
  /// [ErrorFinanzas] y deja lo que ya había.
  Future<void> cargar() async {
    final filas = await fuente.leer(TablasDispersion.dispersiones);
    final renglones = await fuente.leer(TablasDispersion.lineas);
    final parametros = await fuente.leer(
      TablasFinanzas.parametros,
      columnas: TablasDispersion.columnasParametros,
    );
    final porReparto = <String, List<Map<String, dynamic>>>{};
    for (final r in renglones) {
      (porReparto[r['dispersion_id'] as String] ??= []).add(r);
    }
    final lista = <Dispersion>[];
    for (final f in filas) {
      final mios = porReparto[f['id'] as String] ?? const [];
      mios.sort((a, b) => entero(a['orden']).compareTo(entero(b['orden'])));
      lista.add(dispersionDeFila(f, mios));
    }
    lista.sort((a, b) => a.creadaEn.compareTo(b.creadaEn));
    final params = <String, ParametrosDispersion>{};
    for (final f in parametros) {
      final p = parametrosDispersionDeFila(f);
      if (p != null) params['${f['libro_id']}'] = p;
    }
    _lista = lista;
    _parametros = params;
    _borradores.clear();
    _cambios.add(actuales);
  }

  @override
  ParametrosDispersion? parametrosDe(String libroId) => _parametros[libroId];

  // -------------------------------------------------------------- escribir

  @override
  Future<void> guardar(Dispersion dispersion) async {
    switch (dispersion.estado) {
      case EstadoDispersion.propuesta:
        try {
          final r = await fuente.rpc(TablasDispersion.guardarPropuesta, {
            'p_dispersion': cargaDeDispersion(dispersion),
          });
          _recibir(r, dispersion);
          _borradores.remove(dispersion.id);
        } on ErrorFinanzas catch (e) {
          // Un borrador sin dinero no necesita señal: se queda aquí.
          if (!e.sinConexion) rethrow;
          _borradores[dispersion.id] = dispersion;
        }
      case EstadoDispersion.automatica:
        final r = await fuente.rpc(TablasDispersion.confirmar, {
          'p_dispersion': cargaDeDispersion(dispersion),
        });
        _recibir(r, dispersion);
      case EstadoDispersion.porRepartir:
      case EstadoDispersion.confirmada:
      case EstadoDispersion.anulada:
        throw StateError(
          'Un reparto ${dispersion.estado.name} no se guarda con guardar(): '
          'usa confirmar, deshacer o corregirTipo.',
        );
    }
    _cambios.add(actuales);
  }

  @override
  Future<void> confirmar(
    Dispersion dispersion, {
    required List<Movimiento> movimientos,
    String? cuentaAhorroId,
  }) async {
    final fecha = movimientos.isEmpty ? null : movimientos.first.fecha;
    final r = await fuente.rpc(TablasDispersion.confirmar, {
      'p_dispersion': cargaDeDispersion(
        dispersion,
        cuentaAhorroId: cuentaAhorroId,
        fecha: fecha,
      ),
    });
    _borradores.remove(dispersion.id);
    _recibir(r, dispersion);
    _cambios.add(actuales);
    // El servidor creó los movimientos: Finanzas vuelve a cargar el libro.
    if (movimientos.isNotEmpty) await alCambiarMovimientos?.call();
  }

  @override
  Future<void> deshacer(Dispersion dispersion, {required String motivo}) async {
    final r = await fuente.rpc(TablasDispersion.deshacer, {
      'p_dispersion': dispersion.id,
      'p_motivo': motivo,
    });
    _recibir(r, dispersion.conEstado(EstadoDispersion.anulada));
    _cambios.add(actuales);
    await alCambiarMovimientos?.call();
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
    await fuente.rpc(TablasDispersion.corregirTipo, {
      'p_movimiento': movimientoId,
      'p_cuenta_origen': cuentaOrigenId,
      'p_motivo': motivo,
      'p_grupo': grupoId,
      'p_id_anulacion': idAnulacion,
      'p_id_nuevo': idNuevo,
    });
    // El disparador del servidor anuló el borrador del ingreso viejo: se
    // refleja aquí sin esperar otra carga.
    _lista = [
      for (final d in _lista)
        if (d.movimientoId == movimientoId &&
            d.estado != EstadoDispersion.anulada)
          d.conEstado(EstadoDispersion.anulada)
        else
          d,
    ];
    _borradores.removeWhere((_, d) => d.movimientoId == movimientoId);
    _cambios.add(actuales);
    await alCambiarMovimientos?.call();
  }

  @override
  Future<void> guardarParametros(
    String libroId,
    ParametrosDispersion p, {
    String? motivo,
  }) async {
    final r = await fuente.rpc(TablasDispersion.parametros, {
      'p_libro': libroId,
      'p_modo': nombreEnum(p.modo),
      'p_desde': p.desde == null ? null : fechaIso(p.desde!),
      'p_parte_libre_pb': p.parteLibrePuntosBase,
      'p_tope_ahorro': p.topeAhorro,
      'p_quitar_tope': p.topeAhorro == null,
      'p_motivo': motivo,
    });
    final guardado = r is Map
        ? parametrosDispersionDeFila({
            'dispersion_modo': r['modo'],
            'dispersion_desde': r['desde'],
            'dispersion_parte_libre_pb': r['parte_libre_pb'],
            'dispersion_tope_ahorro': r['tope_ahorro'],
          })
        : null;
    _parametros = {..._parametros, libroId: guardado ?? p};
    _cambios.add(actuales);
  }

  /// Toma el reparto que devolvió el servidor (o, si no vino, [respaldo]) y lo
  /// pone en la lista por id.
  void _recibir(Object? r, Dispersion respaldo) {
    final recibido = r is Map
        ? dispersionDeJson(Map<String, dynamic>.from(r))
        : null;
    final d = recibido ?? respaldo;
    final i = _lista.indexWhere((x) => x.id == d.id);
    _lista = [
      for (var k = 0; k < _lista.length; k++)
        if (k == i) d else _lista[k],
      if (i < 0) d,
    ];
    // Un borrador nuevo reemplaza a la propuesta vieja del mismo ingreso: el
    // servidor anula la otra.
    if (d.estado != EstadoDispersion.anulada) {
      _lista = [
        for (final x in _lista)
          if (x.id != d.id &&
              x.movimientoId == d.movimientoId &&
              x.estado == EstadoDispersion.propuesta)
            x.conEstado(EstadoDispersion.anulada)
          else
            x,
      ];
    }
  }

  Future<void> cerrar() => _cambios.close();
}

// ------------------------------------------------------------------ filas

/// El reparto que viaja a `fin_guardar_propuesta` y `fin_confirmar_dispersion`
/// (`p_dispersion`). Los renglones que mueven dinero llevan el id estable del
/// movimiento que el servidor va a crear.
Map<String, Object?> cargaDeDispersion(
  Dispersion d, {
  String? cuentaAhorroId,
  Fecha? fecha,
}) => {
  'id': d.id,
  'libro_id': d.libroId,
  'movimiento_id': d.movimientoId,
  'modo': nombreEnum(d.modo),
  'motivo': d.motivo,
  'cuenta_ahorro_id': cuentaAhorroId,
  'fecha': fecha == null ? null : fechaIso(fecha),
  'lineas': [
    for (final l in d.lineas)
      {
        'destino': nombreEnum(l.destino),
        'referencia_id': l.referenciaId,
        'etiqueta': l.etiqueta,
        'monto_centavos': l.monto,
        if (l.destino.mueveDinero && l.monto > 0)
          'movimiento_id': idEstable(
            ClavesId.dispersionMovimiento(d.id, claveDeLineaDispersion(l)),
          ),
      },
  ],
};

/// Un reparto de las tablas (la fila y sus renglones, ya ordenados).
Dispersion dispersionDeFila(
  Map<String, dynamic> f,
  List<Map<String, dynamic>> renglones,
) => Dispersion(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  movimientoId: '${f['movimiento_id']}',
  estado: enumDe(EstadoDispersion.values, f['estado']),
  modo: enumDe(ModoDispersion.values, f['modo'] ?? 'confirmacion'),
  lineas: [for (final r in renglones) _lineaDeFila(r)],
  creadaEn: horaDe(f['creada_en']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  resueltaPor: texto(f['resuelta_por']),
  resueltaEn: horaDe(f['resuelta_en']),
  enNombreDe: texto(f['en_nombre_de']),
  motivo: texto(f['motivo']),
);

/// El reparto que devuelven las RPC (la misma forma con `lineas` adentro).
Dispersion dispersionDeJson(Map<String, dynamic> j) => dispersionDeFila(j, [
  for (final l in (j['lineas'] as List? ?? const []))
    Map<String, dynamic>.from(l as Map),
]);

LineaDispersion _lineaDeFila(Map<String, dynamic> r) => LineaDispersion(
  destino: enumDe(DestinoLinea.values, r['destino']),
  referenciaId: texto(r['referencia_id']),
  etiqueta: '${r['etiqueta']}',
  monto: entero(r['monto_centavos']),
);

/// Los parámetros de una fila de `fin_parametros`; nulo si la función aún no
/// se activó en ese libro (`dispersion_desde` nulo): la app usa los de omisión.
ParametrosDispersion? parametrosDispersionDeFila(Map<String, dynamic> f) {
  final desde = fechaDe(f['dispersion_desde']);
  if (desde == null) return null;
  return ParametrosDispersion(
    modo: enumDe(ModoDispersion.values, f['dispersion_modo'] ?? 'confirmacion'),
    desde: desde,
    parteLibrePuntosBase: entero(f['dispersion_parte_libre_pb']),
    topeAhorro: enteroONulo(f['dispersion_tope_ahorro']),
  );
}

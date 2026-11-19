/// Dónde se guardan los repartos de ingresos (`fin_dispersiones` y
/// `fin_dispersion_lineas`; `docs/specs/fase-8-finanzas-dispersion.md`,
/// sección 8).
///
/// **Interfaz sin servidor.** Hoy solo existe la versión en memoria
/// ([RepositorioDispersionesEnMemoria]): sirve a las pruebas y al modo
/// demostración, y las pantallas ya trabajan contra esta interfaz. Cuando el
/// backend construya las tablas y las funciones (`fin_confirmar_dispersion`,
/// `fin_guardar_propuesta`), se agrega una implementación de Supabase y se
/// cambia el proveedor; nada de las pantallas cambia. Confirmar necesita
/// señal (el servidor liga los movimientos al guardar).
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';

abstract interface class RepositorioDispersiones {
  /// Los repartos vigentes y anulados, en el orden en que se guardaron.
  List<Dispersion> get actuales;

  /// Avisa cada vez que cambian [actuales].
  Stream<List<Dispersion>> get cambios;

  /// Guarda (o reemplaza por id) un reparto.
  Future<void> guardar(Dispersion dispersion);

  /// Parámetros del libro (nulos si no hay fila; la app usa los de omisión).
  ParametrosDispersion? parametrosDe(String libroId);

  Future<void> guardarParametros(String libroId, ParametrosDispersion p);
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
  ParametrosDispersion? parametrosDe(String libroId) => _parametros[libroId];

  @override
  Future<void> guardarParametros(String libroId, ParametrosDispersion p) async {
    _parametros[libroId] = p;
    _cambios.add(actuales);
  }

  Future<void> cerrar() => _cambios.close();
}

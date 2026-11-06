library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'modelos.dart';

abstract interface class RepositorioHabitos {
  Future<List<ObjetivoHab>> objetivos();
  Future<void> guardarObjetivo(ObjetivoHab o);
  Future<List<RegistroHab>> registros(DateTime desde, DateTime hasta);
  Future<void> guardarRegistro(RegistroHab r);
}

/// Repositorio en memoria (pruebas, demostración y sin sesión).
class RepositorioHabitosEnMemoria implements RepositorioHabitos {
  final Map<String, ObjetivoHab> _objetivos = {};
  final Map<String, RegistroHab> _registros = {};

  @override
  Future<List<ObjetivoHab>> objetivos() async => _objetivos.values.toList();

  @override
  Future<void> guardarObjetivo(ObjetivoHab o) async {
    final v = _objetivos[o.id];
    if (v != null && v.modificadoEn.isAfter(o.modificadoEn))
      return; // último gana
    _objetivos[o.id] = o;
  }

  @override
  Future<List<RegistroHab>> registros(DateTime desde, DateTime hasta) async => [
    for (final r in _registros.values)
      if (!r.fecha.isBefore(soloDia(desde)) && !r.fecha.isAfter(soloDia(hasta)))
        r,
  ];

  @override
  Future<void> guardarRegistro(RegistroHab r) async {
    final v = _registros[r.id];
    if (v != null && v.modificadoEn.isAfter(r.modificadoEn)) return;
    _registros[r.id] = r;
  }
}

/// Repositorio con Supabase (RLS: cada persona lee lo suyo). `persona_id` y
/// `hogar_id` los pone el servidor; el último cambio gana por `modificado_en`.
class RepositorioHabitosSupabase implements RepositorioHabitos {
  RepositorioHabitosSupabase(this._cliente);
  final SupabaseClient Function() _cliente;

  @override
  Future<List<ObjetivoHab>> objetivos() async => [
    for (final f in await _cliente().from('hab_objetivos').select())
      ObjetivoHab.deFila(f),
  ];

  @override
  Future<void> guardarObjetivo(ObjetivoHab o) async =>
      _cliente().from('hab_objetivos').upsert(o.aFila());

  @override
  Future<List<RegistroHab>> registros(DateTime desde, DateTime hasta) async => [
    for (final f
        in await _cliente()
            .from('hab_registros')
            .select()
            .gte('fecha', desde.toIso8601String().substring(0, 10))
            .lte('fecha', hasta.toIso8601String().substring(0, 10)))
      RegistroHab.deFila(f),
  ];

  @override
  Future<void> guardarRegistro(RegistroHab r) async =>
      _cliente().from('hab_registros').upsert(r.aFila());
}

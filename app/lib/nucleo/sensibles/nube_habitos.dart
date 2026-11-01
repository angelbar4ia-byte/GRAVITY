/// La parte de Hábitos que vive en Supabase y no son filas del libro: borrar
/// mis datos (`hab_borrar_mis_datos`). Los sobres suben por la cola
/// (`subida_diferida.dart`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'mis_datos.dart';

class NubeDeHabitosSupabase implements NubeDeHabitos {
  NubeDeHabitosSupabase(this._cliente);

  final SupabaseClient Function() _cliente;

  @override
  Future<void> borrarMisDatos(AlcanceDeBorrado alcance) =>
      _cliente().rpc('hab_borrar_mis_datos', params: {'p_alcance': alcance.valor});
}

/// En memoria (pruebas y demostración).
class NubeDeHabitosEnMemoria implements NubeDeHabitos {
  final List<AlcanceDeBorrado> borrados = [];
  Object? falla;

  @override
  Future<void> borrarMisDatos(AlcanceDeBorrado alcance) async {
    if (falla != null) throw falla!;
    borrados.add(alcance);
  }
}

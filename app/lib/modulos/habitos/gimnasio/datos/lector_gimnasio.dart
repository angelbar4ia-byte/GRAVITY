/// Lector de «Mi gimnasio»: baja del servidor las seis tablas `hab_ent_*` de la
/// persona (RLS: solo lo suyo) para fusionarlas con lo local.
///
/// Sigue el patrón de los repositorios de Hábitos (`RepositorioHabitosSupabase`:
/// un cliente que se pide al usar, sin estado). **Solo lee**: lo que la persona
/// hace se guarda primero en el equipo y sube por la cola
/// (`RepositorioGimnasio`); este lector nunca escribe.
///
/// Sin conexión (o con cualquier fallo) devuelve `null` y la app sigue con lo
/// local: nunca bloquea ni reintenta sola.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lo que trajo el servidor, con los nombres de columna de `hab_ent_*`, listo
/// para `RepositorioGimnasio.fusionarDelServidor`.
class FilasGimnasioServidor {
  const FilasGimnasioServidor({
    this.perfil = const [],
    this.planDias = const [],
    this.inventario = const [],
    this.bandas = const [],
    this.sesiones = const [],
    this.series = const [],
  });

  final List<Map<String, Object?>> perfil;
  final List<Map<String, Object?>> planDias;
  final List<Map<String, Object?>> inventario;
  final List<Map<String, Object?>> bandas;
  final List<Map<String, Object?>> sesiones;
  final List<Map<String, Object?>> series;

  int get total =>
      perfil.length +
      planDias.length +
      inventario.length +
      bandas.length +
      sesiones.length +
      series.length;
}

abstract interface class LectorGimnasio {
  /// Lee las seis tablas de la persona. `null` si no se pudo (sin red, sin
  /// sesión, error del servidor).
  Future<FilasGimnasioServidor?> leer();
}

/// Lee una tabla completa, de 1 000 en 1 000 filas, hasta un tope de seguridad.
typedef LeerTabla =
    Future<List<Map<String, Object?>>> Function(String tabla, int desde, int a);

/// El lector sobre cualquier fuente que sepa leer un tramo de una tabla (el
/// cliente de Supabase en la app; una función en las pruebas).
class LectorGimnasioDeTablas implements LectorGimnasio {
  LectorGimnasioDeTablas(this._leerTramo, {this.tramo = 1000, this.tope = 20000});

  final LeerTabla _leerTramo;
  final int tramo;

  /// Filas máximas por tabla (la cuota del servidor para series es de 60 000;
  /// el historial de la pantalla no necesita más).
  final int tope;

  Future<List<Map<String, Object?>>> _tabla(String nombre) async {
    final r = <Map<String, Object?>>[];
    for (var d = 0; d < tope; d += tramo) {
      final parte = await _leerTramo(nombre, d, d + tramo - 1);
      r.addAll(parte);
      if (parte.length < tramo) break;
    }
    return r;
  }

  @override
  Future<FilasGimnasioServidor?> leer() async {
    try {
      return FilasGimnasioServidor(
        perfil: await _tabla('hab_ent_perfil'),
        planDias: await _tabla('hab_ent_plan_dias'),
        inventario: await _tabla('hab_ent_inventario'),
        bandas: await _tabla('hab_ent_bandas'),
        sesiones: await _tabla('hab_ent_sesiones'),
        series: await _tabla('hab_ent_series'),
      );
    } catch (error) {
      // Sin red o sin permiso: se sigue con lo local. No se anota el contenido.
      debugPrint('Mi gimnasio: no se pudo bajar del servidor (${error.runtimeType}).');
      return null;
    }
  }
}

/// El lector de la app: el cliente activo de Supabase.
class LectorGimnasioSupabase extends LectorGimnasioDeTablas {
  LectorGimnasioSupabase(SupabaseClient Function() cliente)
    : super(
        (tabla, desde, a) async => [
          for (final f
              in await cliente()
                  .from(tabla)
                  .select()
                  .order('modificado_en', ascending: true)
                  .range(desde, a))
            (f as Map).cast<String, Object?>(),
        ],
      );
}

/// Sin servidor (demostración y pruebas): no hay nada que bajar.
class LectorGimnasioNulo implements LectorGimnasio {
  const LectorGimnasioNulo();

  @override
  Future<FilasGimnasioServidor?> leer() async => null;
}

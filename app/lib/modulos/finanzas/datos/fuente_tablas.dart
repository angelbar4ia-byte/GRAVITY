/// Acceso a las tablas del servidor, separado del repositorio para poder
/// probarlo sin Supabase ([FuenteTablasEnMemoria]).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../nucleo/sesion/errores_red.dart';
import 'repositorio.dart';

abstract interface class FuenteTablas {
  /// Todas las filas visibles de [tabla] (la RLS filtra).
  Future<List<Map<String, dynamic>>> leer(
    String tabla, {
    String columnas = '*',
  });

  /// Inserta o actualiza [filas] (upsert por [conflicto]). Con
  /// [ignorarDuplicados], lo que ya existe no se toca (solo agregar).
  Future<void> guardar(
    String tabla,
    List<Map<String, Object?>> filas, {
    String conflicto = 'id',
    bool ignorarDuplicados = false,
  });

  /// Cambia [cambios] en las filas que coinciden con [donde] (igualdad; un
  /// valor nulo es `is null`).
  Future<void> actualizar(
    String tabla,
    Map<String, Object?> cambios, {
    required Map<String, Object?> donde,
  });

  /// Borra las filas que coinciden con [donde].
  Future<void> borrar(String tabla, {required Map<String, Object?> donde});

  /// Llama una función del servidor.
  Future<Object?> rpc(String funcion, Map<String, Object?> parametros);
}

/// Fuente con Supabase. Usa el cliente de la persona activa en cada llamada
/// (en la tablet, el de quien entró con su PIN: `clienteActivo`).
class FuenteTablasSupabase implements FuenteTablas {
  FuenteTablasSupabase(this._cliente);

  final SupabaseClient Function() _cliente;

  /// PostgREST devuelve como máximo 1000 filas por consulta.
  static const _pagina = 1000;

  Future<T> _seguro<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on PostgrestException catch (e) {
      throw ErrorFinanzas(
        _mensaje(e),
        // `fin_emitir_aviso`: 22023 "se llegó al tope de 60 avisos al día".
        topeAlcanzado: e.code == '22023' && e.message.contains('tope'),
      );
    } catch (e) {
      if (esErrorDeRed(e)) throw ErrorFinanzas.conexion;
      rethrow;
    }
  }

  static String _mensaje(PostgrestException e) => switch (e.code) {
    '42501' => 'No tienes permiso para hacer eso en este libro.',
    '23503' =>
      'Falta un dato del que depende (quizá aún no sube): '
          '${e.message}',
    '23505' => 'Ya existe: ${e.message}',
    '55000' => e.message,
    _ => e.message,
  };

  @override
  Future<List<Map<String, dynamic>>> leer(
    String tabla, {
    String columnas = '*',
  }) => _seguro(() async {
    final todas = <Map<String, dynamic>>[];
    for (var desde = 0; ; desde += _pagina) {
      final filas = await _cliente()
          .from(tabla)
          .select(columnas)
          .range(desde, desde + _pagina - 1);
      todas.addAll(filas);
      if (filas.length < _pagina) break;
    }
    return todas;
  });

  @override
  Future<void> guardar(
    String tabla,
    List<Map<String, Object?>> filas, {
    String conflicto = 'id',
    bool ignorarDuplicados = false,
  }) => _seguro(() async {
    if (filas.isEmpty) return;
    await _cliente()
        .from(tabla)
        .upsert(
          filas,
          onConflict: conflicto,
          ignoreDuplicates: ignorarDuplicados,
        );
  });

  @override
  Future<void> actualizar(
    String tabla,
    Map<String, Object?> cambios, {
    required Map<String, Object?> donde,
  }) => _seguro(() async {
    var consulta = _cliente().from(tabla).update(cambios);
    for (final e in donde.entries) {
      consulta = e.value == null
          ? consulta.isFilter(e.key, null)
          : consulta.eq(e.key, e.value!);
    }
    await consulta;
  });

  @override
  Future<void> borrar(String tabla, {required Map<String, Object?> donde}) =>
      _seguro(() async {
        var consulta = _cliente().from(tabla).delete();
        for (final e in donde.entries) {
          consulta = e.value == null
              ? consulta.isFilter(e.key, null)
              : consulta.eq(e.key, e.value!);
        }
        await consulta;
      });

  @override
  Future<Object?> rpc(String funcion, Map<String, Object?> parametros) =>
      _seguro(() => _cliente().rpc(funcion, params: parametros));
}

/// Fuente en memoria para las pruebas del repositorio de Supabase: guarda
/// filas por tabla y simula falta de señal.
class FuenteTablasEnMemoria implements FuenteTablas {
  final Map<String, List<Map<String, Object?>>> tablas = {};

  /// Respuestas de las funciones del servidor.
  final Map<String, Object? Function(Map<String, Object?>)> funciones = {};

  /// Llamadas a funciones (nombre, parámetros).
  final List<(String, Map<String, Object?>)> llamadas = [];

  bool sinSenal = false;

  void _senal() {
    if (sinSenal) throw ErrorFinanzas.conexion;
  }

  List<Map<String, Object?>> tabla(String nombre) =>
      tablas.putIfAbsent(nombre, () => []);

  @override
  Future<List<Map<String, dynamic>>> leer(
    String tabla, {
    String columnas = '*',
  }) async {
    _senal();
    return [for (final f in this.tabla(tabla)) Map<String, dynamic>.of(f)];
  }

  @override
  Future<void> guardar(
    String tabla,
    List<Map<String, Object?>> filas, {
    String conflicto = 'id',
    bool ignorarDuplicados = false,
  }) async {
    _senal();
    final llaves = conflicto.split(',');
    final t = this.tabla(tabla);
    for (final fila in filas) {
      final i = t.indexWhere((x) => llaves.every((k) => x[k] == fila[k]));
      if (i < 0) {
        t.add(Map.of(fila));
      } else if (!ignorarDuplicados) {
        t[i] = {...t[i], ...fila};
      }
    }
  }

  @override
  Future<void> actualizar(
    String tabla,
    Map<String, Object?> cambios, {
    required Map<String, Object?> donde,
  }) async {
    _senal();
    final t = this.tabla(tabla);
    for (var i = 0; i < t.length; i++) {
      if (donde.entries.every((e) => t[i][e.key] == e.value)) {
        t[i] = {...t[i], ...cambios};
      }
    }
  }

  @override
  Future<void> borrar(
    String tabla, {
    required Map<String, Object?> donde,
  }) async {
    _senal();
    this
        .tabla(tabla)
        .removeWhere((f) => donde.entries.every((e) => f[e.key] == e.value));
  }

  @override
  Future<Object?> rpc(String funcion, Map<String, Object?> parametros) async {
    _senal();
    llamadas.add((funcion, parametros));
    return funciones[funcion]?.call(parametros);
  }
}

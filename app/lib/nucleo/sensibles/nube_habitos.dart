/// La parte de Hábitos que vive en Supabase y no son filas del libro: borrar
/// mis datos (`hab_borrar_mis_datos`). Los sobres suben por la cola
/// (`subida_diferida.dart`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../sesion/errores_red.dart';
import 'llaves_habitos.dart';
import 'mis_datos.dart';
import 'nube_cifrada.dart';
import 'sobres.dart';

class NubeDeHabitosSupabase implements NubeDeHabitos {
  NubeDeHabitosSupabase(this._cliente);

  final SupabaseClient Function() _cliente;

  @override
  Future<void> borrarMisDatos(AlcanceDeBorrado alcance) => _cliente().rpc(
    'hab_borrar_mis_datos',
    params: {'p_alcance': alcance.valor},
  );
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

/// Administración de la nube cifrada con las funciones y tablas de Hábitos
/// (`supabase/migrations/20261106000000_habitos_sensibles.sql`).
class AdministracionNubeHabitosSupabase implements AdministracionNubeHabitos {
  AdministracionNubeHabitosSupabase(this._cliente);

  final SupabaseClient Function() _cliente;

  Future<T> _seguro<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '55000' => const ErrorNubeCifrada(
          'Antes de activar la nube hay que guardar la llave con tu frase.',
        ),
        '42501' => const ErrorNubeCifrada(
          'Tu cuenta no puede usar la nube cifrada de Hábitos.',
        ),
        '22023' => ErrorNubeCifrada(error.message),
        _ => ErrorNubeCifrada('No se pudo: ${error.message}'),
      };
    } catch (error) {
      if (esErrorDeRed(error)) throw ErrorNubeCifrada.sinConexion;
      rethrow;
    }
  }

  @override
  Future<EstadoNubeServidor> leerEstado() => _seguro(() async {
    final cliente = _cliente();
    final filasModos = await cliente.from('hab_modos').select('tipo, modo');
    final llave = await cliente.from('hab_llaves').select().maybeSingle();
    final ajustes = await cliente
        .from('hab_ajustes')
        .select('epoca_nube')
        .maybeSingle();
    final modos = <TipoSensible, ModoSensible>{};
    for (final fila in filasModos) {
      final tipo = TipoSensible.values
          .where((t) => t.valor == fila['tipo'])
          .firstOrNull;
      final modo = ModoSensible.values
          .where((m) => m.valor == fila['modo'])
          .firstOrNull;
      if (tipo != null && modo != null) modos[tipo] = modo;
    }
    return EstadoNubeServidor(
      modos: modos,
      llave: llave == null
          ? null
          : LlaveEnvuelta.desdeJson(llave.cast<String, Object?>()),
      epoca: (ajustes?['epoca_nube'] as int?) ?? 0,
    );
  });

  @override
  Future<void> guardarLlave(LlaveEnvuelta llave) => _seguro(
    () => _cliente().rpc(
      'hab_guardar_llave',
      params: {
        'p_version': llave.version,
        'p_kdf': llave.kdf,
        'p_kdf_params': {'vueltas': llave.vueltas},
        'p_sal': llave.sal,
        'p_llave_envuelta': llave.llaveEnvuelta,
      },
    ),
  );

  @override
  Future<void> cambiarModo(
    TipoSensible tipo,
    ModoSensible modo, {
    bool confirmarBorrado = false,
  }) => _seguro(
    () => _cliente().rpc(
      'hab_cambiar_modo',
      params: {
        'p_tipo': tipo.valor,
        'p_modo': modo.valor,
        'p_confirmar_borrado': confirmarBorrado,
      },
    ),
  );

  @override
  Future<void> reiniciarNube([TipoSensible? tipo]) => _seguro(
    () => _cliente().rpc(
      'hab_reiniciar_nube',
      params: {'p_tipo': tipo?.valor ?? 'todos'},
    ),
  );

  @override
  Future<List<Sobre>> sobresDeLaNube(TipoSensible tipo) => _seguro(() async {
    final filas = await _cliente()
        .from('hab_sobres')
        .select('id, tipo, revision, cifrado, llave_version, eliminado')
        .eq('tipo', tipo.valor);
    return [
      for (final fila in filas)
        if (Sobre.desdeJson(fila.cast<String, Object?>()) case final sobre?)
          sobre,
    ];
  });
}

/// En memoria (pruebas y demostración): se comporta como las funciones del
/// servidor que importan a la pantalla.
class AdministracionNubeHabitosEnMemoria implements AdministracionNubeHabitos {
  AdministracionNubeHabitosEnMemoria();

  final Map<TipoSensible, ModoSensible> modos = {
    for (final t in TipoSensible.values) t: ModoSensible.soloTelefono,
  };
  LlaveEnvuelta? llave;
  int epoca = 0;
  final Map<TipoSensible, List<Sobre>> sobresPorTipo = {
    for (final t in TipoSensible.values) t: [],
  };

  /// Simula que no hay señal.
  bool sinConexion = false;
  int llamadas = 0;

  void _revisar() {
    llamadas++;
    if (sinConexion) throw ErrorNubeCifrada.sinConexion;
  }

  @override
  Future<EstadoNubeServidor> leerEstado() async {
    _revisar();
    return EstadoNubeServidor(modos: Map.of(modos), llave: llave, epoca: epoca);
  }

  @override
  Future<void> guardarLlave(LlaveEnvuelta nueva) async {
    _revisar();
    final actual = llave;
    if (actual == null) {
      if (nueva.version != 1) {
        throw const ErrorNubeCifrada('La primera envoltura es la versión 1.');
      }
    } else if (nueva.version == actual.version &&
        nueva.llaveEnvuelta == actual.llaveEnvuelta) {
      return;
    } else if (nueva.version != actual.version + 1) {
      throw const ErrorNubeCifrada('La versión de la envoltura sube de 1 en 1.');
    }
    llave = nueva;
  }

  @override
  Future<void> cambiarModo(
    TipoSensible tipo,
    ModoSensible modo, {
    bool confirmarBorrado = false,
  }) async {
    _revisar();
    if (modos[tipo] == modo) return;
    if (modo == ModoSensible.nubeCifrada) {
      if (llave == null) {
        throw const ErrorNubeCifrada(
          'Antes de activar la nube hay que guardar la llave con tu frase.',
        );
      }
    } else {
      if (!confirmarBorrado) {
        throw const ErrorNubeCifrada(
          'Volver a solo teléfono borra lo de la nube: pide confirmación.',
        );
      }
      sobresPorTipo[tipo]!.clear();
      epoca++;
    }
    modos[tipo] = modo;
  }

  @override
  Future<void> reiniciarNube([TipoSensible? tipo]) async {
    _revisar();
    for (final t in tipo == null ? TipoSensible.values : [tipo]) {
      sobresPorTipo[t]!.clear();
      modos[t] = ModoSensible.soloTelefono;
    }
    if (!modos.values.any((m) => m == ModoSensible.nubeCifrada)) llave = null;
    epoca++;
  }

  @override
  Future<List<Sobre>> sobresDeLaNube(TipoSensible tipo) async {
    _revisar();
    return List.of(sobresPorTipo[tipo]!);
  }
}

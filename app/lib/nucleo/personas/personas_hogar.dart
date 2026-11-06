/// Las personas del hogar con el esquema del servidor (E3 de la Fase 4): ver
/// quién está, **dar de baja** y **cambiar de rol**. Solo el dueño (política
/// `membresias_editar` de `supabase/migrations/20261020000000_base.sql`).
///
/// En el servidor una baja no borra nada: `membresias.activa = false` y
/// `hasta = ahora`; el acceso se pierde de inmediato (D5). Nadie se da de baja
/// ni se cambia el rol a sí mismo, y el rol `dueno` no se asigna.
///
/// Tras una baja o un cambio de rol, Finanzas puede haber cambiado de manos
/// (el administrador de un libro compartido, el albacea): quien llama usa
/// `refrescarFinanzas` (ver la pantalla de Personas).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../contratos/roles.dart';
import '../sesion/errores_red.dart';
import '../sesion/sesion.dart' show nombreParaMostrar;

/// Una persona del hogar con su membresía vigente.
@immutable
class MiembroDelHogar {
  const MiembroDelHogar({
    required this.membresiaId,
    required this.personaId,
    required this.nombre,
    required this.rol,
    this.esMaestra = false,
  });

  final String membresiaId;
  final String personaId;
  final String nombre;
  final Rol rol;

  /// Cuenta maestra (D19): solo lee; su rol es coadministrador y no cambia.
  final bool esMaestra;

  MiembroDelHogar copiarCon({Rol? rol}) => MiembroDelHogar(
    membresiaId: membresiaId,
    personaId: personaId,
    nombre: nombre,
    rol: rol ?? this.rol,
    esMaestra: esMaestra,
  );
}

/// Error con un mensaje listo para mostrar.
class ErrorPersonas implements Exception {
  const ErrorPersonas(this.mensaje);

  final String mensaje;

  static const sinConexion = ErrorPersonas(
    'Sin conexión. Intenta de nuevo cuando haya señal.',
  );
  static const sinPermiso = ErrorPersonas(
    'Solo el dueño del hogar puede cambiar a las personas.',
  );

  @override
  String toString() => 'ErrorPersonas: $mensaje';
}

/// Roles que el dueño puede asignar (el dueño no se asigna).
const rolesAsignables = [
  Rol.coadministrador,
  Rol.familiar,
  Rol.cuidador,
  Rol.casa,
];

abstract interface class RepositorioPersonasHogar {
  /// Personas con membresía vigente en [hogarId].
  Future<List<MiembroDelHogar>> miembros(String hogarId);

  /// Quita el acceso de [membresiaId] de inmediato.
  Future<void> darDeBaja(String membresiaId);

  /// Cambia el rol de [membresiaId] a [nuevo] (nunca `dueno`).
  Future<void> cambiarRol(String membresiaId, Rol nuevo);
}

class RepositorioPersonasHogarSupabase implements RepositorioPersonasHogar {
  RepositorioPersonasHogarSupabase(
    this._cliente, {
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final SupabaseClient Function() _cliente;
  final DateTime Function() _reloj;

  Future<T> _seguro<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '42501' => ErrorPersonas.sinPermiso,
        '22023' || '23514' || '23505' || '23503' || 'P0001' => ErrorPersonas(
          error.message,
        ),
        _ => ErrorPersonas('No se pudo: ${error.message}'),
      };
    } catch (error) {
      if (esErrorDeRed(error)) throw ErrorPersonas.sinConexion;
      rethrow;
    }
  }

  @override
  Future<List<MiembroDelHogar>> miembros(String hogarId) => _seguro(() async {
    Future<List<Map<String, dynamic>>> leer(String columnas) => _cliente()
        .from('membresias')
        .select(columnas)
        .eq('hogar_id', hogarId)
        .eq('activa', true)
        .order('desde')
        .order('id');
    List<Map<String, dynamic>> filas;
    try {
      filas = await leer(
        'id, persona_id, rol, desde, hasta, es_maestra, '
        'personas(nombre_visible)',
      );
    } on PostgrestException catch (error) {
      // Servidor sin la columna de la cuenta maestra todavía.
      if (error.code != '42703' && error.code != 'PGRST204') rethrow;
      filas = await leer(
        'id, persona_id, rol, desde, hasta, personas(nombre_visible)',
      );
    }
    final ahora = _reloj();
    final lista = <MiembroDelHogar>[];
    for (final fila in filas) {
      final rol = Rol.values.where((r) => r.name == fila['rol']).firstOrNull;
      if (rol == null) continue;
      final hasta = fila['hasta'] == null
          ? null
          : DateTime.tryParse('${fila['hasta']}');
      final desde = DateTime.tryParse('${fila['desde']}');
      // Vigente: ya empezó y no ha terminado (igual que al entrar).
      if (desde != null && desde.isAfter(ahora)) continue;
      if (hasta != null && !hasta.isAfter(ahora)) continue;
      final persona = fila['personas'];
      final nombre = persona is Map ? persona['nombre_visible'] : null;
      lista.add(
        MiembroDelHogar(
          membresiaId: '${fila['id']}',
          personaId: '${fila['persona_id']}',
          nombre: nombreParaMostrar(rol, '${nombre ?? 'Sin nombre'}'),
          rol: rol,
          esMaestra: fila['es_maestra'] == true,
        ),
      );
    }
    return lista;
  });

  @override
  Future<void> darDeBaja(String membresiaId) => _seguro(() async {
    final filas = await _cliente()
        .from('membresias')
        .update({
          'activa': false,
          'hasta': _reloj().toUtc().toIso8601String(),
        })
        .eq('id', membresiaId)
        .select('id');
    // Las reglas de fila no avisan cuando no dejan cambiar nada: 0 filas.
    if (filas.isEmpty) throw ErrorPersonas.sinPermiso;
  });

  @override
  Future<void> cambiarRol(String membresiaId, Rol nuevo) => _seguro(() async {
    if (nuevo == Rol.dueno) {
      throw const ErrorPersonas('El rol de dueño no se asigna.');
    }
    final filas = await _cliente()
        .from('membresias')
        .update({'rol': nuevo.name})
        .eq('id', membresiaId)
        .select('id');
    if (filas.isEmpty) throw ErrorPersonas.sinPermiso;
  });
}

/// En memoria: modo demostración y pruebas. Aplica las reglas del servidor
/// que la pantalla debe respetar.
class RepositorioPersonasHogarEnMemoria implements RepositorioPersonasHogar {
  RepositorioPersonasHogarEnMemoria({
    List<MiembroDelHogar> inicial = const [],
    this.personaQueAdministra,
  }) : _miembros = [...inicial];

  final List<MiembroDelHogar> _miembros;

  /// Persona que usa la pantalla: no puede cambiarse a sí misma.
  final String? personaQueAdministra;

  final List<String> bajas = [];
  final List<(String, Rol)> cambios = [];
  bool sinConexion = false;

  @override
  Future<List<MiembroDelHogar>> miembros(String hogarId) async {
    if (sinConexion) throw ErrorPersonas.sinConexion;
    return List.unmodifiable(_miembros);
  }

  MiembroDelHogar _buscar(String membresiaId) {
    final m = _miembros.where((x) => x.membresiaId == membresiaId).firstOrNull;
    if (m == null) throw ErrorPersonas.sinPermiso;
    if (m.personaId == personaQueAdministra || m.rol == Rol.dueno) {
      throw const ErrorPersonas('No puedes cambiar a esta persona.');
    }
    return m;
  }

  @override
  Future<void> darDeBaja(String membresiaId) async {
    if (sinConexion) throw ErrorPersonas.sinConexion;
    final m = _buscar(membresiaId);
    _miembros.remove(m);
    bajas.add(membresiaId);
  }

  @override
  Future<void> cambiarRol(String membresiaId, Rol nuevo) async {
    if (sinConexion) throw ErrorPersonas.sinConexion;
    if (nuevo == Rol.dueno) {
      throw const ErrorPersonas('El rol de dueño no se asigna.');
    }
    final m = _buscar(membresiaId);
    if (m.esMaestra && nuevo != Rol.coadministrador) {
      throw const ErrorPersonas(
        'La cuenta maestra es coadministradora. Cambia primero la cuenta '
        'maestra.',
      );
    }
    _miembros[_miembros.indexOf(m)] = m.copiarCon(rol: nuevo);
    cambios.add((membresiaId, nuevo));
  }
}

/// Se fija en el arranque (Supabase) o en la prueba; sin servidor, vacío.
final repositorioPersonasHogarProvider = Provider<RepositorioPersonasHogar>(
  (ref) => RepositorioPersonasHogarEnMemoria(),
);

/// Invitaciones del hogar (solo el dueño las crea y las ve). Hoy, la de la
/// **cuenta maestra** (D19, 23/oct/2026): otra persona con su propio login,
/// de solo lectura total.
///
/// Firma acordada con backend (migración
/// `20261024000000_finanzas_respuestas_dueno.sql`):
///
/// ```
/// crear_invitacion(p_hogar_id, p_correo, p_rol, p_vigencia_dias default 7,
///                  p_es_maestra default false) -> (invitacion_id, token, expira)
/// revocar_invitacion(p_invitacion_id)
/// cuenta_maestra(p_hogar_id) -> (persona_id, nombre_visible)
/// ```
///
/// El token sale **una sola vez** (en el servidor solo queda su hash) y el
/// servidor no manda correo: la app lo muestra al dueño para que lo entregue.
/// Si cambia algo del servidor, se cambia aquí y en nada más.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sesion/errores_red.dart';

/// Lo que devuelve el servidor al crear una invitación.
@immutable
class InvitacionCreada {
  const InvitacionCreada({
    required this.id,
    required this.token,
    required this.expira,
  });

  final String id;

  /// Código que entrega el dueño. No se vuelve a poder ver.
  final String token;
  final DateTime expira;
}

/// Una invitación que aún espera ser aceptada.
@immutable
class InvitacionPendiente {
  const InvitacionPendiente({
    required this.id,
    required this.correo,
    required this.rol,
    required this.esMaestra,
    required this.expira,
  });

  final String id;
  final String correo;
  final String rol;
  final bool esMaestra;
  final DateTime expira;
}

/// La cuenta maestra de hoy.
@immutable
class CuentaMaestraActual {
  const CuentaMaestraActual({required this.personaId, required this.nombre});

  final String personaId;
  final String nombre;
}

/// Error con un mensaje listo para mostrar.
class ErrorInvitacion implements Exception {
  const ErrorInvitacion(this.mensaje);

  final String mensaje;

  static const sinConexion = ErrorInvitacion(
    'Sin conexión. Intenta de nuevo cuando haya señal.',
  );
  static const sinPermiso = ErrorInvitacion(
    'Solo el dueño del hogar puede invitar.',
  );

  @override
  String toString() => 'ErrorInvitacion: $mensaje';
}

abstract interface class RepositorioInvitaciones {
  /// Invita a [correo] como cuenta maestra: rol coadministrador con la marca
  /// de maestra. La persona es **otra** (no puede ser ya del hogar).
  Future<InvitacionCreada> crearCuentaMaestra({
    required String hogarId,
    required String correo,
    int vigenciaDias = 7,
  });

  /// Invitaciones que siguen vigentes (sin aceptar ni revocar, sin vencer).
  Future<List<InvitacionPendiente>> pendientes(String hogarId);

  Future<void> revocar(String invitacionId);

  /// Quién es la cuenta maestra hoy, o `null` si no hay.
  Future<CuentaMaestraActual?> maestraActual(String hogarId);
}

/// Con servidor (Supabase): el cliente de la sesión que está dentro.
class RepositorioInvitacionesSupabase implements RepositorioInvitaciones {
  RepositorioInvitacionesSupabase(this._cliente, {DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now;

  final SupabaseClient Function() _cliente;
  final DateTime Function() _reloj;

  Future<T> _seguro<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '42501' => ErrorInvitacion.sinPermiso,
        '22023' => ErrorInvitacion(error.message),
        _ => ErrorInvitacion('No se pudo: ${error.message}'),
      };
    } catch (error) {
      if (esErrorDeRed(error)) throw ErrorInvitacion.sinConexion;
      rethrow;
    }
  }

  static Map<String, dynamic> _primera(Object? respuesta) {
    // Una función que devuelve una tabla responde con una lista de filas.
    final fila = respuesta is List ? respuesta.firstOrNull : respuesta;
    if (fila is! Map) {
      throw const ErrorInvitacion('El servidor no devolvió la invitación.');
    }
    return fila.cast<String, dynamic>();
  }

  @override
  Future<InvitacionCreada> crearCuentaMaestra({
    required String hogarId,
    required String correo,
    int vigenciaDias = 7,
  }) => _seguro(() async {
    final fila = _primera(
      await _cliente().rpc(
        'crear_invitacion',
        params: {
          'p_hogar_id': hogarId,
          'p_correo': correo.trim(),
          'p_rol': 'coadministrador',
          'p_vigencia_dias': vigenciaDias,
          'p_es_maestra': true,
        },
      ),
    );
    return InvitacionCreada(
      id: '${fila['invitacion_id']}',
      token: '${fila['token']}',
      expira: DateTime.parse('${fila['expira']}'),
    );
  });

  @override
  Future<List<InvitacionPendiente>> pendientes(String hogarId) => _seguro(() async {
    Future<List<Map<String, dynamic>>> leer(String columnas) => _cliente()
        .from('invitaciones')
        .select(columnas)
        .eq('hogar_id', hogarId)
        .isFilter('aceptada_en', null)
        .isFilter('revocada_en', null);
    List<Map<String, dynamic>> filas;
    try {
      filas = await leer('id, correo, rol, es_maestra, expira_en');
    } on PostgrestException catch (error) {
      // Servidor sin la columna de la maestra todavía: ninguna lo es.
      if (error.code != '42703' && error.code != 'PGRST204') rethrow;
      filas = await leer('id, correo, rol, expira_en');
    }
    final ahora = _reloj();
    return [
      for (final f in filas)
        if (DateTime.parse('${f['expira_en']}').isAfter(ahora))
          InvitacionPendiente(
            id: '${f['id']}',
            correo: '${f['correo']}',
            rol: '${f['rol']}',
            esMaestra: f['es_maestra'] == true,
            expira: DateTime.parse('${f['expira_en']}'),
          ),
    ];
  });

  @override
  Future<void> revocar(String invitacionId) => _seguro(
    () => _cliente().rpc(
      'revocar_invitacion',
      params: {'p_invitacion_id': invitacionId},
    ),
  );

  @override
  Future<CuentaMaestraActual?> maestraActual(String hogarId) => _seguro(() async {
    final respuesta = await _cliente().rpc(
      'cuenta_maestra',
      params: {'p_hogar_id': hogarId},
    );
    final fila = respuesta is List ? respuesta.firstOrNull : respuesta;
    if (fila is! Map) return null;
    return CuentaMaestraActual(
      personaId: '${fila['persona_id']}',
      nombre: '${fila['nombre_visible']}',
    );
  });
}

/// En memoria: modo demostración (sin servidor) y pruebas. Aplica las reglas
/// del servidor que la pantalla debe respetar (correo válido, una invitación
/// pendiente por correo).
class RepositorioInvitacionesEnMemoria implements RepositorioInvitaciones {
  RepositorioInvitacionesEnMemoria({
    DateTime Function()? reloj,
    this.correosDeMiembros = const {},
    this.maestra,
  }) : _reloj = reloj ?? DateTime.now;

  final DateTime Function() _reloj;

  /// Correos que ya son del hogar: la maestra es **otra** persona.
  final Set<String> correosDeMiembros;
  CuentaMaestraActual? maestra;

  final List<InvitacionPendiente> _pendientes = [];
  final List<String> revocadas = [];
  int _siguiente = 1;

  /// Simula que no hay señal.
  bool sinConexion = false;

  @override
  Future<InvitacionCreada> crearCuentaMaestra({
    required String hogarId,
    required String correo,
    int vigenciaDias = 7,
  }) async {
    if (sinConexion) throw ErrorInvitacion.sinConexion;
    final limpio = correo.trim().toLowerCase();
    if (correosDeMiembros.contains(limpio)) {
      throw const ErrorInvitacion(
        'Ese correo ya es de una persona del hogar: la cuenta maestra es '
        'otra persona, con su propio login.',
      );
    }
    // Una sola invitación pendiente por correo: la anterior se revoca.
    _pendientes.removeWhere((i) => i.correo == limpio);
    final id = 'invitacion-${_siguiente++}';
    final expira = _reloj().add(Duration(days: vigenciaDias));
    _pendientes.add(
      InvitacionPendiente(
        id: id,
        correo: limpio,
        rol: 'coadministrador',
        esMaestra: true,
        expira: expira,
      ),
    );
    return InvitacionCreada(id: id, token: 'token-de-ejemplo-$id', expira: expira);
  }

  @override
  Future<List<InvitacionPendiente>> pendientes(String hogarId) async {
    if (sinConexion) throw ErrorInvitacion.sinConexion;
    final ahora = _reloj();
    return [
      for (final i in _pendientes)
        if (i.expira.isAfter(ahora)) i,
    ];
  }

  @override
  Future<void> revocar(String invitacionId) async {
    if (sinConexion) throw ErrorInvitacion.sinConexion;
    revocadas.add(invitacionId);
    _pendientes.removeWhere((i) => i.id == invitacionId);
  }

  @override
  Future<CuentaMaestraActual?> maestraActual(String hogarId) async {
    if (sinConexion) throw ErrorInvitacion.sinConexion;
    return maestra;
  }
}

/// Se fija en el arranque (Supabase) o en la prueba; sin servidor, en memoria.
final repositorioInvitacionesProvider = Provider<RepositorioInvitaciones>(
  (ref) => RepositorioInvitacionesEnMemoria(),
);

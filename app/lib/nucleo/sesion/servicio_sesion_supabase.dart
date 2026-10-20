/// Sesión con Supabase (D7): cuentas con correo y contraseña.
///
/// El rol se lee del servidor (membresías del hogar), nunca de la app. La
/// última sesión válida se guarda en el almacenamiento seguro para que el
/// teléfono siga funcionando sin señal (la cola sin conexión la necesita).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../contratos/roles.dart';
import '../seguridad/almacen_seguro.dart';
import 'sesion.dart';

/// Lee la persona y el rol del usuario autenticado en [cliente].
typedef LectorPerfil = Future<Sesion> Function(SupabaseClient cliente);

/// Lector por omisión: función `mi_perfil()` del servidor, que devuelve
/// `persona_id`, `nombre`, `correo`, `rol` y `hogar_id` de quien llama
/// (propuesta para el agente backend; se ajusta al esquema final).
Future<Sesion> leerPerfilPorOmision(SupabaseClient cliente) async {
  final respuesta = await cliente.rpc<dynamic>('mi_perfil');
  final fila = switch (respuesta) {
    final List<dynamic> filas when filas.isNotEmpty => filas.first,
    final Map<dynamic, dynamic> mapa => mapa,
    _ => null,
  };
  if (fila is! Map) throw ErrorSesion.sinRol;
  return sesionDesdeFila(fila.cast<String, Object?>());
}

/// Convierte una fila de `mi_perfil()` en [Sesion].
Sesion sesionDesdeFila(Map<String, Object?> fila) {
  final rolTexto = fila['rol'];
  final rol = Rol.values.where((r) => r.name == rolTexto).firstOrNull;
  final personaId = fila['persona_id'] ?? fila['id'];
  if (rol == null || personaId is! String) throw ErrorSesion.sinRol;
  return Sesion(
    persona: Persona(
      id: personaId,
      nombre: (fila['nombre'] as String?) ?? 'Sin nombre',
      correo: fila['correo'] as String?,
    ),
    rol: rol,
    hogarId: fila['hogar_id'] as String?,
  );
}

/// Traduce errores del servidor a mensajes para la persona.
ErrorSesion traducirErrorSesion(Object error) {
  if (error is ErrorSesion) return error;
  if (error is AuthRetryableFetchException ||
      error is SocketException ||
      error is TimeoutException) {
    return ErrorSesion.sinConexion;
  }
  if (error is AuthException) {
    final codigo = error.statusCode;
    if (codigo == '400' || codigo == '401' || codigo == '422') {
      return ErrorSesion.credencialesIncorrectas;
    }
    return ErrorSesion('No se pudo entrar: ${error.message}');
  }
  return const ErrorSesion('No se pudo entrar. Intenta de nuevo.');
}

class ServicioSesionSupabase extends ServicioSesionEnMemoria {
  ServicioSesionSupabase({
    required this._cliente,
    required this._almacen,
    required this.url,
    required this.llavePublica,
    LectorPerfil? lectorPerfil,
  }) : _lector = lectorPerfil ?? leerPerfilPorOmision;

  static const claveSesionGuardada = 'sesion.ultima';

  final SupabaseClient _cliente;
  final AlmacenSeguro _almacen;
  final LectorPerfil _lector;
  final String url;
  final String llavePublica;
  StreamSubscription<AuthState>? _suscripcion;

  @override
  bool get esDemostracion => false;

  @override
  Future<void> iniciar() async {
    _suscripcion ??= _cliente.auth.onAuthStateChange.listen(
      (estado) {
        if (estado.event == AuthChangeEvent.signedOut) {
          unawaited(_almacen.borrar(claveSesionGuardada));
          if (sesionActual != null) emitir(null);
        }
      },
      onError: (Object error) => debugPrint('Sesión: $error'),
    );
    final usuario = _cliente.auth.currentUser;
    if (usuario == null) return;
    try {
      final sesion = await _lector(_cliente);
      await _guardar(sesion);
      emitir(sesion);
    } catch (error) {
      // Sin señal al abrir: se usa la última sesión válida de este usuario.
      final guardada = await _leerGuardada();
      if (guardada != null && guardada.$1 == usuario.id) {
        emitir(guardada.$2);
      } else {
        debugPrint('No se pudo recuperar la sesión: $error');
      }
    }
  }

  @override
  Future<Sesion> entrar({
    required String correo,
    required String contrasena,
  }) async {
    try {
      await _cliente.auth.signInWithPassword(
        email: correo.trim(),
        password: contrasena,
      );
      final sesion = await _lector(_cliente);
      await _guardar(sesion);
      emitir(sesion);
      return sesion;
    } catch (error) {
      if (error is ErrorSesion && _cliente.auth.currentUser != null) {
        // Entró pero no tiene rol: no se deja la sesión a medias.
        await _cliente.auth.signOut();
      }
      throw traducirErrorSesion(error);
    }
  }

  @override
  Future<Sesion> verificarCredenciales({
    required String correo,
    required String contrasena,
  }) async {
    // Cliente aparte, en memoria y sin renovar tokens: no toca la sesión
    // abierta en el dispositivo.
    final temporal = SupabaseClient(
      url,
      llavePublica,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      await temporal.auth.signInWithPassword(
        email: correo.trim(),
        password: contrasena,
      );
      final sesion = await _lector(temporal);
      await temporal.auth.signOut();
      return sesion;
    } catch (error) {
      throw traducirErrorSesion(error);
    } finally {
      await temporal.dispose();
    }
  }

  @override
  Future<void> salir() async {
    try {
      await _cliente.auth.signOut();
    } catch (error) {
      debugPrint('Salir sin conexión: $error');
    }
    await _almacen.borrar(claveSesionGuardada);
    emitir(null);
  }

  Future<void> _guardar(Sesion sesion) async {
    final usuarioId = _cliente.auth.currentUser?.id;
    if (usuarioId == null) return;
    await _almacen.escribir(
      claveSesionGuardada,
      jsonEncode({'usuario_id': usuarioId, 'sesion': sesion.aJson()}),
    );
  }

  Future<(String, Sesion)?> _leerGuardada() async {
    final texto = await _almacen.leer(claveSesionGuardada);
    if (texto == null) return null;
    try {
      final json = (jsonDecode(texto) as Map).cast<String, Object?>();
      return (
        json['usuario_id']! as String,
        Sesion.desdeJson((json['sesion']! as Map).cast<String, Object?>()),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cerrar() async {
    await _suscripcion?.cancel();
    await super.cerrar();
  }
}

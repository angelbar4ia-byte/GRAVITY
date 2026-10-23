/// Sesión con Supabase (D7): cuentas con correo y contraseña.
///
/// El rol se lee del servidor (membresías del hogar), nunca de la app. La
/// última sesión válida se guarda en el almacenamiento seguro para que el
/// teléfono siga funcionando **sin señal**; con señal, si el servidor dice que
/// la cuenta ya no tiene rol (dada de baja), no se abre (revisión de la
/// Fase 0, I3).
///
/// En la tablet de la casa (D14) la sesión del equipo es la cuenta Casa y,
/// mientras alguien entra con su PIN, las peticiones salen con la sesión de
/// esa persona ([SesionesPorPersona], I6).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../contratos/roles.dart';
import '../seguridad/almacen_seguro.dart';
import '../seguridad/limpieza_local.dart';
import 'errores_red.dart';
import 'sesion.dart';

/// Lee la persona y el rol del usuario autenticado en [cliente].
typedef LectorPerfil = Future<Sesion> Function(SupabaseClient cliente);

/// Lector por omisión, sobre el esquema base del servidor
/// (`supabase/migrations/20261020000000_base.sql`): la persona del usuario
/// (`personas.usuario_id`) y su membresía vigente (`membresias`). Las reglas
/// por registro dejan leer a cada quien lo suyo.
Future<Sesion> leerPerfilPorOmision(SupabaseClient cliente) async {
  final usuario = cliente.auth.currentUser;
  if (usuario == null) throw ErrorSesion.credencialesIncorrectas;
  final persona = await cliente
      .from('personas')
      .select('id, nombre_visible')
      .eq('usuario_id', usuario.id)
      .maybeSingle();
  if (persona == null) throw ErrorSesion.sinRol;
  // En orden fijo (la más antigua primero): con dos hogares, siempre el mismo
  // (revisión de la Fase 0, M4; elegir hogar llega con `mi_perfil()`).
  Future<List<Map<String, dynamic>>> leerMembresias(String columnas) => cliente
      .from('membresias')
      .select(columnas)
      .eq('persona_id', persona['id'] as String)
      .eq('activa', true)
      .order('desde')
      .order('hogar_id');
  List<Map<String, dynamic>> membresias;
  try {
    membresias = await leerMembresias('rol, hogar_id, desde, hasta, es_maestra');
  } on PostgrestException catch (error) {
    // Servidor sin la columna de la cuenta maestra (D19) todavía: nadie es
    // maestra, pero se puede entrar.
    if (error.code != '42703' && error.code != 'PGRST204') rethrow;
    membresias = await leerMembresias('rol, hogar_id, desde, hasta');
  }
  final vigente = membresiaVigente(membresias, DateTime.now());
  if (vigente == null) throw ErrorSesion.sinRol;
  return sesionDesdeFila({
    'persona_id': persona['id'],
    'nombre': persona['nombre_visible'],
    'correo': usuario.email,
    'rol': vigente['rol'],
    'hogar_id': vigente['hogar_id'],
    'es_maestra': vigente['es_maestra'],
  });
}

/// Primera membresía vigente en [ahora] (`desde <= ahora` y `hasta` nula o
/// futura), o `null`.
Map<String, dynamic>? membresiaVigente(
  List<Map<String, dynamic>> membresias,
  DateTime ahora,
) {
  for (final fila in membresias) {
    final desde = DateTime.tryParse('${fila['desde']}');
    final hasta = fila['hasta'] == null
        ? null
        : DateTime.tryParse('${fila['hasta']}');
    if (desde != null && desde.isAfter(ahora)) continue;
    if (hasta != null && !hasta.isAfter(ahora)) continue;
    return fila;
  }
  return null;
}

/// Convierte una fila (`persona_id`, `nombre`, `correo`, `rol`, `hogar_id`,
/// `es_maestra`) en [Sesion]. Lanza [ErrorSesion.sinRol] si el rol no es de
/// D5.
Sesion sesionDesdeFila(Map<String, Object?> fila) {
  final rolTexto = fila['rol'];
  final rol = Rol.values.where((r) => r.name == rolTexto).firstOrNull;
  final personaId = fila['persona_id'] ?? fila['id'];
  if (rol == null || personaId is! String) throw ErrorSesion.sinRol;
  return Sesion(
    persona: Persona(
      id: personaId,
      nombre: nombreParaMostrar(rol, (fila['nombre'] as String?) ?? 'Sin nombre'),
      correo: fila['correo'] as String?,
    ),
    rol: rol,
    hogarId: fila['hogar_id'] as String?,
    esMaestra: fila['es_maestra'] == true,
  );
}

/// Traduce errores del servidor a mensajes para la persona.
ErrorSesion traducirErrorSesion(Object error) {
  if (error is ErrorSesion) return error;
  if (esErrorDeRed(error)) return ErrorSesion.sinConexion;
  if (error is AuthException) {
    final codigo = error.statusCode;
    if (codigo == '400' || codigo == '401' || codigo == '422') {
      return ErrorSesion.credencialesIncorrectas;
    }
    return ErrorSesion('No se pudo entrar: ${error.message}');
  }
  return const ErrorSesion('No se pudo entrar. Intenta de nuevo.');
}

/// Crea un cliente de Supabase aparte (sin guardar la sesión en el equipo).
typedef CreadorCliente =
    SupabaseClient Function(String url, String llave, {bool autoRenovar});

SupabaseClient _clienteAparte(String url, String llave, {bool autoRenovar = false}) =>
    SupabaseClient(
      url,
      llave,
      authOptions: AuthClientOptions(autoRefreshToken: autoRenovar),
    );

class ServicioSesionSupabase extends ServicioSesionEnMemoria
    implements SesionesPorPersona {
  ServicioSesionSupabase({
    required this._cliente,
    required this._almacen,
    required this.url,
    required this.llavePublica,
    LectorPerfil? lectorPerfil,
    CreadorCliente? crearCliente,
    LimpiezaLocal? limpieza,
  }) : _lector = lectorPerfil ?? leerPerfilPorOmision,
       _crearCliente = crearCliente ?? _clienteAparte,
       _limpieza = limpieza ?? LimpiezaLocal(_almacen);

  static const claveSesionGuardada = 'sesion.ultima';

  final SupabaseClient _cliente;
  final AlmacenSeguro _almacen;
  final LectorPerfil _lector;
  final CreadorCliente _crearCliente;

  /// Borra lo guardado en el equipo de quien sale o se da de baja (M5).
  final LimpiezaLocal _limpieza;

  /// `true` mientras [salir] cierra la sesión: el evento `signedOut` que eso
  /// provoca no vuelve a limpiar.
  bool _saliendo = false;
  final String url;
  final String llavePublica;
  StreamSubscription<AuthState>? _suscripcion;

  // Sesión de la persona que entró con su PIN en la tablet (I6).
  SupabaseClient? _clientePersona;
  String? _personaActiva;
  StreamSubscription<AuthState>? _suscripcionPersona;
  final _credenciales = StreamController<String?>.broadcast();

  @override
  bool get esDemostracion => false;

  /// Cliente con el que deben salir las peticiones al servidor: el de la
  /// persona que entró con su PIN o, si no hay, el del equipo.
  SupabaseClient get clienteActivo => _clientePersona ?? _cliente;

  @override
  String? get personaEnServidor =>
      _personaActiva ??
      (_cliente.auth.currentSession == null ? null : sesionActual?.persona.id);

  @override
  Stream<String?> get credencialesDePersona => _credenciales.stream;

  @override
  Future<void> iniciar() async {
    _suscripcion ??= _cliente.auth.onAuthStateChange.listen(
      (estado) {
        if (estado.event == AuthChangeEvent.signedOut) {
          unawaited(_almacen.borrar(claveSesionGuardada));
          // Si es `salir()` quien cierra, ya limpia él (una sola vez).
          final persona = _saliendo ? null : sesionActual?.persona.id;
          if (persona != null) unawaited(_limpieza.alQuitarPersona(persona));
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
      if (esErrorDeRed(error)) {
        // Sin señal al abrir: se usa la última sesión válida de este usuario.
        final guardada = await _leerGuardada();
        if (guardada != null && guardada.$1 == usuario.id) {
          emitir(guardada.$2);
        } else {
          debugPrint('Sin señal y sin sesión guardada: $error');
        }
        return;
      }
      // Con señal y sin rol vigente (dada de baja) o con la sesión vencida:
      // no se abre con el rol guardado (D5: se pierde el acceso de inmediato).
      debugPrint('La cuenta ya no abre: $error');
      await _cerrarEnEsteEquipo();
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
        // Entró pero no tiene rol: no se deja la sesión a medias (y no hay
        // nada suyo que borrar).
        await _cerrarEnEsteEquipo(limpiar: false);
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
    final temporal = _crearCliente(url, llavePublica, autoRenovar: false);
    try {
      await temporal.auth.signInWithPassword(
        email: correo.trim(),
        password: contrasena,
      );
      final sesion = await _lector(temporal);
      await _salirSinFallar(temporal);
      return sesion;
    } catch (error) {
      throw traducirErrorSesion(error);
    } finally {
      await temporal.dispose();
    }
  }

  @override
  Future<CredencialPersona> obtenerCredencial({
    required String correo,
    required String contrasena,
  }) async {
    // Como verificarCredenciales, pero la sesión de la persona NO se cierra:
    // su credencial queda para entrar después con su PIN.
    final temporal = _crearCliente(url, llavePublica, autoRenovar: false);
    try {
      await temporal.auth.signInWithPassword(
        email: correo.trim(),
        password: contrasena,
      );
      final sesion = await _lector(temporal);
      final abierta = temporal.auth.currentSession;
      if (abierta == null) throw ErrorSesion.credencialesIncorrectas;
      return CredencialPersona(sesion, jsonEncode(abierta.toJson()));
    } catch (error) {
      if (error is ErrorSesion && temporal.auth.currentUser != null) {
        await _salirSinFallar(temporal);
      }
      throw traducirErrorSesion(error);
    } finally {
      await temporal.dispose();
    }
  }

  @override
  Future<AperturaPersona> abrirSesionDePersona(
    String personaId,
    String credencial,
  ) async {
    await cerrarSesionDePersona();
    final Session? guardada;
    try {
      guardada = Session.fromJson(
        (jsonDecode(credencial) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      throw ErrorSesion.credencialVencida;
    }
    final renovar = guardada?.refreshToken;
    if (guardada == null || renovar == null || renovar.isEmpty) {
      throw ErrorSesion.credencialVencida;
    }

    final cliente = _crearCliente(url, llavePublica, autoRenovar: true);
    var conSenal = true;
    try {
      await cliente.auth.setSession(
        renovar,
        accessToken: guardada.isExpired ? null : guardada.accessToken,
      );
    } catch (error) {
      if (!esErrorDeRed(error)) {
        await cliente.dispose();
        throw ErrorSesion.credencialVencida;
      }
      // Sin señal: se abre con la credencial guardada; el cliente la renueva
      // cuando vuelva la señal.
      conSenal = false;
      await cliente.auth.setInitialSession(credencial);
    }

    Sesion? sesion;
    if (conSenal) {
      try {
        sesion = await _lector(cliente);
        if (sesion.persona.id != personaId) throw ErrorSesion.credencialVencida;
      } catch (error) {
        if (!esErrorDeRed(error)) {
          if (error == ErrorSesion.sinRol) await _salirSinFallar(cliente);
          await cliente.dispose();
          throw traducirErrorSesion(error);
        }
      }
    }

    _clientePersona = cliente;
    _personaActiva = personaId;
    _suscripcionPersona = cliente.auth.onAuthStateChange.listen(
      (estado) {
        if (!identical(_clientePersona, cliente)) return;
        final abierta = estado.session;
        if (estado.event == AuthChangeEvent.signedOut) {
          // La sesión de la persona terminó (revocada): se avisa para volver
          // a la cuenta del equipo.
          _credenciales.add(null);
          unawaited(cerrarSesionDePersona());
        } else if (abierta != null &&
            (estado.event == AuthChangeEvent.tokenRefreshed ||
                estado.event == AuthChangeEvent.signedIn ||
                estado.event == AuthChangeEvent.userUpdated)) {
          _credenciales.add(jsonEncode(abierta.toJson()));
        }
      },
      onError: (Object error) => debugPrint('Sesión de la persona: $error'),
    );
    final vigente = cliente.auth.currentSession;
    return AperturaPersona(
      sesion: sesion,
      credencial: vigente == null ? credencial : jsonEncode(vigente.toJson()),
    );
  }

  @override
  Future<String?> cerrarSesionDePersona() async {
    final cliente = _clientePersona;
    if (cliente == null) return null;
    final vigente = cliente.auth.currentSession;
    _clientePersona = null;
    _personaActiva = null;
    await _suscripcionPersona?.cancel();
    _suscripcionPersona = null;
    // Sin cerrar sesión en el servidor: la credencial sigue sirviendo para la
    // próxima vez que la persona entre con su PIN.
    await cliente.dispose();
    return vigente == null ? null : jsonEncode(vigente.toJson());
  }

  @override
  Future<void> salir() async {
    final persona = sesionActual?.persona.id;
    _saliendo = true;
    try {
      await cerrarSesionDePersona();
      try {
        await _cliente.auth.signOut();
      } catch (error) {
        debugPrint('Salir sin conexión: $error');
      }
      await _almacen.borrar(claveSesionGuardada);
      // M5: lo guardado de la persona (copias locales de los módulos) no se
      // queda en el equipo.
      if (persona != null) await _limpieza.alQuitarPersona(persona);
    } finally {
      _saliendo = false;
    }
    emitir(null);
  }

  /// Cierra la sesión en este equipo aunque no haya respuesta del servidor.
  ///
  /// Con [limpiar], borra también lo guardado de la persona (M5; D5: la baja
  /// quita el acceso de inmediato). La persona sale de la sesión abierta o,
  /// al abrir la app, de la última sesión guardada; si no se sabe de quién
  /// era, se barren todas las copias locales.
  Future<void> _cerrarEnEsteEquipo({bool limpiar = true}) async {
    final guardada = limpiar ? await _leerGuardada() : null;
    final persona = sesionActual?.persona.id ?? guardada?.$2.persona.id;
    await _salirSinFallar(_cliente);
    await _almacen.borrar(claveSesionGuardada);
    if (limpiar) {
      if (persona != null) {
        await _limpieza.alQuitarPersona(persona);
      } else {
        await _limpieza.alQuitarTodas();
      }
    }
    if (sesionActual != null) emitir(null);
  }

  static Future<void> _salirSinFallar(SupabaseClient cliente) async {
    try {
      await cliente.auth.signOut();
    } catch (error) {
      debugPrint('Cerrar sesión sin respuesta del servidor: $error');
    }
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
    await cerrarSesionDePersona();
    await _suscripcion?.cancel();
    await _credenciales.close();
    await super.cerrar();
  }
}

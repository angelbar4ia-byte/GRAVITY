/// Sesión de la persona que usa la app: quién es y con qué rol (D5).
library;

import 'dart:async';

import '../contratos/roles.dart';

/// Nombre que se muestra de la cuenta del equipo de las tablets (rol `casa`,
/// D14; decisión del dueño del 23/oct/2026): **"Hogar"**. El rol sigue
/// llamándose `casa` en el código y en el servidor.
const nombreCuentaDelHogar = 'Hogar';

/// El nombre que se muestra de la persona de [rol]: el de la cuenta del
/// equipo siempre es [nombreCuentaDelHogar], diga lo que diga el servidor.
String nombreParaMostrar(Rol rol, String nombre) =>
    rol == Rol.casa ? nombreCuentaDelHogar : nombre;

/// Persona con cuenta propia (D5). Nunca se guardan datos reales en el código.
class Persona {
  const Persona({required this.id, required this.nombre, this.correo});

  /// Identificador de la persona (UUID del servidor).
  final String id;
  final String nombre;
  final String? correo;

  Map<String, Object?> aJson() => {
    'id': id,
    'nombre': nombre,
    if (correo != null) 'correo': correo,
  };

  factory Persona.desdeJson(Map<String, Object?> json) => Persona(
    id: json['id']! as String,
    nombre: json['nombre']! as String,
    correo: json['correo'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Persona &&
      other.id == id &&
      other.nombre == nombre &&
      other.correo == correo;

  @override
  int get hashCode => Object.hash(id, nombre, correo);

  @override
  String toString() => 'Persona($id, $nombre)';
}

/// Sesión abierta: persona, rol, hogar y si es la cuenta maestra.
class Sesion {
  const Sesion({
    required this.persona,
    required this.rol,
    this.hogarId,
    this.esMaestra = false,
  });

  final Persona persona;
  final Rol rol;
  final String? hogarId;

  /// Cuenta maestra del hogar (D19, `membresias.es_maestra`): **solo lee**
  /// todo (libros de Finanzas e historial de GRAVITY de todos) y nunca
  /// escribe en lo ajeno. La asigna el dueño; una por hogar.
  final bool esMaestra;

  Map<String, Object?> aJson() => {
    'persona': persona.aJson(),
    'rol': rol.name,
    if (hogarId != null) 'hogar_id': hogarId,
    if (esMaestra) 'es_maestra': true,
  };

  factory Sesion.desdeJson(Map<String, Object?> json) {
    final rol = Rol.values.byName(json['rol']! as String);
    final persona = Persona.desdeJson(
      (json['persona']! as Map).cast<String, Object?>(),
    );
    return Sesion(
      // Una sesión guardada antes del cambio de nombre se muestra como "Hogar".
      persona: Persona(
        id: persona.id,
        nombre: nombreParaMostrar(rol, persona.nombre),
        correo: persona.correo,
      ),
      rol: rol,
      hogarId: json['hogar_id'] as String?,
      esMaestra: json['es_maestra'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Sesion &&
      other.persona == persona &&
      other.rol == rol &&
      other.hogarId == hogarId &&
      other.esMaestra == esMaestra;

  @override
  int get hashCode => Object.hash(persona, rol, hogarId, esMaestra);

  @override
  String toString() =>
      'Sesion(${persona.nombre}, ${rol.name}${esMaestra ? ', maestra' : ''})';
}

/// Error de sesión con un mensaje listo para mostrar en la interfaz.
class ErrorSesion implements Exception {
  const ErrorSesion(this.mensaje);

  final String mensaje;

  static const credencialesIncorrectas = ErrorSesion(
    'Correo o contraseña incorrectos.',
  );
  static const sinConexion = ErrorSesion(
    'Sin conexión. Intenta de nuevo cuando haya señal.',
  );
  static const sinRol = ErrorSesion(
    'Tu cuenta aún no tiene un rol en el hogar. Pide al Dueño que te invite.',
  );
  static const credencialVencida = ErrorSesion(
    'Tu sesión en este equipo venció. Pide que te agreguen de nuevo con tu '
    'correo y contraseña.',
  );

  @override
  String toString() => 'ErrorSesion: $mensaje';
}

/// Servicio de sesión. La app solo conoce esta interfaz: en producción es
/// Supabase (D7); sin llaves, el modo demostración; en pruebas, la falsa.
abstract interface class ServicioSesion {
  /// Sesión abierta o `null` si nadie ha entrado.
  Sesion? get sesionActual;

  /// Avisa cada vez que se entra o se sale.
  Stream<Sesion?> get cambios;

  /// `true` si no hay servidor configurado (datos de ejemplo).
  bool get esDemostracion;

  /// Recupera la sesión guardada, si existe. Se llama una vez al arrancar.
  Future<void> iniciar();

  /// Entra con correo y contraseña. Lanza [ErrorSesion] si no se puede.
  Future<Sesion> entrar({required String correo, required String contrasena});

  /// Comprueba las credenciales de otra persona **sin cambiar** la sesión
  /// abierta (p. ej. para agregarla a la tablet de la casa). Lanza
  /// [ErrorSesion] si no son válidas.
  Future<Sesion> verificarCredenciales({
    required String correo,
    required String contrasena,
  });

  /// Cierra la sesión.
  Future<void> salir();
}

/// Credencial de una persona para un equipo compartido: su sesión del
/// servidor, para volver a abrirla después sin contraseña. La app la guarda
/// cifrada con el PIN de la persona (`nucleo/seguridad/cifrado.dart`).
class CredencialPersona {
  const CredencialPersona(this.sesion, this.credencial);

  final Sesion sesion;

  /// Texto opaco (en Supabase, la sesión con su token de renovación).
  final String credencial;
}

/// Resultado de [SesionesPorPersona.abrirSesionDePersona].
class AperturaPersona {
  const AperturaPersona({required this.sesion, required this.credencial});

  /// Sesión con el rol vigente según el servidor; `null` sin señal.
  final Sesion? sesion;

  /// Credencial vigente (el servidor la renueva al usarla).
  final String credencial;

  bool get sinConexion => sesion == null;
}

/// Capacidad de los servicios con servidor en un equipo compartido (tablet de
/// la casa, D14): la sesión del servidor cambia a la persona que entra con su
/// PIN y regresa a la cuenta del equipo (Casa) al salir. Así el servidor
/// aplica los permisos de quien usa la tablet y la bitácora lleva su nombre
/// (D5). [ServicioSesion.sesionActual] sigue siendo la cuenta del equipo.
abstract interface class SesionesPorPersona {
  /// Comprueba correo y contraseña de la persona y devuelve su sesión (rol
  /// real) y una credencial para entrar después con su PIN. No cambia la
  /// sesión abierta. Lanza [ErrorSesion].
  Future<CredencialPersona> obtenerCredencial({
    required String correo,
    required String contrasena,
  });

  /// Abre en el servidor la sesión de la persona de [credencial]; las
  /// peticiones salen con su identidad hasta [cerrarSesionDePersona].
  ///
  /// Devuelve su sesión con el rol vigente (`null` si no hay señal: se abre
  /// con la credencial guardada y el rol que ya se conocía) y la credencial
  /// renovada, que hay que guardar en lugar de la anterior. Lanza
  /// [ErrorSesion.sinRol] si ya no tiene acceso (dada de baja) y
  /// [ErrorSesion.credencialVencida] si la credencial ya no sirve.
  Future<AperturaPersona> abrirSesionDePersona(
    String personaId,
    String credencial,
  );

  /// Avisa cuando el servidor renueva la credencial de la persona que está
  /// dentro (hay que guardarla otra vez) y emite `null` si su sesión terminó
  /// (p. ej. la revocaron): la app regresa a la cuenta del equipo.
  Stream<String?> get credencialesDePersona;

  /// Cierra la sesión de la persona **sin revocarla** y regresa a la cuenta
  /// del equipo. Devuelve su credencial vigente, para guardarla.
  Future<String?> cerrarSesionDePersona();

  /// Persona con cuya sesión salen ahora las peticiones al servidor (la del
  /// equipo o la que entró con su PIN); `null` si no hay sesión.
  String? get personaEnServidor;

  /// Abre una sesión **aparte** de la persona de [credencial] (su permiso de
  /// subida de la bandeja de salida) sin cambiar la sesión del equipo ni la de
  /// quien esté dentro. Lanza [ErrorSesion.sinConexion] sin señal,
  /// [ErrorSesion.sinRol] si ya no tiene acceso (dada de baja) y
  /// [ErrorSesion.credencialVencida] si la credencial ya no sirve.
  Future<SesionAparte> abrirSesionAparte(String personaId, String credencial);
}

/// Una sesión de [personaId] abierta **aparte** de la de la tablet y de la de
/// quien esté dentro, solo para subir su bandeja de salida sin pedir su PIN
/// (D14, 23/oct/2026; ver `cola/bandeja_salida.dart`).
abstract interface class SesionAparte {
  String get personaId;

  /// Avisa cada vez que el servidor renueva la credencial: hay que guardarla
  /// de inmediato (la anterior ya no sirve; reusarla puede revocar la sesión).
  Stream<String> get renovaciones;

  /// Cierra la sesión **sin revocarla** y devuelve la credencial vigente.
  Future<String?> cerrar();
}

/// Capacidad extra del modo demostración: entrar con un rol elegido.
abstract interface class EntradaDeDemostracion {
  List<Rol> get rolesDisponibles;

  Future<Sesion> entrarComo(Rol rol);
}

/// Base común para los servicios que guardan la sesión en memoria.
abstract class ServicioSesionEnMemoria implements ServicioSesion {
  ServicioSesionEnMemoria({Sesion? inicial}) : _actual = inicial;

  final _cambios = StreamController<Sesion?>.broadcast();
  Sesion? _actual;

  @override
  Sesion? get sesionActual => _actual;

  @override
  Stream<Sesion?> get cambios => _cambios.stream;

  /// Cambia la sesión y avisa.
  void emitir(Sesion? sesion) {
    _actual = sesion;
    _cambios.add(sesion);
  }

  @override
  Future<void> iniciar() async {}

  @override
  Future<void> salir() async => emitir(null);

  Future<void> cerrar() => _cambios.close();
}

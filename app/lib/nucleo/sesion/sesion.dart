/// Sesión de la persona que usa la app: quién es y con qué rol (D5).
library;

import 'dart:async';

import '../contratos/roles.dart';

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

/// Sesión abierta: persona, rol y hogar.
class Sesion {
  const Sesion({required this.persona, required this.rol, this.hogarId});

  final Persona persona;
  final Rol rol;
  final String? hogarId;

  Map<String, Object?> aJson() => {
    'persona': persona.aJson(),
    'rol': rol.name,
    if (hogarId != null) 'hogar_id': hogarId,
  };

  factory Sesion.desdeJson(Map<String, Object?> json) => Sesion(
    persona: Persona.desdeJson(
      (json['persona']! as Map).cast<String, Object?>(),
    ),
    rol: Rol.values.byName(json['rol']! as String),
    hogarId: json['hogar_id'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Sesion &&
      other.persona == persona &&
      other.rol == rol &&
      other.hogarId == hogarId;

  @override
  int get hashCode => Object.hash(persona, rol, hogarId);

  @override
  String toString() => 'Sesion(${persona.nombre}, ${rol.name})';
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

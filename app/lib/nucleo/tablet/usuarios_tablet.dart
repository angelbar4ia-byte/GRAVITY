/// Personas que entran en la tablet de la casa (D14) y su configuración.
/// Todo se guarda en el almacenamiento seguro; el PIN solo como hash.
library;

import 'dart:convert';

import '../contratos/roles.dart';
import '../sesion/sesion.dart';
import '../seguridad/almacen_seguro.dart';

/// Contexto de uso de la tablet (D14). Ampliable: se agregan a la lista.
class ContextoCasa {
  const ContextoCasa(this.id, this.nombre);

  final String id;
  final String nombre;
}

const List<ContextoCasa> contextosCasa = [
  ContextoCasa('general', 'General'),
  ContextoCasa('cocina', 'Cocina'),
  ContextoCasa('gimnasio', 'Gimnasio'),
  ContextoCasa('cuidados', 'Cuidados'),
];

/// Tiempo sin uso para regresar al modo Casa (editable, D14).
const regresoModoCasaPorOmision = Duration(minutes: 2);
const regresoModoCasaMinimo = Duration(seconds: 30);
const regresoModoCasaMaximo = Duration(minutes: 30);

/// Persona registrada en la tablet.
class UsuarioTablet {
  const UsuarioTablet({
    required this.personaId,
    required this.nombre,
    required this.rol,
    required this.hashPin,
    this.huella = false,
    this.hogarId,
  });

  factory UsuarioTablet.desdeSesion(
    Sesion sesion, {
    required String hashPin,
    bool huella = false,
  }) => UsuarioTablet(
    personaId: sesion.persona.id,
    nombre: sesion.persona.nombre,
    rol: sesion.rol,
    hashPin: hashPin,
    huella: huella,
    hogarId: sesion.hogarId,
  );

  final String personaId;
  final String nombre;
  final Rol rol;

  /// Hash del PIN (`HashPin.crear`), nunca el PIN.
  final String hashPin;

  /// `true` si puede entrar con huella además del PIN.
  final bool huella;
  final String? hogarId;

  Sesion get sesion => Sesion(
    persona: Persona(id: personaId, nombre: nombre),
    rol: rol,
    hogarId: hogarId,
  );

  UsuarioTablet copiarCon({String? hashPin, bool? huella}) => UsuarioTablet(
    personaId: personaId,
    nombre: nombre,
    rol: rol,
    hashPin: hashPin ?? this.hashPin,
    huella: huella ?? this.huella,
    hogarId: hogarId,
  );

  Map<String, Object?> aJson() => {
    'persona_id': personaId,
    'nombre': nombre,
    'rol': rol.name,
    'hash_pin': hashPin,
    'huella': huella,
    if (hogarId != null) 'hogar_id': hogarId,
  };

  factory UsuarioTablet.desdeJson(Map<String, Object?> json) => UsuarioTablet(
    personaId: json['persona_id']! as String,
    nombre: json['nombre']! as String,
    rol: Rol.values.byName(json['rol']! as String),
    hashPin: json['hash_pin']! as String,
    huella: (json['huella'] as bool?) ?? false,
    hogarId: json['hogar_id'] as String?,
  );
}

/// Configuración local de la tablet.
class ConfiguracionTablet {
  const ConfiguracionTablet({
    this.regresoModoCasa = regresoModoCasaPorOmision,
    this.contexto = 'general',
  });

  final Duration regresoModoCasa;
  final String contexto;

  ConfiguracionTablet copiarCon({Duration? regresoModoCasa, String? contexto}) =>
      ConfiguracionTablet(
        regresoModoCasa: regresoModoCasa ?? this.regresoModoCasa,
        contexto: contexto ?? this.contexto,
      );

  Map<String, Object?> aJson() => {
    'regreso_segundos': regresoModoCasa.inSeconds,
    'contexto': contexto,
  };

  factory ConfiguracionTablet.desdeJson(Map<String, Object?> json) =>
      ConfiguracionTablet(
        regresoModoCasa: Duration(
          seconds:
              (json['regreso_segundos'] as int?) ??
              regresoModoCasaPorOmision.inSeconds,
        ),
        contexto: (json['contexto'] as String?) ?? 'general',
      );
}

/// Lee y guarda personas y configuración de la tablet.
class RepositorioTablet {
  RepositorioTablet(this._almacen);

  static const claveUsuarios = 'tablet.usuarios';
  static const claveConfiguracion = 'tablet.configuracion';

  final AlmacenSeguro _almacen;

  Future<List<UsuarioTablet>> leerUsuarios() async {
    final texto = await _almacen.leer(claveUsuarios);
    if (texto == null) return [];
    try {
      return [
        for (final item in jsonDecode(texto) as List)
          UsuarioTablet.desdeJson((item as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarUsuarios(List<UsuarioTablet> usuarios) =>
      _almacen.escribir(
        claveUsuarios,
        jsonEncode([for (final u in usuarios) u.aJson()]),
      );

  Future<ConfiguracionTablet> leerConfiguracion() async {
    final texto = await _almacen.leer(claveConfiguracion);
    if (texto == null) return const ConfiguracionTablet();
    try {
      return ConfiguracionTablet.desdeJson(
        (jsonDecode(texto) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return const ConfiguracionTablet();
    }
  }

  Future<void> guardarConfiguracion(ConfiguracionTablet configuracion) =>
      _almacen.escribir(claveConfiguracion, jsonEncode(configuracion.aJson()));
}

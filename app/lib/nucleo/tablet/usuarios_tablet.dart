/// Personas que entran en la tablet de la casa (D14) y su configuración.
/// Todo se guarda en el almacenamiento seguro; el PIN solo como hash, y la
/// credencial del servidor de cada persona, cifrada con su PIN (I6).
library;

import 'dart:convert';

import '../contratos/roles.dart';
import '../sesion/sesion.dart';
import '../seguridad/almacen_seguro.dart';
import '../seguridad/cifrado.dart';

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

/// Persona registrada en la tablet. Entra **solo con su PIN**: en la tablet
/// compartida la huella no identifica a la persona (Android acepta cualquier
/// dedo registrado en el equipo; revisión de la Fase 0, B3).
class UsuarioTablet {
  const UsuarioTablet({
    required this.personaId,
    required this.nombre,
    required this.rol,
    required this.hashPin,
    this.hogarId,
  });

  factory UsuarioTablet.desdeSesion(Sesion sesion, {required String hashPin}) =>
      UsuarioTablet(
        personaId: sesion.persona.id,
        nombre: sesion.persona.nombre,
        rol: sesion.rol,
        hashPin: hashPin,
        hogarId: sesion.hogarId,
      );

  final String personaId;
  final String nombre;
  final Rol rol;

  /// Hash del PIN (`HashPin.crear`), nunca el PIN.
  final String hashPin;
  final String? hogarId;

  Sesion get sesion => Sesion(
    persona: Persona(id: personaId, nombre: nombre),
    rol: rol,
    hogarId: hogarId,
  );

  UsuarioTablet copiarCon({String? hashPin, Sesion? sesion}) => UsuarioTablet(
    personaId: personaId,
    nombre: sesion?.persona.nombre ?? nombre,
    rol: sesion?.rol ?? rol,
    hashPin: hashPin ?? this.hashPin,
    hogarId: sesion?.hogarId ?? hogarId,
  );

  Map<String, Object?> aJson() => {
    'persona_id': personaId,
    'nombre': nombre,
    'rol': rol.name,
    'hash_pin': hashPin,
    if (hogarId != null) 'hogar_id': hogarId,
  };

  /// Lee una persona guardada. Una marca `huella` de versiones anteriores se
  /// ignora: ya no abre.
  factory UsuarioTablet.desdeJson(Map<String, Object?> json) => UsuarioTablet(
    personaId: json['persona_id']! as String,
    nombre: json['nombre']! as String,
    rol: Rol.values.byName(json['rol']! as String),
    hashPin: json['hash_pin']! as String,
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

  /// Fallos del PIN por persona (sobreviven al reinicio, I2).
  static const claveIntentos = 'tablet.intentos_pin';

  /// Credencial cifrada con el PIN de [personaId].
  static String claveCredencial(String personaId) =>
      'tablet.credencial.$personaId';

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

  /// Guarda la [credencial] de la persona cifrada con [llave] (de su PIN).
  Future<void> guardarCredencial(
    String personaId,
    LlavePin llave,
    String credencial,
  ) => _almacen.escribir(
    claveCredencial(personaId),
    CifradoPin.cifrar(llave, credencial),
  );

  /// Descifra la credencial de la persona con su [pin]: devuelve la llave
  /// (para volver a cifrarla al renovarse) y la credencial, o `null` si no hay
  /// o el PIN no la abre.
  Future<(LlavePin, String)?> leerCredencial(String personaId, String pin) async {
    final sobre = await _almacen.leer(claveCredencial(personaId));
    return sobre == null ? null : CifradoPin.descifrar(pin, sobre);
  }

  Future<bool> tieneCredencial(String personaId) async =>
      await _almacen.leer(claveCredencial(personaId)) != null;

  Future<void> borrarCredencial(String personaId) =>
      _almacen.borrar(claveCredencial(personaId));
}

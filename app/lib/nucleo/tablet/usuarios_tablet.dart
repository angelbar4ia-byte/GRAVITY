/// Personas que entran en las tablets (D14) y su configuración: tipo de tablet
/// (personal o pública de la casa) y personas permitidas.
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

/// Tipo de tablet (D14, actualizada el 21/oct/2026). Se elige en
/// Ajustes › Dispositivos.
enum TipoTablet {
  /// Del dueño y la pareja: en reposo, pantalla de bloqueo con los perfiles
  /// permitidos; **sin** modo Casa. Tras el tiempo sin uso vuelve al bloqueo.
  personal,

  /// De la casa: en reposo, modo Casa (cuenta de rol Casa, sin dinero ni datos
  /// clínicos). Leer no pide identidad; registrar sí.
  publica,
}

/// Roles que pueden entrar a una tablet personal (D14: dueño y pareja).
const Set<Rol> rolesDeTabletPersonal = {Rol.dueno, Rol.coadministrador};

/// Tiempo sin uso para regresar al reposo: modo Casa o bloqueo (D14).
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
    this.esMaestra = false,
  });

  factory UsuarioTablet.desdeSesion(Sesion sesion, {required String hashPin}) =>
      UsuarioTablet(
        personaId: sesion.persona.id,
        nombre: sesion.persona.nombre,
        rol: sesion.rol,
        hashPin: hashPin,
        hogarId: sesion.hogarId,
        esMaestra: sesion.esMaestra,
      );

  final String personaId;
  final String nombre;
  final Rol rol;

  /// Hash del PIN (`HashPin.crear`), nunca el PIN.
  final String hashPin;
  final String? hogarId;

  /// Cuenta maestra (D19): solo lee; nunca escribe en lo ajeno.
  final bool esMaestra;

  Sesion get sesion => Sesion(
    persona: Persona(id: personaId, nombre: nombre),
    rol: rol,
    hogarId: hogarId,
    esMaestra: esMaestra,
  );

  UsuarioTablet copiarCon({String? hashPin, Sesion? sesion}) => UsuarioTablet(
    personaId: personaId,
    nombre: sesion?.persona.nombre ?? nombre,
    rol: sesion?.rol ?? rol,
    hashPin: hashPin ?? this.hashPin,
    hogarId: sesion?.hogarId ?? hogarId,
    esMaestra: sesion?.esMaestra ?? esMaestra,
  );

  Map<String, Object?> aJson() => {
    'persona_id': personaId,
    'nombre': nombre,
    'rol': rol.name,
    'hash_pin': hashPin,
    if (hogarId != null) 'hogar_id': hogarId,
    if (esMaestra) 'es_maestra': true,
  };

  /// Lee una persona guardada. Una marca `huella` de versiones anteriores se
  /// ignora: ya no abre.
  factory UsuarioTablet.desdeJson(Map<String, Object?> json) => UsuarioTablet(
    personaId: json['persona_id']! as String,
    nombre: json['nombre']! as String,
    rol: Rol.values.byName(json['rol']! as String),
    hashPin: json['hash_pin']! as String,
    hogarId: json['hogar_id'] as String?,
    esMaestra: json['es_maestra'] == true,
  );
}

/// Configuración local de la tablet.
class ConfiguracionTablet {
  const ConfiguracionTablet({
    this.regresoModoCasa = regresoModoCasaPorOmision,
    this.contexto = 'general',
    this.tipo = TipoTablet.publica,
    this.permitidas = const {},
  });

  /// Tiempo sin uso para volver al reposo (modo Casa o bloqueo).
  final Duration regresoModoCasa;
  final String contexto;
  final TipoTablet tipo;

  /// En la tablet personal, quiénes pueden entrar (ids de persona). Solo
  /// cuentan las personas de la tablet con rol de [rolesDeTabletPersonal].
  final Set<String> permitidas;

  bool get esPersonal => tipo == TipoTablet.personal;

  ConfiguracionTablet copiarCon({
    Duration? regresoModoCasa,
    String? contexto,
    TipoTablet? tipo,
    Set<String>? permitidas,
  }) => ConfiguracionTablet(
    regresoModoCasa: regresoModoCasa ?? this.regresoModoCasa,
    contexto: contexto ?? this.contexto,
    tipo: tipo ?? this.tipo,
    permitidas: permitidas ?? this.permitidas,
  );

  Map<String, Object?> aJson() => {
    'regreso_segundos': regresoModoCasa.inSeconds,
    'contexto': contexto,
    'tipo': tipo.name,
    'permitidas': permitidas.toList()..sort(),
  };

  factory ConfiguracionTablet.desdeJson(Map<String, Object?> json) =>
      ConfiguracionTablet(
        regresoModoCasa: Duration(
          seconds:
              (json['regreso_segundos'] as int?) ??
              regresoModoCasaPorOmision.inSeconds,
        ),
        contexto: (json['contexto'] as String?) ?? 'general',
        tipo:
            TipoTablet.values
                .where((t) => t.name == json['tipo'])
                .firstOrNull ??
            TipoTablet.publica,
        permitidas: {
          for (final id in (json['permitidas'] as List?) ?? const [])
            if (id is String) id,
        },
      );
}

/// `true` si [usuario] puede entrar a una tablet con [configuracion]: en la
/// pública, cualquiera de la tablet; en la personal, solo las permitidas con
/// rol de dueño o pareja.
bool puedeEntrarEnTablet(
  UsuarioTablet usuario,
  ConfiguracionTablet configuracion,
) =>
    !configuracion.esPersonal ||
    (rolesDeTabletPersonal.contains(usuario.rol) &&
        configuracion.permitidas.contains(usuario.personaId));

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
  Future<(LlavePin, String)?> leerCredencial(
    String personaId,
    String pin,
  ) async {
    final sobre = await _almacen.leer(claveCredencial(personaId));
    return sobre == null ? null : CifradoPin.descifrarAsync(pin, sobre);
  }

  Future<bool> tieneCredencial(String personaId) async =>
      await _almacen.leer(claveCredencial(personaId)) != null;

  Future<void> borrarCredencial(String personaId) =>
      _almacen.borrar(claveCredencial(personaId));
}

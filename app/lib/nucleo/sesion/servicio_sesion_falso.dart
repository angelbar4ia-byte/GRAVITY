/// Servicio de sesión falso para pruebas (de cualquier agente).
///
/// ```dart
/// final sesion = ServicioSesionFalso(
///   cuentas: {'ana@ejemplo.test': CuentaFalsa('secreta', sesionDeEjemplo(Rol.cuidador))},
/// );
/// ```
///
/// También simula la sesión del servidor por persona de la tablet
/// ([SesionesPorPersona]): [personaEnServidor] dice con qué persona saldrían
/// las peticiones.
library;

import 'dart:async';
import 'dart:convert';

import '../contratos/roles.dart';
import 'servicio_sesion_demostracion.dart';
import 'sesion.dart';

class CuentaFalsa {
  const CuentaFalsa(this.contrasena, this.sesion);

  final String contrasena;
  final Sesion sesion;
}

class ServicioSesionFalso extends ServicioSesionEnMemoria
    implements SesionesPorPersona {
  ServicioSesionFalso({
    Map<String, CuentaFalsa>? cuentas,
    super.inicial,
    this.sinConexion = false,
  }) : cuentas = cuentas ?? {};

  /// Abre el servicio con una sesión de ejemplo del [rol].
  factory ServicioSesionFalso.con(Rol rol) =>
      ServicioSesionFalso(inicial: sesionDeEjemplo(rol));

  final Map<String, CuentaFalsa> cuentas;

  /// Simula que no hay internet: entrar y verificar fallan.
  bool sinConexion;

  int vecesEntrar = 0;
  int vecesSalir = 0;
  int vecesVerificar = 0;

  /// Personas (por id) dadas de baja: su credencial ya no abre.
  final Set<String> bajas = {};

  /// Veces que se abrió la sesión del servidor de una persona.
  int vecesAbrirPersona = 0;

  /// Como el refresh token de Supabase: al usarse **rota**, y usar uno que ya
  /// rotó no sirve ([ErrorSesion.credencialVencida]; en Supabase, además,
  /// puede revocar toda la sesión). Sirve para vigilar que la app nunca use
  /// una copia vieja de la credencial. Por omisión, apagado.
  bool rotacionEstricta = false;

  /// Veces que se intentó abrir con una credencial que ya había rotado.
  int usosDeCredencialVieja = 0;

  /// Veces que se abrió una sesión aparte (bandeja de salida).
  int vecesAbrirAparte = 0;

  /// Si las sesiones aparte rotan la credencial al abrirse (como Supabase
  /// cuando el token de acceso ya venció).
  bool rotaAlAbrirAparte = true;

  /// Sesiones aparte abiertas y aún sin cerrar.
  final List<SesionAparteFalsa> sesionesAparteAbiertas = [];

  /// La última sesión aparte que se abrió.
  SesionAparteFalsa? ultimaSesionAparte;

  /// Vuelta de la credencial que sirve ahora, por persona.
  final Map<String, int> _vigente = {};

  void _revisarCadena(String personaId, int vuelta) {
    if (!rotacionEstricta) return;
    final vigente = _vigente[personaId];
    // Una copia vieja (vuelta menor) ya no sirve. Una credencial de vuelta
    // mayor es de un inicio de sesión nuevo (la persona se volvió a agregar):
    // el servidor sí la conoce.
    if (vigente != null && vuelta < vigente) {
      usosDeCredencialVieja++;
      throw ErrorSesion.credencialVencida;
    }
  }

  String? _personaActiva;
  String? _credencialActiva;
  final _credenciales = StreamController<String?>.broadcast();

  /// Credencial falsa de [sesion] (la vuelta cambia en cada renovación).
  static String credencialDe(Sesion sesion, {int vuelta = 0}) =>
      'falsa:$vuelta:${base64Url.encode(utf8.encode(jsonEncode(sesion.aJson())))}';

  /// Sesión y vuelta de una credencial falsa, o `null` si no lo es.
  static (Sesion, int)? leerCredencial(String credencial) {
    final partes = credencial.split(':');
    if (partes.length != 3 || partes[0] != 'falsa') return null;
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(partes[2])));
      return (
        Sesion.desdeJson((json as Map).cast<String, Object?>()),
        int.parse(partes[1]),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String? get personaEnServidor => _personaActiva ?? sesionActual?.persona.id;

  @override
  Stream<String?> get credencialesDePersona => _credenciales.stream;

  @override
  Future<CredencialPersona> obtenerCredencial({
    required String correo,
    required String contrasena,
  }) async {
    vecesVerificar++;
    final sesion = _comprobar(correo, contrasena);
    return CredencialPersona(sesion, credencialDe(sesion));
  }

  /// Hace que la **siguiente** apertura de una sesión de persona (o aparte)
  /// falle con este error y luego vuelva a funcionar (p. ej.
  /// [ErrorSesion.servidorOcupado], el límite de peticiones).
  ErrorSesion? fallarSiguienteApertura;

  void _fallarSiHaceFalta() {
    final error = fallarSiguienteApertura;
    if (error == null) return;
    fallarSiguienteApertura = null;
    throw error;
  }

  @override
  Future<AperturaPersona> abrirSesionDePersona(
    String personaId,
    String credencial,
  ) async {
    vecesAbrirPersona++;
    _fallarSiHaceFalta();
    await cerrarSesionDePersona();
    final leida = leerCredencial(credencial);
    if (leida == null || leida.$1.persona.id != personaId) {
      throw ErrorSesion.credencialVencida;
    }
    if (!sinConexion && bajas.contains(personaId)) throw ErrorSesion.sinRol;
    _revisarCadena(personaId, leida.$2);
    final renovada = credencialDe(leida.$1, vuelta: leida.$2 + 1);
    _vigente[personaId] = leida.$2 + 1;
    _personaActiva = personaId;
    _credencialActiva = renovada;
    return AperturaPersona(
      sesion: sinConexion ? null : leida.$1,
      credencial: renovada,
    );
  }

  /// Simula que el servidor renueva la credencial de la persona que está
  /// dentro.
  void renovarCredencialDePersona() {
    final actual = _credencialActiva;
    final leida = actual == null ? null : leerCredencial(actual);
    if (leida == null) return;
    _credencialActiva = credencialDe(leida.$1, vuelta: leida.$2 + 1);
    _vigente[leida.$1.persona.id] = leida.$2 + 1;
    _credenciales.add(_credencialActiva);
  }

  /// Simula que el servidor revoca la sesión de la persona que está dentro.
  void revocarSesionDePersona() {
    if (_personaActiva == null) return;
    _personaActiva = null;
    _credencialActiva = null;
    _credenciales.add(null);
  }

  @override
  Future<SesionAparte> abrirSesionAparte(
    String personaId,
    String credencial, {
    required void Function(String credencial) alRenovar,
  }) async {
    vecesAbrirAparte++;
    _fallarSiHaceFalta();
    if (sinConexion) throw ErrorSesion.sinConexion;
    final leida = leerCredencial(credencial);
    if (leida == null || leida.$1.persona.id != personaId) {
      throw ErrorSesion.credencialVencida;
    }
    if (bajas.contains(personaId)) throw ErrorSesion.sinRol;
    _revisarCadena(personaId, leida.$2);
    var vuelta = leida.$2;
    if (rotaAlAbrirAparte) {
      vuelta++;
      _vigente[personaId] = vuelta;
      alRenovar(credencialDe(leida.$1, vuelta: vuelta));
    }
    final sesion = SesionAparteFalsa._(this, leida.$1, vuelta, alRenovar);
    sesionesAparteAbiertas.add(sesion);
    ultimaSesionAparte = sesion;
    return sesion;
  }

  @override
  Future<String?> cerrarSesionDePersona() async {
    final credencial = _credencialActiva;
    _personaActiva = null;
    _credencialActiva = null;
    return credencial;
  }

  @override
  bool get esDemostracion => false;

  /// Cambia la sesión desde la prueba.
  void fijarSesion(Sesion? sesion) => emitir(sesion);

  @override
  Future<Sesion> entrar({
    required String correo,
    required String contrasena,
  }) async {
    vecesEntrar++;
    final sesion = _comprobar(correo, contrasena);
    emitir(sesion);
    return sesion;
  }

  @override
  Future<Sesion> verificarCredenciales({
    required String correo,
    required String contrasena,
  }) async {
    vecesVerificar++;
    return _comprobar(correo, contrasena);
  }

  Sesion _comprobar(String correo, String contrasena) {
    if (sinConexion) throw ErrorSesion.sinConexion;
    final cuenta = cuentas[correo.trim().toLowerCase()];
    if (cuenta == null || cuenta.contrasena != contrasena) {
      throw ErrorSesion.credencialesIncorrectas;
    }
    return cuenta.sesion;
  }

  @override
  Future<void> salir() async {
    vecesSalir++;
    await cerrarSesionDePersona();
    await super.salir();
  }

  @override
  Future<void> cerrar() async {
    await _credenciales.close();
    await super.cerrar();
  }
}

/// Sesión aparte falsa: lleva la credencial vigente y puede simular que el
/// servidor la rota a mitad de la subida.
class SesionAparteFalsa implements SesionAparte {
  SesionAparteFalsa._(
    this._servicio,
    this._sesion,
    this._vuelta,
    this._alRenovar,
  );

  final ServicioSesionFalso _servicio;
  final Sesion _sesion;
  int _vuelta;
  final void Function(String credencial) _alRenovar;
  bool cerrada = false;

  @override
  String get personaId => _sesion.persona.id;

  /// Credencial que sirve ahora.
  String get credencial =>
      ServicioSesionFalso.credencialDe(_sesion, vuelta: _vuelta);

  /// El servidor rota la credencial (token de acceso vencido): se entrega ya.
  void rotar() {
    _vuelta++;
    _servicio._vigente[personaId] = _vuelta;
    _alRenovar(credencial);
  }

  @override
  Future<String?> cerrar() async {
    cerrada = true;
    _servicio.sesionesAparteAbiertas.remove(this);
    return credencial;
  }
}

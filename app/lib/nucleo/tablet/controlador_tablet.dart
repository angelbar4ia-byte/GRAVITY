/// Tablet de la casa (D14): modo Casa por omisión, cambio de usuario con PIN
/// o huella y regreso al modo Casa.
///
/// Fase 0: el cambio de usuario es local (la interfaz se arma con el rol de
/// la persona). El cambio de la sesión del servidor por persona queda
/// pendiente (ver app/README.md).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contratos/roles.dart';
import '../seguridad/pin.dart';
import '../seguridad/proveedores_seguridad.dart';
import '../sesion/proveedores_sesion.dart';
import '../sesion/servicio_sesion_demostracion.dart';
import '../sesion/sesion.dart';
import 'usuarios_tablet.dart';

enum ResultadoDesbloqueo {
  abierto,
  pinIncorrecto,

  /// Demasiados intentos fallidos: se espera un momento.
  bloqueado,
  huellaNoDisponible,
  huellaFallida,
  noExiste,
}

class EstadoTablet {
  const EstadoTablet({
    this.cargado = false,
    this.usuarios = const [],
    this.usuarioActivo,
    this.configuracion = const ConfiguracionTablet(),
  });

  final bool cargado;
  final List<UsuarioTablet> usuarios;

  /// Persona que entró con PIN o huella; `null` en modo Casa.
  final UsuarioTablet? usuarioActivo;
  final ConfiguracionTablet configuracion;

  bool get enModoCasa => usuarioActivo == null;

  EstadoTablet copiarCon({
    bool? cargado,
    List<UsuarioTablet>? usuarios,
    ConfiguracionTablet? configuracion,
  }) => EstadoTablet(
    cargado: cargado ?? this.cargado,
    usuarios: usuarios ?? this.usuarios,
    usuarioActivo: usuarioActivo,
    configuracion: configuracion ?? this.configuracion,
  );

  EstadoTablet conUsuarioActivo(UsuarioTablet? usuario) => EstadoTablet(
    cargado: cargado,
    usuarios: usuarios,
    usuarioActivo: usuario,
    configuracion: configuracion,
  );
}

final controladorTabletProvider =
    NotifierProvider<ControladorTablet, EstadoTablet>(ControladorTablet.new);

class ControladorTablet extends Notifier<EstadoTablet> {
  static const intentosAntesDeBloquear = 5;
  static const duracionBloqueo = Duration(seconds: 30);

  /// PIN de las personas de ejemplo (solo en modo demostración).
  static const pinDeDemostracion = '1234';

  late RepositorioTablet _repositorio;
  Future<void>? _carga;
  final _fallos = <String, int>{};
  final _bloqueadoHasta = <String, DateTime>{};

  @override
  EstadoTablet build() {
    _repositorio = RepositorioTablet(ref.watch(almacenSeguroProvider));
    ref.listen(sesionActualProvider, (anterior, siguiente) {
      if (siguiente == null) volverAModoCasa();
    });
    _carga = _cargar();
    return const EstadoTablet();
  }

  /// Termina cuando se leyeron las personas guardadas.
  Future<void> get listo => _carga ?? Future.value();

  Future<void> _cargar() async {
    var usuarios = await _repositorio.leerUsuarios();
    final configuracion = await _repositorio.leerConfiguracion();
    if (usuarios.isEmpty && ref.read(servicioSesionProvider).esDemostracion) {
      usuarios = _usuariosDeDemostracion();
      await _repositorio.guardarUsuarios(usuarios);
    }
    if (!ref.mounted) return;
    state = state.copiarCon(
      cargado: true,
      usuarios: usuarios,
      configuracion: configuracion,
    );
  }

  List<UsuarioTablet> _usuariosDeDemostracion() => [
    for (final rol in const [
      Rol.dueno,
      Rol.coadministrador,
      Rol.familiar,
      Rol.cuidador,
    ])
      UsuarioTablet.desdeSesion(
        sesionDeEjemplo(rol),
        hashPin: HashPin.crear(pinDeDemostracion),
      ),
  ];

  UsuarioTablet? _buscar(String personaId) =>
      state.usuarios.where((u) => u.personaId == personaId).firstOrNull;

  /// Entra como [personaId] si el PIN coincide. Tras 5 intentos fallidos se
  /// bloquea 30 segundos.
  ResultadoDesbloqueo desbloquearConPin(String personaId, String pin) {
    final usuario = _buscar(personaId);
    if (usuario == null) return ResultadoDesbloqueo.noExiste;
    final ahora = ref.read(relojSeguridadProvider)();
    final hasta = _bloqueadoHasta[personaId];
    if (hasta != null && ahora.isBefore(hasta)) {
      return ResultadoDesbloqueo.bloqueado;
    }
    if (HashPin.verificar(pin, usuario.hashPin)) {
      _fallos.remove(personaId);
      _bloqueadoHasta.remove(personaId);
      state = state.conUsuarioActivo(usuario);
      return ResultadoDesbloqueo.abierto;
    }
    final fallos = (_fallos[personaId] ?? 0) + 1;
    if (fallos >= intentosAntesDeBloquear) {
      _fallos.remove(personaId);
      _bloqueadoHasta[personaId] = ahora.add(duracionBloqueo);
      return ResultadoDesbloqueo.bloqueado;
    }
    _fallos[personaId] = fallos;
    return ResultadoDesbloqueo.pinIncorrecto;
  }

  /// Entra como [personaId] con la huella del dispositivo, si la activó.
  Future<ResultadoDesbloqueo> desbloquearConHuella(String personaId) async {
    final usuario = _buscar(personaId);
    if (usuario == null) return ResultadoDesbloqueo.noExiste;
    final biometria = ref.read(biometriaProvider);
    if (!usuario.huella || !await biometria.disponible()) {
      return ResultadoDesbloqueo.huellaNoDisponible;
    }
    final ok = await biometria.autenticar('Entrar como ${usuario.nombre}');
    if (!ref.mounted) return ResultadoDesbloqueo.huellaFallida;
    if (!ok) return ResultadoDesbloqueo.huellaFallida;
    state = state.conUsuarioActivo(usuario);
    return ResultadoDesbloqueo.abierto;
  }

  /// Regresa al modo Casa (rol Casa, sin dinero ni datos clínicos).
  void volverAModoCasa() {
    if (state.usuarioActivo != null) state = state.conUsuarioActivo(null);
  }

  /// Agrega (o actualiza) a una persona con su PIN. La [sesion] viene del
  /// servidor (`ServicioSesion.verificarCredenciales`), así el rol es real.
  Future<UsuarioTablet> agregarUsuario(
    Sesion sesion, {
    required String pin,
    bool huella = false,
  }) async {
    if (sesion.rol == Rol.casa) {
      throw ArgumentError('La cuenta Casa es el modo Casa: no necesita PIN.');
    }
    if (!pinValido(pin)) {
      throw ArgumentError('El PIN debe tener de 4 a 6 dígitos.');
    }
    await listo;
    final usuario = UsuarioTablet.desdeSesion(
      sesion,
      hashPin: HashPin.crear(pin),
      huella: huella,
    );
    final usuarios = [
      for (final u in state.usuarios)
        if (u.personaId != usuario.personaId) u,
      usuario,
    ];
    await _repositorio.guardarUsuarios(usuarios);
    state = state.copiarCon(usuarios: usuarios);
    return usuario;
  }

  /// Comprueba correo y contraseña de la persona y la agrega con su PIN.
  Future<UsuarioTablet> agregarConCredenciales({
    required String correo,
    required String contrasena,
    required String pin,
    bool huella = false,
  }) async {
    if (!pinValido(pin)) {
      throw ArgumentError('El PIN debe tener de 4 a 6 dígitos.');
    }
    final sesion = await ref
        .read(servicioSesionProvider)
        .verificarCredenciales(correo: correo, contrasena: contrasena);
    return agregarUsuario(sesion, pin: pin, huella: huella);
  }

  Future<void> quitarUsuario(String personaId) async {
    await listo;
    final usuarios = [
      for (final u in state.usuarios)
        if (u.personaId != personaId) u,
    ];
    await _repositorio.guardarUsuarios(usuarios);
    if (state.usuarioActivo?.personaId == personaId) volverAModoCasa();
    state = state.copiarCon(usuarios: usuarios);
  }

  Future<void> cambiarPin(String personaId, String pin) async {
    if (!pinValido(pin)) {
      throw ArgumentError('El PIN debe tener de 4 a 6 dígitos.');
    }
    await _actualizar(
      personaId,
      (u) => u.copiarCon(hashPin: HashPin.crear(pin)),
    );
  }

  Future<void> cambiarHuella(String personaId, {required bool activa}) =>
      _actualizar(personaId, (u) => u.copiarCon(huella: activa));

  Future<void> _actualizar(
    String personaId,
    UsuarioTablet Function(UsuarioTablet) cambio,
  ) async {
    await listo;
    final usuarios = [
      for (final u in state.usuarios)
        u.personaId == personaId ? cambio(u) : u,
    ];
    await _repositorio.guardarUsuarios(usuarios);
    state = state.copiarCon(usuarios: usuarios);
  }

  /// Tiempo sin uso para regresar al modo Casa (de 30 s a 30 min).
  Future<void> fijarRegresoModoCasa(Duration tiempo) async {
    final acotado = tiempo < regresoModoCasaMinimo
        ? regresoModoCasaMinimo
        : (tiempo > regresoModoCasaMaximo ? regresoModoCasaMaximo : tiempo);
    await _guardarConfiguracion(
      state.configuracion.copiarCon(regresoModoCasa: acotado),
    );
  }

  Future<void> elegirContexto(String contexto) =>
      _guardarConfiguracion(state.configuracion.copiarCon(contexto: contexto));

  Future<void> _guardarConfiguracion(ConfiguracionTablet configuracion) async {
    await listo;
    state = state.copiarCon(configuracion: configuracion);
    await _repositorio.guardarConfiguracion(configuracion);
  }
}

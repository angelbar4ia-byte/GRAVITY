/// Tablet de la casa (D14): modo Casa por omisión con la cuenta de rol Casa,
/// cambio de persona con PIN y regreso al modo Casa.
///
/// Revisión de la Fase 0:
/// - I6: al entrar una persona con su PIN, la sesión del **servidor** también
///   cambia a la suya (su credencial va cifrada con su PIN en el
///   almacenamiento seguro) y regresa a la cuenta Casa al salir o tras el
///   tiempo sin uso. Así el servidor aplica sus permisos y la bitácora lleva
///   su nombre (D5).
/// - B3: la huella no abre la tablet compartida; solo el PIN.
/// - I2: los intentos fallidos del PIN se guardan y la espera crece.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contratos/roles.dart';
import '../seguridad/cifrado.dart';
import '../seguridad/intentos.dart';
import '../seguridad/pin.dart';
import '../seguridad/proveedores_seguridad.dart';
import '../sesion/proveedores_sesion.dart';
import '../sesion/servicio_sesion_demostracion.dart';
import '../sesion/sesion.dart';
import 'usuarios_tablet.dart';

enum ResultadoDesbloqueo {
  abierto,
  pinIncorrecto,

  /// Demasiados intentos fallidos: hay que esperar
  /// ([ControladorTablet.esperaRestante]).
  bloqueado,

  /// La tablet compartida no abre con huella (B3): solo con el PIN.
  huellaNoDisponible,

  /// Falta (o venció) la cuenta de la persona en esta tablet: hay que volver
  /// a agregarla con su correo y contraseña.
  faltaCuenta,

  /// El servidor dice que la persona ya no tiene acceso (dada de baja): se
  /// quitó de la tablet.
  sinAcceso,

  /// La tablet no tiene abierta la cuenta Casa (D14).
  requiereCuentaCasa,

  /// No se pudo comprobar la cuenta en el servidor; se puede reintentar.
  error,

  /// Se volvió al modo Casa mientras la persona entraba.
  cancelado,
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

  /// Persona que entró con su PIN; `null` en modo Casa.
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

  /// Espera del primer bloqueo; se duplica en cada bloqueo siguiente.
  static const duracionBloqueo = Duration(seconds: 30);
  static const duracionBloqueoMaxima = Duration(minutes: 15);
  static const politicaIntentos = PoliticaIntentos(
    intentosAntesDeBloquear: intentosAntesDeBloquear,
    primeraEspera: duracionBloqueo,
    esperaMaxima: duracionBloqueoMaxima,
  );

  /// PIN de las personas de ejemplo (solo en modo demostración).
  static const pinDeDemostracion = '1234';

  late RepositorioTablet _repositorio;
  late LimiteIntentos _intentos;
  Future<void>? _carga;

  // Persona dentro: la llave de su PIN vive en memoria solo mientras está
  // dentro, para volver a cifrar su credencial cuando el servidor la renueva.
  LlavePin? _llave;
  String? _personaConLlave;
  StreamSubscription<String?>? _renovaciones;
  int _generacion = 0;
  Future<ResultadoDesbloqueo>? _entrada;
  Future<void> _cambios = Future.value();

  @override
  EstadoTablet build() {
    final almacen = ref.watch(almacenSeguroProvider);
    _repositorio = RepositorioTablet(almacen);
    _intentos = LimiteIntentos(
      almacen,
      clave: RepositorioTablet.claveIntentos,
      politica: politicaIntentos,
      reloj: () => ref.read(relojSeguridadProvider)(),
    );
    ref.listen(sesionActualProvider, (anterior, siguiente) {
      // Se cerró (o cambió) la cuenta de la tablet: nadie queda dentro.
      if (siguiente?.persona.id != anterior?.persona.id) volverAModoCasa();
    });
    ref.onDispose(() {
      _renovaciones?.cancel();
      _llave?.olvidar();
    });
    _carga = _cargar();
    return const EstadoTablet();
  }

  /// Termina cuando se leyeron las personas guardadas.
  Future<void> get listo => _carga ?? Future.value();

  /// Termina cuando la sesión del servidor terminó de cambiar (entrar o
  /// volver a la cuenta Casa).
  Future<void> get cambiosEnServidor => _cambios;

  Future<void> _cargar() async {
    var usuarios = await _repositorio.leerUsuarios();
    final configuracion = await _repositorio.leerConfiguracion();
    await _intentos.cargar();
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

  /// Cuánto falta para que [personaId] pueda intentar su PIN otra vez, o
  /// `null` si no está bloqueada.
  Duration? esperaRestante(String personaId) =>
      _intentos.esperaRestante(personaId);

  /// Comprueba el PIN de [personaId] y, si es correcto, empieza a entrar
  /// (ver [entrarConPin], que espera a que la sesión del servidor cambie).
  /// Tras 5 fallos seguidos se bloquea 30 s; cada bloqueo siguiente dura el
  /// doble, hasta 15 min. Los fallos sobreviven al reinicio de la app.
  ResultadoDesbloqueo desbloquearConPin(String personaId, String pin) {
    final usuario = _buscar(personaId);
    if (usuario == null) return ResultadoDesbloqueo.noExiste;
    if (_intentos.bloqueado(personaId)) return ResultadoDesbloqueo.bloqueado;
    if (!HashPin.verificar(pin, usuario.hashPin)) {
      return _intentos.anotarFallo(personaId) == ResultadoFallo.bloqueado
          ? ResultadoDesbloqueo.bloqueado
          : ResultadoDesbloqueo.pinIncorrecto;
    }
    _intentos.anotarAcierto(personaId);
    _entrada = _entrar(usuario, pin);
    return ResultadoDesbloqueo.abierto;
  }

  /// Entra como [personaId] con su PIN: la interfaz se arma con su rol cuando
  /// la sesión del servidor ya es la suya (o sin señal, con su credencial
  /// guardada).
  Future<ResultadoDesbloqueo> entrarConPin(String personaId, String pin) async {
    final resultado = desbloquearConPin(personaId, pin);
    if (resultado != ResultadoDesbloqueo.abierto) return resultado;
    return _entrada!;
  }

  bool _vigente(int generacion) => ref.mounted && generacion == _generacion;

  Future<ResultadoDesbloqueo> _entrar(UsuarioTablet usuario, String pin) async {
    final generacion = ++_generacion;
    final servicio = ref.read(servicioSesionProvider);
    if (servicio is! SesionesPorPersona) {
      // Sin servidor (demostración): solo cambia la interfaz.
      state = state.conUsuarioActivo(usuario);
      return ResultadoDesbloqueo.abierto;
    }
    final sesiones = servicio as SesionesPorPersona;
    if (ref.read(sesionActualProvider)?.rol != Rol.casa) {
      return ResultadoDesbloqueo.requiereCuentaCasa;
    }
    final guardada = await _repositorio.leerCredencial(usuario.personaId, pin);
    if (guardada == null) return ResultadoDesbloqueo.faltaCuenta;
    final (llave, credencial) = guardada;

    final AperturaPersona apertura;
    try {
      apertura = await _enSerie(
        () => sesiones.abrirSesionDePersona(usuario.personaId, credencial),
      );
    } on ErrorSesion catch (error) {
      llave.olvidar();
      if (error == ErrorSesion.sinRol) {
        // Dada de baja: pierde el acceso de inmediato (D5).
        await quitarUsuario(usuario.personaId);
        return ResultadoDesbloqueo.sinAcceso;
      }
      if (error == ErrorSesion.credencialVencida) {
        await _repositorio.borrarCredencial(usuario.personaId);
        return ResultadoDesbloqueo.faltaCuenta;
      }
      return ResultadoDesbloqueo.error;
    }
    await _repositorio.guardarCredencial(
      usuario.personaId,
      llave,
      apertura.credencial,
    );

    if (!_vigente(generacion)) {
      // Se volvió al modo Casa mientras entraba: se regresa a la cuenta Casa.
      await _enSerie(() => _cerrarEnServidor(sesiones, usuario.personaId, llave));
      return ResultadoDesbloqueo.cancelado;
    }

    var activo = usuario;
    final vigente = apertura.sesion;
    if (vigente != null &&
        (vigente.rol != usuario.rol ||
            vigente.persona.nombre != usuario.nombre ||
            vigente.hogarId != usuario.hogarId)) {
      // El rol lo dice el servidor, no lo guardado en la tablet.
      activo = usuario.copiarCon(sesion: vigente);
      await _guardarUsuarios([
        for (final u in state.usuarios) u.personaId == activo.personaId ? activo : u,
      ]);
      if (!_vigente(generacion)) {
        await _enSerie(
          () => _cerrarEnServidor(sesiones, usuario.personaId, llave),
        );
        return ResultadoDesbloqueo.cancelado;
      }
    }
    _llave = llave;
    _personaConLlave = usuario.personaId;
    _renovaciones = sesiones.credencialesDePersona.listen(_alRenovar);
    state = state.conUsuarioActivo(activo);
    return ResultadoDesbloqueo.abierto;
  }

  void _alRenovar(String? credencial) {
    final persona = _personaConLlave;
    final llave = _llave;
    if (persona == null || llave == null) return;
    if (credencial == null) {
      // El servidor cerró la sesión de la persona: su credencial ya no sirve.
      unawaited(_repositorio.borrarCredencial(persona));
      volverAModoCasa();
      return;
    }
    unawaited(_repositorio.guardarCredencial(persona, llave, credencial));
  }

  Future<void> _cerrarEnServidor(
    SesionesPorPersona sesiones,
    String personaId,
    LlavePin llave,
  ) async {
    final credencial = await sesiones.cerrarSesionDePersona();
    if (credencial != null) {
      await _repositorio.guardarCredencial(personaId, llave, credencial);
    }
    llave.olvidar();
  }

  /// Abrir y cerrar en el servidor van uno tras otro, nunca a la vez.
  Future<T> _enSerie<T>(Future<T> Function() tarea) {
    final resultado = _cambios.then((_) => tarea());
    _cambios = resultado.then((_) {}, onError: (Object _) {});
    return resultado;
  }

  /// La tablet compartida **no** abre con huella (revisión de la Fase 0, B3;
  /// D14): Android acepta cualquier dedo registrado en el equipo y no dice de
  /// quién es. Solo el PIN identifica a la persona; la huella sirve para el
  /// bloqueo del teléfono personal.
  Future<ResultadoDesbloqueo> desbloquearConHuella(String personaId) async =>
      _buscar(personaId) == null
      ? ResultadoDesbloqueo.noExiste
      : ResultadoDesbloqueo.huellaNoDisponible;

  /// Regresa al modo Casa (rol Casa, sin dinero ni datos clínicos) y la
  /// sesión del servidor a la cuenta Casa.
  void volverAModoCasa() {
    _generacion++;
    if (state.usuarioActivo != null) state = state.conUsuarioActivo(null);
    final persona = _personaConLlave;
    final llave = _llave;
    _personaConLlave = null;
    _llave = null;
    unawaited(_renovaciones?.cancel());
    _renovaciones = null;
    final servicio = ref.read(servicioSesionProvider);
    if (persona != null && llave != null && servicio is SesionesPorPersona) {
      unawaited(
        _enSerie(
          () => _cerrarEnServidor(servicio as SesionesPorPersona, persona, llave),
        ),
      );
    }
  }

  /// Agrega (o actualiza) a una persona con su PIN. La [sesion] viene del
  /// servidor, así el rol es real; la [credencial] (su sesión del servidor) se
  /// guarda cifrada con el PIN.
  Future<UsuarioTablet> agregarUsuario(
    Sesion sesion, {
    required String pin,
    String? credencial,
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
    );
    if (credencial != null) {
      final llave = LlavePin.derivar(pin);
      await _repositorio.guardarCredencial(usuario.personaId, llave, credencial);
      llave.olvidar();
    } else {
      // Una credencial anterior ya no abre con el PIN nuevo.
      await _repositorio.borrarCredencial(usuario.personaId);
    }
    _intentos.olvidar(usuario.personaId);
    await _guardarUsuarios([
      for (final u in state.usuarios)
        if (u.personaId != usuario.personaId) u,
      usuario,
    ]);
    return usuario;
  }

  /// Comprueba correo y contraseña de la persona en el servidor y la agrega
  /// con su PIN (y, con servidor, con su credencial para entrar después).
  Future<UsuarioTablet> agregarConCredenciales({
    required String correo,
    required String contrasena,
    required String pin,
  }) async {
    if (!pinValido(pin)) {
      throw ArgumentError('El PIN debe tener de 4 a 6 dígitos.');
    }
    final servicio = ref.read(servicioSesionProvider);
    if (servicio is SesionesPorPersona) {
      final obtenida = await (servicio as SesionesPorPersona).obtenerCredencial(
        correo: correo,
        contrasena: contrasena,
      );
      return agregarUsuario(
        obtenida.sesion,
        pin: pin,
        credencial: obtenida.credencial,
      );
    }
    final sesion = await servicio.verificarCredenciales(
      correo: correo,
      contrasena: contrasena,
    );
    return agregarUsuario(sesion, pin: pin);
  }

  Future<void> quitarUsuario(String personaId) async {
    await listo;
    if (_personaConLlave == personaId ||
        state.usuarioActivo?.personaId == personaId) {
      volverAModoCasa();
      await _cambios;
    }
    await _repositorio.borrarCredencial(personaId);
    _intentos.olvidar(personaId);
    await _guardarUsuarios([
      for (final u in state.usuarios)
        if (u.personaId != personaId) u,
    ]);
  }

  /// Cambia el PIN de la persona. Pide su PIN actual: con él se descifra su
  /// credencial y se vuelve a cifrar con el nuevo. Si lo olvidó, se quita de
  /// la tablet y se agrega otra vez con su correo y contraseña.
  Future<ResultadoDesbloqueo> cambiarPin(
    String personaId, {
    required String pinActual,
    required String pinNuevo,
  }) async {
    if (!pinValido(pinNuevo)) {
      throw ArgumentError('El PIN debe tener de 4 a 6 dígitos.');
    }
    await listo;
    final usuario = _buscar(personaId);
    if (usuario == null) return ResultadoDesbloqueo.noExiste;
    if (_intentos.bloqueado(personaId)) return ResultadoDesbloqueo.bloqueado;
    if (!HashPin.verificar(pinActual, usuario.hashPin)) {
      return _intentos.anotarFallo(personaId) == ResultadoFallo.bloqueado
          ? ResultadoDesbloqueo.bloqueado
          : ResultadoDesbloqueo.pinIncorrecto;
    }
    _intentos.anotarAcierto(personaId);
    final guardada = await _repositorio.leerCredencial(personaId, pinActual);
    if (guardada != null) {
      final llaveNueva = LlavePin.derivar(pinNuevo);
      await _repositorio.guardarCredencial(personaId, llaveNueva, guardada.$2);
      guardada.$1.olvidar();
      if (_personaConLlave == personaId) {
        _llave?.olvidar();
        _llave = llaveNueva;
      } else {
        llaveNueva.olvidar();
      }
    }
    await _guardarUsuarios([
      for (final u in state.usuarios)
        u.personaId == personaId
            ? u.copiarCon(hashPin: HashPin.crear(pinNuevo))
            : u,
    ]);
    return ResultadoDesbloqueo.abierto;
  }

  Future<void> _guardarUsuarios(List<UsuarioTablet> usuarios) async {
    await _repositorio.guardarUsuarios(usuarios);
    if (ref.mounted) state = state.copiarCon(usuarios: usuarios);
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

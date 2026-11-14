/// Tablets (D14): cambio de persona con PIN y regreso al reposo.
///
/// Dos tipos (21/oct/2026), con la cuenta de rol Casa como cuenta del equipo:
/// - **Pública de la casa:** en reposo, modo Casa. Leer no pide identidad;
///   registrar algo de la casa pide elegir el nombre (sin PIN) y registrar
///   algo personal pide nombre y PIN solo para esa acción
///   ([entrarParaAccion]).
/// - **Personal** (dueño y pareja): en reposo, pantalla de bloqueo con las
///   personas permitidas; sin modo Casa.
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
import 'dart:math' show min;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cola/bandeja_salida.dart';
import '../contratos/roles.dart';
import '../seguridad/cifrado.dart';
import '../seguridad/intentos.dart';
import '../seguridad/pin.dart';
import '../seguridad/proveedores_seguridad.dart';
import '../seguridad/serie_pin.dart';
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

  /// Tablet personal: la persona no está entre las permitidas.
  noPermitida,

  /// El PIN es el correcto, pero quien ve dinero ahora lo necesita de 6
  /// dígitos (D18, 23/oct): no entra todavía; debe elegir uno nuevo
  /// ([ControladorTablet.cambiarPinYEntrar]). Su cuenta guardada y su
  /// bandeja de salida se conservan: el cambio las vuelve a cifrar.
  debeCambiarPin,
}

class EstadoTablet {
  const EstadoTablet({
    this.cargado = false,
    this.usuarios = const [],
    this.usuarioActivo,
    this.configuracion = const ConfiguracionTablet(),
    this.soloAccion = false,
  });

  final bool cargado;
  final List<UsuarioTablet> usuarios;

  /// Persona que entró con su PIN; `null` en reposo (modo Casa o bloqueo).
  final UsuarioTablet? usuarioActivo;
  final ConfiguracionTablet configuracion;

  /// Tablet pública: la persona entró solo para **una acción** personal (un
  /// gasto, un hábito…). La pantalla sigue en el modo Casa y, al terminar la
  /// acción o tras el tiempo sin uso, vuelve al reposo.
  final bool soloAccion;

  /// `true` si nadie está dentro (modo Casa en la pública, bloqueo en la
  /// personal).
  bool get enModoCasa => usuarioActivo == null;

  /// `true` si la pantalla muestra el reposo de la tablet pública (modo
  /// Casa), también durante una acción personal.
  bool get muestraModoCasa =>
      !configuracion.esPersonal && (enModoCasa || soloAccion);

  /// `true` si la tablet personal está bloqueada (nadie dentro).
  bool get bloqueada => configuracion.esPersonal && enModoCasa;

  /// Personas que se muestran para entrar (en la personal, solo las
  /// permitidas).
  List<UsuarioTablet> get usuariosQuePuedenEntrar => [
    for (final usuario in usuarios)
      if (puedeEntrarEnTablet(usuario, configuracion)) usuario,
  ];

  EstadoTablet copiarCon({
    bool? cargado,
    List<UsuarioTablet>? usuarios,
    ConfiguracionTablet? configuracion,
  }) => EstadoTablet(
    cargado: cargado ?? this.cargado,
    usuarios: usuarios ?? this.usuarios,
    usuarioActivo: usuarioActivo,
    configuracion: configuracion ?? this.configuracion,
    soloAccion: soloAccion,
  );

  EstadoTablet conUsuarioActivo(
    UsuarioTablet? usuario, {
    bool soloAccion = false,
  }) => EstadoTablet(
    cargado: cargado,
    usuarios: usuarios,
    usuarioActivo: usuario,
    configuracion: configuracion,
    soloAccion: usuario != null && soloAccion,
  );
}

/// Ganchos de la entrada y la salida de una persona con su PIN en la tablet.
/// La app los conecta con lo que necesita el PIN en memoria: abrir las llaves
/// de los datos sensibles de Hábitos en la tablet personal (D21) y cerrarlas al
/// salir. Sin conexión, no pasa nada.
final alEntrarConPinProvider =
    Provider<Future<void> Function(String personaId, String pin)?>(
      (ref) => null,
    );
final alSalirDeLaTabletProvider = Provider<void Function(String personaId)?>(
  (ref) => null,
);

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

  /// PIN de las personas de ejemplo (solo en modo demostración). Es de 6
  /// dígitos y no trivial: así sirve también para el dueño y la pareja.
  static const pinDeDemostracion = '246813';

  late RepositorioTablet _repositorio;
  late LimiteIntentos _intentos;

  /// Una verificación de PIN a la vez (los fallos se cuentan en fila).
  final _serie = SerieDePin();
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
        // Solo demostración (sin servidor): pocas vueltas para no congelar el
        // arranque; se rehace con las de hoy al entrar.
        hashPin: HashPin.crear(
          pinDeDemostracion,
          iteraciones: min(
            HashPin.iteracionesPorDefecto,
            HashPin.iteracionesAnteriores,
          ),
        ),
      ),
  ];

  UsuarioTablet? _buscar(String personaId) =>
      state.usuarios.where((u) => u.personaId == personaId).firstOrNull;

  /// Cuánto falta para que [personaId] pueda intentar su PIN otra vez, o
  /// `null` si no está bloqueada.
  Duration? esperaRestante(String personaId) =>
      _intentos.esperaRestante(personaId);

  /// Comprueba el PIN de [personaId] **sin entrar ni cambiar nada** (p. ej.
  /// para volver a ver los montos, que se ocultan solos tras unos minutos sin
  /// uso). Cuenta los intentos fallidos igual que al entrar: la espera crece y
  /// la comparten los dos caminos.
  Future<ResultadoDesbloqueo> comprobarPin(String personaId, String pin) =>
      _serie.correr(() async {
        final usuario = _buscar(personaId);
        if (usuario == null) return ResultadoDesbloqueo.noExiste;
        if (_intentos.bloqueado(personaId)) {
          return ResultadoDesbloqueo.bloqueado;
        }
        if (!await HashPin.verificarAsync(pin, usuario.hashPin)) {
          return _intentos.anotarFallo(personaId) == ResultadoFallo.bloqueado
              ? ResultadoDesbloqueo.bloqueado
              : ResultadoDesbloqueo.pinIncorrecto;
        }
        _intentos.anotarAcierto(personaId);
        if (pinEsCortoParaSuRol(usuario.rol, pin)) {
          return ResultadoDesbloqueo.debeCambiarPin;
        }
        return ResultadoDesbloqueo.abierto;
      });

  /// Comprueba el PIN de [personaId] y, si es correcto, empieza a entrar
  /// (ver [entrarConPin], que espera a que la sesión del servidor cambie).
  /// Tras 5 fallos seguidos se bloquea 30 s; cada bloqueo siguiente dura el
  /// doble, hasta 15 min. Los fallos sobreviven al reinicio de la app.
  ///
  /// La derivación del PIN corre en un hilo aparte: devuelve un [Future]. Las
  /// verificaciones van en fila ([SerieDePin]) para que los fallos se cuenten
  /// uno tras otro.
  Future<ResultadoDesbloqueo> desbloquearConPin(
    String personaId,
    String pin, {
    bool soloAccion = false,
  }) => _serie.correr(() async {
    final usuario = _buscar(personaId);
    if (usuario == null) return ResultadoDesbloqueo.noExiste;
    if (!puedeEntrarEnTablet(usuario, state.configuracion)) {
      return ResultadoDesbloqueo.noPermitida;
    }
    if (_intentos.bloqueado(personaId)) return ResultadoDesbloqueo.bloqueado;
    if (!await HashPin.verificarAsync(pin, usuario.hashPin)) {
      return _intentos.anotarFallo(personaId) == ResultadoFallo.bloqueado
          ? ResultadoDesbloqueo.bloqueado
          : ResultadoDesbloqueo.pinIncorrecto;
    }
    _intentos.anotarAcierto(personaId);
    // D18 (23/oct): quien ve dinero necesita un PIN de 6 dígitos. Con uno más
    // corto no entra todavía: primero lo cambia (cambiarPinYEntrar).
    if (pinEsCortoParaSuRol(usuario.rol, pin)) {
      return ResultadoDesbloqueo.debeCambiarPin;
    }
    _entrada = _entrar(usuario, pin, soloAccion: soloAccion);
    return ResultadoDesbloqueo.abierto;
  });

  /// Entra como [personaId] con su PIN: la interfaz se arma con su rol cuando
  /// la sesión del servidor ya es la suya (o sin señal, con su credencial
  /// guardada).
  Future<ResultadoDesbloqueo> entrarConPin(String personaId, String pin) async {
    final resultado = await desbloquearConPin(personaId, pin);
    if (resultado != ResultadoDesbloqueo.abierto) return resultado;
    return _entrada!;
  }

  /// Tablet pública: la persona se identifica con nombre y PIN **solo para
  /// una acción** personal (un gasto, un hábito, algo de Cuidados). La
  /// pantalla sigue en el modo Casa; quien abre la acción llama a
  /// [volverAModoCasa] al terminarla, y si no, el tiempo sin uso lo hace.
  Future<ResultadoDesbloqueo> entrarParaAccion(
    String personaId,
    String pin,
  ) async {
    if (state.configuracion.esPersonal) {
      return entrarConPin(personaId, pin);
    }
    final resultado = await desbloquearConPin(personaId, pin, soloAccion: true);
    if (resultado != ResultadoDesbloqueo.abierto) return resultado;
    return _entrada!;
  }

  /// Migración del PIN corto (D18, 23/oct): quien ve dinero y entró con un PIN
  /// de menos de 6 dígitos ([ResultadoDesbloqueo.debeCambiarPin]) elige uno
  /// nuevo y entra. [cambiarPin] vuelve a cifrar su credencial y, si salió con
  /// algo por subir, la llave de su bandeja de salida; nada se pierde.
  Future<ResultadoDesbloqueo> cambiarPinYEntrar(
    String personaId, {
    required String pinActual,
    required String pinNuevo,
    bool paraAccion = false,
  }) async {
    final cambio = await cambiarPin(
      personaId,
      pinActual: pinActual,
      pinNuevo: pinNuevo,
    );
    if (cambio != ResultadoDesbloqueo.abierto) return cambio;
    return paraAccion
        ? entrarParaAccion(personaId, pinNuevo)
        : entrarConPin(personaId, pinNuevo);
  }

  bool _vigente(int generacion) => ref.mounted && generacion == _generacion;

  Future<ResultadoDesbloqueo> _entrar(
    UsuarioTablet usuario,
    String pin, {
    bool soloAccion = false,
  }) async {
    final generacion = ++_generacion;
    final servicio = ref.read(servicioSesionProvider);
    if (servicio is! SesionesPorPersona) {
      // Sin servidor (demostración): solo cambia la interfaz.
      state = state.conUsuarioActivo(usuario, soloAccion: soloAccion);
      return ResultadoDesbloqueo.abierto;
    }
    final sesiones = servicio as SesionesPorPersona;
    if (ref.read(sesionActualProvider)?.rol != Rol.casa) {
      return ResultadoDesbloqueo.requiereCuentaCasa;
    }
    // Si la persona salió con algo por subir, su credencial más reciente está
    // en la bandeja de salida (se mueve, no se copia): vuelve al sobre de su
    // PIN ahora que lo tenemos.
    final bandeja = ref.read(bandejaDeLaTabletProvider);
    final delaBandeja = bandeja == null
        ? null
        : await bandeja.tomarParaEntrada(usuario.personaId, pin);
    final (LlavePin, String)? guardada;
    if (delaBandeja != null) {
      final llaveNueva = await LlavePin.derivarAsync(pin);
      await _repositorio.guardarCredencial(
        usuario.personaId,
        llaveNueva,
        delaBandeja,
      );
      guardada = (llaveNueva, delaBandeja);
    } else {
      guardada = await _repositorio.leerCredencial(usuario.personaId, pin);
    }
    if (guardada == null) return ResultadoDesbloqueo.faltaCuenta;
    var (llave, credencial) = guardada;
    // M9': un sobre hecho con menos vueltas de PBKDF2 (los de antes, de 10 000)
    // se vuelve a cifrar con las de hoy; es el único momento en que se tiene el
    // PIN. La credencial es la misma; solo cambia la llave que la protege.
    if (llave.iteraciones < HashPin.iteracionesPorDefecto) {
      final nueva = await LlavePin.derivarAsync(pin);
      llave.olvidar();
      llave = nueva;
    }

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
      await _enSerie(
        () => _cerrarEnServidor(sesiones, usuario.personaId, llave),
      );
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
        for (final u in state.usuarios)
          u.personaId == activo.personaId ? activo : u,
      ]);
      if (!_vigente(generacion)) {
        await _enSerie(
          () => _cerrarEnServidor(sesiones, usuario.personaId, llave),
        );
        return ResultadoDesbloqueo.cancelado;
      }
    }
    if (activo.rol != usuario.rol && pinEsCortoParaSuRol(activo.rol, pin)) {
      // El servidor le dio un rol que ve dinero y su PIN es corto: no entra
      // (se regresa a la cuenta Hogar) hasta que lo cambie.
      await _enSerie(
        () => _cerrarEnServidor(sesiones, usuario.personaId, llave),
      );
      return ResultadoDesbloqueo.debeCambiarPin;
    }
    // Lo mismo con el hash del PIN guardado (verifica sin abrir el sobre).
    if (HashPin.necesitaActualizarse(usuario.hashPin)) {
      final rehecho = activo.copiarCon(hashPin: await HashPin.crearAsync(pin));
      activo = rehecho;
      await _guardarUsuarios([
        for (final u in state.usuarios)
          u.personaId == rehecho.personaId ? rehecho : u,
      ]);
    }
    try {
      await ref.read(alEntrarConPinProvider)?.call(usuario.personaId, pin);
    } catch (_) {
      // Las llaves de Hábitos no se abrieron: lo reservado pedirá el PIN.
    }
    _llave = llave;
    _personaConLlave = usuario.personaId;
    _renovaciones = sesiones.credencialesDePersona.listen(_alRenovar);
    state = state.conUsuarioActivo(activo, soloAccion: soloAccion);
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
      final bandeja = ref.mounted ? ref.read(bandejaDeLaTabletProvider) : null;
      if (bandeja != null && await bandeja.hayPendientesDe(personaId)) {
        // Sale con algo por subir (sin señal): su credencial pasa a la bandeja
        // de salida para que se suba sola, sin pedir el PIN otra vez. Se
        // MUEVE: el sobre del PIN se borra, porque dos copias se estorban (el
        // servidor rota el refresh token al usarlo).
        await bandeja.delegar(personaId, credencial, llave);
        await _repositorio.borrarCredencial(personaId);
      } else {
        await _repositorio.guardarCredencial(personaId, llave, credencial);
      }
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

  /// Regresa al reposo y la sesión del servidor a la cuenta Casa: en la
  /// tablet pública, al modo Casa (rol Casa, sin dinero ni datos clínicos); en
  /// la personal, a la pantalla de bloqueo.
  void volverAlReposo() => volverAModoCasa();

  /// Igual que [volverAlReposo] (nombre de la Fase 0).
  void volverAModoCasa() {
    _generacion++;
    if (state.usuarioActivo != null) state = state.conUsuarioActivo(null);
    final persona = _personaConLlave;
    final llave = _llave;
    if (persona != null) ref.read(alSalirDeLaTabletProvider)?.call(persona);
    _personaConLlave = null;
    _llave = null;
    unawaited(_renovaciones?.cancel());
    _renovaciones = null;
    final servicio = ref.read(servicioSesionProvider);
    if (persona != null && llave != null && servicio is SesionesPorPersona) {
      unawaited(
        _enSerie(
          () =>
              _cerrarEnServidor(servicio as SesionesPorPersona, persona, llave),
        ),
      );
    }
  }

  /// Agrega (o actualiza) a una persona con su PIN. La [sesion] viene del
  /// servidor, así el rol es real; la [credencial] (su sesión del servidor) se
  /// guarda cifrada con el PIN. Revisa el formato y el largo del PIN: que no sea
  /// trivial se exige donde la persona lo elige ([agregarConCredenciales] y
  /// [cambiarPin]). El largo sí se exige aquí, con el rol real: 6 dígitos si
  /// la persona ve dinero (D18, 23/oct).
  Future<UsuarioTablet> agregarUsuario(
    Sesion sesion, {
    required String pin,
    String? credencial,
  }) async {
    if (sesion.rol == Rol.casa) {
      throw ArgumentError('La cuenta Casa es el modo Casa: no necesita PIN.');
    }
    if (!pinValidoPara(sesion.rol, pin)) {
      throw ArgumentError(_textoPinInvalido(sesion.rol));
    }
    await listo;
    final usuario = UsuarioTablet.desdeSesion(
      sesion,
      hashPin: await HashPin.crearAsync(pin),
    );
    // Volver a agregar a alguien trae una credencial nueva (otra cadena de
    // renovación): el permiso de subida viejo, si lo había, no debe pisarla al
    // entrar (B5 de la revisión de la Fase 1b). Lo que tenía por subir se
    // conserva y sube con su sesión nueva.
    await ref
        .read(bandejaDeLaTabletProvider)
        ?.alAgregarDeNuevo(usuario.personaId);
    if (credencial != null) {
      final llave = await LlavePin.derivarAsync(pin);
      await _repositorio.guardarCredencial(
        usuario.personaId,
        llave,
        credencial,
      );
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
    // En la tablet personal, el dueño o la pareja que se agrega puede entrar.
    final configuracion = state.configuracion;
    if (configuracion.esPersonal &&
        rolesDeTabletPersonal.contains(usuario.rol)) {
      await _guardarConfiguracion(
        configuracion.copiarCon(
          permitidas: {...configuracion.permitidas, usuario.personaId},
        ),
      );
    }
    return usuario;
  }

  static String _textoPinInvalido(Rol? rol) => rol != null && rolVeDinero(rol)
      ? 'Quien ve dinero usa un PIN de 6 dígitos.'
      : 'El PIN debe tener de 4 a 6 dígitos.';

  /// Un PIN que la persona **elige** debe tener el largo de su rol (6 dígitos
  /// si ve dinero; si no, de 4 a 6) y no ser trivial (`0000`, `1234`,
  /// repetidos, secuencias: M9). Lanza [ArgumentError] con el motivo para
  /// mostrar. Con [rol] `null` (aún no se sabe cuál será) solo exige el
  /// formato general; el largo del rol se exige al conocerlo.
  static void _exigirPinNuevo(String pin, {Rol? rol}) {
    final error = errorDePinNuevo(pin, rol: rol);
    if (error != null) {
      throw ArgumentError(pinValido(pin) ? error : _textoPinInvalido(rol));
    }
  }

  /// Comprueba correo y contraseña de la persona en el servidor y la agrega
  /// con su PIN (y, con servidor, con su credencial para entrar después).
  Future<UsuarioTablet> agregarConCredenciales({
    required String correo,
    required String contrasena,
    required String pin,
  }) async {
    _exigirPinNuevo(pin);
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
    // Su permiso de subida (si salió con algo pendiente) también se borra, y lo
    // que no alcanzó a subir queda en "requiere atención".
    await ref.read(bandejaDeLaTabletProvider)?.alQuitarPersona(personaId);
    // M5: lo guardado de la persona (copias locales de los módulos) tampoco
    // se queda en la tablet.
    await ref.read(limpiezaLocalProvider).alQuitarPersona(personaId);
    await _guardarUsuarios([
      for (final u in state.usuarios)
        if (u.personaId != personaId) u,
    ]);
    if (state.configuracion.permitidas.contains(personaId)) {
      await _guardarConfiguracion(
        state.configuracion.copiarCon(
          permitidas: {...state.configuracion.permitidas}..remove(personaId),
        ),
      );
    }
  }

  /// Cambia el PIN de la persona. Pide su PIN actual: con él se descifra su
  /// credencial y se vuelve a cifrar con el nuevo. Si lo olvidó, se quita de
  /// la tablet y se agrega otra vez con su correo y contraseña.
  Future<ResultadoDesbloqueo> cambiarPin(
    String personaId, {
    required String pinActual,
    required String pinNuevo,
  }) async {
    await listo;
    final usuario = _buscar(personaId);
    if (usuario == null) return ResultadoDesbloqueo.noExiste;
    _exigirPinNuevo(pinNuevo, rol: usuario.rol);
    // El límite se revisa dentro de la fila (F4-S1).
    final fallo = await _serie.correr<ResultadoDesbloqueo?>(() async {
      if (_intentos.bloqueado(personaId)) return ResultadoDesbloqueo.bloqueado;
      if (!await HashPin.verificarAsync(pinActual, usuario.hashPin)) {
        return _intentos.anotarFallo(personaId) == ResultadoFallo.bloqueado
            ? ResultadoDesbloqueo.bloqueado
            : ResultadoDesbloqueo.pinIncorrecto;
      }
      _intentos.anotarAcierto(personaId);
      return null;
    });
    if (fallo != null) return fallo;
    // Si su credencial está en la bandeja, la llave que la protege pasa al PIN
    // nuevo (si no, el próximo PIN no podría abrirla).
    await ref
        .read(bandejaDeLaTabletProvider)
        ?.cambiarPin(personaId, pinActual, pinNuevo);
    final guardada = await _repositorio.leerCredencial(personaId, pinActual);
    if (guardada != null) {
      final llaveNueva = await LlavePin.derivarAsync(pinNuevo);
      await _repositorio.guardarCredencial(personaId, llaveNueva, guardada.$2);
      guardada.$1.olvidar();
      if (_personaConLlave == personaId) {
        _llave?.olvidar();
        _llave = llaveNueva;
      } else {
        llaveNueva.olvidar();
      }
    }
    final hashNuevo = await HashPin.crearAsync(pinNuevo);
    await _guardarUsuarios([
      for (final u in state.usuarios)
        u.personaId == personaId ? u.copiarCon(hashPin: hashNuevo) : u,
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

  /// Cambia el tipo de tablet (Ajustes › Dispositivos). Al pasar a personal,
  /// quien está dentro (si es dueño o pareja) queda permitido, para que la
  /// tablet no quede bloqueada sin nadie que pueda entrar.
  Future<void> elegirTipo(TipoTablet tipo) async {
    await listo;
    final actual = state.configuracion;
    if (actual.tipo == tipo) return;
    final activo = state.usuarioActivo;
    final permitidas = {
      for (final id in actual.permitidas)
        if (state.usuarios.any(
          (u) => u.personaId == id && rolesDeTabletPersonal.contains(u.rol),
        ))
          id,
      if (tipo == TipoTablet.personal &&
          activo != null &&
          rolesDeTabletPersonal.contains(activo.rol))
        activo.personaId,
    };
    await _guardarConfiguracion(
      actual.copiarCon(tipo: tipo, permitidas: permitidas),
    );
    // Quien entró solo para una acción en la pública no sigue dentro.
    if (state.soloAccion) volverAlReposo();
  }

  /// Permite (o no) que [personaId] entre a la tablet personal. Solo dueño y
  /// pareja ([rolesDeTabletPersonal]).
  Future<void> permitir(String personaId, {required bool permitida}) async {
    await listo;
    final usuario = _buscar(personaId);
    if (usuario == null) return;
    if (permitida && !rolesDeTabletPersonal.contains(usuario.rol)) {
      throw ArgumentError(
        'En la tablet personal solo entran el dueño y la pareja.',
      );
    }
    final permitidas = {...state.configuracion.permitidas};
    permitida ? permitidas.add(personaId) : permitidas.remove(personaId);
    await _guardarConfiguracion(
      state.configuracion.copiarCon(permitidas: permitidas),
    );
    if (!permitida && state.usuarioActivo?.personaId == personaId) {
      volverAlReposo();
    }
  }

  Future<void> _guardarConfiguracion(ConfiguracionTablet configuracion) async {
    await listo;
    state = state.copiarCon(configuracion: configuracion);
    await _repositorio.guardarConfiguracion(configuracion);
  }
}

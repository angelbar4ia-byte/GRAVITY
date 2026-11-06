/// Bloqueo del teléfono personal con PIN o huella (ROADMAP, Fase 0; revisión
/// de la Fase 0, I8).
///
/// - Se activa en Ajustes › Privacidad con un PIN (solo se guarda su hash) y,
///   si el teléfono la tiene, la huella. El PIN es de 6 dígitos para quien ve
///   dinero y de 4 a 6 para los demás (D18, 23/oct). En un teléfono personal
///   la huella sí sirve: los dedos registrados son de su dueño.
/// - Bloquea al abrir la app y al volver de segundo plano tras un tiempo
///   (1 minuto por omisión; configurable).
/// - Los intentos fallidos se guardan y la espera crece, como en la tablet.
/// - Es de cada persona: la configuración va con su id.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contratos/roles.dart';
import '../sesion/proveedores_sesion.dart';
import 'intentos.dart';
import 'pin.dart';
import 'pin_de_montos.dart';
import 'serie_pin.dart';
import 'proveedores_seguridad.dart';

/// Tiempo en segundo plano tras el que se pide el PIN.
const bloqueoTrasPorOmision = Duration(minutes: 1);
const opcionesBloqueoTras = [
  Duration.zero,
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
];

/// Configuración guardada del bloqueo de una persona.
class ConfiguracionBloqueo {
  const ConfiguracionBloqueo({
    required this.hashPin,
    this.huella = false,
    this.tras = bloqueoTrasPorOmision,
  });

  final String hashPin;
  final bool huella;
  final Duration tras;

  ConfiguracionBloqueo copiarCon({
    String? hashPin,
    bool? huella,
    Duration? tras,
  }) => ConfiguracionBloqueo(
    hashPin: hashPin ?? this.hashPin,
    huella: huella ?? this.huella,
    tras: tras ?? this.tras,
  );

  Map<String, Object?> aJson() => {
    'hash_pin': hashPin,
    'huella': huella,
    'tras_segundos': tras.inSeconds,
  };

  static ConfiguracionBloqueo? desdeJson(Map<String, Object?> json) {
    final hash = json['hash_pin'];
    if (hash is! String) return null;
    return ConfiguracionBloqueo(
      hashPin: hash,
      huella: (json['huella'] as bool?) ?? false,
      tras: Duration(
        seconds:
            (json['tras_segundos'] as int?) ?? bloqueoTrasPorOmision.inSeconds,
      ),
    );
  }
}

/// Lo que pasa con el PIN del bloqueo al quitarlo: el hash (si no se olvidó)
/// se conserva como PIN propio de los montos. Solo existe en el estado que
/// produce [ControladorBloqueo.quitarBloqueo]; el controlador de los montos lo
/// lee para enterarse al instante (P1 de la revisión de la Fase 1b).
class TraspasoDePin {
  const TraspasoDePin(this.hash);

  /// El hash que pasa a los montos; `null` si no pasa nada (olvidó su PIN).
  final String? hash;
}

class EstadoBloqueo {
  const EstadoBloqueo({
    this.cargado = false,
    this.configuracion,
    this.bloqueado = false,
    this.traspaso,
  });

  final bool cargado;

  /// `null` si la persona no activó el bloqueo.
  final ConfiguracionBloqueo? configuracion;
  final bool bloqueado;

  /// Solo en el estado que deja [ControladorBloqueo.quitarBloqueo].
  final TraspasoDePin? traspaso;

  bool get activo => configuracion != null;
}

enum ResultadoBloqueo {
  abierto,
  pinIncorrecto,
  bloqueado,
  huellaFallida,

  /// El PIN es el correcto, pero quien ve dinero ahora lo necesita de 6
  /// dígitos (D18, 23/oct): no se abre todavía; hay que elegir uno nuevo
  /// ([ControladorBloqueo.cambiarPin]).
  debeCambiarPin,
}

final controladorBloqueoProvider =
    NotifierProvider<ControladorBloqueo, EstadoBloqueo>(ControladorBloqueo.new);

class ControladorBloqueo extends Notifier<EstadoBloqueo> {
  static const claveIntentos = 'bloqueo.intentos_pin';
  static String claveConfiguracion(String personaId) => 'bloqueo.$personaId';

  late LimiteIntentos _intentos;
  String? _persona;
  DateTime? _enSegundoPlanoDesde;
  Future<void>? _carga;

  /// Una verificación de PIN a la vez (los fallos se cuentan en fila).
  final _serie = SerieDePin();

  DateTime _ahora() => ref.read(relojSeguridadProvider)();

  @override
  EstadoBloqueo build() {
    final almacen = ref.watch(almacenSeguroProvider);
    _intentos = LimiteIntentos(
      almacen,
      clave: claveIntentos,
      politica: const PoliticaIntentos(),
      reloj: _ahora,
    );
    // Al abrir la app se bloquea; tras entrar con contraseña (otra persona o
    // la misma), no.
    _persona = ref.read(sesionActualProvider)?.persona.id;
    ref.listen(sesionActualProvider.select((sesion) => sesion?.persona.id), (
      _,
      persona,
    ) {
      _persona = persona;
      _enSegundoPlanoDesde = null;
      _carga = _cargar(persona, bloquear: false);
    });
    _carga = _cargar(_persona, bloquear: true);
    return const EstadoBloqueo();
  }

  /// Termina cuando se leyó la configuración.
  Future<void> get listo => _carga ?? Future.value();

  Future<void> _cargar(String? persona, {required bool bloquear}) async {
    ConfiguracionBloqueo? configuracion;
    if (persona != null) {
      final texto = await ref
          .read(almacenSeguroProvider)
          .leer(claveConfiguracion(persona));
      if (texto != null) {
        try {
          configuracion = ConfiguracionBloqueo.desdeJson(
            (jsonDecode(texto) as Map).cast<String, Object?>(),
          );
        } catch (_) {
          configuracion = null;
        }
      }
    }
    await _intentos.cargar();
    if (!ref.mounted || persona != _persona) return;
    state = EstadoBloqueo(
      cargado: true,
      configuracion: configuracion,
      bloqueado: bloquear && configuracion != null,
    );
  }

  Future<void> _guardar(
    ConfiguracionBloqueo? configuracion, {
    TraspasoDePin? traspaso,
  }) async {
    final persona = _persona;
    if (persona == null) return;
    final almacen = ref.read(almacenSeguroProvider);
    if (configuracion == null) {
      await almacen.borrar(claveConfiguracion(persona));
    } else {
      await almacen.escribir(
        claveConfiguracion(persona),
        jsonEncode(configuracion.aJson()),
      );
    }
    if (ref.mounted) {
      state = EstadoBloqueo(
        cargado: true,
        configuracion: configuracion,
        bloqueado: state.bloqueado && configuracion != null,
        traspaso: traspaso,
      );
    }
  }

  /// Rol de la persona de este teléfono (de él depende el largo del PIN).
  Rol? get _rol => ref.read(sesionActualProvider)?.rol;

  static const _sinActual =
      'Ya hay un PIN: para cambiarlo hace falta el actual (configurarPin con actual).';

  /// Activa el bloqueo con [pin], o lo cambia. El PIN es de 6 dígitos si la
  /// persona ve dinero y de 4 a 6 si no (D18, 23/oct).
  ///
  /// **Cambiar un PIN pide el actual** (P1 de la revisión de la Fase 1b): si ya
  /// hay un PIN en vigor (el del bloqueo o el propio de los montos), hay que
  /// pasarlo en [actual]; sin él lanza [StateError], y uno equivocado cuenta
  /// como fallo y no cambia nada. Crearlo, solo cuando no hay ninguno.
  Future<ResultadoBloqueo> configurarPin(String pin, {String? actual}) async {
    // Largo del rol y M9: nada de 0000, 1234, repetidos ni secuencias.
    final error = errorDePinNuevo(pin, rol: _rol);
    if (error != null) throw ArgumentError(error);
    await listo;
    final persona = _persona;
    final existente = state.configuracion;
    if (existente != null) {
      if (actual == null) throw StateError(_sinActual);
      return cambiarPin(actual, pin);
    }
    final propio = persona == null
        ? null
        : await leerPinPropioDeMontos(ref.read(almacenSeguroProvider), persona);
    if (propio != null) {
      // Quitar el bloqueo conserva su PIN como el propio de los montos: poner
      // otro nuevo sin saber ese sería la misma puerta. Activar el bloqueo con
      // ese mismo PIN no cambia el secreto: escribirlo ya es conocerlo. Todo
      // intento, bueno o malo, pasa por el límite de fallos.
      if (_intentos.bloqueado(persona!)) return ResultadoBloqueo.bloqueado;
      if (!await HashPin.verificarAsync(actual ?? pin, propio)) {
        final bloqueado =
            _intentos.anotarFallo(persona) == ResultadoFallo.bloqueado;
        if (actual == null && !bloqueado) throw StateError(_sinActual);
        return bloqueado
            ? ResultadoBloqueo.bloqueado
            : ResultadoBloqueo.pinIncorrecto;
      }
      _intentos.anotarAcierto(persona);
    }
    await _guardar(
      ConfiguracionBloqueo(hashPin: await HashPin.crearAsync(pin)),
    );
    return ResultadoBloqueo.abierto;
  }

  /// Quita el bloqueo del teléfono. **Su PIN se conserva como el PIN propio
  /// para ver los montos** (P1 de la revisión de la Fase 1b): apagar el
  /// bloqueo no deja crear otro PIN sin conocer el actual. Con [olvido] (la
  /// persona olvidó su PIN y va a volver a entrar con su correo y contraseña)
  /// no se conserva nada: se borran también el PIN propio de los montos.
  Future<void> quitarBloqueo({bool olvido = false}) async {
    await listo;
    final persona = _persona;
    final traspaso = olvido ? null : state.configuracion?.hashPin;
    if (persona != null) {
      _intentos.olvidar(persona);
      if (olvido || traspaso != null) {
        await guardarPinPropioDeMontos(
          ref.read(almacenSeguroProvider),
          persona,
          traspaso,
        );
      }
    }
    await _guardar(null, traspaso: TraspasoDePin(traspaso));
  }

  /// Apaga o enciende la huella sin comprobar nada (apagarla no pide nada;
  /// para encenderla desde la pantalla usa [activarHuella]).
  Future<void> fijarHuella(bool activa) async {
    await listo;
    final actual = state.configuracion;
    if (actual != null) await _guardar(actual.copiarCon(huella: activa));
  }

  /// Enciende la huella (D22, P10) **solo si la persona se identifica ahora**:
  /// así se comprueba que el teléfono sí tiene huellas registradas y que quien
  /// la activa es quien tiene el teléfono en la mano. Sin bloqueo con PIN no
  /// hay respaldo, así que no se activa. `true` si quedó activa.
  ///
  /// La huella es **alternativa** al PIN, nunca su reemplazo: el PIN sigue
  /// abriendo siempre (respaldo si la huella falla o se bloquea).
  Future<bool> activarHuella() async {
    await listo;
    final actual = state.configuracion;
    if (actual == null) return false;
    final biometria = ref.read(biometriaProvider);
    if (!await biometria.disponible()) return false;
    final ok = await biometria.autenticar('Activar el desbloqueo con huella');
    if (!ref.mounted || !ok) return false;
    await _guardar(actual.copiarCon(huella: true));
    return true;
  }

  Future<void> fijarTiempo(Duration tras) async {
    await listo;
    final actual = state.configuracion;
    if (actual != null) await _guardar(actual.copiarCon(tras: tras));
  }

  /// Cuánto falta para poder intentar el PIN otra vez, o `null`.
  Duration? esperaRestante() {
    final persona = _persona;
    return persona == null ? null : _intentos.esperaRestante(persona);
  }

  /// Comprueba el PIN del bloqueo **sin desbloquear nada** (p. ej. para volver
  /// a ver los montos). Cuenta los fallos igual que [desbloquearConPin].
  Future<ResultadoBloqueo> comprobarPin(String pin) => _serie.correr(() async {
    final persona = _persona;
    final configuracion = state.configuracion;
    if (persona == null || configuracion == null) {
      return ResultadoBloqueo.pinIncorrecto;
    }
    if (_intentos.bloqueado(persona)) return ResultadoBloqueo.bloqueado;
    if (!await HashPin.verificarAsync(pin, configuracion.hashPin)) {
      return _intentos.anotarFallo(persona) == ResultadoFallo.bloqueado
          ? ResultadoBloqueo.bloqueado
          : ResultadoBloqueo.pinIncorrecto;
    }
    _intentos.anotarAcierto(persona);
    if (pinEsCortoParaSuRol(_rol, pin)) return ResultadoBloqueo.debeCambiarPin;
    _actualizarHash(pin, configuracion);
    return ResultadoBloqueo.abierto;
  });

  /// Cambia el PIN del bloqueo comprobando el actual y, si el teléfono estaba
  /// bloqueado, lo abre. Es la salida de [ResultadoBloqueo.debeCambiarPin]
  /// (PIN corto de quien ve dinero). Lanza [ArgumentError] si el nuevo no sirve.
  Future<ResultadoBloqueo> cambiarPin(String pinActual, String pinNuevo) async {
    final error = errorDePinNuevo(pinNuevo, rol: _rol);
    if (error != null) throw ArgumentError(error);
    await listo;
    final persona = _persona;
    final configuracion = state.configuracion;
    if (persona == null || configuracion == null) {
      return ResultadoBloqueo.pinIncorrecto;
    }
    if (_intentos.bloqueado(persona)) return ResultadoBloqueo.bloqueado;
    final correcto = await _serie.correr(
      () => HashPin.verificarAsync(pinActual, configuracion.hashPin),
    );
    if (!correcto) {
      return _intentos.anotarFallo(persona) == ResultadoFallo.bloqueado
          ? ResultadoBloqueo.bloqueado
          : ResultadoBloqueo.pinIncorrecto;
    }
    _intentos.anotarAcierto(persona);
    await _guardar(
      configuracion.copiarCon(hashPin: await HashPin.crearAsync(pinNuevo)),
    );
    _desbloquear();
    return ResultadoBloqueo.abierto;
  }

  Future<ResultadoBloqueo> desbloquearConPin(String pin) =>
      _serie.correr(() async {
        final persona = _persona;
        final configuracion = state.configuracion;
        if (persona == null || configuracion == null) {
          _desbloquear();
          return ResultadoBloqueo.abierto;
        }
        if (_intentos.bloqueado(persona)) return ResultadoBloqueo.bloqueado;
        if (!await HashPin.verificarAsync(pin, configuracion.hashPin)) {
          return _intentos.anotarFallo(persona) == ResultadoFallo.bloqueado
              ? ResultadoBloqueo.bloqueado
              : ResultadoBloqueo.pinIncorrecto;
        }
        _intentos.anotarAcierto(persona);
        // D18 (23/oct): con un PIN corto, quien ve dinero no entra todavía.
        if (pinEsCortoParaSuRol(_rol, pin)) {
          return ResultadoBloqueo.debeCambiarPin;
        }
        _desbloquear();
        _actualizarHash(pin, configuracion);
        return ResultadoBloqueo.abierto;
      });

  /// M9': un hash hecho con menos vueltas de PBKDF2 (los de antes) se rehace
  /// con las de hoy en cuanto se escribe el PIN, el único momento en que se
  /// tiene.
  void _actualizarHash(String pin, ConfiguracionBloqueo configuracion) {
    if (!HashPin.necesitaActualizarse(configuracion.hashPin)) return;
    unawaited(() async {
      final rehecho = await HashPin.crearAsync(pin);
      if (!ref.mounted ||
          state.configuracion?.hashPin != configuracion.hashPin) {
        return;
      }
      await _guardar(state.configuracion!.copiarCon(hashPin: rehecho));
    }());
  }

  /// Desbloquea con la huella del teléfono, si la persona la activó.
  Future<ResultadoBloqueo> desbloquearConHuella() async {
    final configuracion = state.configuracion;
    final biometria = ref.read(biometriaProvider);
    if (configuracion == null ||
        !configuracion.huella ||
        !await biometria.disponible()) {
      return ResultadoBloqueo.huellaFallida;
    }
    final ok = await biometria.autenticar('Desbloquear GRAVITY');
    if (!ref.mounted || !ok) return ResultadoBloqueo.huellaFallida;
    _desbloquear();
    return ResultadoBloqueo.abierto;
  }

  void _desbloquear() {
    if (state.bloqueado) {
      state = EstadoBloqueo(
        cargado: state.cargado,
        configuracion: state.configuracion,
      );
    }
  }

  /// La app pasó a segundo plano.
  void alIrASegundoPlano() => _enSegundoPlanoDesde ??= _ahora();

  /// La app volvió: si pasó el tiempo configurado, se bloquea.
  void alVolver() {
    final desde = _enSegundoPlanoDesde;
    _enSegundoPlanoDesde = null;
    final configuracion = state.configuracion;
    if (desde == null || configuracion == null || state.bloqueado) return;
    if (_ahora().difference(desde) >= configuracion.tras) bloquearAhora();
  }

  void bloquearAhora() {
    if (state.activo && !state.bloqueado) {
      state = EstadoBloqueo(
        cargado: state.cargado,
        configuracion: state.configuracion,
        bloqueado: true,
      );
    }
  }
}

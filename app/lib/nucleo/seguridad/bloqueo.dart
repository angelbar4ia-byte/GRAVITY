/// Bloqueo del teléfono personal con PIN o huella (ROADMAP, Fase 0; revisión
/// de la Fase 0, I8).
///
/// - Se activa en Ajustes › Privacidad con un PIN de 4 a 6 dígitos (solo se
///   guarda su hash) y, si el teléfono la tiene, la huella. En un teléfono
///   personal la huella sí sirve: los dedos registrados son de su dueño.
/// - Bloquea al abrir la app y al volver de segundo plano tras un tiempo
///   (1 minuto por omisión; configurable).
/// - Los intentos fallidos se guardan y la espera crece, como en la tablet.
/// - Es de cada persona: la configuración va con su id.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sesion/proveedores_sesion.dart';
import 'intentos.dart';
import 'pin.dart';
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

  ConfiguracionBloqueo copiarCon({String? hashPin, bool? huella, Duration? tras}) =>
      ConfiguracionBloqueo(
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

class EstadoBloqueo {
  const EstadoBloqueo({
    this.cargado = false,
    this.configuracion,
    this.bloqueado = false,
  });

  final bool cargado;

  /// `null` si la persona no activó el bloqueo.
  final ConfiguracionBloqueo? configuracion;
  final bool bloqueado;

  bool get activo => configuracion != null;
}

enum ResultadoBloqueo { abierto, pinIncorrecto, bloqueado, huellaFallida }

final controladorBloqueoProvider =
    NotifierProvider<ControladorBloqueo, EstadoBloqueo>(ControladorBloqueo.new);

class ControladorBloqueo extends Notifier<EstadoBloqueo> {
  static const claveIntentos = 'bloqueo.intentos_pin';
  static String claveConfiguracion(String personaId) => 'bloqueo.$personaId';

  late LimiteIntentos _intentos;
  String? _persona;
  DateTime? _enSegundoPlanoDesde;
  Future<void>? _carga;

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

  Future<void> _guardar(ConfiguracionBloqueo? configuracion) async {
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
      );
    }
  }

  /// Activa el bloqueo (o cambia el PIN).
  Future<void> configurarPin(String pin) async {
    if (!pinValido(pin)) {
      throw ArgumentError('El PIN debe tener de 4 a 6 dígitos.');
    }
    // M9: nada de 0000, 1234, repetidos ni secuencias.
    final debil = motivoPinDebil(pin);
    if (debil != null) throw ArgumentError(debil);
    await listo;
    final actual = state.configuracion;
    final hash = HashPin.crear(pin);
    await _guardar(
      actual?.copiarCon(hashPin: hash) ?? ConfiguracionBloqueo(hashPin: hash),
    );
  }

  /// Quita el bloqueo del teléfono.
  Future<void> quitarBloqueo() async {
    await listo;
    final persona = _persona;
    if (persona != null) _intentos.olvidar(persona);
    await _guardar(null);
  }

  Future<void> fijarHuella(bool activa) async {
    await listo;
    final actual = state.configuracion;
    if (actual != null) await _guardar(actual.copiarCon(huella: activa));
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

  ResultadoBloqueo desbloquearConPin(String pin) {
    final persona = _persona;
    final configuracion = state.configuracion;
    if (persona == null || configuracion == null) {
      _desbloquear();
      return ResultadoBloqueo.abierto;
    }
    if (_intentos.bloqueado(persona)) return ResultadoBloqueo.bloqueado;
    if (!HashPin.verificar(pin, configuracion.hashPin)) {
      return _intentos.anotarFallo(persona) == ResultadoFallo.bloqueado
          ? ResultadoBloqueo.bloqueado
          : ResultadoBloqueo.pinIncorrecto;
    }
    _intentos.anotarAcierto(persona);
    _desbloquear();
    return ResultadoBloqueo.abierto;
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

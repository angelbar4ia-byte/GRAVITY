/// Montos ocultos automáticos (decisión del dueño del 23/oct/2026, D18).
///
/// El correo y la contraseña se piden **una vez por dispositivo** y la sesión
/// sigue abierta. Tras unos minutos sin uso (2 por omisión, editable en
/// Ajustes › Privacidad) **los montos se ocultan solos** y para volver a
/// verlos se pide el **PIN** (en el teléfono, también la huella).
///
/// Qué PIN se pide, según dónde se use:
/// - **Tablet:** el de la persona que entró (identifica a la persona).
/// - **Teléfono con bloqueo activado:** el mismo del bloqueo (no se manejan
///   dos PIN).
/// - **Si no hay ninguno** (la laptop, o un teléfono sin bloqueo): un PIN
///   **propio para ver los montos**, que la persona crea la primera vez. Nunca
///   se guarda el PIN, solo su hash con sal; no se aceptan PIN triviales
///   ([motivoPinDebil]) y el largo es el de siempre (4 a 6 dígitos).
///
/// El ocultado en pantalla (qué es "visible", los widgets de monto) es del
/// sistema de diseño (`diseno/proveedores.dart`: `montosVisiblesProvider`,
/// `montosOcultosProvider`, `revelarMontosProvider`); esto es lo que pone la
/// plataforma: el tiempo, los PIN y la huella. La conexión está en
/// `app/montos/`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cola/proveedores_cola.dart' show personaQueRegistraProvider;
import '../tablet/controlador_tablet.dart';
import 'bloqueo.dart';
import 'intentos.dart';
import 'pin.dart';
import 'proveedores_seguridad.dart';

/// Tiempo sin uso tras el que los montos se ocultan solos.
const ocultarMontosTrasPorOmision = Duration(minutes: 2);

/// Lo que se puede elegir en Ajustes › Privacidad.
const opcionesOcultarMontosTras = [
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
];

/// Dónde se comprueba el PIN para volver a ver los montos.
enum FuenteDePinMontos {
  /// El de la persona que entró en la tablet.
  tablet,

  /// El del bloqueo del teléfono.
  bloqueo,

  /// Uno propio, solo para ver los montos.
  propio,
}

enum ResultadoRevelar {
  /// El PIN (o la huella) era el correcto: se pueden mostrar los montos.
  revelado,
  pinIncorrecto,

  /// Demasiados intentos fallidos: hay que esperar ([ControladorMontos.esperaRestante]).
  bloqueado,

  /// Aún no hay un PIN propio: hay que crearlo ([ControladorMontos.crearPin]).
  faltaPin,
  huellaFallida,
}

class EstadoMontos {
  const EstadoMontos({
    this.cargado = false,
    this.ocultarTras = ocultarMontosTrasPorOmision,
    this.tienePinPropio = false,
  });

  final bool cargado;

  /// Tiempo sin uso tras el que se ocultan los montos.
  final Duration ocultarTras;

  /// La persona ya creó su PIN para ver los montos.
  final bool tienePinPropio;

  EstadoMontos copiarCon({
    bool? cargado,
    Duration? ocultarTras,
    bool? tienePinPropio,
  }) => EstadoMontos(
    cargado: cargado ?? this.cargado,
    ocultarTras: ocultarTras ?? this.ocultarTras,
    tienePinPropio: tienePinPropio ?? this.tienePinPropio,
  );
}

final controladorMontosProvider =
    NotifierProvider<ControladorMontos, EstadoMontos>(ControladorMontos.new);

class ControladorMontos extends Notifier<EstadoMontos> {
  static String claveConfiguracion(String personaId) =>
      'montos.config.$personaId';
  static const claveIntentos = 'montos.intentos_pin';

  late LimiteIntentos _intentos;
  String? _persona;
  String? _hashPin;
  Future<void>? _carga;

  DateTime _ahora() => ref.read(relojSeguridadProvider)();

  @override
  EstadoMontos build() {
    final almacen = ref.watch(almacenSeguroProvider);
    _intentos = LimiteIntentos(
      almacen,
      clave: claveIntentos,
      politica: const PoliticaIntentos(),
      reloj: _ahora,
    );
    // La configuración es de cada persona: al cambiar (otra sesión, otra
    // persona en la tablet) se vuelve a leer.
    _persona = ref.watch(personaQueRegistraProvider);
    _carga = _cargar(_persona);
    return const EstadoMontos();
  }

  /// Termina cuando se leyó la configuración.
  Future<void> get listo => _carga ?? Future.value();

  Future<void> _cargar(String? persona) async {
    var ocultarTras = ocultarMontosTrasPorOmision;
    String? hash;
    if (persona != null) {
      final texto = await ref
          .read(almacenSeguroProvider)
          .leer(claveConfiguracion(persona));
      if (texto != null) {
        try {
          final json = (jsonDecode(texto) as Map).cast<String, Object?>();
          final segundos = json['ocultar_tras_segundos'];
          if (segundos is int && segundos > 0) {
            ocultarTras = Duration(seconds: segundos);
          }
          final guardado = json['hash_pin'];
          if (guardado is String) hash = guardado;
        } catch (_) {
          // Lo guardado no se entiende: valores por omisión.
        }
      }
    }
    await _intentos.cargar();
    if (!ref.mounted || persona != _persona) return;
    _hashPin = hash;
    state = EstadoMontos(
      cargado: true,
      ocultarTras: ocultarTras,
      tienePinPropio: hash != null,
    );
  }

  Future<void> _guardar({Duration? ocultarTras, String? hashPin}) async {
    final persona = _persona;
    if (persona == null) return;
    final tras = ocultarTras ?? state.ocultarTras;
    final hash = hashPin ?? _hashPin;
    await ref
        .read(almacenSeguroProvider)
        .escribir(
          claveConfiguracion(persona),
          jsonEncode({
            'ocultar_tras_segundos': tras.inSeconds,
            'hash_pin': ?hash,
          }),
        );
    if (!ref.mounted || persona != _persona) return;
    _hashPin = hash;
    state = state.copiarCon(ocultarTras: tras, tienePinPropio: hash != null);
  }

  /// Cambia el tiempo sin uso tras el que se ocultan los montos.
  Future<void> fijarOcultarTras(Duration tras) async {
    await listo;
    await _guardar(ocultarTras: tras);
  }

  /// Quién comprueba el PIN para ver los montos ahora.
  FuenteDePinMontos get fuente {
    final persona = _persona;
    final tablet = ref.read(controladorTabletProvider);
    if (persona != null && tablet.usuarioActivo?.personaId == persona) {
      return FuenteDePinMontos.tablet;
    }
    if (ref.read(controladorBloqueoProvider).activo) {
      return FuenteDePinMontos.bloqueo;
    }
    return FuenteDePinMontos.propio;
  }

  /// `true` si hay que crear el PIN propio antes de poder pedir ver los
  /// montos (no hay PIN de tablet ni de bloqueo, y tampoco uno propio).
  bool get hayQueCrearPin =>
      fuente == FuenteDePinMontos.propio && !state.tienePinPropio;

  /// Crea (o cambia) el PIN propio para ver los montos. Lanza
  /// [ArgumentError] con el motivo si no es un PIN que se pueda aceptar
  /// (formato o trivial: `0000`, `1234`, repetidos, secuencias).
  Future<void> crearPin(String pin) async {
    final error = errorDePinNuevo(pin);
    if (error != null) throw ArgumentError(error);
    await listo;
    await _guardar(hashPin: HashPin.crear(pin));
    final persona = _persona;
    if (persona != null) _intentos.olvidar(persona);
  }

  /// Cuánto falta para poder intentar el PIN otra vez, o `null`.
  Duration? esperaRestante() {
    final persona = _persona;
    if (persona == null) return null;
    return switch (fuente) {
      FuenteDePinMontos.tablet => ref
          .read(controladorTabletProvider.notifier)
          .esperaRestante(persona),
      FuenteDePinMontos.bloqueo =>
        ref.read(controladorBloqueoProvider.notifier).esperaRestante(),
      FuenteDePinMontos.propio => _intentos.esperaRestante(persona),
    };
  }

  /// Comprueba el PIN. `revelado` si es el correcto. No muestra nada por sí
  /// mismo: quien lo llama muestra los montos.
  Future<ResultadoRevelar> verificar(String pin) async {
    await listo;
    final persona = _persona;
    if (persona == null) return ResultadoRevelar.pinIncorrecto;
    switch (fuente) {
      case FuenteDePinMontos.tablet:
        return switch (ref
            .read(controladorTabletProvider.notifier)
            .comprobarPin(persona, pin)) {
          ResultadoDesbloqueo.abierto => ResultadoRevelar.revelado,
          ResultadoDesbloqueo.bloqueado => ResultadoRevelar.bloqueado,
          _ => ResultadoRevelar.pinIncorrecto,
        };
      case FuenteDePinMontos.bloqueo:
        return switch (ref
            .read(controladorBloqueoProvider.notifier)
            .comprobarPin(pin)) {
          ResultadoBloqueo.abierto => ResultadoRevelar.revelado,
          ResultadoBloqueo.bloqueado => ResultadoRevelar.bloqueado,
          _ => ResultadoRevelar.pinIncorrecto,
        };
      case FuenteDePinMontos.propio:
        final hash = _hashPin;
        if (hash == null) return ResultadoRevelar.faltaPin;
        if (_intentos.bloqueado(persona)) return ResultadoRevelar.bloqueado;
        if (!HashPin.verificar(pin, hash)) {
          return _intentos.anotarFallo(persona) == ResultadoFallo.bloqueado
              ? ResultadoRevelar.bloqueado
              : ResultadoRevelar.pinIncorrecto;
        }
        _intentos.anotarAcierto(persona);
        return ResultadoRevelar.revelado;
    }
  }

  /// `true` si se puede pedir la huella: solo en un teléfono personal (los
  /// dedos registrados son de su dueño). **Nunca** en las tablets
  /// compartidas (Android no dice de quién es el dedo; D18).
  Future<bool> huellaDisponible() async {
    if (fuente == FuenteDePinMontos.tablet) return false;
    return ref.read(biometriaProvider).disponible();
  }

  /// Pide la huella para ver los montos.
  Future<ResultadoRevelar> verificarConHuella() async {
    if (!await huellaDisponible()) return ResultadoRevelar.huellaFallida;
    final ok = await ref.read(biometriaProvider).autenticar('Ver los montos');
    return ok ? ResultadoRevelar.revelado : ResultadoRevelar.huellaFallida;
  }
}

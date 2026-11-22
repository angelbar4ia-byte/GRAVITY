/// Puerta al texto a voz del sistema (fuente A) con `flutter_tts` 4.2.5.
///
/// Todo lo que el plugin tiene de particular (formatos de voz de Android y de
/// Windows, cómo avisan que terminaron, qué hace `stop`) queda aquí; la fuente
/// [FuenteDispositivo] solo conoce [PuertoTts], que tiene su versión falsa
/// para pruebas ([PuertoTtsFalso]).
///
/// Lo que se leyó en el código del plugin (4.2.5) y condiciona este archivo:
/// - **Android**: con `awaitSpeakCompletion(true)`, `speak` completa con 1 al
///   terminar y con 0 si lo cortaron (`stop`/`pause`) o si ya había algo
///   sonando. Si hay un error, `speak` **no completa**: solo avisa por
///   `setErrorHandler`. Por eso el resultado sale de la primera señal que
///   llegue (fin, corte o error), no solo del `Future` de `speak`.
/// - **Windows** (la rama de WinRT, `flutter_tts_plugin.cpp:18`): `stop()`
///   responde 1 al `speak` que estaba pendiente (parece "terminó bien") y
///   desreferencia ese resultado sin comprobar que exista: **llamar a `stop`
///   sin que nada suene cierra la app**. Por eso aquí `stop` solo se llama si
///   hay un turno en curso, y lo cortado se marca como interrumpido por
///   nosotros, no por lo que conteste el plugin. `getSpeechRateValidRange` no
///   existe en Windows: se usan valores por omisión.
/// - Ningún error copia el mensaje del plugin ni el texto: solo códigos (R6).
library;

import 'dart:async';

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_tts/flutter_tts.dart';

import '../../fuente_de_voz.dart';
import '../../tipos.dart';

/// Cómo terminó de sonar un turno.
enum ResultadoHabla { completo, interrumpido }

/// Rango de velocidad del plugin (su escala: 0.5 es la normal).
typedef RangoVelocidadPlugin = ({double min, double normal, double max});

abstract interface class PuertoTts {
  /// Todas las voces tal como las da el sistema. Lanza [FalloDeSintesis] con
  /// `sin_motor_de_voz` si el equipo no tiene motor de voz.
  Future<List<VozDelSistema>> voces();

  Future<RangoVelocidadPlugin> rangoVelocidad();

  /// Elige la voz; `false` si el sistema no la encuentra.
  Future<bool> fijarVoz(String nombre, String locale);

  /// En la escala del plugin (0.5 es la normal).
  Future<void> fijarVelocidad(double velocidad);

  /// Dice el texto y completa cuando termina, lo cortan o falla (en ese caso
  /// lanza [FalloDeSintesis]). Un solo texto a la vez.
  Future<ResultadoHabla> hablar(String texto);

  /// Corta lo que suene. No hace nada si no suena nada.
  Future<void> detener();
}

/// La implementación real, con `flutter_tts`. El plugin se crea al primer uso,
/// no al arrancar la app.
class PuertoTtsFlutter implements PuertoTts {
  PuertoTtsFlutter({FlutterTts? tts, this.esperaDeCorte = const Duration(milliseconds: 250)})
    : _ttsInyectado = tts;

  final FlutterTts? _ttsInyectado;

  /// Cuánto se espera, como máximo, el aviso de "cancelado" del plugin tras
  /// cortar, antes de hablar otra vez (para que ese aviso no corte al turno
  /// siguiente).
  final Duration esperaDeCorte;

  late final FlutterTts _tts = _ttsInyectado ?? FlutterTts();

  Future<void>? _inicio;
  Completer<ResultadoHabla>? _actual;
  int _cancelesEsperados = 0;
  Completer<void>? _cancelRecibido;

  Future<void> _iniciar() => _inicio ??= _prepararPlugin();

  Future<void> _prepararPlugin() async {
    await _proteger(() async {
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() => _cerrarActual(ResultadoHabla.completo));
      _tts.setCancelHandler(_alCancelar);
      _tts.setErrorHandler((_) => _fallarActual('speak_error'));
    });
  }

  void _alCancelar() {
    if (_cancelesEsperados > 0) {
      // Es el aviso de nuestro propio `stop`.
      _cancelesEsperados--;
      final r = _cancelRecibido;
      if (r != null && !r.isCompleted) r.complete();
      return;
    }
    // Lo cortó el sistema (por ejemplo, otra app tomó el audio).
    _cerrarActual(ResultadoHabla.interrumpido);
  }

  void _cerrarActual(ResultadoHabla r) {
    final c = _actual;
    if (c != null && !c.isCompleted) {
      _actual = null;
      c.complete(r);
    }
  }

  void _fallarActual(String codigo) {
    final c = _actual;
    if (c != null && !c.isCompleted) {
      _actual = null;
      c.completeError(FalloDeSintesis(Fuente.dispositivo, codigo));
    }
  }

  /// Convierte lo que lance el plugin en un [FalloDeSintesis] con un código
  /// corto (nunca el mensaje: podría traer el texto).
  Future<T> _proteger<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on MissingPluginException {
      throw const FalloDeSintesis(Fuente.dispositivo, 'plugin_no_disponible');
    } on PlatformException catch (e) {
      throw FalloDeSintesis(Fuente.dispositivo, 'plataforma_${e.code}');
    } on ErrorVoz {
      rethrow;
    } catch (_) {
      throw const FalloDeSintesis(Fuente.dispositivo, 'error_inesperado');
    }
  }

  @override
  Future<List<VozDelSistema>> voces() => _proteger(() async {
    await _iniciar();
    final crudo = await _tts.getVoices;
    if (crudo is! List) {
      // Android devuelve nulo si el servicio de voz no está listo.
      throw const FalloDeSintesis(Fuente.dispositivo, 'sin_motor_de_voz');
    }
    final voces = <VozDelSistema>[];
    for (final item in crudo) {
      if (item is! Map) continue;
      final v = vozDelSistemaDe(item);
      if (v != null) voces.add(v);
    }
    return voces;
  });

  @override
  Future<RangoVelocidadPlugin> rangoVelocidad() async {
    try {
      final r = await _tts.getSpeechRateValidRange;
      return (min: r.min, normal: r.normal, max: r.max);
    } catch (_) {
      // Windows no lo implementa: 0.5 es la velocidad normal en las dos
      // plataformas (`flutter_tts` la mapea así).
      return (min: 0.0, normal: 0.5, max: 1.5);
    }
  }

  @override
  Future<bool> fijarVoz(String nombre, String locale) => _proteger(() async {
    await _iniciar();
    final r = await _tts.setVoice({'name': nombre, 'locale': locale});
    return r == 1 || r == true;
  });

  @override
  Future<void> fijarVelocidad(double velocidad) => _proteger(() async {
    await _iniciar();
    await _tts.setSpeechRate(velocidad);
  });

  @override
  Future<ResultadoHabla> hablar(String texto) async {
    await _iniciar();
    await _esperarAvisoDeCorte();
    if (_actual != null) await detener();
    final c = Completer<ResultadoHabla>();
    _actual = c;
    unawaited(
      _proteger(() => _tts.speak(texto)).then<void>(
        (r) {
          if (c.isCompleted) return;
          if (identical(_actual, c)) _actual = null;
          // 1: terminó. 0: lo cortaron o el plugin lo rechazó porque ya había
          // algo sonando (si lo cortamos nosotros, `c` ya está completo).
          if (r == 0) {
            c.completeError(
              const FalloDeSintesis(Fuente.dispositivo, 'speak_rechazado'),
            );
          } else {
            c.complete(ResultadoHabla.completo);
          }
        },
        onError: (Object error) {
          if (c.isCompleted) return;
          if (identical(_actual, c)) _actual = null;
          c.completeError(
            error is ErrorVoz
                ? error
                : const FalloDeSintesis(Fuente.dispositivo, 'error_inesperado'),
          );
        },
      ),
    );
    return c.future;
  }

  Future<void> _esperarAvisoDeCorte() async {
    if (_cancelesEsperados == 0) return;
    final r = _cancelRecibido ??= Completer<void>();
    await Future.any([r.future, Future<void>.delayed(esperaDeCorte)]);
    _cancelesEsperados = 0;
    _cancelRecibido = null;
  }

  @override
  Future<void> detener() async {
    final c = _actual;
    if (c == null || c.isCompleted) return; // Nada suena: no se llama a `stop`.
    _actual = null;
    c.complete(ResultadoHabla.interrumpido);
    _cancelesEsperados++;
    try {
      await _tts.stop();
    } catch (_) {
      // Si no se pudo cortar, no se espera un aviso que no va a llegar.
      _cancelesEsperados = 0;
    }
  }
}

/// Convierte una voz tal como la da `flutter_tts` en [VozDelSistema], o `null`
/// si no trae nombre ni idioma. Android: `name`, `locale`, `quality`,
/// `latency`, `network_required` y `features`. Windows: `name`, `locale`,
/// `gender` e `identifier`.
VozDelSistema? vozDelSistemaDe(Map<Object?, Object?> crudo) {
  final nombre = crudo['name']?.toString() ?? '';
  final locale = crudo['locale']?.toString() ?? '';
  if (nombre.isEmpty || locale.isEmpty) return null;
  final red = crudo['network_required']?.toString();
  final rasgos = (crudo['features']?.toString() ?? '')
      .split(RegExp(r'[\t,]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty);
  final generoCrudo = crudo['gender']?.toString().toLowerCase();
  final bajo = nombre.toLowerCase();
  final genero = switch (generoCrudo) {
    'female' => Genero.mujer,
    'male' => Genero.hombre,
    // Android casi nunca dice el género, pero las voces de Google lo llevan en
    // el nombre (`en-us-x-sfg#female_1-local`). Es una pista, no un dato.
    _ when bajo.contains('female') => Genero.mujer,
    _ when bajo.contains('#male') || bajo.contains('_male') => Genero.hombre,
    _ => Genero.sinDato,
  };
  return VozDelSistema(
    nombre: nombre,
    locale: locale,
    calidad: crudo['quality']?.toString(),
    requiereRed: red == null ? null : red == '1',
    instalada: !rasgos.contains('notInstalled'),
    genero: genero,
  );
}

/// Puerta falsa: no toca ningún plugin. Guarda lo que se le pidió.
class PuertoTtsFalso implements PuertoTts {
  PuertoTtsFalso({
    List<VozDelSistema>? voces,
    this.rango = (min: 0.0, normal: 0.5, max: 1.5),
    this.manual = false,
    this.errorAlListar,
  }) : vocesDelSistema = voces ?? [];

  List<VozDelSistema> vocesDelSistema;
  RangoVelocidadPlugin rango;

  /// Si es `true`, cada turno espera a [terminarTurno].
  bool manual;

  /// Lo que lanza [voces] (equipo sin motor de voz).
  ErrorVoz? errorAlListar;

  /// Si es `true`, [fijarVoz] dice que no encontró la voz.
  bool vozNoEncontrada = false;

  /// Si no es `null`, el turno con ese número (desde 0) falla.
  int? fallarEnTurno;

  final dichos = <String>[];
  final vocesFijadas = <({String nombre, String locale})>[];
  final velocidadesFijadas = <double>[];
  int cortes = 0;
  int consultasDeVoces = 0;
  int _turnos = 0;
  Completer<ResultadoHabla>? _actual;

  bool get sonando => _actual != null && !_actual!.isCompleted;

  void terminarTurno() {
    final c = _actual;
    if (c != null && !c.isCompleted) c.complete(ResultadoHabla.completo);
  }

  @override
  Future<List<VozDelSistema>> voces() async {
    consultasDeVoces++;
    final error = errorAlListar;
    if (error != null) throw error;
    return vocesDelSistema;
  }

  @override
  Future<RangoVelocidadPlugin> rangoVelocidad() async => rango;

  @override
  Future<bool> fijarVoz(String nombre, String locale) async {
    vocesFijadas.add((nombre: nombre, locale: locale));
    return !vozNoEncontrada;
  }

  @override
  Future<void> fijarVelocidad(double velocidad) async =>
      velocidadesFijadas.add(velocidad);

  @override
  Future<ResultadoHabla> hablar(String texto) async {
    final indice = _turnos++;
    if (fallarEnTurno == indice) {
      throw const FalloDeSintesis(Fuente.dispositivo, 'speak_error');
    }
    dichos.add(texto);
    final c = _actual = Completer<ResultadoHabla>();
    if (!manual) c.complete(ResultadoHabla.completo);
    return c.future;
  }

  @override
  Future<void> detener() async {
    final c = _actual;
    if (c != null && !c.isCompleted) {
      cortes++;
      c.complete(ResultadoHabla.interrumpido);
    }
  }
}

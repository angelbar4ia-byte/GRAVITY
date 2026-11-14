/// Voz de la conversación con GRAVITY (Fase 6b): escuchar y hablar.
///
/// Reglas:
/// - La voz no identifica a la persona (D5): quien habla es quien tiene la
///   sesión abierta. No hay huella de voz ni se decide nada por la voz.
/// - La voz no autoriza acciones (D8): lo que se reconoce entra como un
///   mensaje de texto normal y pasa por el mismo filtro de D3 del servidor.
///   Las acciones que piden confirmación siguen pidiendo el botón.
/// - Solo se lee en voz alta la respuesta del asistente (texto ya filtrado),
///   nunca los mensajes locales de la pantalla (pueden traer cifras, D3/D6),
///   y solo si la persona lo activó.
///
/// Fase 8: el dictado real (teléfono Android) usa `speech_to_text`; la lectura
/// en voz alta sigue sin implementación (solo se dicta).
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Reconocimiento de voz: convierte lo dicho en texto.
abstract class VozEntrada {
  /// Si el dispositivo puede escuchar. Sin ello no se muestra el micrófono.
  Future<bool> disponible();

  /// Escucha una frase y devuelve el texto reconocido, o `null` si no se
  /// entendió nada o se canceló.
  Future<String?> escuchar();

  /// Deja de escuchar.
  Future<void> detener();
}

/// Síntesis de voz: lee un texto en voz alta.
abstract class VozSalida {
  Future<void> hablar(String texto);
  Future<void> detener();
}

/// Dictado con el reconocimiento de voz del teléfono (Android). Solo dicta:
/// el micrófono y su permiso se piden al tocar el micrófono, nunca al abrir el
/// panel ([disponible] no inicializa nada ni pide permisos).
class VozEntradaTelefono implements VozEntrada {
  VozEntradaTelefono([SpeechToText? motor]) : _motor = motor ?? SpeechToText();
  final SpeechToText _motor;
  Completer<String?>? _espera;

  @override
  Future<bool> disponible() async => true;

  @override
  Future<String?> escuchar() async {
    final ok = await _motor.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') _terminar(null);
      },
      onError: (_) => _terminar(null),
    );
    if (!ok) return null; // Sin permiso o sin servicio de voz.
    _espera = Completer<String?>();
    String? ultimo;
    await _motor.listen(
      listenOptions: SpeechListenOptions(
        partialResults: false,
        listenMode: ListenMode.dictation,
        localeId: 'es_MX',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
      onResult: (r) {
        ultimo = r.recognizedWords;
        if (r.finalResult) _terminar(ultimo);
      },
    );
    final texto = await _espera!.future;
    return (texto ?? ultimo)?.trim().isEmpty ?? true ? null : (texto ?? ultimo);
  }

  void _terminar(String? texto) {
    final e = _espera;
    if (e != null && !e.isCompleted) e.complete(texto);
  }

  @override
  Future<void> detener() async {
    await _motor.stop();
    _terminar(null);
  }
}

/// Sin reconocimiento de voz (valor por omisión mientras no haya plugin).
class VozEntradaNoDisponible implements VozEntrada {
  const VozEntradaNoDisponible();

  @override
  Future<bool> disponible() async => false;

  @override
  Future<String?> escuchar() async => null;

  @override
  Future<void> detener() async {}
}

/// Sin síntesis de voz (valor por omisión mientras no haya plugin).
class VozSalidaNoDisponible implements VozSalida {
  const VozSalidaNoDisponible();

  @override
  Future<void> hablar(String texto) async {}

  @override
  Future<void> detener() async {}
}

/// Voz de entrada falsa para pruebas: devuelve el texto que se le indique.
/// No toca ningún micrófono.
class VozEntradaFalsa implements VozEntrada {
  VozEntradaFalsa([this.texto, this.estaDisponible = true]);

  String? texto;
  bool estaDisponible;
  int escuchas = 0;

  @override
  Future<bool> disponible() async => estaDisponible;

  @override
  Future<String?> escuchar() async {
    escuchas++;
    return texto;
  }

  @override
  Future<void> detener() async {}
}

/// Voz de salida falsa para pruebas: guarda lo que se le pidió decir.
class VozSalidaFalsa implements VozSalida {
  final dichas = <String>[];

  @override
  Future<void> hablar(String texto) async => dichas.add(texto);

  @override
  Future<void> detener() async {}
}

final vozEntradaProvider = Provider<VozEntrada>(
  (ref) => !kIsWeb && Platform.isAndroid
      ? VozEntradaTelefono()
      : const VozEntradaNoDisponible(),
);

final vozSalidaProvider = Provider<VozSalida>(
  (ref) => const VozSalidaNoDisponible(),
);

/// Si la persona activó leer las respuestas en voz alta. Apagado por omisión
/// y por sesión de la app: no se guarda.
class LeerEnVozAlta extends Notifier<bool> {
  @override
  bool build() => false;

  void fijar(bool activo) => state = activo;
}

final leerEnVozAltaProvider = NotifierProvider<LeerEnVozAlta, bool>(
  LeerEnVozAlta.new,
);

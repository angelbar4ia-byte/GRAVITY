/// El reproductor real, con `audioplayers` 6.8.1 (aprobado por el dueño el
/// 22/nov/2026). **Es el único archivo que importa el paquete.**
///
/// El plugin se crea al primer uso, no al arrancar la app. Solo se le dan
/// rutas del equipo (`DeviceFileSource`): nunca una dirección de red (R8).
///
/// Sin verificar en un aparato (spec 14, "Para probar en dispositivo"): que
/// suene en el Galaxy A52 y en Windows, que entre un archivo y el siguiente
/// no haya un silencio notable y cuánto tarda en empezar cada uno.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'reproductor_de_audio.dart';

class ReproductorAudioplayers implements ReproductorDeAudio {
  ReproductorAudioplayers();

  AudioPlayer? _jugador;

  AudioPlayer get _p =>
      _jugador ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  String? _ruta;

  @override
  Future<void> abrir(String rutaDeArchivo) async {
    _ruta = rutaDeArchivo;
    await _p.setSource(DeviceFileSource(rutaDeArchivo));
  }

  @override
  Future<void> reproducir() async {
    if (_ruta == null) return;
    await _p.resume();
  }

  @override
  Future<void> pausar() async => await _p.pause();

  @override
  Future<void> parar() async {
    if (_jugador == null) return;
    await _p.stop();
  }

  @override
  Future<void> fijarVelocidad(double factor) async =>
      await _p.setPlaybackRate(factor);

  @override
  Stream<Duration> get posicion => _p.onPositionChanged;

  @override
  Stream<void> get terminado => _p.onPlayerComplete;

  @override
  Future<void> liberar() async {
    final j = _jugador;
    _jugador = null;
    if (j != null) await j.dispose();
  }
}
